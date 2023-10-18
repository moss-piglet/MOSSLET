# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :metamorphic,
  ecto_repos: [Metamorphic.Repo.Local],
  generators: [binary_id: true]

config :metamorphic,
  mailer_default_from_email: "support@mail.metamorphic.app",
  server_public_key: System.get_env("SERVER_PUBLIC_KEY"),
  server_private_key: System.get_env("SERVER_PRIVATE_KEY"),
  avatars_bucket: System.get_env("AVATARS_BUCKET"),
  memories_bucket: System.get_env("MEMORIES_BUCKET"),
  canonical_host: System.get_env("PHX_HOST")

config :metamorphic, Metamorphic.Repo.Local, priv: "priv/repo"

# Configures the endpoint
config :metamorphic, MetamorphicWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MetamorphicWeb.ErrorHTML, json: MetamorphicWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Metamorphic.PubSub,
  live_view: [signing_salt: "QZW2G8XF", encryption_salt: "NbUPFFBa"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :metamorphic, Metamorphic.Mailer, adapter: Swoosh.Adapters.Local

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
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures Oban
config :metamorphic, Oban,
  repo: Metamorphic.Repo.Local,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, tokens: 10]

# Configures cldr
config :ex_cldr,
  default_locale: "en",
  default_backend: Metamorphic.Cldr

# Configures exaws
config :ex_aws,
  json_codec: Jason,
  access_key_id: [{:system, "STORJ_ACCESS_KEY"}],
  secret_access_key: [{:system, "STORJ_SECRET_KEY"}],
  region: {:system, "STORJ_REGION"}

config :ex_aws, :s3,
  scheme: "https",
  host: {:system, "STORJ_HOST"}

config :ex_aws, :retries, max_attempts: 3

# Configure the time zone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configure langchain OpenAI key
config :langchain,
  openai_key: System.get_env("OPENAI_KEY"),
  openai_org_id: System.get_env("OPENAI_ORG_ID")

# Configure Sentry error monitoring
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: ~w(production staging),
  environment_name: System.get_env("RELEASE_LEVEL") || "development"

# Configure Stripe for Bling
config :stripity_stripe,
  api_key: System.get_env("STRIPE_API_KEY"),
  public_key: System.get_env("STRIPE_PUBLIC_KEY"),
  webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET")

# Configure Bling for Bankroll and Stripe
config :bling,
  bling: Metamorphic.Bling,
  repo: Metamorphic.Repo.Local,
  customers: [user: Metamorphic.Accounts.User],
  subscription: Metamorphic.Subscriptions.Subscription,
  subscription_item: Metamorphic.Subscriptions.SubscriptionItem

# Configure Bankroll for Stripe
config :bankroll,
  bling: Metamorphic.Bling,
  bankroll: Metamorphic.Bankroll,
  company_name: "Metamorphic",
  plans: [
    %{
      title: "Starter",
      description: "Our free plan. Connect and share online for free, privacy included.",
      features: [
        "50 Memories",
        "Unlimited Connections",
        "Unlimited Posts"
      ],
      prices: %{
        monthly: %{id: "price_1O0mvfJhDwcSIdONuQrqTL5T", price: "$0"},
        yearly: %{id: "price_1O0mvfJhDwcSIdONuQrqTL5T", price: "$0"}
      }
    },
    %{
      title: "Lite",
      description: "Our lite plan. Everything in Starter plus 10x more Memories and AI.",
      features: [
        "2,500 tokens per month",
        "500 Memories",
        "Unlimited Connections",
        "Unlimited Posts"
      ],
      prices: %{
        monthly: %{id: "price_1O1rQ2JhDwcSIdONrVDfHOJE", price: "$5"},
        yearly: %{id: "price_1O1rQ2JhDwcSIdONMqY2HbBR", price: "$50"}
      }
    },
    %{
      title: "Plus",
      description:
        "Our most popular plan. Everything in Lite with 10x more Memories and AI tokens.",
      features: [
        "25,000 tokens per month",
        "5,000 Memories",
        "Unlimited Connections",
        "Unlimited Posts"
      ],
      prices: %{
        monthly: %{id: "price_1O1rTKJhDwcSIdONiT9TuJj8", price: "$15"},
        yearly: %{id: "price_1O1rTKJhDwcSIdONOfy8K9V1", price: "$150"}
      }
    },
    %{
      title: "Pro",
      description: "Our Pro plan. Everything in Plus with 10k Memories and 50k AI tokens.",
      features: [
        "50,000 tokens per month",
        "10,000 Memories",
        "Unlimited Connections",
        "Unlimited Posts"
      ],
      prices: %{
        monthly: %{id: "price_1O1s0pJhDwcSIdON4Zp3JW50", price: "$25"},
        yearly: %{id: "price_1O1s0pJhDwcSIdON6OhArMSs", price: "$250"}
      }
    },
    %{
      title: "Pro AI",
      description:
        "Our Pro AI plan. Everything in Pro with 100k AI tokens and a lifetime of Memories.",
      features: [
        "100,000 tokens per month",
        "50,000 Memories",
        "Unlimited Connections",
        "Unlimited Posts"
      ],
      prices: %{
        monthly: %{id: "price_1O1tWLJhDwcSIdONE4IvNK7z", price: "$50"},
        yearly: %{id: "price_1O1tWLJhDwcSIdON0vHW9UAZ", price: "$500"}
      }
    }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
