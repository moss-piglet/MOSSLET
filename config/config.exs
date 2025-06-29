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
  live_view: [signing_salt: "QZW2G8XF", encryption_salt: "NbUPFFBa"]

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
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
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
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ],
  queues: [default: 10, tokens: 10, invites: 10, storage: 10],
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
config :mosslet, :billing_products, [
  %{
    id: "prod_QCKH8FgOWQC8QK",
    name: "MOSSLET (Personal)",
    description:
      "Enjoy lifetime access with a one-time payment. MOSSLET (Personal) is designed for individuals who value peace of mind and privacy. Bring a friend and join today to share meaningful experiences in a safe and supportive environment.",
    most_popular: false,
    features: [
      "Unlimited Connections, Groups, and Posts",
      "Unlimited new features",
      "Streamlined settings",
      "Own your data",
      "Advanced asymmetric encryption",
      "Email support",
      "Supports Affirm Payment Plans"
    ],
    line_items: [
      %{
        id: "personal",
        interval: :one_time,
        price: "price_1RWOMUJhDwcSIdONXefktbNO",
        quantity: 1,
        amount: 5900,
        allow_promotion_codes: true
      }
    ],
    mode: "payment",
    automatic_tax: %{enabled: true}
  }
]

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
