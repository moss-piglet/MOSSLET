defmodule Mosslet.Extensions.BannerProcessor do
  @moduledoc """
  A GenServer to handle the temp storage of
  users' encrypted banners in ETS for fast loading.

  Only caches the current user's own banner.
  Stores encrypted binary data - decryption happens on read.
  """
  use GenServer

  @ttl_seconds 600

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def put_banner(connection_id, encrypted_binary) do
    expires_at = System.system_time(:second) + @ttl_seconds
    :ets.insert(__MODULE__, {cache_key(connection_id), encrypted_binary, expires_at})
  end

  def get_banner(connection_id) do
    key = cache_key(connection_id)
    now = System.system_time(:second)

    case :ets.lookup(__MODULE__, key) do
      [{^key, encrypted_binary, expires_at}] when expires_at > now ->
        encrypted_binary

      [{^key, _encrypted_binary, _expired}] ->
        :ets.delete(__MODULE__, key)
        nil

      [] ->
        nil
    end
  end

  def delete_banner(connection_id) do
    :ets.delete(__MODULE__, cache_key(connection_id))
  end

  def mark_banner_recently_updated(connection_id) do
    key = "no_fetch:#{connection_id}"
    expires_at = System.system_time(:second) + 60
    :ets.insert(__MODULE__, {key, expires_at})
  end

  def banner_recently_updated?(connection_id) do
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

  defp cache_key(connection_id), do: "banner:#{connection_id}"

  def init(_) do
    :ets.new(__MODULE__, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Phoenix.PubSub.subscribe(Mosslet.PubSub, "banner_cache_global")

    schedule_sweep()
    {:ok, nil}
  end

  def handle_info({:banner_updated, connection_id, encrypted_binary}, state) do
    delete_banner(connection_id)
    put_banner(connection_id, encrypted_binary)
    mark_banner_recently_updated(connection_id)
    {:noreply, state}
  end

  def handle_info({:banner_deleted, connection_id}, state) do
    delete_banner(connection_id)
    mark_banner_recently_updated(connection_id)
    {:noreply, state}
  end

  def handle_info(:sweep_expired, state) do
    sweep_expired_entries()
    schedule_sweep()
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep_expired, :timer.minutes(5))
  end

  defp sweep_expired_entries do
    now = System.system_time(:second)

    __MODULE__
    |> :ets.tab2list()
    |> Enum.each(fn
      {key, _binary, expires_at} when expires_at <= now ->
        :ets.delete(__MODULE__, key)

      {key, expires_at} when is_integer(expires_at) and expires_at <= now ->
        :ets.delete(__MODULE__, key)

      _ ->
        :ok
    end)
  end
end
