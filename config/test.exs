import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :argon2_elixir, t_cost: 1, m_cost: 8

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mosslet, Mosslet.Repo.Local,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mosslet_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mosslet, MossletWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DPRAIDzuG28QXK2U5i9dSOqY3jXHXn+K1OluX+1QvplETYNIw5b9pAd1og9CAo4N",
  live_view: [signing_salt: "GFtryJYFK3ow0glC"],
  server: true

# Configure driver for wallaby
config :mosslet, :sandbox, Ecto.Adapters.SQL.Sandbox
config :wallaby, driver: Wallaby.Selenium, otp_app: :mosslet

# In test we don't send emails.
config :mosslet, Mosslet.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :mosslet, MossletWeb.Plugs.ContentSecurityPolicy,
  csp:
    "default-src 'none'; form-action 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'self'; object-src 'self';  base-uri 'self'; frame-src 'self';  manifest-src 'self';"

config :email_checker,
  default_dns: :system,
  also_dns: [],
  validations: [EmailChecker.Check.Format],
  smtp_retries: 2,
  timeout_milliseconds: :infinity

# Speed up tests for argon2
config :argon2_elixir,
  t_cost: 1,
  m_cost: 8

# Stop Oban from running jobs during tests
config :mosslet, Oban, testing: :manual

# Disable bot detection during tests
config :mosslet, Mosslet.Security.BotDetector, auto_ban_enabled: false
