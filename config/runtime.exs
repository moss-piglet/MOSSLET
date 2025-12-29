import Config

if System.get_env("MOSSLET_DESKTOP") == "true" do
  config :phoenix_live_view,
    debug_heex_annotations: false,
    debug_tags_location: false,
    debug_attributes: false

  Mosslet.Platform.Config.ensure_data_directory!()

  config :mosslet, Mosslet.Repo.SQLite,
    database: Mosslet.Platform.Config.sqlite_database_path(),
    pool_size: 5,
    journal_mode: :wal,
    cache_size: -64_000,
    temp_store: :memory,
    synchronous: :normal

  config :mosslet, MossletWeb.Endpoint,
    adapter: Bandit.PhoenixAdapter,
    http: [port: 0],
    server: true,
    secret_key_base: Mosslet.Platform.Config.generate_secret(),
    render_errors: [
      formats: [html: MossletWeb.ErrorHTML, json: MossletWeb.ErrorJSON],
      layout: false
    ],
    pubsub_server: Mosslet.PubSub,
    live_view: [signing_salt: Mosslet.Platform.Config.generate_salt()]
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/Mosslet start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :mosslet, MossletWeb.Endpoint, server: true
end

if config_env() == :prod do
  config :flame, :terminator, log: :info
  config :flame, :backend, FLAME.FlyBackend

  config :flame, FLAME.FlyBackend,
    token: System.fetch_env!("FLY_API_TOKEN"),
    cpu_kind: "performance",
    cpus: 2,
    memory_mb: 4096,
    env: %{
      "DATABASE_URL" => System.fetch_env!("DATABASE_URL"),
      "RELEASE_COOKIE" => System.fetch_env!("RELEASE_COOKIE"),
      "BUMBLEBEE_CACHE_DIR" => System.get_env("BUMBLEBEE_CACHE_DIR", "/app/.bumblebee"),
      "BUMBLEBEE_OFFLINE" => System.get_env("BUMBLEBEE_OFFLINE", "true")
    }

  config :mosslet, dns_cluster_query: System.get_env("DNS_CLUSTER_QUERY")

  # Configure plug_attack
  config :mosslet, plug_attack_ip_secret: System.get_env("PLUG_ATTACK_IP_SECRET")

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :mosslet, Mosslet.Repo.Local,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    connect_timeout: 30_000,
    timeout: 30_000,
    queue_target: 5_000,
    queue_interval: 1_000

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "mosslet.com"
  port = String.to_integer(System.get_env("PORT") || "8080")

  # Configure the canonical host for redirects.
  config :mosslet,
    canonical_host: host

  config :mosslet, MossletWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: true,
    force_ssl: [rewrite_on: [:x_forwarded_proto]],
    live_view: [
      signing_salt: System.get_env("LIVE_VIEW_SIGNING_SALT"),
      encryption_salt: System.get_env("LIVE_VIEW_ENCRYPTION_SALT")
    ],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :mosslet,
    server_public_key: System.get_env("SERVER_PUBLIC_KEY"),
    server_private_key: System.get_env("SERVER_PRIVATE_KEY"),
    env: :prod

  # Configure Swoosh for production.
  config :mosslet, Mosslet.Mailer,
    adapter: Swoosh.Adapters.Mailgun,
    api_key: System.get_env("MAILGUN_API_KEY"),
    domain: System.get_env("MAILGUN_DOMAIN")

  config :swoosh,
    api_client: Swoosh.ApiClient.Finch,
    finch_name: Mosslet.Finch

  # Configure Oban for fly_postgres.
  # We want to ensure we're only running on
  # the primary database.
  unless System.get_env("FLY_REGION") do
    System.put_env("FLY_REGION", "ewr")
  end

  unless System.get_env("PRIMARY_REGION") do
    System.put_env("PRIMARY_REGION", "ewr")
  end

  primary? = System.get_env("FLY_REGION") == System.get_env("PRIMARY_REGION")

  unless primary? do
    config :oban_met, auto_start: false

    config :mosslet, Oban,
      queues: false,
      plugins: false,
      peer: false
  end

  # Configure langchain OpenAI key
  config :langchain,
    openai_key: System.get_env("OPENAI_KEY"),
    openai_org_id: System.get_env("OPENAI_ORG_ID")

  # Configure image nsfw detection
  # autostart: false - NSFW detection runs on FLAME runners via Mosslet.AI.NsfwServing
  config :image, :classifier,
    model: {:hf, "Falconsai/nsfw_image_detection"},
    featurizer: {:hf, "Falconsai/nsfw_image_detection"},
    featurizer_options: [module: Bumblebee.Vision.VitFeaturizer],
    name: Image.Classification.Server,
    autostart: false

  config :bumblebee, progress_bar_enabled: false

  # Configure Stripe
  config :stripity_stripe,
    api_key: System.get_env("STRIPE_API_KEY"),
    signing_secret: System.get_env("STRIPE_WEBHOOK_SECRET")

  csp =
    System.get_env("CSP_HEADER") ||
      "default-src 'none'; form-action 'self'; script-src 'self' 'unsafe-eval' https://unpkg.com/@popperjs/core@2.11.8/dist/umd/popper.min.js https://unpkg.com/tippy.js@6.3.7/dist/tippy-bundle.umd.min.js https://unpkg.com/trix@2.1.13/dist/trix.umd.min.js https://cdn.usefathom.com/script.js; style-src 'self' 'unsafe-inline' https://unpkg.com/trix@2.1.13/dist/trix.css; img-src 'self' data: blob: https://cdn.usefathom.com/ https://mosslet-prod.fly.storage.tigris.dev/ https://res.cloudinary.com/; font-src 'self' https://fonts.gstatic.com; connect-src 'self' wss://mosslet.com https://mosslet.com; frame-ancestors 'self'; object-src 'self'; base-uri 'self'; frame-src 'self'; manifest-src 'self';"

  config :mosslet, MossletWeb.Plugs.ContentSecurityPolicy, csp: csp

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :mosslet, MossletWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :mosslet, MossletWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :mosslet, Mosslet.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
