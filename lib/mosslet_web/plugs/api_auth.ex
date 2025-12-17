defmodule MossletWeb.Plugs.APIAuth do
  @moduledoc """
  API authentication plug for desktop/mobile apps.

  Validates JWT bearer tokens and attaches the user and session key to the conn.
  The session key is used for decrypting user data on the device.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Mosslet.Accounts
  alias Mosslet.API.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- get_bearer_token(conn),
         {:ok, claims} <- Token.verify(token),
         {:ok, user} <- get_user_from_claims(claims) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_claims, claims)
      |> assign(:session_key, claims["key"])
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized", message: error_message(reason)})
        |> halt()
    end
  end

  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end

  defp get_user_from_claims(%{"sub" => user_id}) do
    case Accounts.get_user(user_id) do
      nil -> {:error, :user_not_found}
      %{is_suspended?: true} -> {:error, :user_suspended}
      %{is_deleted?: true} -> {:error, :user_deleted}
      user -> {:ok, user}
    end
  end

  defp error_message(:missing_token), do: "Missing authorization header"
  defp error_message(:invalid_token), do: "Invalid or expired token"
  defp error_message(:expired), do: "Token has expired"
  defp error_message(:user_not_found), do: "User not found"
  defp error_message(:user_suspended), do: "Account suspended"
  defp error_message(:user_deleted), do: "Account deleted"
  defp error_message(_), do: "Authentication failed"
end
