defmodule MossletWeb.Plugs.OrgSubdomainTest do
  @moduledoc """
  Tests for the subdomain-aware host plug (Task #240, Phase B, slice B):

    * `MossletWeb.Plugs.OrgSubdomain.subdomain_label/2` — the pure host-parsing
      decision the canonical-host plug also reuses to stay subdomain-tolerant.
    * `MossletWeb.Plugs.OrgSubdomain.call/2` — resolves the host's label to an org
      and tags `conn.assigns[:subdomain_org]`, WITHOUT authorizing.
    * Auth-not-weakened guarantee: resolving an org from the host does NOT grant
      access — the existing membership gate (`Orgs.get_org!/2`) still bounces a
      non-member.

  The subdomain hostname label is NON-SENSITIVE plaintext, so it is parsed and
  resolved in the clear; authorization stays with `current_scope` + membership.
  """
  use Mosslet.DataCase, async: false

  import Plug.Test
  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo
  alias MossletWeb.Plugs.OrgSubdomain

  @base_host "mosslet.com"

  setup do
    previous = Application.get_env(:mosslet, :canonical_host)
    Application.put_env(:mosslet, :canonical_host, @base_host)

    on_exit(fn ->
      if previous do
        Application.put_env(:mosslet, :canonical_host, previous)
      else
        Application.delete_env(:mosslet, :canonical_host)
      end
    end)

    :ok
  end

  defp business_org(user \\ nil) do
    org_fixture(user || user_fixture(), %{"type" => "business"})
  end

  # Mirrors the slice-A test helper: persists a subdomain via the changeset on
  # the primary (Repo.transaction_on_primary for ALL writes).
  defp set_subdomain!(org, subdomain) do
    {:ok, {:ok, org}} =
      Repo.transaction_on_primary(fn ->
        org
        |> Org.subdomain_changeset(%{"subdomain" => subdomain})
        |> Repo.update()
      end)

    org
  end

  describe "subdomain_label/2" do
    test "extracts a single, non-reserved label from <label>.<base_host>" do
      assert OrgSubdomain.subdomain_label("acmebiz.mosslet.com", @base_host) ==
               {:ok, "acmebiz"}
    end

    test "returns :none for the apex (base_host itself)" do
      assert OrgSubdomain.subdomain_label("mosslet.com", @base_host) == :none
    end

    test "returns :none for a foreign host" do
      assert OrgSubdomain.subdomain_label("evil.com", @base_host) == :none
      assert OrgSubdomain.subdomain_label("acmebiz.evil.com", @base_host) == :none
    end

    test "returns :none for reserved labels (www/app/api/...)" do
      for reserved <- ["www", "app", "api", "admin", "mail", "billing"] do
        assert OrgSubdomain.subdomain_label("#{reserved}.mosslet.com", @base_host) == :none,
               "expected #{reserved} to be :none"
      end
    end

    test "returns :none for multi-level labels" do
      assert OrgSubdomain.subdomain_label("a.b.mosslet.com", @base_host) == :none
    end

    test "returns :none for an empty label and nil/blank base host" do
      assert OrgSubdomain.subdomain_label(".mosslet.com", @base_host) == :none
      assert OrgSubdomain.subdomain_label("acmebiz.mosslet.com", nil) == :none
      assert OrgSubdomain.subdomain_label("acmebiz.mosslet.com", "") == :none
      assert OrgSubdomain.subdomain_label(nil, @base_host) == :none
    end
  end

  describe "call/2 — resolution + tagging" do
    test "tags conn.assigns.subdomain_org for a known subdomain" do
      org = set_subdomain!(business_org(), "acmebiz")

      conn =
        conn(:get, "/")
        |> Map.put(:host, "acmebiz.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      assert conn.assigns.subdomain_org.id == org.id
      refute conn.halted
    end

    test "is case-insensitive (citext + DNS case-insensitivity)" do
      org = set_subdomain!(business_org(), "acmebiz")

      conn =
        conn(:get, "/")
        |> Map.put(:host, "ACMEBIZ.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      assert conn.assigns.subdomain_org.id == org.id
    end

    test "does not tag for an unknown subdomain (graceful, no crash)" do
      conn =
        conn(:get, "/")
        |> Map.put(:host, "does-not-exist.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      refute Map.has_key?(conn.assigns, :subdomain_org)
      refute conn.halted
    end

    test "does not tag for the apex host" do
      _org = set_subdomain!(business_org(), "acmebiz")

      conn =
        conn(:get, "/")
        |> Map.put(:host, "mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      refute Map.has_key?(conn.assigns, :subdomain_org)
    end

    test "does not tag for a reserved label even if an org claimed it via DB" do
      # Reserved labels can't be set via the changeset; the plug must still never
      # resolve them, so this is a structural guarantee independent of the DB.
      conn =
        conn(:get, "/")
        |> Map.put(:host, "www.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      refute Map.has_key?(conn.assigns, :subdomain_org)
    end

    test "is a no-op when no canonical host is configured" do
      Application.delete_env(:mosslet, :canonical_host)
      _org = set_subdomain!(business_org(), "acmebiz")

      conn =
        conn(:get, "/")
        |> Map.put(:host, "acmebiz.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      refute Map.has_key?(conn.assigns, :subdomain_org)
    end
  end

  describe "auth is NOT weakened by host resolution" do
    test "resolving the org from the host does not grant a non-member access" do
      owner = user_fixture()
      org = set_subdomain!(business_org(owner), "acmebiz")
      non_member = user_fixture()

      # The plug resolves the org purely from the (public) subdomain...
      conn =
        conn(:get, "/")
        |> Map.put(:host, "acmebiz.mosslet.com")
        |> OrgSubdomain.call(OrgSubdomain.init([]))

      assert conn.assigns.subdomain_org.id == org.id

      # ...but the membership gate (Orgs.get_org!/2, Ecto.assoc(:orgs)-scoped)
      # still bounces a non-member and still admits the owner/member. Resolution
      # is not authorization.
      assert_raise Ecto.NoResultsError, fn ->
        Orgs.get_org!(non_member, org.slug)
      end

      assert Orgs.get_org!(owner, org.slug).id == org.id
    end
  end
end
