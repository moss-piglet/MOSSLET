defmodule Mosslet.Orgs.OrgLogoTest do
  @moduledoc """
  Tests for the org brand-logo branding add-on (Task #228, Phase A):
  `Org.put_logo_changeset/2`, `Org.clear_logo_changeset/1`, the context
  `Orgs.set_org_logo/2` / `Orgs.clear_org_logo/1` write paths, the
  `Orgs.can_manage_branding?/2` gate, and the ZK at-rest invariant (the stored
  `logo_url` pointer is Cloak-encrypted in the DB).
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Membership
  alias Mosslet.Orgs.Org

  @logo_path "uploads/files/#{Ecto.UUID.generate()}.bin"

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Repo.transaction_on_primary(fn ->
        Membership.insert_changeset(org, user, role) |> Repo.insert()
      end)

    membership
  end

  defp setup_business do
    owner = user_fixture()
    admin = user_fixture()
    member = user_fixture()
    org = org_fixture(owner, %{"type" => "business"})

    # create_org already adds the owner as an :admin membership.
    owner_ms = Orgs.get_membership!(owner, org.slug)
    admin_ms = add_member(org, admin, :admin)
    member_ms = add_member(org, member, :member)

    %{
      org: org,
      owner: owner,
      admin: admin,
      member: member,
      owner_ms: owner_ms,
      admin_ms: admin_ms,
      member_ms: member_ms
    }
  end

  describe "Org logo changesets" do
    test "put_logo_changeset/2 stages the storage path" do
      org = org_fixture(user_fixture(), %{"type" => "business"})
      cs = Org.put_logo_changeset(org, @logo_path)

      assert cs.valid?
      assert Ecto.Changeset.get_change(cs, :logo_url) == @logo_path
    end

    test "clear_logo_changeset/1 nils the logo" do
      org = org_fixture(user_fixture(), %{"type" => "business"})
      {:ok, org} = Orgs.set_org_logo(org, @logo_path)

      cs = Org.clear_logo_changeset(org)
      assert Ecto.Changeset.get_field(cs, :logo_url) == nil
    end

    test "logo_url is not cast from user params (programmatic-only)" do
      org = org_fixture(user_fixture(), %{"type" => "business"})

      # The public update changeset must ignore a user-supplied logo_url.
      cs = Org.update_changeset(org, %{"logo_url" => "uploads/files/evil.bin"})
      assert Ecto.Changeset.get_change(cs, :logo_url) == nil
    end
  end

  describe "Orgs.set_org_logo/2 + clear_org_logo/1" do
    test "stamps then clears the logo path on the org" do
      org = org_fixture(user_fixture(), %{"type" => "business"})

      assert {:ok, updated} = Orgs.set_org_logo(org, @logo_path)
      assert updated.logo_url == @logo_path
      assert Orgs.get_org_by_id(org.id).logo_url == @logo_path

      assert {:ok, cleared} = Orgs.clear_org_logo(updated)
      assert cleared.logo_url == nil
      assert Orgs.get_org_by_id(org.id).logo_url == nil
    end

    test "replacing the logo updates the stored path (old blob cleanup is fire-and-forget)" do
      org = org_fixture(user_fixture(), %{"type" => "business"})
      first_path = "uploads/files/#{Ecto.UUID.generate()}.bin"
      second_path = "uploads/files/#{Ecto.UUID.generate()}.bin"

      {:ok, org} = Orgs.set_org_logo(org, first_path)
      assert org.logo_url == first_path

      # Replacing stamps the new path; the previous blob is deleted best-effort
      # in the background (StorjTask), which we don't await here.
      {:ok, org} = Orgs.set_org_logo(org, second_path)
      assert org.logo_url == second_path
      assert Orgs.get_org_by_id(org.id).logo_url == second_path
    end

    test "logo_url is stored Cloak-encrypted at rest (ZK pointer invariant)" do
      org = org_fixture(user_fixture(), %{"type" => "business"})
      {:ok, _} = Orgs.set_org_logo(org, @logo_path)

      # Read the raw column bytes, bypassing Cloak. The stored ciphertext must
      # NOT contain the plaintext storage path.
      [raw] =
        Mosslet.Repo.query!(
          "SELECT logo_url FROM orgs WHERE id = $1",
          [Ecto.UUID.dump!(org.id)]
        ).rows
        |> List.first()

      assert is_binary(raw)
      refute raw =~ @logo_path
    end
  end

  describe "Orgs.can_manage_branding?/2" do
    test "admins may manage branding; members may not" do
      %{org: org, owner_ms: owner_ms, admin_ms: admin_ms, member_ms: member_ms} =
        setup_business()

      # owner_ms and admin_ms both have role :admin in the fixture.
      assert Orgs.can_manage_branding?(org, owner_ms)
      assert Orgs.can_manage_branding?(org, admin_ms)
      refute Orgs.can_manage_branding?(org, member_ms)
    end

    test "an owner who is NOT an admin cannot manage branding (admins-only)" do
      owner = user_fixture()
      org = org_fixture(owner, %{"type" => "business"})

      # An owner who has been demoted to a plain member: still created_by, but
      # branding is admins-only, so they may not manage it.
      member_ms = %Membership{org_id: org.id, user_id: owner.id, role: :member}

      assert Orgs.owner?(org, owner.id)
      refute Orgs.can_manage_branding?(org, member_ms)
    end
  end
end
