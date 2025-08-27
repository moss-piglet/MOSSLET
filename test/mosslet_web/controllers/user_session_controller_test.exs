defmodule MossletWeb.UserSessionControllerTest do
  use MossletWeb.ConnCase, async: true

  import Mosslet.AccountsFixtures

  @valid_email "validemail@example.com"

  setup do
    %{user: user_fixture(%{email: @valid_email})}
  end

  describe "POST /auth/sign_in" do
    test "logs the user in and begins onboarding", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/auth/sign_in", %{
          "user" => %{"email" => @valid_email, "password" => valid_user_password()}
        })

      # Check that user is redirected to the onboarding page
      assert get_session(conn, :user_token)
      refute user.is_onboarded?
      assert redirected_to(conn) == ~p"/app/users/onboarding"
    end

    test "logs the user in after onboarding", %{conn: conn, user: user} do
      {:ok, user} = Mosslet.Accounts.update_user_onboarding(user, %{is_onboarded?: true})

      conn =
        post(conn, ~p"/auth/sign_in", %{
          "user" => %{"email" => @valid_email, "password" => valid_user_password()}
        })

      # Check that user is redirected to the onboarding page
      assert get_session(conn, :user_token)
      assert user.is_onboarded?
      assert redirected_to(conn) == ~p"/app"
    end

    test "logs the user in with remember me", %{conn: conn, user: _user} do
      conn =
        post(conn, ~p"/auth/sign_in", %{
          "user" => %{
            "email" => @valid_email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_mosslet_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/app/users/onboarding"
    end

    test "logs the user in with return to", %{conn: conn, user: _user} do
      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/auth/sign_in", %{
          "user" => %{
            "email" => @valid_email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/app/users/onboarding"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "Welcome back!"
    end

    test "login following registration", %{conn: conn, user: _user} do
      conn =
        conn
        |> post(~p"/auth/sign_in", %{
          "_action" => "registered",
          "user" => %{
            "email" => @valid_email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/app/users/onboarding"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "Account created successfully"
    end

    test "login following password update", %{conn: conn, user: user} do
      {:ok, _user} = Mosslet.Accounts.update_user_onboarding(user, %{is_onboarded?: true})

      conn =
        conn
        |> post(~p"/auth/sign_in", %{
          "_action" => "password_updated",
          "user" => %{
            "email" => @valid_email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == ~p"/app/users/change-password"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "Password updated successfully"
    end

    test "redirects to login page with invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/sign_in", %{
          "user" => %{"email" => "invalid@email.com", "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Invalid email or password, please try again."

      assert redirected_to(conn) == ~p"/auth/sign_in"
    end
  end

  describe "DELETE /auth/sign_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> fetch_session()
        |> delete(~p"/auth/sign_out")

      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Signed out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/auth/sign_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Signed out successfully"
    end
  end
end
