defmodule MossletWeb.BusinessLiveTest do
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

  # Active personal (:user) subscription so the user can create/manage orgs
  # (org creation requires the owner to have finalized their own subscription —
  # Task #215 follow-up).
  defp subscribe_user(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    subscribe_user(user)
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

  defp subscribe_org(org, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 1)
    status = Keyword.get(opts, :status, "active")

    {:ok, customer} =
      Mosslet.Billing.Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _sub} =
      Mosslet.Billing.Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "business-monthly",
        status: status,
        quantity: quantity,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
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

    test "hides New business CTA + shows add-business note when an unpaid business is owned", %{
      conn: conn
    } do
      {user, key} = onboarded_user("bizupsell")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      refute has_element?(lv, "#new-business-button")
      assert has_element?(lv, "#business-upsell-note")
    end

    test "add-business note is trial-aware and does NOT tell trialing owners to subscribe", %{
      conn: conn
    } do
      # A user on a Business *trial* (their :user customer holds a trialing
      # business-* sub). They own a business; the note must acknowledge the
      # trial and offer to start the paid plan early — never "subscribe".
      email = "biztrial#{System.unique_integer([:positive])}@example.com"
      user = user_fixture(%{email: email, password: @password})
      user = Accounts.confirm_user!(user)
      {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

      {:ok, customer} =
        Customers.create_customer_for_source(:user, user.id, %{
          email: "billing-#{System.unique_integer([:positive])}@example.com",
          provider: "stripe",
          provider_customer_id: "cus_#{System.unique_integer([:positive])}"
        })

      {:ok, _sub} =
        Subscriptions.create_subscription(%{
          billing_customer_id: customer.id,
          plan_id: "business-monthly",
          status: "trialing",
          quantity: 1,
          provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
          provider_subscription_items: [%{price: "price_test"}],
          current_period_start: NaiveDateTime.utc_now()
        })

      {:ok, _org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      key = get_key(user)
      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      assert has_element?(lv, "#business-upsell-note")
      note_html = lv |> element("#business-upsell-note") |> render()

      assert note_html =~ "trial ends"
      assert note_html =~ "start your paid plan early"
      refute note_html =~ "Subscribe"
    end

    test "blocks creating a second unpaid owned business server-side", %{conn: _conn} do
      {user, _key} = onboarded_user("bizupsell")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})

      assert {:error, :business_entitlement_required} =
               Orgs.create_org(user, %{"name" => "Beta", "type" => "business"})
    end

    test "allows a second business once the first is on an active paid plan", %{conn: conn} do
      {user, key} = onboarded_user("bizupsell")
      {:ok, first} = Orgs.create_org(user, %{"name" => "Acme", "type" => "business"})
      subscribe_org(first)

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      assert has_element?(lv, "#new-business-button")
      refute has_element?(lv, "#business-upsell")

      assert {:ok, _second} = Orgs.create_org(user, %{"name" => "Beta", "type" => "business"})
    end

    test "guided onboarding create routes to org-scoped subscribe", %{conn: conn} do
      {user, key} = onboarded_user("bizonboard")

      conn = log_in(conn, user, key)
      {:ok, new_lv, _html} = live(conn, ~p"/app/business/new?onboarding=1")

      assert {:error, {:live_redirect, %{to: to}}} =
               new_lv
               |> form("#new-business-form", business: %{name: "Onboard Co"})
               |> render_submit()

      assert to =~ ~r{^/app/org/[^/]+/subscribe$}
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

    test "shows seat usage and blocks invite at cap counting pending invites", ctx do
      # Cap the business at 2 seats via a purchased subscription quantity.
      subscribe_org(ctx.org, quantity: 2)

      {:ok, lv, html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert html =~ "1 of 2 seats used"

      lv |> form("#invite-form", invite: %{email: "first@example.com"}) |> render_submit()
      assert render(lv) =~ "2 of 2 seats used"
      assert has_element?(lv, "#business-seat-full-notice")

      html =
        lv |> form("#invite-form", invite: %{email: "second@example.com"}) |> render_submit()

      assert html =~ "All seats are in use"
      assert Orgs.seat_summary(ctx.org).pending == 1
    end

    test "invites surface a pending-invitations list with resend + revoke", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#pending-invitations")

      lv |> form("#invite-form", invite: %{email: "pending@example.com"}) |> render_submit()

      assert has_element?(lv, "#pending-invitations")
      assert render(lv) =~ "pending@example.com"

      [invitation] = Orgs.list_invitations_by_org(ctx.org)
      assert has_element?(lv, "#resend-invitation-#{invitation.id}")
      assert has_element?(lv, "#revoke-invitation-#{invitation.id}")

      # Resend does not change the pending set.
      lv |> element("#resend-invitation-#{invitation.id}") |> render_click()
      assert length(Orgs.list_invitations_by_org(ctx.org)) == 1

      # Revoke removes it.
      lv |> element("#revoke-invitation-#{invitation.id}") |> render_click()
      assert Orgs.list_invitations_by_org(ctx.org) == []
      refute has_element?(lv, "#pending-invitations")
    end
  end

  describe "Org-dash per-circle member management (Task #231)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("mgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "MgCo", "type" => "business"})

      {member, member_key} = onboarded_user("mgmember")
      add_member(org, member, :member)

      {orgmate, _ok} = onboarded_user("mgorgmate")
      add_member(org, orgmate, :member)

      {outsider, _ok2} = onboarded_user("mgoutsider")

      {:ok, group} =
        Groups.create_business_circle_zk(org, admin, zk_attrs(), [member], [sealed_for(member)])

      confirm_circle_membership(group, member)

      %{
        conn: conn,
        org: org,
        group: group,
        admin: admin,
        admin_key: admin_key,
        member: member,
        member_key: member_key,
        orgmate: orgmate,
        outsider: outsider
      }
    end

    defp confirm_circle_membership(group, user) do
      ug = Enum.find(Groups.get_group!(group.id).user_groups, &(&1.user_id == user.id))

      {:ok, {:ok, _}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          ug |> Groups.UserGroup.confirm_changeset() |> Mosslet.Repo.update()
        end)

      :ok
    end

    test "an org admin can open the manage panel for a circle", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#manage-circle-#{ctx.group.id}")

      lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()

      assert has_element?(lv, "#manage-circle-panel-#{ctx.group.id}")
      # The circle's confirmed member appears with a Remove affordance.
      assert has_element?(lv, "#manage-remove-#{ctx.group.id}-#{ctx.member.id}")
      # The owner can't be removed.
      refute has_element?(lv, "#manage-remove-#{ctx.group.id}-#{ctx.admin.id}")
      # An org member not yet in the circle is addable.
      assert has_element?(lv, "#manage-add-#{ctx.group.id}-#{ctx.orgmate.id}")
    end

    test "an org admin can add an org member via the ZK finalize path", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()

      render_hook(lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(ctx.orgmate)]
      })

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == ctx.orgmate.id))
    end

    test "an outsider can never be added even via a tampered finalize", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()

      render_hook(lv, "request_add_members", %{"user_ids" => [ctx.outsider.id]})

      render_hook(lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(ctx.outsider)]
      })

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.outsider.id))
    end

    test "an org admin can remove a member from the circle", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()
      lv |> element("#manage-remove-#{ctx.group.id}-#{ctx.member.id}") |> render_click()

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.member.id))
    end

    test "the circle owner can never be removed even via a tampered event", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()
      render_hook(lv, "remove_circle_member", %{"user_id" => ctx.admin.id})

      group = Groups.get_group!(ctx.group.id)
      assert Enum.any?(group.user_groups, &(&1.user_id == ctx.admin.id))
    end

    test "a plain member cannot manage a circle (no affordance + tampered writes refused)", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      # A plain org member who is just a circle member has no manage affordance.
      refute has_element?(lv, "#manage-circle-#{ctx.group.id}")

      # Even if they force the panel open + push a write, the server refuses
      # (manage_circle_id is nil -> no-op; and can_manage_circle? is false).
      render_hook(lv, "manage_circle", %{"circle_id" => ctx.group.id})

      render_hook(lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(ctx.orgmate)]
      })

      group = Groups.get_group!(ctx.group.id)
      refute Enum.any?(group.user_groups, &(&1.user_id == ctx.orgmate.id))
    end

    test "realtime: adding a member from the dash updates an open circle page", ctx do
      # The member has the circle page open; the admin adds the orgmate from the
      # org dashboard. The org-update broadcast must refresh the circle roster.
      {:ok, circle_lv, _html} =
        ctx.conn
        |> log_in(ctx.member, ctx.member_key)
        |> live(~p"/app/business/#{ctx.org.slug}/circles/#{ctx.group.id}")

      refute has_element?(circle_lv, "#circle-member-#{ctx.orgmate.id}")

      {:ok, dash_lv, _html} =
        ctx.conn
        |> log_in(ctx.admin, ctx.admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      dash_lv |> element("#manage-circle-#{ctx.group.id}") |> render_click()

      render_hook(dash_lv, "finalize_group_members_zk", %{
        "sealed_members" => [sealed_for(ctx.orgmate)]
      })

      # The open circle page picks up the new member live (no reload).
      assert has_element?(circle_lv, "#circle-member-#{ctx.orgmate.id}")
    end
  end

  describe "Connect with teammate (Task #226)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("connadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Connectel", "type" => "business"})

      {member, _mk} = onboarded_user("connmember")
      add_member(org, member, :member)

      %{conn: conn, admin: admin, admin_key: admin_key, org: org, member: member}
    end

    test "shows a Connect button for an unconnected teammate", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # Button appears for the other member, but never for self.
      assert has_element?(lv, "#connect-#{ctx.member.id}")
      refute has_element?(lv, "#connect-#{ctx.admin.id}")
    end

    test "clicking Connect sends a UserConnection invite and flips to Pending", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#connect-pending-#{ctx.member.id}")

      lv |> element("#connect-#{ctx.member.id}") |> render_click()

      # A pending (unconfirmed) personal connection row now exists between the
      # admin (requester) and member (recipient). On create, the row is
      # user_id=recipient, reverse_user_id=requester (an "arrival" for the
      # recipient), so we look it up from the recipient's side.
      assert %{} = uconn = Accounts.get_user_connection_between_users(ctx.admin.id, ctx.member.id)
      assert is_nil(uconn.confirmed_at)

      # The button is replaced by a non-actionable Pending pill.
      refute has_element?(lv, "#connect-#{ctx.member.id}")
      assert has_element?(lv, "#connect-pending-#{ctx.member.id}")
    end

    test "connect_teammate refuses a non-member and self (server-authoritative)", ctx do
      {outsider, _ok} = onboarded_user("connoutsider")
      scope = %{user: Accounts.preload_connection(ctx.admin), key: ctx.admin_key}

      assert {:error, :not_a_member} =
               MossletWeb.OrgIdentity.connect_teammate(ctx.org, scope, outsider.id)

      assert {:error, :not_a_member} =
               MossletWeb.OrgIdentity.connect_teammate(ctx.org, scope, ctx.admin.id)
    end

    test "connection_statuses_for batches status across directions", ctx do
      {other, _ok} = onboarded_user("connother")
      add_member(ctx.org, other, :member)

      statuses = Accounts.connection_statuses_for(ctx.admin.id, [ctx.member.id, other.id])
      assert statuses[ctx.member.id] == :none
      assert statuses[other.id] == :none

      scope = %{user: Accounts.preload_connection(ctx.admin), key: ctx.admin_key}
      {:ok, _uconn} = MossletWeb.OrgIdentity.connect_teammate(ctx.org, scope, ctx.member.id)

      statuses = Accounts.connection_statuses_for(ctx.admin.id, [ctx.member.id, other.id])
      assert statuses[ctx.member.id] == :pending
      assert statuses[other.id] == :none
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

      # A second business org (owned by a different user, so it isn't gated by
      # the multi-business entitlement) with its own circle — must not leak.
      {:ok, other_org} =
        Orgs.create_org(ctx.outsider, %{"name" => "Initech", "type" => "business"})

      {:ok, _other_group} =
        Groups.create_business_circle_zk(other_org, ctx.outsider, zk_attrs(), [], [])

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

    test "add_group_members_zk enforces I1 by construction on a business circle", ctx do
      # This is the function the UI edit path actually calls
      # (form_component.ex finalize_group_members_zk). It must drop a non-org
      # member even though it is NOT the business-specific helper.
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), [], [])

      {newbie, _nk} = onboarded_user("ctxnewbie2")
      add_member(ctx.org, newbie, :member)

      {:ok, inserted} =
        Groups.add_group_members_zk(group, [
          sealed_for(newbie),
          sealed_for(ctx.outsider)
        ])

      # Only the org member is sealed in; the outsider is dropped server-side.
      assert inserted == 1
      refreshed = Groups.get_group!(group.id)
      member_ids = Enum.map(refreshed.user_groups, & &1.user_id)
      assert newbie.id in member_ids
      refute ctx.outsider.id in member_ids
    end

    test "add_group_members_zk does NOT filter members on a personal circle", ctx do
      # A personal circle has org_id == nil — I1 must not apply, and any
      # sealed_members are inserted as before (no org filtering).
      {:ok, group} =
        Groups.create_group_zk(zk_attrs(), ctx.admin, [], [])

      assert is_nil(group.org_id)

      {:ok, inserted} =
        Groups.add_group_members_zk(group, [
          sealed_for(ctx.member),
          sealed_for(ctx.outsider)
        ])

      # Both are inserted: a personal circle is governed only by the editor's
      # connections, exactly as before this change.
      assert inserted == 2
      refreshed = Groups.get_group!(group.id)
      member_ids = Enum.map(refreshed.user_groups, & &1.user_id)
      assert ctx.member.id in member_ids
      assert ctx.outsider.id in member_ids
    end
  end
end
