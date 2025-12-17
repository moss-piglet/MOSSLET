defmodule MossletWeb.Plugs.BotDefense do
  @moduledoc """
  Plug to block requests from banned IPs and detect suspicious activity.

  This plug:
  1. Checks the ETS table for already-banned IPs (O(1) lookup)
  2. Runs automatic detection for rate limiting, bad bots, and suspicious patterns
  3. Auto-bans detected threats

  ## Usage

  Add to your endpoint.ex before the router:

      plug MossletWeb.Plugs.BotDefense
      plug MossletWeb.Router

  ## Options

  - `:status` - HTTP status code to return (default: 403)
  - `:body` - Response body (default: "Forbidden")
  - `:detect` - Enable automatic detection (default: true)
  """
  import Plug.Conn

  alias Mosslet.Security.BotDefense
  alias Mosslet.Security.BotDetector

  def init(opts), do: opts

  def call(conn, opts) do
    cond do
      Mosslet.Platform.native?() ->
        conn

      BotDefense.banned?(conn.remote_ip) ->
        BotDefense.increment_blocked_request(conn.remote_ip)
        block_request(conn, opts)

      Keyword.get(opts, :detect, true) and should_detect?(conn) ->
        case BotDetector.analyze(conn) do
          {:ok, :allow} ->
            conn

          {:ban, _reason, _source} ->
            block_request(conn, opts)
        end

      true ->
        conn
    end
  end

  defp should_detect?(conn) do
    not static_asset?(conn.request_path)
  end

  defp static_asset?(path) do
    String.starts_with?(path, "/assets/") or
      String.ends_with?(path, ".js") or
      String.ends_with?(path, ".css") or
      String.ends_with?(path, ".ico") or
      String.ends_with?(path, ".png") or
      String.ends_with?(path, ".jpg") or
      String.ends_with?(path, ".svg") or
      String.ends_with?(path, ".woff2")
  end

  defp block_request(conn, opts) do
    status = Keyword.get(opts, :status, 403)
    body = Keyword.get(opts, :body, "Forbidden")

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
    |> halt()
  end
end
