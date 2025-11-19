defmodule Mosslet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    flame_parent = FLAME.Parent.get()
    Logger.add_backend(Sentry.LoggerBackend)
    Oban.Telemetry.attach_default_logger()
    Mosslet.ObanReporter.attach()
    # nsfw_serving? = flame_parent || FLAME.Backend.impl() != FLAME.FlyBackend

    children =
      [
        # Start the RPC server
        {Fly.RPC, []},
        # Start the Ecto repository
        Mosslet.Repo.Local,
        # Start the tracker after your DB.
        {Fly.Postgres.LSN.Supervisor, repo: Mosslet.Repo.Local},
        # Start the Cloak vault.
        Mosslet.Vault,
        # Start DNS clustering,
        !flame_parent &&
          {DNSCluster, query: Application.get_env(:mosslet, :dns_cluster_query) || :ignore},
        # Start the Telemetry supervisor
        MossletWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: Mosslet.PubSub},
        # Start Phoenix Presence for privacy-first activity tracking
        MossletWeb.Presence,
        # Start BackgroundTask
        {Task.Supervisor, name: Mosslet.BackgroundTask},
        # Start Finch
        {Finch, name: Mosslet.Finch},
        # Start OpenAI Finch
        {Finch, name: Mosslet.OpenAIFinch},
        # Start ExMarcel's mime type dictionary storage
        ExMarcel.TableWrapper,
        # Start the ETS AvatarProcessor
        Mosslet.Extensions.AvatarProcessor,
        # Start the ETS MemoryProcessor
        Mosslet.Extensions.MemoryProcessor,
        # Start the URL Preview Server for previewing post urls
        Mosslet.Extensions.URLPreviewServer,
        # Start the Timeline Cache (separate from avatar cache)
        Mosslet.Timeline.Performance.TimelineCache,
        # Start the Email Notifications Processor (coordinator)
        Mosslet.Notifications.EmailNotificationsProcessor,
        # Start the Email Notifications GenServer (rate-limited email processing)
        {Mosslet.Notifications.EmailNotificationsGenServer, []},
        # Start the Timeline GenServer (background timeline processing)
        {Mosslet.Timeline.Performance.TimelineGenServer, []},
        # Start the Storj Task Supervisor,
        {Task.Supervisor, name: Mosslet.StorjTask},
        # Start PlugAttack storage (1 hour = 3_600_000 milliseconds)
        {PlugAttack.Storage.Ets, name: MossletWeb.PlugAttack.Storage, clean_period: 3_600_000},
        # Start the Endpoint (http/https)
        # Start Oban supervision.
        {Oban, oban_config()},
        # Start the word retrieval GenServer API for password generator.
        {Mosslet.Extensions.PasswordGenerator.WordRepository, %{}},
        # Start the Flame and filter out non-parents and
        # the Endpoint
        {FLAME.Pool,
         name: Mosslet.MediaRunner,
         min: 0,
         max: 5,
         max_concurrency: 10,
         min_idle_shutdown_after: :timer.seconds(30),
         idle_shutdown_after: :timer.seconds(30),
         log: :info},
        !flame_parent && MossletWeb.Endpoint,
        # Delated serving Nx
        {Mosslet.DelayedServing,
         serving_name: NsfwImageDetection,
         serving_fn: fn -> Mosslet.AI.NsfwImageDetection.serving() end}
      ]
      |> Enum.filter(& &1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mosslet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MossletWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Conditionally disable queues or plugins here.
  defp oban_config do
    # If we are running in the primary region where we have direct access to a
    # writable database, then use the application config. If running in
    # non-primary regions, disable queues and plugins. No jobs will be run
    # there.

    # if using `fly_rpc`, the if condition could be `if Fly.is_primary?() do`
    if System.fetch_env!("PRIMARY_REGION") == System.fetch_env!("FLY_REGION") do
      Logger.info("Oban running in primary region. Activated.")
      Application.fetch_env!(:mosslet, Oban)
    else
      Logger.info("Oban disabled when running in non-primary region.")
      [repo: Mosslet.Repo, queues: false, plugins: false, peer: false]
    end
  end
end
