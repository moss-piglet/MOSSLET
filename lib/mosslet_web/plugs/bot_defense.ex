defmodule MossletWeb.Plugs.BotDefense do
  @moduledoc """
  Plug to block requests from banned IPs before they reach the router.

  This plug checks the ETS table maintained by `Mosslet.Security.BotDefense`
  for banned IPs. Lookups are O(1) and do not hit the database.

  ## Usage

  Add to your endpoint.ex before the router:

      plug MossletWeb.Plugs.BotDefense
      plug MossletWeb.Router

  ## Options

  - `:status` - HTTP status code to return (default: 403)
  - `:body` - Response body (default: "Forbidden")
  """
  import Plug.Conn

  alias Mosslet.Security.BotDefense

  def init(opts), do: opts

  def call(conn, opts) do
    if BotDefense.banned?(conn.remote_ip) do
      BotDefense.increment_blocked_request(conn.remote_ip)

      status = Keyword.get(opts, :status, 403)
      body = Keyword.get(opts, :body, "Forbidden")

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(status, body)
      |> halt()
    else
      conn
    end
  end
end
