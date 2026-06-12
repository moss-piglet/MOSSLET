defmodule MossletWeb.SubscribeLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

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

    test "?plan=family shows the Family plan (subscribe as user first)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "family"}}")

      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      assert render(lv) =~ "MOSSLET (Family)"
    end

    test "?plan=business shows the Business plan (subscribe as user first)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "business"}}")

      assert has_element?(lv, "#family-tab-Business[aria-selected='true']")
      assert render(lv) =~ "MOSSLET (Business)"
    end

    test "?billing=month selects the monthly interval", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal", billing: "month"}}")

      assert has_element?(lv, "#interval-toggle-month[aria-pressed='true']")
    end

    test "selecting the Family tab shows the Family plan (no redirect)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal"}}")

      lv |> element("#family-tab-Family") |> render_click()

      assert_patch(lv, ~p"/app/subscribe?#{%{plan: "family", billing: "year"}}")
      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      assert render(lv) =~ "MOSSLET (Family)"
    end

    test "switching billing interval patches the URL", %{conn: conn} do
      {user, key} = subscribe_user(false)
      conn = log_in(conn, user, key)

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe?#{%{plan: "personal", billing: "year"}}")

      lv |> element("#interval-toggle-month") |> render_click()

      assert_patch(lv, ~p"/app/subscribe?#{%{plan: "personal", billing: "month"}}")
    end

    test "pre-selects plan + interval from persisted session intent (gate bounce)", %{conn: conn} do
      {user, key} = subscribe_user(false)
      # Simulates the org-creation gate redirect to bare /app/subscribe: the
      # plan family + billing interval persist in the session from sign-in.
      conn = log_in(conn, user, key, %{"plan_intent" => "family", "plan_interval" => "month"})

      {:ok, lv, _html} = live(conn, ~p"/app/subscribe")

      assert has_element?(lv, "#family-tab-Family[aria-selected='true']")
      assert has_element?(lv, "#interval-toggle-month[aria-pressed='true']")
      assert render(lv) =~ "MOSSLET (Family)"
    end
  end
end
