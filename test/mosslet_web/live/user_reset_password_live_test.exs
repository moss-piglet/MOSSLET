defmodule MossletWeb.UserResetPasswordLiveTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts

  @valid_email "validtest@example.com"

  setup do
    user = user_fixture(%{email: @valid_email})

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, @valid_email, url)
      end)

    %{token: token, user: user}
  end

  describe "Reset password page" do
    test "renders reset password with valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/auth/reset-password/#{token}")

      assert html =~ "Reset your password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      {:error, {:redirect, to}} = live(conn, ~p"/auth/reset-password/invalid")

      assert to == %{
               flash: %{"error" => "Reset password link is invalid or it has expired."},
               to: ~p"/"
             }
    end

    test "prevents reset password if is_forgot_pwd? false", %{conn: conn, token: token} do
      {:ok, lv, html} = live(conn, ~p"/auth/reset-password/#{token}")

      reset_password_form =
        lv
        |> element("#reset_password_form")
        |> has_element?()

      refute reset_password_form

      assert html =~ "you cannot reset your password using this method"
    end

    test "renders errors for invalid data", %{conn: conn} do
      token = get_token_for_user_with_forgot_password()

      {:ok, lv, _html} = live(conn, ~p"/auth/reset-password/#{token}")

      result =
        lv
        |> element("#reset_password_form")
        |> render_change(
          user: %{"password" => "secret12", "confirmation_password" => "secret123456"}
        )

      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
    end
  end

  describe "Reset Password" do
    test "resets password once", %{conn: conn} do
      token = get_token_for_user_with_forgot_password()

      {:ok, lv, _html} = live(conn, ~p"/auth/reset-password/#{token}")

      {:ok, conn} =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "new valid password hooray!",
            "password_confirmation" => "new valid password hooray!"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/auth/sign_in")

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "Password reset successfully"

      assert Accounts.get_user_by_email_and_password(
               "emailtest@example.com",
               "new valid password hooray!"
             )
    end

    test "does not reset password on invalid data", %{conn: conn} do
      token = get_token_for_user_with_forgot_password()

      {:ok, lv, _html} = live(conn, ~p"/auth/reset-password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        )
        |> render_submit()

      assert result =~ "Reset your password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "Reset password navigation" do
    test "does not redirect to sign in page when the Sign in button is clicked without forgot password setting",
         %{
           conn: conn,
           token: token
         } do
      {:ok, _lv, html} = live(conn, ~p"/auth/reset-password/#{token}")

      assert html =~ "cannot reset your password using this method"
    end

    test "redirects to password reset page when the Register button is clicked", %{
      conn: conn,
      token: token
    } do
      {:ok, lv, _html} = live(conn, ~p"/auth/reset-password/#{token}")

      {:ok, _lv, html} =
        lv
        |> element("a", "Register")
        |> render_click()
        |> follow_redirect(conn, ~p"/auth/register")

      assert html =~ "Register"
    end
  end

  defp get_token_for_user_with_forgot_password() do
    user = user_fixture(%{email: "emailtest@example.com"})

    key =
      case Accounts.User.valid_key_hash?(user, valid_user_password()) do
        {:ok, key} ->
          key

        {:error, _} ->
          nil
      end

    {:ok, user} = Accounts.update_user_forgot_password(user, %{is_forgot_pwd?: true}, key: key)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, "emailtest@example.com", url)
      end)

    token
  end
end
