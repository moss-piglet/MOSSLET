defmodule MossletWeb.UserRegistrationLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/register")

      assert html =~ "Register"
      assert html =~ "Sign in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/auth/register")
        |> follow_redirect(conn, "/app/users/onboarding")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid email on step 1", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Waiting..."
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "invalid or not a valid domain"
    end

    test "renders errors for invalid username on step 2", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      _result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "validtestemail@email.com"})

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"username" => "o"})

      assert result =~ "Waiting..."
      assert result =~ "has invalid format"
      assert result =~ "should be at least 2"
    end

    test "renders errors for invalid password on step 3", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      _result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "validtestemail@email.com"})

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      _result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"username" => "validusername"})

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"password" => "invalid", "password_confirmation" => "no match"})

      assert result =~ "Waiting..."
      assert result =~ "try putting an extra word, dash, space, or number"
      assert result =~ "may be cracked"
      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
    end

    test "renders errors for invalid password reminder on step 4", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      _result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "validtestemail@email.com"})

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      _result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"username" => "validusername"})

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      _result =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "password" => "hello world hello world",
            "password_confirmation" => "hello world hello world"
          }
        )

      _result =
        lv
        |> element(~s|main button:fl-contains("Continue")|)
        |> render_click()

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"password_reminder" => false})

      assert result =~ "Waiting..."
      assert result =~ "please take a moment to understand and agree before continuing"
    end
  end

  describe "register user" do
    test "creates account and awaits user confirmation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      email = unique_user_email()
      username = unique_username()
      password = valid_user_password()

      form =
        form(lv, "#registration_form",
          user: %{
            email: email,
            username: username,
            password: password,
            password_confirmation: password,
            password_reminder: true
          }
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      # Assert that the user will be redirected to the onboarding page
      assert redirected_to(conn) == ~p"/app/users/onboarding"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "Account created successfully"

      # Assert that the user must confirm their email
      conn = get(conn, ~p"/app/users/onboarding")
      assert html_response(conn, 302)
      assert redirected_to(conn) == ~p"/auth/confirm"

      conn = get(conn, ~p"/auth/confirm")
      response = html_response(conn, 200)
      assert response =~ "Please check your email"
    end

    test "renders errors for duplicated email only at final submission", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "test@email.com"})

      assert result =~ "Continue"

      # Now submit the form
      form =
        form(lv, "#registration_form",
          user: %{
            email: "test@email.com",
            username: unique_username(),
            password: valid_user_password(),
            password_confirmation: valid_user_password(),
            password_reminder: true
          }
        )

      result = render_submit(form)
      assert result =~ "Oops, something went wrong! Please check the errors below"
      assert result =~ "email is invalid or already taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/auth/register")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("Sign in")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/auth/sign_in")

      assert login_html =~ "Sign in"
    end
  end
end
