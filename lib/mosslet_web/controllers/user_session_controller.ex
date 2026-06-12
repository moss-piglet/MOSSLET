defmodule MossletWeb.UserSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts
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

  defp create(conn, %{"user" => user_params} = params, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      # Carry plan funnel context (plan/billing) — posted as top-level form
      # fields — into the params UserAuth persists into the session, so
      # onboarding/subscribe can pre-select the chosen plan (Task #215).
      auth_params =
        user_params
        |> maybe_put(params, "plan")
        |> maybe_put(params, "billing")

      conn
      |> maybe_put_invite_return_to(params)
      |> put_flash(:success, info)
      |> UserAuth.log_in_user(user, auth_params)
    else
      # No matching user. For a just-registered flow this means the account was
      # not actually created (e.g. the browser-side ZK key generation + "save"
      # step did not complete before this auto-login POST fired). Rather than
      # bouncing to sign-in with a misleading "invalid email or password", send
      # the user back to registration with their funnel context intact so they
      # can simply try again. (Graceful fallback for Task #213/#222 funnel.)
      handle_failed_create(conn, params)
    end
  end

  # Post-registration auto-login that found no user: return to /auth/register,
  # preserving plan/billing/invite_token, with a friendly retry message.
  defp handle_failed_create(conn, %{"_action" => "registered"} = params) do
    query =
      params
      |> Map.take(["plan", "billing", "invite_token"])
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Map.new()

    conn
    |> put_flash(
      :error,
      gettext("We couldn't finish creating your account. Please try registering again.")
    )
    |> redirect(to: ~p"/auth/register?#{query}")
  end

  # Normal sign-in that failed: don't disclose whether the email is registered.
  defp handle_failed_create(conn, _params) do
    conn
    |> put_flash(:error, gettext("Invalid email or password, please try again."))
    |> redirect(to: ~p"/auth/sign_in")
  end

  # When a public org invite link funneled the user through sign-in/registration,
  # the signed invite token rides along as a top-level form field. Persist it as
  # `user_return_to` so UserAuth lands the freshly-authenticated user back on the
  # public invite page (`/invite/:token`) to accept. ZK-safe: the token is a
  # signed (not encrypted) wrapper of the invitation id, never secret material.
  defp maybe_put_invite_return_to(conn, %{"invite_token" => token})
       when is_binary(token) and token != "" do
    put_session(conn, :user_return_to, ~p"/invite/#{token}")
  end

  defp maybe_put_invite_return_to(conn, _params), do: conn

  defp maybe_put(target, source, key) do
    case Map.get(source, key) do
      nil -> target
      value -> Map.put(target, key, value)
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
