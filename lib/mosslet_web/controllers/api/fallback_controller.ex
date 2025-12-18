defmodule MossletWeb.API.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.
  """
  use MossletWeb, :controller

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_credentials", message: "Invalid email or password"})
  end

  def call(conn, {:error, :account_unavailable}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "account_unavailable", message: "Account is suspended or deleted"})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found", message: "Resource not found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized", message: "Unauthorized"})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden", message: "Access denied"})
  end

  def call(conn, {:error, :invalid_totp_code}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_totp_code", message: "Invalid two-factor authentication code"})
  end

  def call(conn, {:error, :totp_token_expired}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "totp_token_expired",
      message: "TOTP verification token has expired, please login again"
    })
  end

  def call(conn, {:error, :invalid_totp_token}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_totp_token", message: "Invalid TOTP verification token"})
  end

  def call(conn, {:error, :totp_not_enabled}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "totp_not_enabled", message: "Two-factor authentication is not enabled"})
  end

  def call(conn, {:error, :invalid_secret}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_secret", message: "Invalid TOTP secret"})
  end

  def call(conn, {:error, :invalid_remember_token}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_remember_token", message: "Invalid or revoked remember me token"})
  end

  def call(conn, {:error, :remember_token_expired}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: "remember_token_expired",
      message: "Remember me token has expired, please login again"
    })
  end

  def call(conn, {:error, :missing_params}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_params", message: "Required parameters are missing"})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", errors: format_changeset_errors(changeset)})
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: to_string(reason), message: "Request failed"})
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
