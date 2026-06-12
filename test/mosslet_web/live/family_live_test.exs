defmodule MossletWeb.FamilyLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
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

  describe "FamilyLive.Index" do
    test "lists families and creates a new one", %{conn: conn} do
      {user, key} = onboarded_user("familyadmin")

      conn = log_in(conn, user, key)
      {:ok, _lv, html} = live(conn, ~p"/app/family")
      assert html =~ "Family"
      assert html =~ "Start your family space"

      {:ok, new_lv, _html} = live(conn, ~p"/app/family/new")

      {:ok, show_lv, html} =
        new_lv
        |> form("#new-family-form", family: %{name: "The Testers"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "The Testers"
      assert has_element?(show_lv, "#establish-form, #invite-form")
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
  end

  describe "FamilyLive.Show guardianship management" do
    setup do
      {admin, admin_key} = onboarded_user("orgadmin")
      {:ok, org} = Orgs.create_org(admin, %{"name" => "Smiths", "type" => "family"})

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
      %{admin: admin, admin_key: admin_key, org: org}
    end

    test "shows seat usage and blocks invite at cap counting pending invites", ctx do
      # Cap the family at 2 seats via a purchased subscription quantity.
      {:ok, customer} =
        Mosslet.Billing.Customers.create_customer_for_source(:org, ctx.org.id, %{
          email: "billing-#{System.unique_integer([:positive])}@example.com",
          provider: "stripe",
          provider_customer_id: "cus_#{System.unique_integer([:positive])}"
        })

      {:ok, _sub} =
        Mosslet.Billing.Subscriptions.create_subscription(%{
          billing_customer_id: customer.id,
          plan_id: "family-monthly",
          status: "active",
          quantity: 2,
          provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
          provider_subscription_items: [%{price: "price_test"}],
          current_period_start: NaiveDateTime.utc_now()
        })

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
  end
end
