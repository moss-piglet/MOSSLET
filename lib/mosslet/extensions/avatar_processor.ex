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
    # 60 second buffer
    expires_at = System.system_time(:second) + 60
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
      [{^key, expires_at}] when expires_at > now ->
        true

      [{^key, _expired}] ->
        :ets.delete(__MODULE__, key)
        false

      [] ->
        false
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

    # Subscribe to global avatar cache invalidation (for multi-instance deployments)
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "avatar_cache_global")

    # schedule_sweep()
    {:ok, nil}
  end

  # Handle global avatar update - clear local cache and update with new data
  def handle_info({:avatar_updated, connection_id, encrypted_blob}, state) do
    # Clear both possible cache keys
    delete_ets_avatar(connection_id)
    delete_ets_avatar("profile-#{connection_id}")

    # Put the new avatar in local cache
    put_ets_avatar("profile-#{connection_id}", encrypted_blob)

    # Mark as recently updated to prevent S3 re-fetch
    mark_avatar_recently_updated(connection_id)

    {:noreply, state}
  end

  # Handle global avatar deletion - clear local cache
  def handle_info({:avatar_deleted, connection_id}, state) do
    # Clear both possible cache keys
    delete_ets_avatar(connection_id)
    delete_ets_avatar("profile-#{connection_id}")

    # Mark as recently updated to prevent S3 re-fetch of deleted avatar
    mark_avatar_recently_updated(connection_id)

    {:noreply, state}
  end

  # Catch-all for unknown messages
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
