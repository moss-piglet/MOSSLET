defmodule MossletWeb.UnlockSessionController do
  use MossletWeb, :controller

  alias Mosslet.Accounts

  def create(conn, %{"unlock" => %{"password" => password}}) do
    if (%Accounts.User{} = user = get_current_user_from_session(conn)) &&
         is_nil(conn.private.plug_session["key"]) do
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
    else
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
