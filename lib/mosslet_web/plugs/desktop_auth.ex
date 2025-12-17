defmodule MossletWeb.Plugs.DesktopAuth do
  @moduledoc """
  Authentication plug for native desktop builds.

  Wraps Desktop.Auth to ensure only the local WebView can access the app.
  A token is generated and compared to prevent other applications from
  connecting to the local webserver.

  Additionally marks the connection with `:desktop_mode` for any
  platform-specific conditional behavior in the app.
  """
  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    conn
    |> Desktop.Auth.call(opts)
    |> assign(:desktop_mode, true)
  end
end
