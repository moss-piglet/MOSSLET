# Desktop-specific configuration for native app builds
# This config is used when building for macOS, Windows, Linux, iOS, or Android

import Config

config :mosslet,
  env: :desktop

config :mosslet,
  ecto_repos: [Mosslet.Repo.SQLite]

config :mosslet, Mosslet.Repo.SQLite,
  database: {:mosslet, Mosslet.Platform.Config, :sqlite_database_path, []},
  pool_size: 5,
  journal_mode: :wal,
  cache_size: -64_000,
  temp_store: :memory,
  synchronous: :normal

config :mosslet, MossletWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [port: 0],
  server: true,
  secret_key_base: {:mosslet, Mosslet.Platform.Config, :generate_secret, []},
  render_errors: [
    formats: [html: MossletWeb.ErrorHTML, json: MossletWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mosslet.PubSub,
  live_view: [signing_salt: {:mosslet, Mosslet.Platform.Config, :generate_salt, []}]

config :mosslet, :billing_provider, Mosslet.Billing.Providers.DesktopStripe

config :mosslet, Oban,
  repo: Mosslet.Repo.SQLite,
  notifier: Oban.Notifiers.PG,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
  ],
  queues: [
    default: 5,
    sync: 3
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id],
  level: :info
