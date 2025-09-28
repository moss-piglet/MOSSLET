defmodule Mosslet.Extensions.AvatarProcessor do
  @moduledoc """
  A GenServer to handle the temp storage of
  people's encrypted avatars.
  """
  use GenServer

  ## Client

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put_ets_avatar(key, value) do
    :ets.insert(__MODULE__, {key, value})
  end

  def get_ets_avatar(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  def delete_ets_avatar(key) do
    :ets.delete(__MODULE__, key)
  end
  
  @doc """
  Mark an avatar as recently updated to prevent stale S3 fetches
  during database replication lag (especially during deployments).
  """
  def mark_avatar_recently_updated(connection_id) do
    key = "no_fetch:#{connection_id}"
    expires_at = System.system_time(:second) + 60  # 60 second buffer
    :ets.insert(__MODULE__, {key, expires_at})
  end
  
  @doc """
  Check if an avatar was recently updated and should not be fetched from S3.
  This prevents showing old avatars due to database replication lag.
  """
  def avatar_recently_updated?(connection_id) do
    key = "no_fetch:#{connection_id}"
    now = System.system_time(:second)
    
    case :ets.lookup(__MODULE__, key) do
      [{^key, expires_at}] when expires_at > now -> true
      [{^key, _expired}] -> 
        :ets.delete(__MODULE__, key)
        false
      [] -> false
    end
  end

  ## Server
  def init(_) do
    :ets.new(__MODULE__, [
      :ordered_set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    # schedule_sweep()
    {:ok, nil}
  end

  # def handle_info(:sweep, state) do
  #  :ets.delete_all_objects(@tab)
  #  schedule_sweep()
  #  {:noreply, state}
  # end

  # defp schedule_sweep do
  #  Process.send_after(self(), :sweep, @sweep_after)
  # end
end
