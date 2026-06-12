defmodule MossletWeb.BusinessLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp to_letters(digits) do
    digits
    |> String.graphemes()
    |> Enum.map_join(fn d -> <<?a + String.to_integer(d)>> end)
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    key = get_key(user)

    name =
      "Person " <> (System.unique_integer([:positive]) |> Integer.to_string() |> to_letters())

    {:ok, user} =
      Accounts.update_user_onboarding_profile(user, %{name: name},
        change_name: true,
        key: key,
        user: user
      )

    {user, key}
  end

  defp add_member(org, user, role) do
    {:ok, {:ok, membership}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, role) |> Mosslet.Repo.insert()
      end)

    membership
  end

  describe "BusinessLive.Index" do
    test "lists only business orgs and creates a new one", %{conn: conn} do
      {user, key} = onboarded_user("bizadmin")

      # A family org must NOT appear on the business index.
      {:ok, _family} = Orgs.create_org(user, %{"name" => "Smiths", "type" => "family"})

      conn = log_in(conn, user, key)
      {:ok, _lv, html} = live(conn, ~p"/app/business")
      assert html =~ "Business"
      assert html =~ "Start your business workspace"
      refute html =~ "Smiths"

      {:ok, new_lv, _html} = live(conn, ~p"/app/business/new")

      {:ok, show_lv, html} =
        new_lv
        |> form("#new-business-form", business: %{name: "Acme Inc"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Acme Inc"
      assert has_element?(show_lv, "#invite-form")
      assert has_element?(show_lv, "#new-circle-button")
    end
  end

  describe "BusinessLive.Show" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("orgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Acme", "type" => "business"})

      %{conn: conn, admin: admin, admin_key: admin_key, org: org}
    end

    test "redirects when org is not a business", %{conn: conn} do
      {user, key} = onboarded_user("famuser")
      {:ok, family} = Orgs.create_org(user, %{"name" => "Joneses", "type" => "family"})

      assert {:error, {:live_redirect, %{to: "/app/business"}}} =
               conn |> log_in(user, key) |> live(~p"/app/business/#{family.slug}")
    end

    test "renders the member list with role badges", ctx do
      {:ok, _lv, html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert html =~ "Members"
      assert html =~ "Business circles"
      assert html =~ "Admin"
    end

    test "does not render any guardianship UI", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#establish-form")
      refute has_element?(lv, "#guardian-transparency-panel")
      refute has_element?(lv, "#pending-consent-requests")
    end
  end

  describe "Groups business-circle context (ZK eligibility)" do
    setup do
      {admin, _ak} = onboarded_user("ctxadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Globex", "type" => "business"})

      {member, _mk} = onboarded_user("ctxmember")
      add_member(org, member, :member)

      {outsider, _ok} = onboarded_user("ctxoutsider")

      %{admin: admin, org: org, member: member, outsider: outsider}
    end

    defp zk_attrs do
      %{
        encrypted_name: "encrypted-name-blob",
        encrypted_description: "encrypted-desc-blob",
        name_blind_index: "circle name",
        sealed_creator_key: "sealed-creator-key-blob",
        encrypted_user_name: "encrypted-owner-name",
        encrypted_owner_moniker: "encrypted-owner-moniker",
        encrypted_owner_avatar_img: "encrypted-owner-avatar",
        require_password?: false,
        password: ""
      }
    end

    defp sealed_for(user) do
      %{
        "user_id" => user.id,
        "sealed_key" => "sealed-#{user.id}",
        "encrypted_name" => "name-#{user.id}",
        "encrypted_moniker" => "moniker-#{user.id}",
        "encrypted_avatar_img" => "avatar-#{user.id}"
      }
    end

    test "member_of_org? reflects membership", ctx do
      assert Orgs.member_of_org?(ctx.org, ctx.admin.id)
      assert Orgs.member_of_org?(ctx.org, ctx.member.id)
      refute Orgs.member_of_org?(ctx.org, ctx.outsider.id)
    end

    test "create_business_circle_zk drops a non-org-member from the sealed set", ctx do
      users = [ctx.member, ctx.outsider]
      sealed = [sealed_for(ctx.member), sealed_for(ctx.outsider)]

      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), users, sealed)

      assert group.org_id == ctx.org.id

      member_ids = Enum.map(group.user_groups, & &1.user_id)
      # Owner + eligible member only; the outsider is dropped.
      assert ctx.admin.id in member_ids
      assert ctx.member.id in member_ids
      refute ctx.outsider.id in member_ids
    end

    test "create_business_circle_zk rejects a non-business org", ctx do
      {:ok, family} = Orgs.create_org(ctx.admin, %{"name" => "Fam", "type" => "family"})

      assert {:error, :not_a_business_org} =
               Groups.create_business_circle_zk(family, ctx.admin, zk_attrs(), [], [])
    end

    test "create_business_circle_zk rejects a creator who is not an org member", ctx do
      assert {:error, :not_an_org_member} =
               Groups.create_business_circle_zk(ctx.org, ctx.outsider, zk_attrs(), [], [])
    end

    test "add_business_circle_members_zk drops a non-org-member", ctx do
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), [], [])

      {newbie, _nk} = onboarded_user("ctxnewbie")
      add_member(ctx.org, newbie, :member)

      {:ok, inserted} =
        Groups.add_business_circle_members_zk(group, [
          sealed_for(newbie),
          sealed_for(ctx.outsider)
        ])

      assert inserted == 1
      refreshed = Groups.get_group!(group.id)
      member_ids = Enum.map(refreshed.user_groups, & &1.user_id)
      assert newbie.id in member_ids
      refute ctx.outsider.id in member_ids
    end

    test "list_business_circles is org-scoped", ctx do
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), [ctx.member], [
          sealed_for(ctx.member)
        ])

      # A second business org with its own circle — must not leak.
      {:ok, other_org} = Orgs.create_org(ctx.admin, %{"name" => "Initech", "type" => "business"})

      {:ok, _other_group} =
        Groups.create_business_circle_zk(other_org, ctx.admin, zk_attrs(), [], [])

      admin_circles = Groups.list_business_circles(ctx.org, ctx.admin)
      assert Enum.map(admin_circles, & &1.id) == [group.id]

      # The member starts unconfirmed (invited), so it isn't in their confirmed
      # list yet — mirrors the personal-circle invite flow. Confirming surfaces it.
      assert Groups.list_business_circles(ctx.org, ctx.member) == []

      member_ug = Enum.find(group.user_groups, &(&1.user_id == ctx.member.id))

      {:ok, {:ok, _}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          member_ug |> Mosslet.Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
        end)

      member_circles = Groups.list_business_circles(ctx.org, ctx.member)
      assert Enum.map(member_circles, & &1.id) == [group.id]
    end
  end
end
