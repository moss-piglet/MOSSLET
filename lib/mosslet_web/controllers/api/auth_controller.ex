defmodule MossletWeb.API.AuthController do
  @moduledoc """
  API authentication endpoints for desktop/mobile apps.

  Handles login and registration, returning JWT tokens and encrypted user data
  that native apps can decrypt locally for true zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.API.Token

  action_fallback MossletWeb.API.FallbackController

  def login(conn, %{"email" => email, "password" => password}) do
    with %User{} = user <- Accounts.get_user_by_email_and_password(email, password),
         false <- user.is_suspended?,
         false <- user.is_deleted?,
         {:ok, session_key} <- User.valid_key_hash?(user, password),
         {:ok, token} <- Token.generate(user, session_key) do
      Accounts.user_lifecycle_action("after_sign_in", user, %{
        ip: get_ip(conn),
        key: session_key,
        platform: "api"
      })

      conn
      |> put_status(:ok)
      |> json(%{
        token: token,
        user: serialize_user(user, session_key)
      })
    else
      nil ->
        {:error, :invalid_credentials}

      true ->
        {:error, :account_unavailable}

      {:error, _} ->
        {:error, :invalid_credentials}
    end
  end

  def register(conn, %{"user" => user_params}) do
    changeset = User.registration_changeset(%User{}, user_params)

    if changeset.valid? do
      c_attrs = Map.get(changeset.changes, :connection_map, %{})

      with {:ok, user} <- Accounts.register_user(changeset, c_attrs),
           {:ok, session_key} <- User.valid_key_hash?(user, user_params["password"]),
           {:ok, token} <- Token.generate(user, session_key) do
        conn
        |> put_status(:created)
        |> json(%{
          token: token,
          user: serialize_user(user, session_key)
        })
      end
    else
      {:error, changeset}
    end
  end

  def refresh(conn, _params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key
    {:ok, token} = Token.generate(user, session_key)

    conn
    |> put_status(:ok)
    |> json(%{token: token})
  end

  def me(conn, _params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key
    user_data = serialize_user(user, session_key)

    conn
    |> put_status(:ok)
    |> json(%{user: user_data})
  end

  def logout(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{message: "Logged out successfully"})
  end

  defp serialize_user(user, _session_key) do
    %{
      id: user.id,
      email_hash: encode_binary(user.email_hash),
      username_hash: encode_binary(user.username_hash),
      key_pair: encode_key_pair(user.key_pair),
      key_hash: encode_binary(user.key_hash),
      conn_key: encode_binary(user.conn_key),
      is_confirmed: not is_nil(user.confirmed_at),
      is_onboarded: user.is_onboarded?,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end

  defp encode_binary(nil), do: nil

  defp encode_binary(data) when is_binary(data) do
    Base.encode64(data)
  end

  defp encode_key_pair(nil), do: nil

  defp encode_key_pair(key_pair) when is_map(key_pair) do
    Map.new(key_pair, fn {k, v} -> {k, encode_binary(v)} end)
  end

  defp get_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end
end
