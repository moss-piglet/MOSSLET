defmodule Mosslet.Security.BotDefense do
  @moduledoc """
  GenServer for managing IP bans with ETS-backed fast lookups.

  ## Features

  - Fast O(1) IP ban lookups via ETS
  - Automatic ban expiration cleanup
  - Database persistence for bans that survive restarts
  - Real-time PubSub notifications for admin dashboard
  - Support for multiple ban sources (manual, rate_limit, honeypot, cloud_ip)

  ## Architecture

  - ETS table stores HMAC hashes of banned IPs for fast lookups
  - Database stores full ban records with encrypted metadata
  - GenServer coordinates writes and periodic cleanup
  - Plug checks ETS before requests reach router
  """
  use GenServer
  require Logger

  alias Mosslet.Security.IpBan
  alias Mosslet.Repo
  import Ecto.Query

  @ets_table :bot_defense_bans
  @cleanup_interval :timer.minutes(5)
  @flush_interval :timer.seconds(30)
  @pubsub_topic "bot_defense"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if an IP is banned. Returns true/false.
  This is called from the Plug and must be fast.
  """
  def banned?(ip) when is_tuple(ip) do
    ip_hash = hash_ip(ip)

    case :ets.lookup(@ets_table, ip_hash) do
      [{^ip_hash, expires_at}] ->
        if expires_at == :permanent or DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          true
        else
          :ets.delete(@ets_table, ip_hash)
          false
        end

      [] ->
        false
    end
  end

  def banned?(_), do: false

  @doc """
  Ban an IP address.

  ## Options

  - `:reason` - Human-readable reason for the ban
  - `:source` - Ban source (:manual, :rate_limit, :honeypot, :cloud_ip, :suspicious)
  - `:expires_at` - DateTime when ban expires (nil for permanent)
  - `:banned_by_id` - User ID of admin who issued the ban (for manual bans)
  - `:metadata` - Additional metadata map
  """
  def ban_ip(ip, opts \\ []) when is_tuple(ip) do
    GenServer.call(__MODULE__, {:ban_ip, ip, opts})
  end

  @doc """
  Unban an IP address.
  """
  def unban_ip(ip) when is_tuple(ip) do
    GenServer.call(__MODULE__, {:unban_ip, ip})
  end

  @doc """
  List all current bans. Returns list of IpBan structs.
  """
  def list_bans(opts \\ []) do
    GenServer.call(__MODULE__, {:list_bans, opts})
  end

  @doc """
  Get ban count statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Increment the request count for a banned IP (tracks how many blocked requests).
  """
  def increment_blocked_request(ip) when is_tuple(ip) do
    GenServer.cast(__MODULE__, {:increment_blocked, ip})
  end

  @doc """
  Subscribe to bot defense events for real-time admin updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, @pubsub_topic)
  end

  @doc """
  Get the HMAC hash of an IP for lookups.
  """
  def hash_ip(ip) when is_tuple(ip) do
    ip_string = :inet.ntoa(ip) |> to_string()
    Mosslet.Encrypted.HMAC.dump(ip_string) |> elem(1)
  end

  ## GenServer Implementation

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [:set, :public, :named_table, read_concurrency: true])

    send(self(), :load_bans)
    schedule_cleanup()
    schedule_flush()

    {:ok, %{pending_increments: %{}}}
  end

  @impl true
  def handle_info(:load_bans, state) do
    load_bans_from_db()
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_bans()
    schedule_cleanup()
    {:noreply, state}
  end

  @impl true
  def handle_info(:flush_increments, state) do
    flush_pending_increments(state.pending_increments)
    schedule_flush()
    {:noreply, %{state | pending_increments: %{}}}
  end

  @impl true
  def handle_call({:ban_ip, ip, opts}, _from, state) do
    result = do_ban_ip(ip, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:unban_ip, ip}, _from, state) do
    result = do_unban_ip(ip)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:list_bans, opts}, _from, state) do
    bans = do_list_bans(opts)
    {:reply, bans, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = do_get_stats()
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:increment_blocked, ip}, state) do
    ip_string = :inet.ntoa(ip) |> to_string()
    pending = Map.update(state.pending_increments, ip_string, 1, &(&1 + 1))
    {:noreply, %{state | pending_increments: pending}}
  end

  ## Private Implementation

  defp do_ban_ip(ip, opts) do
    ip_hash = hash_ip(ip)
    expires_at = Keyword.get(opts, :expires_at)
    source = Keyword.get(opts, :source, :manual)

    attrs = %{
      ip_hash: :inet.ntoa(ip) |> to_string(),
      reason: Keyword.get(opts, :reason),
      source: source,
      expires_at: expires_at,
      metadata: Keyword.get(opts, :metadata, %{}),
      banned_by_id: Keyword.get(opts, :banned_by_id)
    }

    case Repo.transaction_on_primary(fn ->
           %IpBan{}
           |> IpBan.changeset(attrs)
           |> Repo.insert(on_conflict: :replace_all, conflict_target: :ip_hash)
         end) do
      {:ok, {:ok, ban}} ->
        ets_expires = if expires_at, do: expires_at, else: :permanent
        :ets.insert(@ets_table, {ip_hash, ets_expires})

        broadcast({:ip_banned, ban})
        Logger.info("IP banned: #{inspect(ip)} source=#{source}")

        {:ok, ban}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  defp do_unban_ip(ip) do
    ip_hash = hash_ip(ip)
    ip_string = :inet.ntoa(ip) |> to_string()

    case Repo.transaction_on_primary(fn ->
           from(b in IpBan, where: b.ip_hash == ^ip_string)
           |> Repo.delete_all()
         end) do
      {:ok, {count, _}} when count > 0 ->
        :ets.delete(@ets_table, ip_hash)
        broadcast({:ip_unbanned, ip})
        Logger.info("IP unbanned: #{inspect(ip)}")
        :ok

      {:ok, {0, _}} ->
        {:error, :not_found}

      error ->
        error
    end
  end

  defp do_list_bans(opts) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    source_filter = Keyword.get(opts, :source)

    query = from(b in IpBan, order_by: [desc: b.inserted_at], limit: ^limit, offset: ^offset)

    query =
      if source_filter do
        from(b in query, where: b.source == ^source_filter)
      else
        query
      end

    Repo.all(query)
  end

  defp do_get_stats do
    total = Repo.aggregate(IpBan, :count, :id) || 0

    by_source =
      from(b in IpBan,
        group_by: b.source,
        select: {b.source, count(b.id)}
      )
      |> Repo.all()
      |> Map.new()

    total_blocked =
      from(b in IpBan, select: sum(b.request_count))
      |> Repo.one() || 0

    %{
      total_bans: total,
      by_source: by_source,
      total_blocked_requests: total_blocked,
      ets_entries: :ets.info(@ets_table, :size)
    }
  end

  defp flush_pending_increments(pending) when map_size(pending) == 0, do: :ok

  defp flush_pending_increments(pending) do
    Repo.transaction_on_primary(fn ->
      Enum.each(pending, fn {ip_string, count} ->
        from(b in IpBan, where: b.ip_hash == ^ip_string)
        |> Repo.update_all(inc: [request_count: count])
      end)
    end)
  end

  defp load_bans_from_db do
    now = DateTime.utc_now()

    IpBan
    |> Repo.all()
    |> Enum.each(fn ban ->
      cond do
        is_nil(ban.expires_at) ->
          :ets.insert(@ets_table, {ban.ip_hash, :permanent})

        DateTime.compare(ban.expires_at, now) == :gt ->
          :ets.insert(@ets_table, {ban.ip_hash, ban.expires_at})

        true ->
          :ok
      end
    end)

    Logger.info("BotDefense: Loaded #{:ets.info(@ets_table, :size)} bans into ETS")
  end

  defp cleanup_expired_bans do
    now = DateTime.utc_now()

    expired_hashes =
      :ets.tab2list(@ets_table)
      |> Enum.filter(fn {_hash, expires_at} ->
        expires_at != :permanent and DateTime.compare(expires_at, now) != :gt
      end)
      |> Enum.map(fn {hash, _} -> hash end)

    Enum.each(expired_hashes, fn hash ->
      :ets.delete(@ets_table, hash)
    end)

    if expired_hashes != [] do
      Repo.transaction_on_primary(fn ->
        from(b in IpBan, where: b.ip_hash in ^expired_hashes)
        |> Repo.delete_all()
      end)

      Logger.info("BotDefense: Cleaned up #{length(expired_hashes)} expired bans")
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired, @cleanup_interval)
  end

  defp schedule_flush do
    Process.send_after(self(), :flush_increments, @flush_interval)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, @pubsub_topic, message)
  end
end
