defmodule Mosslet.Orgs.OrgSubdomainTest do
  @moduledoc """
  Tests for the org custom-subdomain branding add-on (Task #240, Phase B,
  slice A): `Org.subdomain_changeset/2` validation (lowercase, hostname format,
  length, reserved-word denylist), DB-level uniqueness, and the non-raising
  `Orgs.get_org_by_subdomain/1` lookup.

  The subdomain hostname label is NON-SENSITIVE plaintext (it is published in the
  org's branded URL), so — unlike the encrypted name/logo — it is stored, indexed
  (`:citext` unique), and looked up in the clear.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  defp business_org do
    org_fixture(user_fixture(), %{"type" => "business"})
  end

  # Persists a subdomain on the org via the changeset, on the primary, mirroring
  # the project's write convention (Repo.transaction_on_primary for ALL writes).
  defp set_subdomain!(org, subdomain) do
    {:ok, {:ok, org}} =
      Repo.transaction_on_primary(fn ->
        org
        |> Org.subdomain_changeset(%{"subdomain" => subdomain})
        |> Repo.update()
      end)

    org
  end

  describe "Org.subdomain_changeset/2 validation" do
    test "accepts a valid lowercase hostname label" do
      cs = Org.subdomain_changeset(business_org(), %{"subdomain" => "acmebiz"})

      assert cs.valid?
      assert Ecto.Changeset.get_change(cs, :subdomain) == "acmebiz"
    end

    test "accepts internal hyphens and digits" do
      cs = Org.subdomain_changeset(business_org(), %{"subdomain" => "acme-biz-123"})
      assert cs.valid?
    end

    test "lowercases and trims the input before validating/storing" do
      cs = Org.subdomain_changeset(business_org(), %{"subdomain" => "  ACME-Biz  "})

      assert cs.valid?
      assert Ecto.Changeset.get_change(cs, :subdomain) == "acme-biz"
    end

    test "requires a subdomain (blank/nil rejected)" do
      for blank <- [nil, "", "   "] do
        cs = Org.subdomain_changeset(business_org(), %{"subdomain" => blank})
        refute cs.valid?
        assert {"can't be blank", _} = cs.errors[:subdomain]
      end
    end

    test "rejects too-short (< 3) and too-long (> 63) labels" do
      short = Org.subdomain_changeset(business_org(), %{"subdomain" => "ab"})
      refute short.valid?
      assert {_, opts} = short.errors[:subdomain]
      assert opts[:kind] == :min

      long =
        Org.subdomain_changeset(business_org(), %{"subdomain" => String.duplicate("a", 64)})

      refute long.valid?
      assert {_, opts} = long.errors[:subdomain]
      assert opts[:kind] == :max

      # 63 is the DNS label maximum and is allowed.
      ok = Org.subdomain_changeset(business_org(), %{"subdomain" => String.duplicate("a", 63)})
      assert ok.valid?
    end

    test "rejects leading/trailing hyphens, dots, and other invalid characters" do
      for bad <- ["-acme", "acme-", "acme.biz", "acme_biz", "acme biz", "acme!"] do
        cs = Org.subdomain_changeset(business_org(), %{"subdomain" => bad})
        refute cs.valid?, "expected #{inspect(bad)} to be invalid"
      end
    end

    test "rejects consecutive hyphens" do
      cs = Org.subdomain_changeset(business_org(), %{"subdomain" => "ac--me"})
      refute cs.valid?
      assert {"cannot contain consecutive hyphens", _} = cs.errors[:subdomain]
    end

    test "rejects reserved labels (case-insensitively)" do
      for reserved <- ["www", "app", "api", "admin", "mail", "billing", "mosslet"] do
        cs = Org.subdomain_changeset(business_org(), %{"subdomain" => reserved})
        refute cs.valid?, "expected #{inspect(reserved)} to be reserved"
        assert {"is reserved", _} = cs.errors[:subdomain]

        # Uppercase form is canonicalized then still caught by the denylist.
        cs_upper =
          Org.subdomain_changeset(business_org(), %{"subdomain" => String.upcase(reserved)})

        refute cs_upper.valid?
        assert {"is reserved", _} = cs_upper.errors[:subdomain]
      end
    end

    test "clear_subdomain_changeset/1 nils the subdomain" do
      org = set_subdomain!(business_org(), "acmebiz")
      cs = Org.clear_subdomain_changeset(org)
      assert Ecto.Changeset.get_field(cs, :subdomain) == nil
    end
  end

  describe "subdomain uniqueness (DB :citext unique index)" do
    test "two orgs cannot share the same subdomain" do
      _first = set_subdomain!(business_org(), "acmebiz")

      {:ok, {:error, changeset}} =
        Repo.transaction_on_primary(fn ->
          business_org()
          |> Org.subdomain_changeset(%{"subdomain" => "acmebiz"})
          |> Repo.update()
        end)

      refute changeset.valid?
      assert {_, opts} = changeset.errors[:subdomain]
      assert opts[:validation] in [:unsafe_unique, :unique]
    end

    test "uniqueness is case-insensitive (citext + lowercasing)" do
      _first = set_subdomain!(business_org(), "acmebiz")

      {:ok, {:error, changeset}} =
        Repo.transaction_on_primary(fn ->
          business_org()
          |> Org.subdomain_changeset(%{"subdomain" => "ACMEBIZ"})
          |> Repo.update()
        end)

      refute changeset.valid?
      assert changeset.errors[:subdomain]
    end

    test "an org keeping its own subdomain on update is not a uniqueness conflict" do
      org = set_subdomain!(business_org(), "acmebiz")
      # Re-applying the same subdomain to the SAME org must not collide.
      again = set_subdomain!(org, "acmebiz")
      assert again.subdomain == "acmebiz"
    end
  end

  describe "Orgs.get_org_by_subdomain/1" do
    test "returns the org for an exact subdomain" do
      org = set_subdomain!(business_org(), "acmebiz")

      found = Orgs.get_org_by_subdomain("acmebiz")
      assert found
      assert found.id == org.id
    end

    test "is case-insensitive (citext column)" do
      org = set_subdomain!(business_org(), "acmebiz")

      assert Orgs.get_org_by_subdomain("ACMEBIZ").id == org.id
      assert Orgs.get_org_by_subdomain("AcMeBiz").id == org.id
    end

    test "returns nil for an unknown subdomain (non-raising)" do
      assert Orgs.get_org_by_subdomain("does-not-exist") == nil
    end

    test "returns nil for orgs that have not claimed a subdomain" do
      _org = business_org()
      assert Orgs.get_org_by_subdomain("acmebiz") == nil
    end
  end
end
