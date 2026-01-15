defmodule Mosslet.AI.ServingManager do
  @moduledoc """
  Manages multiple Nx.Serving instances for privacy-first AI models.

  Starts models asynchronously to avoid blocking application startup.
  Each model is loaded in sequence to manage memory on smaller instances.

  ## Models Managed

  - NsfwImageDetection: Falconsai NSFW image classification
  - TextModeration: toxic-bert for content moderation

  These provide server-side fallback when client-side WebLLM fails.
  """
  use GenServer
  require Logger

  @models [
    {NsfwImageDetection, &Mosslet.AI.NsfwImageDetection.serving/0},
    {TextModeration, &Mosslet.AI.TextModeration.serving/0}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    state = %{
      models: @models,
      loaded: %{},
      loading: nil,
      queue: @models
    }

    send(self(), :load_next)

    {:ok, state}
  end

  def handle_info(:load_next, %{queue: []} = state) do
    Logger.info("All AI models loaded: #{inspect(Map.keys(state.loaded))}")
    {:noreply, state}
  end

  def handle_info(:load_next, %{queue: [{name, serving_fn} | rest]} = state) do
    server = self()

    spawn(fn ->
      Logger.info("Loading AI model: #{inspect(name)}")

      try do
        serving = serving_fn.()
        send(server, {:model_loaded, name, serving})
      rescue
        e ->
          Logger.error("Failed to load #{inspect(name)}: #{Exception.message(e)}")
          send(server, {:model_failed, name})
      end
    end)

    {:noreply, %{state | loading: name, queue: rest}}
  end

  def handle_info({:model_loaded, name, serving}, state) do
    case Nx.Serving.start_link(name: name, serving: serving, batch_timeout: 50) do
      {:ok, _pid} ->
        Logger.info("AI model started: #{inspect(name)}")

      {:error, {:already_started, _pid}} ->
        Logger.info("AI model already running: #{inspect(name)}")

      error ->
        Logger.error("Failed to start serving #{inspect(name)}: #{inspect(error)}")
    end

    new_state = %{state | loaded: Map.put(state.loaded, name, true), loading: nil}
    send(self(), :load_next)
    {:noreply, new_state}
  end

  def handle_info({:model_failed, name}, state) do
    Logger.warning("Skipping failed model: #{inspect(name)}")
    new_state = %{state | loading: nil}
    send(self(), :load_next)
    {:noreply, new_state}
  end

  @doc """
  Check if a specific model is loaded and available.
  """
  def model_available?(name) do
    try do
      GenServer.call(__MODULE__, {:model_available?, name}, 100)
    catch
      :exit, _ -> false
    end
  end

  def handle_call({:model_available?, name}, _from, state) do
    {:reply, Map.get(state.loaded, name, false), state}
  end

  def handle_call(:loaded_models, _from, state) do
    {:reply, Map.keys(state.loaded), state}
  end

  @doc """
  List all loaded models.
  """
  def loaded_models do
    try do
      GenServer.call(__MODULE__, :loaded_models, 100)
    catch
      :exit, _ -> []
    end
  end
end
