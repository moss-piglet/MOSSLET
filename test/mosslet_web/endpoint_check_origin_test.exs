defmodule MossletWeb.EndpointCheckOriginTest do
  @moduledoc """
  Tests for the wildcard `check_origin` configuration that lets org branding
  subdomains' LiveView/WebSocket connections succeed (Task #240, Phase B,
  slice C).

  In prod (`config/runtime.exs`) the endpoint is configured with
  `check_origin: ["//\#{host}", "//*.\#{host}"]`. The bare `//host` admits the
  apex and the `//*.host` wildcard admits every subdomain (incl. `www`), so a
  socket connecting from `https://acmebiz.mosslet.com` is accepted while foreign
  origins are still rejected.

  We exercise `Phoenix.Socket.Transport.check_origin/5` directly with that exact
  list (passed via `opts`) so the assertion is independent of the test-env
  endpoint config and pins the real Phoenix wildcard semantics we rely on.
  """
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  # Mirrors the prod shape in config/runtime.exs for host = "mosslet.com".
  @check_origin ["//mosslet.com", "//*.mosslet.com"]

  defp allowed?(origin) do
    conn =
      conn(:get, "/")
      |> put_req_header("origin", origin)

    result =
      Phoenix.Socket.Transport.check_origin(
        conn,
        __MODULE__,
        MossletWeb.Endpoint,
        check_origin: @check_origin
      )

    not result.halted
  end

  describe "wildcard check_origin" do
    test "accepts an org subdomain origin" do
      assert allowed?("https://acmebiz.mosslet.com")
    end

    test "accepts a deeper/other org subdomain origin" do
      assert allowed?("https://my-org-123.mosslet.com")
    end

    test "accepts the apex origin" do
      assert allowed?("https://mosslet.com")
    end

    test "accepts the www origin" do
      assert allowed?("https://www.mosslet.com")
    end

    test "rejects a foreign origin" do
      refute allowed?("https://evil.example.com")
    end

    test "rejects a look-alike suffix origin (not a true subdomain)" do
      refute allowed?("https://evilmosslet.com")
    end
  end
end
