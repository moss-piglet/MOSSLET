defmodule MossletWeb.SubscribeLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Accounts

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp log_in(conn, user, key, session_extra \\ %{}) do
    session =
      %{
        "user_token" => Accounts.generate_user_session_token(user),
        "key" => key
      }
      |> Map.merge(session_extra)

    conn
    |> Plug.Test.init_test_session(session)
  end

  # An onboarded user; `confirmed?` controls email confirmation. Subscribe must be
  # reachable even when unconfirmed (Task #215).
  defp subscribe_user(confirmed?) do
    email = "subscriber#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password, confirm: confirmed?})
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    {user, get_key(user)}
  end

  describe "personal subscribe (:user) before email confirmation" do
    test "unconfirmed user can reach /app/subscribe and sees a confirm banner", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe")

      assert has_element?(lv, "a", "Resend confirmation email")
    end

    test "shows the plan family switcher defaulting to Personal", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe")

      assert has_element?(lv, "#family-tab-Personal[aria-selected='true']")
      assert has_element?(lv, "#family-tab-Family")
      assert has_element?(lv, "#family-tab-Business")
    end

    test "?plan=family shows the Family org on-ramp (not a :user purchase)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family"}}")

      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      # On-ramp, NOT the :user family pricing card.
      assert has_element?(lv, "#org-onramp-form-family")
      assert has_element?(lv, "#org-onramp-start-family")
      refute render(lv) =~ "MOSSLET (Family)"
      # Interval toggle is hidden on org-onramp tabs.
      refute has_element?(lv, "#interval-toggle-year")
    end

    test "?plan=business shows the Business org on-ramp (not a :user purchase)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "business"}}")

      assert has_element?(lv, "#family-tab-Business[aria-selected='true']")
      assert has_element?(lv, "#org-onramp-form-business")
      assert has_element?(lv, "#org-onramp-start-business")
      refute render(lv) =~ "MOSSLET (Business)"
    end

    test "?billing=month selects the monthly interval", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal", billing: "month"}}")

      assert has_element?(lv, "#interval-toggle-month[aria-pressed='true']")
    end

    test "selecting the Family tab shows the org on-ramp (no redirect)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal"}}")

      lv |> element("#family-tab-Family") |> render_click()

      assert_patch(lv, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")
      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      assert has_element?(lv, "#org-onramp-form-family")
    end

    test "switching billing interval patches the URL", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal", billing: "year"}}")

      lv |> element("#interval-toggle-month") |> render_click()

      assert_patch(lv, ~p"/app/subscribe?#{%{plan: "personal", billing: "month"}}")
    end

    test "pre-selects plan from persisted session intent (gate bounce)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      # Simulates arriving from registration with a family plan intent: the
      # Family tab is pre-selected and shows the org on-ramp (Option B, #235).
      conn = log_in(conn, user, key, %{"plan_intent" => "family", "plan_interval" => "month"})

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe")

      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      assert has_element?(lv, "#org-onramp-form-family")
    end
  end

  describe "org on-ramp (:user source Family/Business tabs)" do
    test "submitting the Family on-ramp creates an inert org and routes to its subscribe page carrying the chosen billing interval (#266)",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")

      lv
      |> form("#org-onramp-form-family", %{"org" => %{"name" => "The Smiths"}})
      |> render_submit()

      org = Mosslet.Orgs.list_owned_orgs(user, :family) |> List.first()
      assert org
      assert org.type == :family
      refute Mosslet.Orgs.org_active?(org)
      assert_redirect(lv, ~p"/app/org/#{org.slug}/subscribe?#{%{billing: "year"}}")
    end

    test "the Family on-ramp carries a MONTHLY choice through to the org subscribe page (#266)",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "month"}}")

      lv
      |> form("#org-onramp-form-family", %{"org" => %{"name" => "The Smiths"}})
      |> render_submit()

      org = Mosslet.Orgs.list_owned_orgs(user, :family) |> List.first()
      assert_redirect(lv, ~p"/app/org/#{org.slug}/subscribe?#{%{billing: "month"}}")
    end

    test "submitting the Business on-ramp creates an inert business org", %{conn: conn} do
      {user, key} = subscribe_user(true)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "business", billing: "year"}}")

      lv
      |> form("#org-onramp-form-business", %{"org" => %{"name" => "Acme Inc"}})
      |> render_submit()

      org = Mosslet.Orgs.list_owned_orgs(user, :business) |> List.first()
      assert org
      assert org.type == :business
      assert_redirect(lv, ~p"/app/org/#{org.slug}/subscribe?#{%{billing: "year"}}")
    end

    test "an UNCONFIRMED user submitting the on-ramp gets a confirm-email nudge, not a crash (#266)",
         %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")

      html =
        lv
        |> form("#org-onramp-form-family", %{"org" => %{"name" => "The Smiths"}})
        |> render_submit()

      assert html =~ "confirm your email"
      assert Mosslet.Orgs.count_owned_orgs(user, :family) == 0
    end

    test "blank name flashes an error and does not create an org", %{conn: conn} do
      {user, key} = subscribe_user(true)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family"}}")

      html =
        lv
        |> form("#org-onramp-form-family", %{"org" => %{"name" => "   "}})
        |> render_submit()

      assert html =~ "Please enter a name"
      assert Mosslet.Orgs.count_owned_orgs(user, :family) == 0
    end

    test "deep-links to an existing active org instead of offering to create one",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      org = org_fixture(user, %{"name" => "Existing Fam", "type" => :family})
      ensure_org_subscription(org, status: "active")
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")

      assert has_element?(lv, "#org-onramp-manage-family")
      refute has_element?(lv, "#org-onramp-form-family")
      # The Manage deep-link carries the chosen billing interval (#266).
      assert has_element?(
               lv,
               "#org-onramp-manage-family[href='/app/org/#{org.slug}/subscribe?billing=year']"
             )
    end

    test "resumes an INERT owned org (mid-checkout) instead of re-offering create (#266)",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      # Inert: created but NEVER activated (no :org subscription) — e.g. the user
      # re-unlocked auth in a new tab before finishing Stripe checkout.
      org = org_fixture(user, %{"name" => "Half-set Fam", "type" => :family})
      refute Mosslet.Orgs.org_active?(org)
      conn = log_in(conn, user, key)

      {:ok, lv, html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")

      # No create form (it would hit the one-family limit); instead a resume CTA
      # to the inert org's subscribe page, carrying the chosen interval.
      refute has_element?(lv, "#org-onramp-form-family")

      assert has_element?(
               lv,
               "#org-onramp-manage-family[href='/app/org/#{org.slug}/subscribe?billing=year']"
             )

      assert html =~ "Continue &amp; start your trial"
    end

    test "the create_org event resumes an existing inert org rather than erroring on the limit (#266)",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      org = org_fixture(user, %{"name" => "Half-set Fam", "type" => :family})
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family", billing: "month"}}")

      # A stale create_org submit (e.g. an old tab) must NOT crash on the
      # one-family limit; it resumes the inert org's checkout instead.
      render_hook(lv, "create_org", %{"type" => "family", "org" => %{"name" => "Whatever"}})

      assert Mosslet.Orgs.count_owned_orgs(user, :family) == 1
      assert_redirect(lv, ~p"/app/org/#{org.slug}/subscribe?#{%{billing: "month"}}")
    end
  end

  describe "org-scoped subscribe (:org source) — trial-start surface (Task #235)" do
    test "an inert family org owner reaches /app/org/:slug/subscribe and sees the family plan",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      org = org_fixture(user, %{"name" => "The Smiths", "type" => :family})
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/org/#{org.slug}/subscribe")

      # The org's own (:org-source) plan is offered — the per-seat checkout form
      # for the family plan, not the :user on-ramp.
      assert has_element?(lv, "#seat-checkout-family-monthly, #seat-checkout-family-yearly")
      refute has_element?(lv, "#org-onramp-form-family")
    end

    test "submitting the org family checkout routes to the org-scoped checkout URL",
         %{conn: conn} do
      {user, key} = subscribe_user(true)
      org = org_fixture(user, %{"name" => "The Smiths", "type" => :family})
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/org/#{org.slug}/subscribe?#{%{billing: "month"}}")

      {:error, {:redirect, %{to: to}}} =
        lv
        |> form("#seat-checkout-family-monthly", %{"checkout" => %{}})
        |> render_submit()

      assert to =~ "/app/org/#{org.slug}/checkout/family-monthly"
    end
  end
end
