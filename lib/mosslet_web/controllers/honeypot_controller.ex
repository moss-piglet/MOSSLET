defmodule MossletWeb.HoneypotController do
  @moduledoc """
  Controller for honeypot endpoints that trap malicious bots.

  These endpoints mimic common attack targets. Any access automatically
  bans the requesting IP via BotDetector.
  """
  use MossletWeb, :controller

  alias Mosslet.Security.BotDetector

  def trap(conn, _params) do
    BotDetector.honeypot_triggered(conn.remote_ip, conn.request_path)

    conn
    |> put_status(404)
    |> text("Not Found")
  end
end
