defmodule Mosslet.Security.BotDetector do
  @moduledoc """
  Automatic bot detection logic.

  Detects suspicious traffic patterns and triggers automatic bans through BotDefense.

  ## Detection Methods

  - **Rate Limiting**: Tracks request counts per IP, auto-bans on threshold violations
  - **Bot User Agents**: Detects known malicious bot signatures
  - **Honeypot Triggers**: Flags IPs that access hidden honeypot endpoints
  - **Suspicious Patterns**: Detects path traversal, SQL injection attempts, etc.

  ## Configuration

  Configure thresholds in config:

      config :mosslet, Mosslet.Security.BotDetector,
        rate_limit_window: 60_000,
        rate_limit_max: 100,
        rate_limit_ban_duration: :timer.hours(1),
        auto_ban_enabled: true
  """
  use GenServer
  require Logger

  alias Mosslet.Security.BotDefense

  @ets_table :bot_detector_requests
  @cleanup_interval :timer.seconds(30)

  @default_config %{
    rate_limit_window: 60_000,
    rate_limit_max: 100,
    rate_limit_ban_duration: :timer.hours(1),
    burst_window: 5_000,
    burst_max: 30,
    auto_ban_enabled: true
  }

  @known_bad_bots ~w(
    ahrefsbot
    semrushbot
    dotbot
    mj12bot
    blexbot
    seekportbot
    petalbot
    bytespider
    gptbot
    ccbot
    claudebot
    anthropic
    dataforseobot
    serpstatbot
  )

  @suspicious_patterns [
    # Path traversal
    ~r/\.\.\/|\.\.\\/,
    # SQL injection
    ~r/\bunion\b.*\bselect\b/i,
    # XSS attempts
    ~r/<script/i,
    # Code injection
    ~r/\bexec\b|\beval\b/i,
    # Common scan targets
    ~r/\.env|\.git|wp-admin|phpmy/i,
    # LFI attempts
    ~r/etc\/passwd|proc\/self/i
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze a connection for bot/suspicious activity.
  Returns `{:ok, :allow}` or `{:ban, reason, source}`.
  """
  def analyze(conn) do
    ip = conn.remote_ip
    path = conn.request_path
    user_agent = get_user_agent(conn)

    config = get_config()

    cond do
      not config.auto_ban_enabled ->
        {:ok, :allow}

      bad_bot?(user_agent) ->
        Logger.warning("Bad bot detected: #{inspect(ip)} - #{user_agent}")

        BotDefense.ban_ip(ip,
          reason: "Known malicious bot: #{user_agent}",
          source: :suspicious,
          expires_at: nil
        )

        {:ban, "Known malicious bot: #{user_agent}", :suspicious}

      suspicious_path?(path) ->
        Logger.warning("Suspicious path accessed: #{inspect(ip)} - #{path}")

        BotDefense.ban_ip(ip,
          reason: "Suspicious request path: #{path}",
          source: :suspicious,
          expires_at: nil
        )

        {:ban, "Suspicious request path: #{path}", :suspicious}

      rate_limited?(ip, config) ->
        {:ban, "Rate limit exceeded", :rate_limit}

      true ->
        track_request(ip)
        {:ok, :allow}
    end
  end

  @doc """
  Record a honeypot trigger and ban the IP.
  Call this from honeypot endpoints.
  """
  def honeypot_triggered(ip, path) when is_tuple(ip) do
    config = get_config()

    if config.auto_ban_enabled do
      Logger.warning("Honeypot triggered: #{inspect(ip)} accessed #{path}")

      BotDefense.ban_ip(ip,
        reason: "Honeypot triggered: #{path}",
        source: :honeypot,
        expires_at: nil
      )
    end
  end

  @doc """
  Check if a user agent matches known bad bots.
  """
  def bad_bot?(nil), do: false

  def bad_bot?(user_agent) do
    ua_lower = String.downcase(user_agent)

    Enum.any?(@known_bad_bots, fn bot ->
      String.contains?(ua_lower, bot)
    end)
  end

  @doc """
  Check if a path contains suspicious patterns.
  """
  def suspicious_path?(path) do
    Enum.any?(@suspicious_patterns, fn pattern ->
      Regex.match?(pattern, path)
    end)
  end

  @doc """
  Get current detection statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @impl true
  def init(_opts) do
    :ets.new(@ets_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()

    {:ok, %{banned_count: 0}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    tracked_ips = :ets.info(@ets_table, :size)
    {:reply, Map.put(state, :tracked_ips, tracked_ips), state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> nil
    end
  end

  defp rate_limited?(ip, config) do
    ip_hash = BotDefense.hash_ip(ip)
    now = System.monotonic_time(:millisecond)
    window_start = now - config.rate_limit_window
    burst_start = now - config.burst_window

    case :ets.lookup(@ets_table, ip_hash) do
      [{^ip_hash, requests}] ->
        recent = Enum.filter(requests, fn ts -> ts > window_start end)
        burst = Enum.filter(requests, fn ts -> ts > burst_start end)

        cond do
          length(recent) >= config.rate_limit_max ->
            auto_ban(
              ip,
              config,
              "Rate limit: #{length(recent)} requests in #{config.rate_limit_window}ms"
            )

            true

          length(burst) >= config.burst_max ->
            auto_ban(
              ip,
              config,
              "Burst limit: #{length(burst)} requests in #{config.burst_window}ms"
            )

            true

          true ->
            false
        end

      [] ->
        false
    end
  end

  defp track_request(ip) do
    ip_hash = BotDefense.hash_ip(ip)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@ets_table, ip_hash) do
      [{^ip_hash, requests}] ->
        :ets.insert(@ets_table, {ip_hash, [now | requests]})

      [] ->
        :ets.insert(@ets_table, {ip_hash, [now]})
    end
  end

  defp auto_ban(ip, config, reason) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(config.rate_limit_ban_duration, :millisecond)

    Logger.warning("Auto-banning IP: #{inspect(ip)} - #{reason}")

    BotDefense.ban_ip(ip,
      reason: reason,
      source: :rate_limit,
      expires_at: expires_at
    )
  end

  defp cleanup_old_entries do
    config = get_config()
    cutoff = System.monotonic_time(:millisecond) - config.rate_limit_window

    :ets.tab2list(@ets_table)
    |> Enum.each(fn {ip_hash, requests} ->
      recent = Enum.filter(requests, fn ts -> ts > cutoff end)

      if recent == [] do
        :ets.delete(@ets_table, ip_hash)
      else
        :ets.insert(@ets_table, {ip_hash, recent})
      end
    end)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  defp get_config do
    app_config = Application.get_env(:mosslet, __MODULE__, [])
    Map.merge(@default_config, Map.new(app_config))
  end
end
