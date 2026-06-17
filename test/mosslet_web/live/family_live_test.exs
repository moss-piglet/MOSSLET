defmodule MossletWeb.FamilyLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
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

  # Active personal (:user) subscription so the user can create/manage orgs.
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

  # Activates a family org's own `:org`-source subscription so its content
  # surfaces are reachable (Option B, Task #235): inert/unpaid orgs redirect to
  # subscribe. Idempotent on the customer + subscription.
  defp subscribe_family(org, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 5)
    status = Keyword.get(opts, :status, "active")

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

    case Subscriptions.get_active_subscription_by_customer_id(customer.id) do
      nil ->
        {:ok, _sub} =
          Subscriptions.create_subscription(%{
            billing_customer_id: customer.id,
            plan_id: "family-monthly",
            status: status,
            quantity: quantity,
            provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
            provider_subscription_items: [%{price: "price_test"}],
            current_period_start: NaiveDateTime.utc_now()
          })

      existing ->
        {:ok, _sub} =
          Subscriptions.update_subscription(existing, %{status: status, quantity: quantity})
    end

    :ok
  end

  defp onboarded_user(name_seed) do
    email = "#{name_seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    # Org creation/management requires an active personal subscription (Task #215
    # follow-up), so give the test user one.
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

  describe "FamilyLive.Index" do
    test "lists families and creates a new one", %{conn: conn} do
      {user, key} = onboarded_user("familyadmin")

      conn = log_in(conn, user, key)
      {:ok, _lv, html} = live(conn, ~p"/app/family")
      assert html =~ "Family"
      assert html =~ "Start your family space"

      {:ok, new_lv, _html} = live(conn, ~p"/app/family/new")

      # Under Option B (Task #235) a newly created org is INERT and the owner is
      # funneled straight to org-scoped checkout to activate it.
      {:error, {:live_redirect, %{to: to}}} =
        new_lv
        |> form("#new-family-form", family: %{name: "The Testers"})
        |> render_submit()

      [%{slug: slug, type: :family}] = Orgs.list_owned_orgs(user, :family)
      assert to == ~p"/app/org/#{slug}/subscribe"
    end

    test "hides the New family CTA once a family is owned (max 1)", %{conn: conn} do
      {user, key} = onboarded_user("familyadmin")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Smiths", "type" => "family"})

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/family")

      refute has_element?(lv, "#new-family-button")
    end

    test "blocks creating a second owned family server-side", %{conn: conn} do
      {user, key} = onboarded_user("familyadmin")
      {:ok, _org} = Orgs.create_org(user, %{"name" => "Smiths", "type" => "family"})

      assert {:error, :family_limit_reached} =
               Orgs.create_org(user, %{"name" => "Joneses", "type" => "family"})

      # The user can still reach the page; the server gate is the source of truth.
      conn = log_in(conn, user, key)
      {:ok, _lv, html} = live(conn, ~p"/app/family")
      assert html =~ "Smiths"
    end

    test "guided onboarding create routes to org-scoped subscribe", %{conn: conn} do
      {user, key} = onboarded_user("familyonboard")

      conn = log_in(conn, user, key)
      {:ok, new_lv, _html} = live(conn, ~p"/app/family/new?onboarding=1")

      assert {:error, {:live_redirect, %{to: to}}} =
               new_lv
               |> form("#new-family-form", family: %{name: "The Onboarders"})
               |> render_submit()

      assert to =~ ~r{^/app/org/[^/]+/subscribe$}
    end

    test "an inert (unpaid) owned family shows an Activate card, not a content link",
         %{conn: conn} do
      {user, key} = onboarded_user("familyinert")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Inert Fam", "type" => "family"})

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/family")

      assert has_element?(lv, "#family-inert-#{org.id}")
      assert has_element?(lv, "#family-activate-#{org.id}")
      # No dead content link for an inert org.
      refute has_element?(lv, "a[href='/app/family/#{org.slug}']")
    end

    test "an active owned family links to its content surface", %{conn: conn} do
      {user, key} = onboarded_user("familyactive")
      {:ok, org} = Orgs.create_org(user, %{"name" => "Active Fam", "type" => "family"})
      subscribe_family(org)

      conn = log_in(conn, user, key)
      {:ok, lv, _html} = live(conn, ~p"/app/family")

      assert has_element?(lv, "a[href='/app/family/#{org.slug}']")
      refute has_element?(lv, "#family-inert-#{org.id}")
    end
  end

  describe "FamilyLive.Show guardianship management" do
    setup do
      {admin, admin_key} = onboarded_user("orgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Smiths", "type" => "family"})
      subscribe_family(org)

      {guardian, _gk} = onboarded_user("guard")
      {managed, managed_key} = onboarded_user("ward")

      {:ok, {:ok, _g_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, guardian, :guardian) |> Mosslet.Repo.insert()
        end)

      {:ok, {:ok, _m_ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, managed, :managed_member) |> Mosslet.Repo.insert()
        end)

      %{
        admin: admin,
        admin_key: admin_key,
        org: org,
        guardian: guardian,
        managed: managed,
        managed_key: managed_key
      }
    end

    test "admin can establish a guardianship", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#establish-form")

      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)

      lv
      |> element("#establish-form")
      |> render_submit(%{
        "guardian_membership_id" => g_ms.id,
        "managed_membership_id" => m_ms.id
      })

      assert [gship] = Orgs.list_guardianships_by_org(ctx.org)
      assert gship.status == :pending
      # Consent gate: pending => not co-sealed
      assert Orgs.list_active_guardian_users_for_user(ctx.managed.id) == []
    end

    test "managed member sees pending consent request and can accept", ctx do
      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)
      {:ok, gship} = Orgs.establish_guardianship(g_ms, m_ms)

      {:ok, lv, html} =
        ctx.conn |> log_in(ctx.managed, ctx.managed_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert html =~ "Guardianship requests"
      assert has_element?(lv, "#accept-#{gship.id}")

      lv |> element("#accept-#{gship.id}") |> render_click()

      assert [updated] = Orgs.list_guardianships_by_org(ctx.org)
      assert updated.status == :active
      # Now the consent gate opens.
      assert [guardian_user] = Orgs.list_active_guardian_users_for_user(ctx.managed.id)
      assert guardian_user.id == ctx.guardian.id
    end

    test "managed member sees transparency panel once active", ctx do
      g_ms = Orgs.get_membership!(ctx.guardian, ctx.org.slug)
      m_ms = Orgs.get_membership!(ctx.managed, ctx.org.slug)
      {:ok, gship} = Orgs.establish_guardianship(g_ms, m_ms)
      {:ok, _} = Orgs.accept_guardianship(gship)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.managed, ctx.managed_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#guardian-transparency-panel")
    end
  end

  describe "FamilyLive.Show seat cap" do
    setup do
      {admin, admin_key} = onboarded_user("seatadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Smiths", "type" => "family"})
      # Activate the org (Option B, Task #235) with enough seats for the invite
      # tests; the seat-cap test re-subscribes with an explicit quantity.
      subscribe_family(org, quantity: 5)
      %{admin: admin, admin_key: admin_key, org: org}
    end

    test "shows seat usage and blocks invite at cap counting pending invites", ctx do
      # Cap the family at 2 seats via a purchased subscription quantity.
      subscribe_family(ctx.org, quantity: 2)

      {:ok, lv, html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert html =~ "1 of 2 seats used"

      # First invite fills the 2nd seat (now 2 of 2 used, counting pending).
      lv |> form("#invite-form", invite: %{email: "first@example.com"}) |> render_submit()
      assert render(lv) =~ "2 of 2 seats used"
      assert has_element?(lv, "#family-seat-full-notice")

      # Second invite is blocked at the cap.
      html =
        lv |> form("#invite-form", invite: %{email: "second@example.com"}) |> render_submit()

      assert html =~ "All seats are in use"
      assert Orgs.seat_summary(ctx.org).pending == 1
    end

    test "invites surface a pending-invitations list with resend + revoke", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      refute has_element?(lv, "#pending-invitations")

      lv |> form("#invite-form", invite: %{email: "cousin@example.com"}) |> render_submit()

      assert has_element?(lv, "#pending-invitations")
      assert render(lv) =~ "cousin@example.com"

      [invitation] = Orgs.list_invitations_by_org(ctx.org)
      assert has_element?(lv, "#resend-invitation-#{invitation.id}")
      assert has_element?(lv, "#revoke-invitation-#{invitation.id}")

      lv |> element("#resend-invitation-#{invitation.id}") |> render_click()
      assert length(Orgs.list_invitations_by_org(ctx.org)) == 1

      lv |> element("#revoke-invitation-#{invitation.id}") |> render_click()
      assert Orgs.list_invitations_by_org(ctx.org) == []
      refute has_element?(lv, "#pending-invitations")
    end
  end

  describe "Connect with teammate (Task #226)" do
    setup do
      {admin, admin_key} = onboarded_user("famconnadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Connellys", "type" => "family"})
      subscribe_family(org)

      {member, _mk} = onboarded_user("famconnmember")

      {:ok, {:ok, _ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, member, :member) |> Mosslet.Repo.insert()
        end)

      %{admin: admin, admin_key: admin_key, org: org, member: member}
    end

    test "shows a Connect button for an unconnected family member but not self", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#connect-#{ctx.member.id}")
      refute has_element?(lv, "#connect-#{ctx.admin.id}")
    end

    test "clicking Connect sends a UserConnection invite and flips to Pending", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.admin, ctx.admin_key) |> live(~p"/app/family/#{ctx.org.slug}")

      lv |> element("#connect-#{ctx.member.id}") |> render_click()

      assert %{} = uconn = Accounts.get_user_connection_between_users(ctx.admin.id, ctx.member.id)
      assert is_nil(uconn.confirmed_at)

      refute has_element?(lv, "#connect-#{ctx.member.id}")
      assert has_element?(lv, "#connect-pending-#{ctx.member.id}")
    end
  end

  describe "FamilyLive.Show ownership transfer (Task #237)" do
    setup %{conn: conn} do
      {owner, owner_key} = onboarded_user("famowner")
      {member, member_key} = onboarded_user("fammember")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Smiths", "type" => "family"})
      subscribe_family(org)

      {:ok, {:ok, _ms}} =
        Mosslet.Repo.transaction_on_primary(fn ->
          Orgs.Membership.insert_changeset(org, member, :member) |> Mosslet.Repo.insert()
        end)

      %{
        conn: conn,
        owner: owner,
        owner_key: owner_key,
        member: member,
        member_key: member_key,
        org: org
      }
    end

    test "owner sees the Ownership section + transfer button (parity with business)", ctx do
      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.owner, ctx.owner_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#org-ownership-section")
      # Transfer/delete live in the calm "manage organization" dropdown now.
      assert has_element?(lv, "#org-manage-menu")
      assert lv |> element("#org-manage-menu-menu") |> render() =~ "Transfer ownership"
    end

    test "the proposed new owner can accept and becomes owner", ctx do
      {:ok, _transfer} =
        Orgs.initiate_ownership_transfer(ctx.org, ctx.owner, ctx.member, @password)

      {:ok, lv, _html} =
        ctx.conn |> log_in(ctx.member, ctx.member_key) |> live(~p"/app/family/#{ctx.org.slug}")

      assert has_element?(lv, "#incoming-transfer-panel")

      lv
      |> form("#accept-transfer-form", %{"transfer" => %{"password" => @password}})
      |> render_submit()

      assert Orgs.owner?(Orgs.get_org_by_id(ctx.org.id), ctx.member.id)
    end
  end
end
