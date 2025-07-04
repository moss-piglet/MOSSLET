defmodule MossletWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :mosslet

  # Enable concurrent testing for Wallaby
  if Application.compile_env(:mosslet, :sandbox, false) do
    plug Phoenix.Ecto.SQL.Sandbox
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_mosslet_key",
    signing_salt: {Mosslet.Encrypted.Session, :signing_salt, []},
    encryption_salt: {Mosslet.Encrypted.Session, :encryption_salt, []},
    same_site: "Lax"
  ]

  # We pass the `:user_agent` in the websocket for Wallaby testing
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [:user_agent, session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # redirect requests through the canonical host=mosslet.com
  plug(:canonical_host)

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :mosslet,
    gzip: false,
    only: MossletWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :mosslet
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Stripe.WebhookPlug,
    at: "/webhooks/stripe",
    handler: Mosslet.Billing.Providers.Stripe.WebhookHandler,
    secret: {Application, :get_env, [:stripity_stripe, :signing_secret]}

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    # 8 MB by trix.js calculations
    length: 8_388_608

  plug Sentry.PlugContext

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug RemoteIp,
    headers: ~w[http_fly_client_ip]

  plug MossletWeb.Router

  defp canonical_host(conn, _opts) do
    opts =
      PlugCanonicalHost.init(canonical_host: Application.get_env(:mosslet, :canonical_host))

    PlugCanonicalHost.call(conn, opts)
  end
end
