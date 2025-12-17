# Desktop-specific configuration for native app builds
# This config is used when building for macOS, Windows, Linux, iOS, or Android
#
# Note: Runtime configuration (database path, secret keys) is handled in runtime.exs
# because config provider tuples don't work in development mode.

import Config

config :mosslet,
  env: :desktop

config :mosslet,
  ecto_repos: [Mosslet.Repo.SQLite]

config :mosslet,
  sync_api_url: "https://mosslet.com/api"

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
