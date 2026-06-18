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

  # Seals an (opaque) org_key for a member so view-models that gate on the
  # viewer holding the org_key (e.g. the brand-logo decrypt hook, Task #228)
  # render. Server-side the sealed key is just an opaque blob — the real value
  # is browser-generated/sealed; tests only need a non-nil membership.key.
  defp seal_org_key(org, user) do
    {:ok, _count} =
      Orgs.seal_org_key_for_members(org, [
        %{user_id: user.id, sealed_key: "sealed-org-key-#{System.unique_integer([:positive])}"}
      ])

    :ok
  end

  # Attaches (or updates) the org's own `:org`-source subscription so its content
  # surfaces are reachable (Option B, Task #235). Idempotent on the customer and
  # on the subscription, so a setup can activate the org and a test can later
  # re-call with a specific seat `quantity`/`status` without creating duplicate
  # customers (which `get_customer_by_source/2` forbids via `Repo.one/1`).
  defp subscribe_org(org, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 1)
    status = Keyword.get(opts, :status, "active")
    plan_id = Keyword.get(opts, :plan_id, "business-monthly")
    items = Keyword.get(opts, :items, [%{"price_id" => "price_test"}])

    customer =
      case Mosslet.Billing.Customers.get_customer_by_source(:org, org.id) do
        nil ->
          {:ok, customer} =
            Mosslet.Billing.Customers.create_customer_for_source(:org, org.id, %{
              email: "billing-#{System.unique_integer([:positive])}@example.com",
              provider: "stripe",
              provider_customer_id: "cus_#{System.unique_integer([:positive])}"
            })

          customer

        customer ->
          customer
      end

    attrs = %{
      billing_customer_id: customer.id,
      plan_id: plan_id,
      status: status,
      quantity: quantity,
      provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
      provider_subscription_items: items,
      current_period_start: NaiveDateTime.utc_now()
    }

    case Mosslet.Billing.Subscriptions.get_active_subscription_by_customer_id(customer.id) do
      nil ->
        {:ok, _sub} = Mosslet.Billing.Subscriptions.create_subscription(attrs)

      existing ->
        {:ok, _sub} =
          Mosslet.Billing.Subscriptions.update_subscription(existing, %{
            status: status,
            quantity: quantity,
            provider_subscription_items: items
          })
    end

    :ok
  end

  defp subdomain_addon_price,
    do:
      Mosslet.Billing.Plans.subdomain_addon_price(
        Mosslet.Billing.Plans.get_plan_by_id!("business-monthly")
      )

  defp subscribe_family(org), do: subscribe_org(org, plan_id: "family-monthly")

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

      # Under Option B (Task #235) a newly created org is INERT and the owner is
      # funneled straight to org-scoped checkout to activate it — the org content
      # stays gated until its `:org` plan is purchased.
      {:error, {:live_redirect, %{to: redirect_to}}} =
        new_lv
        |> form("#new-business-form", business: %{name: "Acme Inc"})
        |> render_submit()

      [%{slug: slug, type: :business}] = Orgs.list_owned_orgs(user, :business)
      assert redirect_to == ~p"/app/org/#{slug}/subscribe"
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

    test "an inert (unpaid) owned business shows an Activate card, not a content link",
         %{conn: conn} do
      {user, key} = onboarded_user("bizinert")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Inert Co", "type" => "business"})

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      assert has_element?(lv, "#business-inert-#{org.id}")
      assert has_element?(lv, "#business-activate-#{org.id}")
      refute has_element?(lv, "a[href='/app/business/#{org.slug}']")
    end

    test "an active owned business links to its content surface", %{conn: conn} do
      {user, key} = onboarded_user("bizactive")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Active Co", "type" => "business"})
      subscribe_org(org)

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      assert has_element?(lv, "a[href='/app/business/#{org.slug}']")
      refute has_element?(lv, "#business-inert-#{org.id}")
    end

    test "a business with a logo renders the decrypt hook on its card (Task #228)", %{conn: conn} do
      {user, key} = onboarded_user("bizlogo")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Logo Co", "type" => "business"})
      subscribe_org(org)
      {:ok, _org} = Orgs.set_org_logo(org, "uploads/files/#{Ecto.UUID.generate()}.bin")
      seal_org_key(org, user)

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      assert has_element?(lv, "#business-logo-#{org.id}[phx-hook='OrgLogoDisplay']")
    end

    test "a logo-less business renders the building fallback (no hook)", %{conn: conn} do
      {user, key} = onboarded_user("biznologo")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Plain Co", "type" => "business"})
      subscribe_org(org)

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/business")

      refute has_element?(lv, "#business-logo-#{org.id}")
    end
  end

  describe "BusinessLive.Show" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("orgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Acme", "type" => "business"})
      # Activate the org's own `:org` plan so its content surfaces are reachable
      # (Option B, Task #235): inert/unpaid orgs redirect to subscribe. Use the
      # business seat floor so invite tests aren't seat-capped (the seat-cap test
      # re-subscribes with an explicit quantity).
      subscribe_org(org, quantity: 20)

      %{conn: conn, admin: admin, admin_key: admin_key, org: org}
    end

    test "redirects when org is not a business", %{conn: conn} do
      {user, key} = onboarded_user("famuser")
      {:ok, family} = Orgs.create_org(user, %{"name" => "Joneses", "type" => "family"})
      # Activate the family org so it passes the :require_active_org gate — we're
      # asserting the LiveView's type mismatch redirect, not the activation gate.
      subscribe_family(family)

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

  describe "BusinessLive.Show branding (Task #228)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("brandadmin")
      {member, member_key} = onboarded_user("brandmember")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Acme", "type" => "business"})
      subscribe_org(org, quantity: 20)
      add_member(org, member, :member)

      %{
        conn: conn,
        admin: admin,
        admin_key: admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "admins see the Branding upload section", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-branding")
      assert has_element?(lv, "#org-logo-uploader")
      assert has_element?(lv, "label", "Upload logo")
    end

    test "non-admin members do NOT see the Branding section (admins-only)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-branding")
    end

    test "header shows the building fallback (no decrypt hook) when no logo is set", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-header-logo")
    end

    test "with a logo set, the header + branding preview render the decrypt hook + remove", ctx do
      {:ok, _org} = Orgs.set_org_logo(ctx.org, "uploads/files/#{Ecto.UUID.generate()}.bin")
      # The decrypt hook only renders when the viewer holds the org_key (sealed
      # in their membership). Seal an opaque key for the admin (server-side it's
      # just an opaque blob — the real value is browser-generated).
      seal_org_key(ctx.org, ctx.admin)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-header-logo[phx-hook='OrgLogoDisplay']")
      assert has_element?(lv, "#org-logo-remove")
      assert has_element?(lv, "label", "Replace logo")
    end

    test "removing the logo clears it and reverts to the fallback", ctx do
      {:ok, _org} = Orgs.set_org_logo(ctx.org, "uploads/files/#{Ecto.UUID.generate()}.bin")
      seal_org_key(ctx.org, ctx.admin)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-header-logo")

      lv |> element("#org-logo-remove") |> render_click()

      refute has_element?(lv, "#org-header-logo")
      assert Orgs.get_org_by_id(ctx.org.id).logo_url == nil
    end
  end

  describe "BusinessLive.Show display-name editing (Task #263)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("nameowner")
      {admin, admin_key} = onboarded_user("nameadmin")
      {member, member_key} = onboarded_user("namemember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      subscribe_org(org, quantity: 20)
      add_member(org, admin, :admin)
      add_member(org, member, :member)
      # Every editor needs to hold the org_key (UI gating); the sealed value is
      # opaque server-side.
      seal_org_key(org, owner)
      seal_org_key(org, admin)
      seal_org_key(org, member)

      %{
        conn: conn,
        owner: owner,
        owner_key: owner_key,
        admin: admin,
        admin_key: admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "a member can rename THEMSELVES (no target_user_id)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-self"
      })

      assert Orgs.get_membership!(ctx.member, ctx.org.slug).display_name == "ciphertext-self"
    end

    test "an admin can rename ANOTHER member (target_user_id)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-by-admin",
        "target_user_id" => ctx.member.id
      })

      assert Orgs.get_membership!(ctx.member, ctx.org.slug).display_name == "ciphertext-by-admin"
    end

    test "a non-admin member CANNOT rename another member (server re-authorizes)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-tampered",
        "target_user_id" => ctx.admin.id
      })

      assert is_nil(Orgs.get_membership!(ctx.admin, ctx.org.slug).display_name)
    end

    test "a self-rename records a display_name_changed audit event (actor == target) (#264)",
         ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-self"
      })

      [event] = Orgs.Audit.list_audit_events(ctx.org)
      assert event.action == "display_name_changed"
      assert event.actor_id == ctx.member.id
      assert event.target_id == ctx.member.id
      assert event.target_type == "user"
    end

    test "an admin renaming another member records a display_name_changed event (actor != target) (#264)",
         ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-by-admin",
        "target_user_id" => ctx.member.id
      })

      [event] = Orgs.Audit.list_audit_events(ctx.org)
      assert event.action == "display_name_changed"
      assert event.actor_id == ctx.admin.id
      assert event.target_id == ctx.member.id
    end

    test "a rejected (tampered) rename records NO audit event (#264)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "save_org_display_name", %{
        "encrypted_display_name" => "ciphertext-tampered",
        "target_user_id" => ctx.admin.id
      })

      assert Orgs.Audit.list_audit_events(ctx.org) == []
    end

    test "the viewer sees an edit affordance on their OWN row once a name is set", ctx do
      membership = Orgs.get_membership!(ctx.member, ctx.org.slug)
      {:ok, _} = Orgs.set_org_display_name(membership, "ciphertext-existing")

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#edit-name-#{ctx.member.id}")

      lv |> element("#edit-name-#{ctx.member.id}") |> render_click()

      assert has_element?(
               lv,
               "#edit-name-form-#{ctx.member.id}[phx-hook='OrgDisplayNameFormHook']"
             )
    end

    test "admins see an edit affordance on OTHER members' rows", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#edit-name-#{ctx.member.id}")
    end

    test "non-admin members do NOT see an edit affordance on OTHER members' rows", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#edit-name-#{ctx.admin.id}")
    end
  end

  describe "BusinessLive.Show custom subdomain (Task #240 / #243, branding add-on)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("subadmin")
      {member, member_key} = onboarded_user("submember")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Acme", "type" => "business"})
      add_member(org, member, :member)

      %{
        conn: conn,
        admin: admin,
        admin_key: admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "without the add-on, the logo is FREE but the subdomain shows an upsell (not a claim form)",
         ctx do
      # Active Business plan, but NO subdomain add-on line item.
      subscribe_org(ctx.org, items: [%{"price_id" => "price_test"}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # Logo is free for all Business orgs.
      assert has_element?(lv, "#org-logo-uploader")

      # Subdomain is gated: section present, but no claim form — the add-on upsell.
      assert has_element?(lv, "#org-subdomain")
      refute has_element?(lv, "#org-subdomain-form")
      assert has_element?(lv, "#org-subdomain-upsell-addon")
    end

    test "the upsell offers a one-click add-on purchase button (no checkout detour)", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => "price_test"}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # The active-org gap (Task #243 follow-up): add it in one click, with a
      # "Manage billing" escape hatch still available for review.
      assert has_element?(lv, "#org-subdomain-add-addon")
    end

    test "an active/trialing org is NOT told to 'subscribe' (trial-aware upsell)", ctx do
      subscribe_org(ctx.org, status: "trialing", items: [%{"price_id" => "price_test"}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # Covered org -> add-on upsell, NOT the "activate a plan / choose a plan" path.
      assert has_element?(lv, "#org-subdomain-upsell-addon")
      refute has_element?(lv, "#org-subdomain-upsell-plan")
    end

    test "with the add-on active, admins see the claim form", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-subdomain-form")
      refute has_element?(lv, "#org-subdomain-upsell-addon")
    end

    test "claiming a subdomain when entitled persists it and shows the live URL", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      lv
      |> form("#org-subdomain-form", branding: %{subdomain: "acmeteam"})
      |> render_submit()

      assert Orgs.get_org_by_id(ctx.org.id).subdomain == "acmeteam"
      assert has_element?(lv, "#org-subdomain-current")
    end

    test "a reserved/watchlist subdomain is rejected (no DB write)", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # Reserved infra label.
      lv |> form("#org-subdomain-form", branding: %{subdomain: "www"}) |> render_submit()
      assert Orgs.get_org_by_id(ctx.org.id).subdomain == nil

      # Finance/impersonation watchlist label.
      lv |> form("#org-subdomain-form", branding: %{subdomain: "paypal"}) |> render_submit()
      assert Orgs.get_org_by_id(ctx.org.id).subdomain == nil
    end

    test "non-admin members do NOT see the branding section at all (admins-only)", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-branding")
      refute has_element?(lv, "#org-subdomain")
    end

    test "a NON-OWNER admin manages the free logo but NOT the (billing) subdomain", ctx do
      {other_admin, other_admin_key} = onboarded_user("subotheradmin")
      add_member(ctx.org, other_admin, :admin)
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn
        |> log_in(other_admin, other_admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      # Free logo stays admin-manageable...
      assert has_element?(lv, "#org-logo-uploader")
      # ...but the subdomain (mutates the paid subscription) is owner-only.
      refute has_element?(lv, "#org-subdomain")
    end

    test "the branded-space pointer is shown to ALL members once the subdomain is live (Task #246)",
         ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])
      {:ok, _org} = Orgs.set_org_subdomain(ctx.org, %{"subdomain" => "acmeteam"})

      # A regular (non-admin) member sees the pointer + the "open" CTA (the test
      # host is the apex, so the member is not yet on the branded subdomain).
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-branded-space")
      assert has_element?(lv, "#org-branded-space-open")
      refute has_element?(lv, "#org-branded-space-here")
    end

    test "the branded-space pointer is absent when the subdomain is NOT live (Task #246)", ctx do
      # Logo-only org (no add-on) — subdomain isn't served, so no pointer.
      subscribe_org(ctx.org, items: [%{"price_id" => "price_test"}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-branded-space")
    end
  end

  describe "BusinessLive.Show seats (Task #247, owner-only add-seats)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("seatowner")
      {other_admin, other_admin_key} = onboarded_user("seatadmin")
      {member, member_key} = onboarded_user("seatmember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      subscribe_org(org, quantity: 20)
      add_member(org, other_admin, :admin)
      add_member(org, member, :member)

      %{
        conn: conn,
        owner: owner,
        owner_key: owner_key,
        other_admin: other_admin,
        other_admin_key: other_admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "the owner sees the in-app seat control", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-seat-management")
      assert has_element?(lv, "#org-seat-form")
      assert has_element?(lv, "#org-seat-input")
      assert has_element?(lv, "#org-seat-update")
    end

    test "a NON-OWNER admin does NOT see the seat control (mutates the paid subscription)", ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.other_admin, ctx.other_admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-seat-management")
    end

    test "a member does NOT see the seat control", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-seat-management")
    end

    test "the seat-full notice's 'Add more seats' points at the on-page control (no dead-end)",
         ctx do
      subscribe_org(ctx.org, quantity: 1)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#business-seat-full-notice")
      assert has_element?(lv, "#business-seat-full-notice a[href='#org-seat-management']")
    end
  end

  describe "BusinessLive.Show Manage disclosure + responsive layout (Task #248)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("mgrowner")
      {other_admin, other_admin_key} = onboarded_user("mgradmin")
      {member, member_key} = onboarded_user("mgrmember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      # Seat-based subscription (quantity) AND the subdomain add-on, so every
      # setup surface (branding, subdomain, seats, ownership) is available.
      subscribe_org(org, quantity: 20, items: [%{"price_id" => subdomain_addon_price()}])
      add_member(org, other_admin, :admin)
      add_member(org, member, :member)

      %{
        conn: conn,
        owner: owner,
        owner_key: owner_key,
        other_admin: other_admin,
        other_admin_key: other_admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "everyday surfaces stay primary, outside the Manage disclosure", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      # Members + invite render, and are NOT nested inside the Manage panel.
      assert has_element?(lv, "#org-members-roster")
      assert has_element?(lv, "#invite-form")
      refute has_element?(lv, "#org-manage-panel #org-members-roster")
      refute has_element?(lv, "#org-manage-panel #invite-form")
    end

    test "the Manage disclosure is collapsed by default and toggles open (owner)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-manage")
      assert has_element?(lv, "#org-manage-panel")
      assert has_element?(lv, "#org-manage-toggle[aria-expanded='false']")

      lv |> element("#org-manage-toggle") |> render_click()
      assert has_element?(lv, "#org-manage-toggle[aria-expanded='true']")

      # Toggling again collapses it.
      lv |> element("#org-manage-toggle") |> render_click()
      assert has_element?(lv, "#org-manage-toggle[aria-expanded='false']")
    end

    test "all setup surfaces live INSIDE the Manage panel (relocated, ids preserved)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-manage-panel #org-branding")
      assert has_element?(lv, "#org-manage-panel #org-subdomain")
      assert has_element?(lv, "#org-manage-panel #org-seat-management")
      assert has_element?(lv, "#org-manage-panel #org-ownership-section")
    end

    test "a non-owner admin sees Manage with branding, but NOT the owner-only seats/subdomain",
         ctx do
      {:ok, lv, _html} =
        ctx.conn
        |> log_in(ctx.other_admin, ctx.other_admin_key)
        |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-manage")
      assert has_element?(lv, "#org-manage-panel #org-branding")
      refute has_element?(lv, "#org-subdomain")
      refute has_element?(lv, "#org-seat-management")
    end

    test "a plain member sees NO Manage disclosure (nothing to set up)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-manage")
      refute has_element?(lv, "#org-branding")
      refute has_element?(lv, "#org-seat-management")
    end

    test "the seat-full notice's 'Add more seats' opens the Manage disclosure (deep-link)", ctx do
      subscribe_org(ctx.org, quantity: 1, items: [%{"price_id" => subdomain_addon_price()}])

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-manage-toggle[aria-expanded='false']")

      lv
      |> element("#business-seat-full-notice a[href='#org-seat-management']")
      |> render_click()

      assert has_element?(lv, "#org-manage-toggle[aria-expanded='true']")
    end
  end

  describe "BusinessLive.Show ownership transfer (Task #237)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("owner")
      {member, member_key} = onboarded_user("member")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Acme", "type" => "business"})
      subscribe_org(org, quantity: 20)
      add_member(org, member, :member)

      %{
        conn: conn,
        admin: admin,
        admin_key: admin_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "owner sees the Ownership section and can open the transfer modal", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-ownership-section")
      # Transfer/delete live in the calm "manage organization" dropdown now.
      assert has_element?(lv, "#org-manage-menu")
      assert lv |> element("#org-manage-menu-menu") |> render() =~ "Transfer ownership"

      render_hook(lv, "open_transfer_modal", %{})
      # The modal is teleported to <body> via a portal, so query its rendered HTML.
      modal_html = lv |> element("#transfer-ownership-modal-portal") |> render()
      assert modal_html =~ "transfer-ownership-modal"
      assert modal_html =~ "transfer-option-#{ctx.member.id}"
    end

    test "the owner shows an Owner badge and can't be removed or role-changed by an admin", ctx do
      # Promote the member to admin so they CAN manage, then verify they still
      # can't act on the owner.
      owner_role = Orgs.get_membership!(ctx.admin, ctx.org.slug).role
      member_ms = Orgs.get_membership!(ctx.member, ctx.org.slug)
      {:ok, _} = Orgs.update_membership(member_ms, %{"role" => "admin"})

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#owner-badge-#{ctx.admin.id}")
      refute has_element?(lv, "#offboard-#{ctx.admin.id}")
      refute has_element?(lv, "#role-form-#{ctx.admin.id}")

      # Server-side guard: a forged change_role on the owner is a no-op.
      render_hook(lv, "change_role", %{"user_id" => ctx.admin.id, "role" => "member"})
      assert Orgs.get_membership!(ctx.admin, ctx.org.slug).role == owner_role
    end

    test "owner of a single-member org sees the invite-first notice, no transfer button", ctx do
      {solo, solo_key} = onboarded_user("solo")
      {:ok, solo_org} = Orgs.create_org(solo, %{"name" => "Solo Co", "type" => "business"})
      subscribe_org(solo_org, quantity: 20)

      {:ok, lv, _html} =
        ctx.conn |> log_in(solo, solo_key) |> live(~p"/app/business/#{solo_org.slug}")

      assert has_element?(lv, "#ownership-no-members-notice")
      # The manage menu still appears (delete is available), but the Transfer
      # item is hidden until there's an eligible member to hand off to.
      refute lv |> element("#org-manage-menu-menu") |> render() =~ "Transfer ownership"
    end

    test "initiating a transfer with the correct password creates a pending transfer", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "open_transfer_modal", %{})

      # The transfer form lives inside the body-portaled modal, so submit its
      # event directly (this is exactly what the form's phx-submit emits).
      render_hook(lv, "initiate_transfer", %{
        "to_user_id" => ctx.member.id,
        "transfer" => %{"password" => @password}
      })

      assert %{to_user_id: to_id} = Orgs.get_pending_transfer_for_org(ctx.org)
      assert to_id == ctx.member.id
      assert render(lv) =~ "Ownership transfer sent"
    end

    test "a wrong password is refused with a friendly error", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_hook(lv, "open_transfer_modal", %{})

      html =
        render_hook(lv, "initiate_transfer", %{
          "to_user_id" => ctx.member.id,
          "transfer" => %{"password" => "the wrong password"}
        })

      assert html =~ "password is incorrect"
      assert Orgs.get_pending_transfer_for_org(ctx.org) == nil
    end

    test "the proposed new owner sees Accept/Decline and can accept", ctx do
      {:ok, _transfer} =
        Orgs.initiate_ownership_transfer(ctx.org, ctx.admin, ctx.member, @password)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#incoming-transfer-panel")
      assert has_element?(lv, "#accept-transfer-form")

      lv
      |> form("#accept-transfer-form", %{"transfer" => %{"password" => @password}})
      |> render_submit()

      assert Orgs.owner?(Orgs.get_org_by_id(ctx.org.id), ctx.member.id)
    end

    test "the proposed new owner can decline", ctx do
      {:ok, _transfer} =
        Orgs.initiate_ownership_transfer(ctx.org, ctx.admin, ctx.member, @password)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      lv |> element("#decline-transfer-submit") |> render_click()

      assert Orgs.get_pending_transfer_for_org(ctx.org) == nil
      assert Orgs.owner?(Orgs.get_org_by_id(ctx.org.id), ctx.admin.id)
    end
  end

  describe "Org-dash per-circle member management (Task #231)" do
    setup %{conn: conn} do
      {admin, admin_key} = onboarded_user("mgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "MgCo", "type" => "business"})
      subscribe_org(org, quantity: 20)

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
      subscribe_org(org, quantity: 20)

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

    test "create_business_circle_zk defaults to a :community circle (#229b)", ctx do
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), [], [])

      assert group.org_circle_type == :community
    end

    test "an org owner/admin can create an official :team circle (#229b)", ctx do
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.admin, zk_attrs(), [], [], :team)

      assert group.org_circle_type == :team
    end

    test "any org member can create a :community circle (#229b)", ctx do
      {:ok, group} =
        Groups.create_business_circle_zk(ctx.org, ctx.member, zk_attrs(), [], [], :community)

      assert group.org_circle_type == :community
    end

    test "a non-admin member cannot create a :team circle (#229b)", ctx do
      assert {:error, :unauthorized_team_circle} =
               Groups.create_business_circle_zk(ctx.org, ctx.member, zk_attrs(), [], [], :team)
    end

    test "can_create_team_circle? gates on org owner/admin (#229b)", ctx do
      assert Orgs.can_create_team_circle?(ctx.org, ctx.admin.id)
      refute Orgs.can_create_team_circle?(ctx.org, ctx.member.id)
      refute Orgs.can_create_team_circle?(ctx.org, ctx.outsider.id)
    end

    test "a personal circle never gets an org_circle_type (#229b)", ctx do
      {:ok, group} = Groups.create_group_zk(zk_attrs(), ctx.admin, [], [])

      assert is_nil(group.org_id)
      assert is_nil(group.org_circle_type)
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

  describe "apex branded-space banner (Task #246)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("bannerowner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      %{conn: conn, owner: owner, owner_key: owner_key, org: org}
    end

    test "shows on apex for a member of a branding-live org", ctx do
      subscribe_org(ctx.org, items: [%{"price_id" => subdomain_addon_price()}])
      {:ok, _org} = Orgs.set_org_subdomain(ctx.org, %{"subdomain" => "acmeteam"})

      {:ok, lv, _html} = ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app")

      assert has_element?(lv, "#branded-space-banner")
      assert has_element?(lv, "#branded-space-banner-switch")
    end

    test "is absent when the member's orgs have no live subdomain", ctx do
      # Active org but no subdomain add-on (logo-only) -> not served on a subdomain.
      subscribe_org(ctx.org, items: [%{"price_id" => "price_test"}])

      {:ok, lv, _html} = ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app")

      refute has_element?(lv, "#branded-space-banner")
    end
  end

  describe "sign-out link (mosslet:logout ZK-wipe dispatcher, Task #246)" do
    test "the authenticated layout renders a DELETE sign-out link to /auth/sign_out", %{
      conn: conn
    } do
      {owner, owner_key} = onboarded_user("signoutlink")

      {:ok, lv, _html} = conn |> log_in(owner, owner_key) |> live(~p"/app")

      # The global click dispatcher in app.js matches exactly these attributes to
      # fire `mosslet:logout` (which wipes sessionStorage/localStorage/IndexedDB
      # ZK keys) — identical on apex and org subdomains.
      assert has_element?(lv, ~s|a[data-to="/auth/sign_out"][data-method="delete"]|)
    end
  end

  describe "ZK admin activity log (Task #212)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("auditowner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Audited Co", "type" => "business"})
      subscribe_org(org, quantity: 20)

      {member, member_key} = onboarded_user("auditmember")
      add_member(org, member, :member)

      %{
        conn: conn,
        owner: owner,
        owner_key: owner_key,
        org: org,
        member: member,
        member_key: member_key
      }
    end

    test "an admin/owner sees the activity log panel + export wiring", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#org-audit-log")
      # The hook carries the member directory + the viewer's sealed org_key so it
      # can resolve names client-side (ZK).
      assert has_element?(lv, "#org-audit-log[phx-hook='AuditLog']")
      # Empty state until an action is recorded.
      assert has_element?(lv, "#org-audit-empty")
    end

    test "a plain member does NOT see the activity log panel", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/business/#{ctx.org.slug}")

      refute has_element?(lv, "#org-audit-log")
    end

    test "recorded events render as rows for an admin (newest first) with an export button",
         ctx do
      target = Ecto.UUID.generate()

      {:ok, e1} =
        Orgs.Audit.record_audit_event(ctx.org, ctx.owner, "circle_created",
          target_id: target,
          target_type: "group"
        )

      {:ok, e2} =
        Orgs.Audit.record_audit_event(ctx.org, ctx.owner, "role_changed",
          target_id: ctx.member.id,
          target_type: "user"
        )

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      assert has_element?(lv, "#audit-#{e1.id}[data-audit-action='circle_created']")
      assert has_element?(lv, "#audit-#{e2.id}[data-audit-action='role_changed']")
      assert has_element?(lv, "#org-audit-export")
      refute has_element?(lv, "#org-audit-empty")
    end

    test "the delete-org modal offers a final audit-log download (owner)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/business/#{ctx.org.slug}")

      render_click(lv, "open_delete_org_modal")

      # The modal is teleported to a portal, so query its rendered HTML rather
      # than has_element? (mirrors org_safe_delete_live_test.exs).
      modal_html = lv |> element("#delete-org-modal-portal") |> render()
      assert modal_html =~ "delete-org-export-audit"
    end
  end
end
