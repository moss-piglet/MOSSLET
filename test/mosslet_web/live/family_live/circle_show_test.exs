defmodule MossletWeb.FamilyLive.CircleShowTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
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

  defp subscribe_org(org) do
    plan_id = if org.type == :family, do: "family-monthly", else: "business-monthly"

    customer =
      case Customers.get_customer_by_source(:org, org.id) do
        nil ->
          {:ok, customer} =
            Customers.create_customer_for_source(:org, org.id, %{
              email: "billing-#{System.unique_integer([:positive])}@example.com",
              provider: "stripe",
              provider_customer_id: "cus_#{System.unique_integer([:positive])}"
            })

          customer

        customer ->
          customer
      end

    {:ok, _sub} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: plan_id,
        status: "active",
        quantity: 5,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    username = "#{name_seed}#{System.unique_integer([:positive])}"
    user = user_fixture(%{email: email, username: username, password: @password})
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

  defp zk_attrs do
    %{
      encrypted_name: "encrypted-name-blob",
      encrypted_description: "encrypted-desc-blob",
      name_blind_index: "fam circle #{System.unique_integer([:positive])}",
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

  defp confirm_membership(group, user) do
    ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

    {:ok, {:ok, _}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        ug |> Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
      end)

    :ok
  end

  setup %{conn: conn} do
    {owner, owner_key} = onboarded_user("fcowner")
    {:ok, family} = Orgs.create_org(owner, %{"name" => "FamilyCircleCo", "type" => "family"})
    :ok = subscribe_org(family)

    {member, member_key} = onboarded_user("fcmember")
    add_member(family, member, :member)

    {outsider, outsider_key} = onboarded_user("fcoutsider")

    {:ok, group} =
      Groups.create_family_circle_zk(family, owner, zk_attrs(), [member], [sealed_for(member)])

    confirm_membership(group, member)

    %{
      conn: conn,
      family: family,
      group: group,
      owner: owner,
      owner_key: owner_key,
      member: member,
      member_key: member_key,
      outsider: outsider,
      outsider_key: outsider_key
    }
  end

  describe "mount auth + eligibility" do
    test "a confirmed family circle member can view the circle", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.owner, ctx.owner_key)
        |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#shared-files-panel")
      assert has_element?(lv, "#circle-members-roster")
      assert has_element?(lv, "#circle-chat-panel")
    end

    test "redirects a non-member of the family to the family index", ctx do
      assert {:error, {:live_redirect, %{to: "/app/family"}}} =
               ctx.conn
               |> log_in(ctx.outsider, ctx.outsider_key)
               |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")
    end

    test "redirects a business org away (family only)", ctx do
      {:ok, business} =
        Orgs.create_org(ctx.owner, %{"name" => "Bizco", "type" => "business"})

      :ok = subscribe_org(business)

      assert {:error, {:live_redirect, %{to: "/app/family"}}} =
               ctx.conn
               |> log_in(ctx.owner, ctx.owner_key)
               |> live(~p"/app/family/#{business.slug}/circles/#{ctx.group.id}")
    end
  end

  describe "leave circle (family route)" do
    test "a non-owner member leaves and is bounced to the family dashboard", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#leave-circle-button")

      assert {:error, {:live_redirect, %{to: to}}} =
               lv |> element("#leave-circle-button") |> render_click()

      assert to == "/app/family/#{ctx.family.slug}"

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.member.id))
    end
  end

  describe "guardian co-read (Task #271)" do
    setup ctx do
      {managed, managed_key} = onboarded_user("fcmanaged")
      managed_ms = add_member(ctx.family, managed, :managed_member)

      {guardian, guardian_key} = onboarded_user("fcguardian")
      guardian_ms = add_member(ctx.family, guardian, :guardian)

      {:ok, g} = Orgs.establish_guardianship(guardian_ms, managed_ms)
      {:ok, _g} = Orgs.accept_guardianship(g)

      Map.merge(ctx, %{
        managed: managed,
        managed_key: managed_key,
        guardian: guardian,
        guardian_key: guardian_key
      })
    end

    test "adding a managed member also seals the circle key for their active guardian", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.owner, ctx.owner_key)
        |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")

      # Phase 1: the owner selects ONLY the managed member to add. The server
      # must, server-authoritatively, also include the managed member's active
      # guardian in the seal targets (guardian co-read — derived from the
      # Guardianship record, not the client's selection).
      render_hook(lv, "request_add_members", %{"user_ids" => [ctx.managed.id]})

      assert_push_event(lv, "seal_group_key_for_new_members", %{members: members})

      seal_target_ids = Enum.map(members, & &1.user_id)
      assert ctx.managed.id in seal_target_ids
      assert ctx.guardian.id in seal_target_ids
    end

    test "the guardian co-read transparency notice shows when a managed member is in the circle",
         ctx do
      # Add + confirm the managed member into the circle.
      {:ok, _} = Groups.add_group_members_zk(ctx.group, [sealed_for(ctx.managed)])
      confirm_membership(ctx.group, ctx.managed)

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.owner, ctx.owner_key)
        |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")

      assert has_element?(lv, "#family-circle-guardian-notice")
    end

    test "no guardian notice when the circle has no managed members", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.owner, ctx.owner_key)
        |> live(~p"/app/family/#{ctx.family.slug}/circles/#{ctx.group.id}")

      refute has_element?(lv, "#family-circle-guardian-notice")
    end
  end
end
