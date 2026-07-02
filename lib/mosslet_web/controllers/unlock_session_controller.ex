defmodule MossletWeb.UnlockSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts

  # PRF-enrolled unlock (board #370): enrolled accounts have no `key_hash`
  # password-only door, so the browser unlocks `user_key` via KDF(password‖prf)
  # and submits the already-decrypted session-key STRING. We trust it ONLY for
  # enrolled accounts (it merely fills the session cookie; the authenticated
  # `user_token` already proves identity). I6 preserved — nothing brute-forceable
  # is stored server-side.
  def create(conn, %{"unlock" => %{"user_key" => user_key} = params})
      when is_binary(user_key) and user_key != "" do
    case get_current_user_from_session(conn) do
      %Accounts.User{} = user ->
        if Accounts.prf_enrolled?(user) do
          maybe_touch_last_used(user, params["wrap_id"])
          conn = put_session(conn, :key, user_key)
          recovery_unlock_redirect(conn, user, params["rc"])
        else
          conn
          |> put_flash(:error, "Invalid password. Please try again.")
          |> redirect(to: ~p"/auth/unlock")
        end

      _ ->
        conn
        |> redirect(to: ~p"/auth/unlock")
    end
  end

  def create(conn, %{"unlock" => %{"password" => password}}) do
    case get_current_user_from_session(conn) do
      %Accounts.User{} = user ->
        case Accounts.User.valid_key_hash?(user, password) do
          {:ok, key} ->
            conn
            |> put_session(:key, key)
            |> put_flash(:info, "Session unlocked successfully!")
            |> redirect(to: ~p"/app")

          {:error, _} ->
            conn
            |> put_flash(:error, "Invalid password. Please try again.")
            |> redirect(to: ~p"/auth/unlock")

          false ->
            conn
            |> put_flash(:error, "Invalid password. Please try again.")
            |> redirect(to: ~p"/auth/unlock")
        end

      _ ->
        conn
        |> redirect(to: ~p"/auth/unlock")
    end
  end

  defp get_current_user_from_session(conn) do
    if user_token = get_session(conn, :user_token) do
      Accounts.get_user_by_session_token(user_token)
    end
  end

  # Best-effort device-roster "last used" update (board #366). Never fatal.
  defp maybe_touch_last_used(user, wrap_id)
       when is_binary(wrap_id) and wrap_id != "" and wrap_id != "recovery" do
    Accounts.touch_prf_wrap_last_used(user, wrap_id)
  end

  defp maybe_touch_last_used(_user, _wrap_id), do: :ok

  # New-device recovery unlock (board #366, design §8): when the browser
  # recovered `user_key` via the recovery key it also proved possession of the
  # recovery secret, so the LiveView minted a fresh recovery-confirmation token
  # (`rc`). Carry it to Device Unlock so the user can immediately enroll THIS
  # device (write an additional :prf wrap). Otherwise this was a normal PRF
  # unlock — go to the app.
  defp recovery_unlock_redirect(conn, user, rc) when is_binary(rc) and rc != "" do
    if Accounts.recovery_confirmation_fresh?(user, rc) do
      conn
      |> put_flash(
        :info,
        "Unlocked with your recovery key. Add this device below so you can unlock with your password next time."
      )
      |> redirect(to: ~p"/app/users/device-unlock?#{[rc: rc]}")
    else
      conn
      |> put_flash(:info, "Session unlocked successfully!")
      |> redirect(to: ~p"/app")
    end
  end

  defp recovery_unlock_redirect(conn, _user, _rc) do
    conn
    |> put_flash(:info, "Session unlocked successfully!")
    |> redirect(to: ~p"/app")
  end
end
