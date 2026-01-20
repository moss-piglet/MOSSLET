defmodule Mosslet.AI.ServingManager do
  @moduledoc """
  Manages Nx.Serving instances for privacy-first AI models with LAZY loading.

  Models are NOT loaded on startup to conserve memory. They are loaded
  on-demand when first needed (i.e., when OpenRouter is unavailable).

  This is important for 2GB Fly.io instances where eager loading would
  consume ~1GB+ of RAM before any actual work happens.

  ## Models Managed

  - NsfwImageDetection: Falconsai NSFW image classification
  - TextModeration: toxic-bert for content moderation
  """
  use GenServer
  require Logger

  @models %{
    NsfwImageDetection => &Mosslet.AI.NsfwImageDetection.serving/0,
    TextModeration => &Mosslet.AI.TextModeration.serving/0
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %{
      loaded: %{},
      loading: MapSet.new()
    }

    Logger.info("AI ServingManager started (lazy loading enabled - models load on first use)")
    {:ok, state}
  end

  @doc """
  Ensures a model is loaded and available. Loads it if not already loaded.
  Returns {:ok, name} when ready, {:error, reason} if loading fails.

  This is the main entry point for lazy loading - call this before using a model.
  """
  def ensure_loaded(name) do
    GenServer.call(__MODULE__, {:ensure_loaded, name}, 60_000)
  catch
    :exit, _ -> {:error, :serving_manager_unavailable}
  end

  @doc """
  Check if a specific model is loaded and available (without loading it).
  """
  def model_available?(name) do
    GenServer.call(__MODULE__, {:model_available?, name}, 100)
  catch
    :exit, _ -> false
  end

  @doc """
  List all loaded models.
  """
  def loaded_models do
    GenServer.call(__MODULE__, :loaded_models, 100)
  catch
    :exit, _ -> []
  end

  def handle_call({:ensure_loaded, name}, _from, state) do
    cond do
      Map.get(state.loaded, name) ->
        {:reply, {:ok, name}, state}

      MapSet.member?(state.loading, name) ->
        {:reply, {:error, :loading_in_progress}, state}

      true ->
        case load_model_sync(name) do
          {:ok, _} ->
            new_state = %{state | loaded: Map.put(state.loaded, name, true)}
            {:reply, {:ok, name}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:model_available?, name}, _from, state) do
    {:reply, Map.get(state.loaded, name, false), state}
  end

  def handle_call(:loaded_models, _from, state) do
    {:reply, Map.keys(state.loaded), state}
  end

  defp load_model_sync(name) do
    case Map.get(@models, name) do
      nil ->
        {:error, :unknown_model}

      serving_fn ->
        Logger.info("Lazy loading AI model: #{inspect(name)}")

        try do
          serving = serving_fn.()

          case Nx.Serving.start_link(name: name, serving: serving, batch_timeout: 50) do
            {:ok, _pid} ->
              Logger.info("AI model started: #{inspect(name)}")
              {:ok, name}

            {:error, {:already_started, _pid}} ->
              Logger.info("AI model already running: #{inspect(name)}")
              {:ok, name}

            error ->
              Logger.error("Failed to start serving #{inspect(name)}: #{inspect(error)}")
              {:error, error}
          end
        rescue
          e ->
            Logger.error("Failed to load #{inspect(name)}: #{Exception.message(e)}")
            {:error, Exception.message(e)}
        end
    end
  end
end
