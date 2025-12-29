defmodule Mosslet.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    if Mosslet.Platform.native?() do
      Desktop.identify_default_locale(MossletWeb.Gettext)
      Mosslet.Platform.Config.ensure_data_directory!()
    end

    unless Mosslet.Platform.native?() do
      Logger.add_backend(Sentry.LoggerBackend)
      Oban.Telemetry.attach_default_logger()
      Mosslet.ObanReporter.attach()
    end

    children = build_children()

    opts = [strategy: :one_for_one, name: Mosslet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    MossletWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp build_children do
    if Mosslet.Platform.native?() do
      native_children()
    else
      web_children()
    end
  end

  defp native_children do
    [
      MossletWeb.Telemetry,
      {Phoenix.PubSub, name: Mosslet.PubSub},
      MossletWeb.Presence,
      {Task.Supervisor, name: Mosslet.BackgroundTask},
      {Finch, name: Mosslet.Finch},
      ExMarcel.TableWrapper,
      Mosslet.Extensions.AvatarProcessor,
      Mosslet.Extensions.BannerProcessor,
      Mosslet.Extensions.MemoryProcessor,
      Mosslet.Repo.SQLite,
      Mosslet.Vault.Native,
      Mosslet.Session.Native,
      Mosslet.Sync,
      MossletWeb.Endpoint,
      MossletWeb.Desktop.Window.child_spec()
    ]
  end

  defp web_children do
    flame_parent = FLAME.Parent.get()

    [
      {Fly.RPC, []},
      Mosslet.Repo.Local,
      {Fly.Postgres.LSN.Supervisor, repo: Mosslet.Repo.Local},
      Mosslet.Vault,
      {Phoenix.PubSub, name: Mosslet.PubSub},
      !flame_parent &&
        {DNSCluster, query: Application.get_env(:mosslet, :dns_cluster_query) || :ignore},
      MossletWeb.Presence,
      {Task.Supervisor, name: Mosslet.BackgroundTask},
      {Finch, name: Mosslet.Finch},
      {PlugAttack.Storage.Ets, name: MossletWeb.PlugAttack.Storage, clean_period: 3_600_000},
      Mosslet.Security.BotDefense,
      MossletWeb.Telemetry,
      !flame_parent && MossletWeb.Endpoint,
      {Finch, name: Mosslet.OpenAIFinch},
      ExMarcel.TableWrapper,
      Mosslet.Extensions.AvatarProcessor,
      Mosslet.Extensions.BannerProcessor,
      Mosslet.Extensions.MemoryProcessor,
      Mosslet.Extensions.URLPreviewServer,
      Mosslet.Timeline.Performance.TimelineCache,
      Mosslet.Notifications.EmailNotificationsProcessor,
      {Mosslet.Notifications.EmailNotificationsGenServer, []},
      {Mosslet.Notifications.ReplyNotificationsGenServer, []},
      {Mosslet.Timeline.Performance.TimelineGenServer, []},
      {Task.Supervisor, name: Mosslet.StorjTask},
      flame_parent &&
        {Mosslet.DelayedServing,
         serving_name: Mosslet.AI.NsfwServing,
         serving_fn: fn -> Mosslet.AI.NsfwImageDetection.serving() end},
      Mosslet.Security.BotDetector,
      {Oban, oban_config()},
      {Mosslet.Extensions.PasswordGenerator.WordRepository, %{}},
      {FLAME.Pool,
       name: Mosslet.MediaRunner,
       min: 0,
       max: 5,
       max_concurrency: 10,
       min_idle_shutdown_after: :timer.minutes(5),
       idle_shutdown_after: :timer.minutes(2),
       log: :info}
    ]
    |> Enum.filter(& &1)
  end

  defp oban_config do
    primary_region = System.get_env("PRIMARY_REGION")
    fly_region = System.get_env("FLY_REGION")

    cond do
      is_nil(primary_region) or is_nil(fly_region) ->
        Logger.info("Oban running in dev/test (no FLY_REGION set). Activated.")
        Application.fetch_env!(:mosslet, Oban)

      primary_region == fly_region ->
        Logger.info("Oban running in primary region. Activated.")
        Application.fetch_env!(:mosslet, Oban)

      true ->
        Logger.info("Oban disabled when running in non-primary region.")

        [
          repo: Mosslet.Repo,
          queues: false,
          plugins: false,
          peer: false,
          notifier: Oban.Notifiers.PG
        ]
    end
  end
end
