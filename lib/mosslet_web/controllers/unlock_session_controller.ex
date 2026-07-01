defmodule MossletWeb.UnlockSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts

  # PRF-enrolled unlock (board #370): enrolled accounts have no `key_hash`
  # password-only door, so the browser unlocks `user_key` via KDF(password‖prf)
  # and submits the already-decrypted session-key STRING. We trust it ONLY for
  # enrolled accounts (it merely fills the session cookie; the authenticated
  # `user_token` already proves identity). I6 preserved — nothing brute-forceable
  # is stored server-side.
  def create(conn, %{"unlock" => %{"user_key" => user_key}})
      when is_binary(user_key) and user_key != "" do
    case get_current_user_from_session(conn) do
      %Accounts.User{} = user ->
        if Accounts.prf_enrolled?(user) do
          conn
          |> put_session(:key, user_key)
          |> put_flash(:info, "Session unlocked successfully!")
          |> redirect(to: ~p"/app")
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
end
