# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mosslet,
  ecto_repos: [Mosslet.Repo.Local],
  generators: [binary_id: true]

config :mosslet,
  app_name: "MOSSLET",
  business_name: "Moss Piglet Corporation",
  support_email: "support@mosslet.com",
  mailer_default_from_name: "Support @ MOSSLET",
  mailer_default_from_email: "support@mosslet.com",
  logo_url_for_emails:
    "https://res.cloudinary.com/metamorphic/image/upload/v1717007234/Mosslet_Stacked_OnLight_pjn9w8.png",
  seo_description:
    "A social alternative that's simple and privacy-first. Ditch intrusive and stressful Big Tech social platforms for MOSSLET — a better alternative to Facebook, Twitter, and Instagram that's simple and privacy-first. Experience peace of mind.",
  github_url: "https://github.com/moss-piglet/mosslet",
  discord_url: "https://discord.gg/hjeUW39ytd",
  server_public_key: System.get_env("SERVER_PUBLIC_KEY"),
  server_private_key: System.get_env("SERVER_PRIVATE_KEY"),
  avatars_bucket: System.get_env("AVATARS_BUCKET"),
  memories_bucket: System.get_env("MEMORIES_BUCKET"),
  canonical_host: System.get_env("PHX_HOST"),
  plug_attack_ip_secret: System.get_env("PLUG_ATTACK_IP_SECRET"),
  s3_access_key_id: System.get_env("AWS_ACCESS_KEY_ID"),
  env: :dev

config :mosslet, Mosslet.Security.BotDetector,
  rate_limit_window: 60_000,
  rate_limit_max: 100,
  burst_window: 5_000,
  burst_max: 30,
  rate_limit_ban_duration: :timer.hours(1),
  auto_ban_enabled: true

# Configures the upload adapter for Trix uploads in dev
config :mosslet, :uploader, adapter: Mosslet.FileUploads.Tigris

config :mosslet, :language_options, [
  %{locale: "en", flag: "🇬🇧", label: "English"},
  %{locale: "fr", flag: "🇫🇷", label: "French"}
]

config :mosslet, Mosslet.Repo.Local, priv: "priv/repo"

# Configures the endpoint
config :mosslet, MossletWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MossletWeb.ErrorHTML, json: MossletWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mosslet.PubSub,
  live_view: [signing_salt: "U4JLNoF5"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mosslet, Mosslet.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --external:@emoji-mart/react --external:emoji-mart --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.10",
  default: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Jason for JSON converting encrypted lists
config :mosslet, Mosslet.Vault, json_library: Jason

# Configures Oban
config :mosslet, Oban,
  repo: Mosslet.Repo.Local,
  notifier: Oban.Notifiers.PG,
  plugins: [
    Oban.Met,
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    # Automatic cache maintenance (ethical performance optimization)
    {Oban.Plugins.Cron,
     crontab: [
       # Clean up expired cache entries every 30 minutes
       {"*/30 * * * *", Mosslet.Timeline.Jobs.CacheMaintenanceJob,
        args: %{"action" => "cleanup_expired"}},
       # Warm cache for active users every 15 minutes during peak hours (9 AM - 9 PM UTC)
       {"*/15 9-21 * * *", Mosslet.Timeline.Jobs.CacheMaintenanceJob,
        args: %{"action" => "warm_active_users", "time_window_minutes" => 30, "max_users" => 100}},
       # Cache statistics every 10 minutes for monitoring
       {"*/10 * * * *", Mosslet.Timeline.Jobs.CacheMaintenanceJob,
        args: %{"action" => "cache_stats", "include_details" => false}},
       # Memory optimization every 2 hours during low traffic (2 AM - 6 AM UTC)
       {"0 2,4,6 * * *", Mosslet.Timeline.Jobs.CacheMaintenanceJob,
        args: %{"action" => "optimize_cache", "optimization_type" => "memory_cleanup"}},
       # Ephemeral post cleanup every hour (privacy-respecting automatic deletion)
       {"0 * * * *", Mosslet.Timeline.Jobs.EphemeralPostCleanupJob,
        args: %{"action" => "cleanup_expired_posts", "cleanup_type" => "bulk_expired"}},
       # Log cleanup daily at 2 AM UTC (privacy-compliant 7-day retention)
       {"0 2 * * *", Mosslet.Logs.Jobs.LogCleanupJob, args: %{"action" => "cleanup_old_logs"}},
       # Key rotation monitoring - weekly check on Sundays at 3 AM UTC
       {"0 3 * * 0", Mosslet.Security.KeyRotationOrchestratorJob, args: %{"action" => "monitor"}},
       # Prune old IP bans weekly on Sundays at 4 AM UTC (90-day retention)
       {"0 4 * * 0", Mosslet.Workers.BanPruneWorker, args: %{"retention_days" => 90}},
       # Process referral payouts on 1st of each month at 9 AM UTC
       {"0 9 1 * *", Mosslet.Billing.Workers.MonthlyPayoutOrchestratorWorker},
       # Check for commissions that became available (hold period expired) daily at 6 AM UTC
       {"0 6 * * *", Mosslet.Billing.Workers.CommissionAvailabilityWorker}
     ]}
  ],
  queues: [
    default: 10,
    tokens: 10,
    invites: 10,
    storage: 10,
    timeline: 5,
    cache_maintenance: 2,
    ephemeral_cleanup: 3,
    email_notifications: 5,
    security: 3,
    key_rotation: 5
  ],
  peer: Oban.Peers.Global

# Configures cldr
config :ex_cldr,
  default_locale: "en",
  default_backend: Mosslet.Cldr

# Configures exaws
config :ex_aws,
  json_codec: Jason,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}],
  region: {:system, "AWS_REGION"}

config :ex_aws, :s3,
  scheme: "https",
  host: {:system, "AWS_HOST"}

config :ex_aws, :retries,
  max_attempts: 10,
  base_backoff_in_ms: 10,
  max_backoff_in_ms: 10_000

# Social login providers
# Full list of strategies: https://github.com/ueberauth/ueberauth/wiki/List-of-Strategies
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]},
    github: {Ueberauth.Strategy.Github, [default_scope: "user:email"]}
  ]

# SETUP_TODO - If you want to use Github auth, replace MyGithubUsername with your Github username
config :ueberauth, Ueberauth.Strategy.Github.OAuth,
  headers: [
    "user-agent": "MyGithubUsername"
  ]

config :mosslet, :passwordless_enabled, false

# Configure the time zone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configure langchain OpenAI key
config :langchain,
  openai_key: System.get_env("OPENAI_KEY"),
  openai_org_id: System.get_env("OPENAI_ORG_ID")

# Configure Nx
config :nx, :default_backend, {EXLA.Backend, client: :host}

# Configure Bumblebee cache
config :bumblebee, offline: System.get_env("BUMBLEBEE_OFFLINE")

# Configure image nsfw detection
config :image, :classifier,
  model: {:hf, "Falconsai/nsfw_image_detection"},
  featurizer: {:hf, "Falconsai/nsfw_image_detection"},
  featurizer_options: [module: Bumblebee.Vision.VitFeaturizer],
  name: Image.Classification.Server,
  autostart: true

# image social platform config
config :image, :social,
  default: :twitter,
  # Twitter/X cards
  twitter: [width: 1200, height: 675],
  facebook: [width: 1200, height: 630],
  linkedin: [width: 1200, height: 627]

# Configure Sentry error monitoring
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(production staging),
  environment_name: System.get_env("RELEASE_LEVEL") || "development"

# Configure Stripe
config :stripity_stripe,
  api_version: "2023-08-16",
  api_key: System.get_env("STRIPE_API_KEY"),
  signing_secret: System.get_env("STRIPE_WEBHOOK_SECRET")

# :user or :org (perhaps change to family)
config :mosslet, :billing_entity, :user
config :mosslet, :billing_provider, Mosslet.Billing.Providers.Stripe

config :mosslet,
       :billing_provider_subscription_link,
       "https://dashboard.stripe.com/test/subscriptions/"

# Configures Stripe billing products (Live mode)
# Note: You need to create the subscription prices in Stripe and replace the placeholder price IDs
config :mosslet, :billing_products, [
  %{
    id: "prod_SRGuwheF0yyKvy",
    name: "MOSSLET (Personal)",
    description:
      "Join month-to-month with the freedom to stay as long as you need. MOSSLET (Personal) is designed for individuals who value peace of mind and privacy. Bring a friend and share meaningful experiences in a safe and supportive environment.",
    most_popular: false,
    features: [
      "Unlimited Connections, Circles, and Posts",
      "Unlimited new features",
      "Streamlined settings",
      "Own your data",
      "Advanced asymmetric encryption",
      "Email support"
    ],
    line_items: [
      %{
        id: "personal-monthly",
        interval: :month,
        price: "price_1SgKEmJhDwcSIdON79ioytdO",
        quantity: 1,
        amount: 1000,
        save_percent: 50,
        trial_days: 14,
        allow_promotion_codes: true
      }
    ],
    mode: "subscription",
    subscription_data: %{trial_period_days: 14},
    automatic_tax: %{enabled: true}
  },
  %{
    id: "prod_SRGuwheF0yyKvy",
    name: "MOSSLET (Personal)",
    description:
      "Get a full year of access at our best rate. MOSSLET (Personal) is designed for individuals who value peace of mind and privacy. Bring a friend and join today to share meaningful experiences in a safe and supportive environment.",
    most_popular: true,
    features: [
      "Unlimited Connections, Circles, and Posts",
      "Unlimited new features",
      "Streamlined settings",
      "Own your data",
      "Advanced asymmetric encryption",
      "Email support",
      "Supports Affirm Payment Plans"
    ],
    line_items: [
      %{
        id: "personal-yearly",
        interval: :year,
        price: "price_1SgKFFJhDwcSIdONBVVpZeAB",
        quantity: 1,
        amount: 8000,
        save_percent: 50,
        trial_days: 14,
        allow_promotion_codes: true
      }
    ],
    mode: "subscription",
    subscription_data: %{trial_period_days: 14},
    automatic_tax: %{enabled: true}
  },
  %{
    id: "prod_SRGuwheF0yyKvy",
    name: "MOSSLET (Personal)",
    description:
      "Enjoy lifetime access with a one-time payment—your best value. MOSSLET (Personal) is designed for individuals who value peace of mind and privacy. Bring a friend and join today to share meaningful experiences in a safe and supportive environment.",
    most_popular: false,
    features: [
      "Unlimited Connections, Circles, and Posts",
      "Unlimited new features",
      "Streamlined settings",
      "Own your data",
      "Advanced asymmetric encryption",
      "Email support",
      "Supports Affirm Payment Plans"
    ],
    line_items: [
      %{
        id: "personal-lifetime",
        interval: :one_time,
        price: "price_1SgKE6JhDwcSIdONJTIsshiX",
        quantity: 1,
        amount: 25000,
        save_percent: 50,
        allow_promotion_codes: true
      }
    ],
    mode: "payment",
    automatic_tax: %{enabled: true}
  }
]

# Referral Program Configuration
config :mosslet, :referral_program,
  enabled: true,
  beta_mode: true,
  code_prefix: "MOSS",
  beta: %{
    commission_rate: "0.30",
    one_time_commission_rate: "0.35",
    referee_discount_percent: 20,
    min_payout_cents: 1500,
    payout_schedule: :monthly
  },
  production: %{
    commission_rate: "0.15",
    one_time_commission_rate: "0.20",
    referee_discount_percent: 20,
    min_payout_cents: 2000,
    payout_schedule: :monthly
  }

# Used in Util.email_valid?
# In prod.ex MX checking is enabled
config :email_checker,
  default_dns: :system,
  also_dns: [],
  validations: [EmailChecker.Check.Format, EmailChecker.Check.MX],
  smtp_retries: 2,
  timeout_milliseconds: :infinity

config :zxcvbn,
  message_formatter: Mosslet.ZXCVBNMessageFormatter

config :flop, repo: Mosslet.Repo.Local

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Import desktop config if MOSSLET_DESKTOP is set (for native app builds)
if System.get_env("MOSSLET_DESKTOP") do
  import_config "desktop.exs"
end
