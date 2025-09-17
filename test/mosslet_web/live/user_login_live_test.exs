defmodule MossletWeb.UserLoginLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @valid_email "oakred@example.com"
  @valid_password "hello world hello world"

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/sign_in")

      assert html =~ "Sign in"
      assert html =~ "Create account"
      assert html =~ "Forgot your password?"
    end

    test "redirects to onboarding if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/auth/sign_in")
        |> follow_redirect(conn, "/app/users/onboarding")

      assert {:ok, _conn} = result
    end

    test "redirects if onboarded and already logged in", %{conn: conn} do
      user = user_fixture()
      {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})

      result =
        conn
        |> log_in_user(user)
        |> live(~p"/auth/sign_in")
        |> follow_redirect(conn, "/app")

      assert {:ok, _conn} = result
    end
  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      _user = user_fixture(%{email: @valid_email, password: @valid_password})

      {:ok, lv, _html} = live(conn, ~p"/auth/sign_in")

      form =
        form(lv, "#login_form",
          user: %{email: @valid_email, password: @valid_password, remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/app/users/onboarding"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_in")

      form =
        form(lv, "#login_form",
          user: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invalid email or password, please try again."

      assert redirected_to(conn) == "/auth/sign_in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_in")

      {:ok, _login_live, html} =
        lv
        |> element("a", "Create account")
        |> render_click()
        |> follow_redirect(conn, ~p"/auth/register")

      assert html =~ "Complete step"
    end

    test "redirects to forgot password page when the Forgot Password button is clicked", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/auth/sign_in")

      {:ok, _lv, html} =
        lv
        |> element("a", "Forgot your password?")
        |> render_click()
        |> follow_redirect(conn, ~p"/auth/reset-password")

      assert html =~ "Forgot your password?"
    end
  end
end
