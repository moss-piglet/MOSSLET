defmodule Mosslet.Groups.FamilyCircleTest do
  @moduledoc """
  Context tests for the family-circle additions (Task #271): the org-type-guarded
  ZK create wrappers and the family-scoped listing. The shared ZK create core is
  already exercised through the business-circle path.
  """
  use Mosslet.DataCase

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp onboarded_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"
    username = "#{seed}#{System.unique_integer([:positive])}"
    user = user_fixture(%{email: email, username: username, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    user
  end

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
      end)

    membership
  end

  defp zk_attrs do
    %{
      encrypted_name: "encrypted-name-blob",
      encrypted_description: "encrypted-desc-blob",
      name_blind_index: "circle name #{System.unique_integer([:positive])}",
      sealed_creator_key: "sealed-creator-key-blob",
      encrypted_user_name: "encrypted-owner-name",
      encrypted_owner_moniker: "encrypted-owner-moniker",
      encrypted_owner_avatar_img: "encrypted-owner-avatar",
      require_password?: false,
      password: ""
    }
  end

  setup do
    owner = onboarded_user("famowner")
    {:ok, family} = Orgs.create_org(owner, %{"name" => "The Family", "type" => "family"})
    {:ok, business} = Orgs.create_org(owner, %{"name" => "Acme Inc", "type" => "business"})
    %{owner: owner, family: family, business: business}
  end

  describe "create_family_circle_zk/5" do
    test "creates a family circle stamped with the family org_id", %{owner: owner, family: family} do
      assert {:ok, group} =
               Groups.create_family_circle_zk(family, owner, zk_attrs(), [], [])

      assert group.org_id == family.id
      # Family circles carry no team/community tier distinction in the UI; the
      # column defaults to :community under the hood.
      assert group.org_circle_type == :community
      assert Enum.any?(group.user_groups, &(&1.user_id == owner.id))
    end

    test "refuses a business org (family only)", %{owner: owner, business: business} do
      assert {:error, :not_a_family_org} =
               Groups.create_family_circle_zk(business, owner, zk_attrs(), [], [])
    end

    test "refuses a non-member owner", %{family: family} do
      outsider = onboarded_user("famoutsider")

      assert {:error, :not_an_org_member} =
               Groups.create_family_circle_zk(family, outsider, zk_attrs(), [], [])
    end
  end

  describe "create_business_circle_zk/6 still guards business" do
    test "refuses a family org", %{owner: owner, family: family} do
      assert {:error, :not_a_business_org} =
               Groups.create_business_circle_zk(family, owner, zk_attrs(), [], [])
    end
  end

  describe "list_family_circles/2" do
    test "lists only the caller's confirmed family circles", %{owner: owner, family: family} do
      {:ok, group} = Groups.create_family_circle_zk(family, owner, zk_attrs(), [], [])

      assert [listed] = Groups.list_family_circles(family, owner)
      assert listed.id == group.id
    end

    test "does not list circles the caller isn't a member of", %{
      owner: owner,
      family: family
    } do
      {:ok, _group} = Groups.create_family_circle_zk(family, owner, zk_attrs(), [], [])

      other = onboarded_user("famother")
      add_member(family, other, :member)

      assert Groups.list_family_circles(family, other) == []
    end
  end
end
