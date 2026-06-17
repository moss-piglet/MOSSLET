defmodule MossletWeb.EndpointCanonicalHostTest do
  @moduledoc """
  Tests for the canonical-host 301 plug's subdomain tolerance (Task #240,
  Phase B, slice B).

  An org's branded host (`acmebiz.mosslet.com`) must NOT be 301-redirected to the
  canonical apex — it is resolved/tagged by `MossletWeb.Plugs.OrgSubdomain` and
  authorized downstream. Reserved labels (`www`), the apex mismatch, and foreign
  hosts still redirect. The `/health` carve-out stays exempt regardless of host.

  These exercise the real `MossletWeb.Endpoint` plug pipeline; the canonical-host
  plug halts at the 301 BEFORE the router, so redirect cases never render a page.
  """
  use MossletWeb.ConnCase, async: false

  @canonical "mosslet.com"

  setup do
    previous = Application.get_env(:mosslet, :canonical_host)
    Application.put_env(:mosslet, :canonical_host, @canonical)

    on_exit(fn ->
      if previous do
        Application.put_env(:mosslet, :canonical_host, previous)
      else
        Application.delete_env(:mosslet, :canonical_host)
      end
    end)

    :ok
  end

  defp with_host(conn, host), do: %{conn | host: host}

  describe "canonical-host 301 redirects" do
    test "redirects www.<canonical> to the canonical host", %{conn: conn} do
      conn = conn |> with_host("www.#{@canonical}") |> get("/")

      assert conn.status == 301
      assert ["http://#{@canonical}/"] == get_resp_header(conn, "location")
    end

    test "redirects a foreign host to the canonical host", %{conn: conn} do
      conn = conn |> with_host("evil.example.com") |> get("/")

      assert conn.status == 301
      assert [location] = get_resp_header(conn, "location")
      assert location =~ "#{@canonical}/"
    end
  end

  describe "subdomain tolerance" do
    test "does NOT redirect an org subdomain host", %{conn: conn} do
      conn = conn |> with_host("acmebiz.#{@canonical}") |> get("/")

      refute conn.status == 301
      assert get_resp_header(conn, "location") == []
    end
  end

  describe "/health carve-out" do
    test "never redirects /health, even on a non-canonical host", %{conn: conn} do
      conn = conn |> with_host("www.#{@canonical}") |> get("/health")

      refute conn.status == 301
    end
  end
end
