defmodule MossletWeb.UserSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Accounts.UserPin
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
      |> put_flash(:error, gettext("Invalid email or password"))
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/auth/sign_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Signed out successfully"))
    |> UserAuth.log_out_user()
  end

  @doc """
  Handles sign in with a token. Used for passwordless sign in. Steps:
  1. User submits their email
  2. A user_token storing a hashed version of the pin code is created for that user that is valid for a short amount of time
  3. The user gets sent the pin code to their email
  4. User is redirected to a pin entering screen that is unique to that user ID
  5. They enter the pin code and if successful, a POST request to this action is made (note they only get a small number of attempts before the token is deleted)
  6. The user is logged in
  """
  def create_from_token(conn, %{"auth" => %{"sign_in_token" => sign_in_token} = params}) do
    with true <- Mosslet.config(:passwordless_enabled),
         {:ok, token} <- Base.decode64(sign_in_token),
         %User{} = user <- Accounts.get_user_by_session_token(token) do
      user_return_to = if params["user_return_to"] == "", do: nil, else: params["user_return_to"]

      conn = if user_return_to, do: put_session(conn, :user_return_to, user_return_to), else: conn

      # Delete the session token as we create a new one in log_in_user
      Accounts.delete_user_session_token(token)

      # Delete any passwordless pins
      UserPin.purge_pins(user)

      # Confirm user if not already
      Accounts.confirm_user!(user)

      # Remember users for 60 days
      UserAuth.log_in_user(conn, user, %{"remember_me" => true})
    else
      _ ->
        conn
        |> put_flash(:error, gettext("Sign in failed."))
        |> redirect(to: ~p"/auth/sign_in")
    end
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
