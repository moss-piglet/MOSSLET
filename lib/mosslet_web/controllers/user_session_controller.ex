defmodule MossletWeb.UserSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias MossletWeb.UserAuth

  plug :redirect_if_passwordless_disabled when action in [:create_from_token]

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, gettext("Account created successfully!"))
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/app/users/change-password")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, gettext("Welcome back!"))
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:success, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, gettext("Invalid email or password, please try again."))
      |> redirect(to: ~p"/auth/sign_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Signed out successfully"))
    |> UserAuth.log_out_user()
  end

  def redirect_if_passwordless_disabled(conn, _opts) do
    if Mosslet.config(:passwordless_enabled) do
      conn
    else
      conn
      |> redirect(to: ~p"/auth/sign_in")
      |> halt()
    end
  end
end
