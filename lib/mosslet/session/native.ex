defmodule Mosslet.Session.Native do
  @moduledoc """
  Native session management for desktop/mobile apps.

  Stores JWT tokens and session state for native apps that authenticate
  via the API instead of browser sessions.

  ## Storage

  - Uses ETS for in-memory token storage during runtime
  - Tokens can be persisted to SQLite for offline support

  ## Usage

      # After successful login
      Mosslet.Session.Native.store_session(user_id, token, user_data)

      # Get current token for API requests
      {:ok, token} = Mosslet.Session.Native.get_token()

      # Check if logged in
      Mosslet.Session.Native.logged_in?()

      # Clear on logout
      Mosslet.Session.Native.clear_session()
  """

  use GenServer

  @table_name :mosslet_native_session

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end

  @doc """
  Stores session data after successful authentication.
  """
  def store_session(user_id, token, user_data \\ %{}) do
    GenServer.call(__MODULE__, {:store_session, user_id, token, user_data})
  end

  @doc """
  Stores just the token (convenience function).
  """
  def store_token(token) do
    GenServer.call(__MODULE__, {:store_token, token})
  end

  @doc """
  Gets the current JWT token.
  """
  def get_token do
    case :ets.lookup(@table_name, :token) do
      [{:token, token}] -> {:ok, token}
      [] -> {:error, :no_token}
    end
  rescue
    ArgumentError -> {:error, :no_session}
  end

  @doc """
  Gets the current user ID.
  """
  def get_user_id do
    case :ets.lookup(@table_name, :user_id) do
      [{:user_id, user_id}] -> {:ok, user_id}
      [] -> {:error, :no_user}
    end
  rescue
    ArgumentError -> {:error, :no_session}
  end

  @doc """
  Gets cached user data.
  """
  def get_user_data do
    case :ets.lookup(@table_name, :user_data) do
      [{:user_data, user_data}] -> {:ok, user_data}
      [] -> {:error, :no_user_data}
    end
  rescue
    ArgumentError -> {:error, :no_session}
  end

  @doc """
  Checks if a user is logged in.
  """
  def logged_in? do
    case get_token() do
      {:ok, _token} -> true
      _ -> false
    end
  end

  @doc """
  Clears all session data.
  """
  def clear_session do
    GenServer.call(__MODULE__, :clear_session)
  end

  @doc """
  Updates the token (e.g., after refresh).
  """
  def update_token(new_token) do
    GenServer.call(__MODULE__, {:update_token, new_token})
  end

  @impl true
  def handle_call({:store_session, user_id, token, user_data}, _from, state) do
    :ets.insert(@table_name, {:user_id, user_id})
    :ets.insert(@table_name, {:token, token})
    :ets.insert(@table_name, {:user_data, user_data})
    :ets.insert(@table_name, {:logged_in_at, DateTime.utc_now()})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_token, token}, _from, state) do
    :ets.insert(@table_name, {:token, token})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_token, new_token}, _from, state) do
    :ets.insert(@table_name, {:token, new_token})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_session, _from, state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, state}
  end
end
