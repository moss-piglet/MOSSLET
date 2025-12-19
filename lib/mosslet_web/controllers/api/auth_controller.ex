defmodule MossletWeb.API.AuthController do
  @moduledoc """
  API authentication endpoints for desktop/mobile apps.

  Handles login and registration, returning JWT tokens and encrypted user data
  that native apps can decrypt locally for true zero-knowledge operation.

  ## TOTP/2FA Support

  When a user has 2FA enabled, the login flow works as follows:

  1. Client sends `POST /api/auth/login` with email + password
  2. If 2FA is enabled, server returns `{totp_required: true, totp_token: "..."}`
  3. Client prompts user for TOTP code
  4. Client sends `POST /api/auth/totp/verify` with totp_token + code
  5. Server validates code and returns full auth token + user data

  The `totp_token` is a short-lived JWT (5 minutes) that proves the user
  successfully authenticated with email/password.

  ## Remember Me Support

  Native clients can request a long-lived remember_me token by passing
  `remember_me: true` in the login request. This token:
  - Is stored in the DB like web session tokens (can be revoked)
  - Lasts 60 days (same as web remember_me cookie)
  - Can be used to get a fresh access token without re-entering password
  """
  use MossletWeb, :controller

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.API.Token

  action_fallback MossletWeb.API.FallbackController

  def login(conn, %{"email" => email, "password" => password} = params) do
    with %User{} = user <- Accounts.get_user_by_email_and_password(email, password),
         false <- user.is_suspended?,
         false <- user.is_deleted?,
         true <- not is_nil(user.confirmed_at),
         {:ok, session_key} <- User.valid_key_hash?(user, password) do
      if Accounts.two_factor_auth_enabled?(user) do
        handle_totp_login(conn, user, session_key, params)
      else
        complete_login(conn, user, session_key, params)
      end
    else
      nil ->
        {:error, :invalid_credentials}

      true ->
        {:error, :account_unavailable}

      false ->
        {:error, :email_not_confirmed}

      {:error, _} ->
        {:error, :invalid_credentials}
    end
  end

  defp handle_totp_login(conn, user, session_key, params) do
    case Map.get(params, "totp_code") do
      nil ->
        {:ok, totp_token} = Token.generate_totp_pending(user, session_key)

        conn
        |> put_status(:ok)
        |> json(%{
          totp_required: true,
          totp_token: totp_token
        })

      code when is_binary(code) ->
        case Accounts.validate_user_totp(user, code) do
          :valid_totp ->
            complete_login(conn, user, session_key, params)

          {:valid_backup_code, remaining} ->
            complete_login(conn, user, session_key, params, backup_codes_remaining: remaining)

          :invalid ->
            {:error, :invalid_totp_code}
        end
    end
  end

  def verify_totp(conn, %{"totp_token" => totp_token, "code" => code} = params) do
    with {:ok, %{user_id: user_id, session_key: session_key}} <-
           Token.verify_totp_pending(totp_token),
         user when not is_nil(user) <- Accounts.get_user(user_id),
         false <- user.is_suspended?,
         false <- user.is_deleted? do
      case Accounts.validate_user_totp(user, code) do
        :valid_totp ->
          complete_login(conn, user, session_key, params)

        {:valid_backup_code, remaining} ->
          complete_login(conn, user, session_key, params, backup_codes_remaining: remaining)

        :invalid ->
          {:error, :invalid_totp_code}
      end
    else
      {:error, :expired} ->
        {:error, :totp_token_expired}

      {:error, _} ->
        {:error, :invalid_totp_token}

      nil ->
        {:error, :invalid_totp_token}

      true ->
        {:error, :account_unavailable}
    end
  end

  def verify_totp(_conn, _params) do
    {:error, :missing_params}
  end

  def refresh_from_remember_me(conn, %{"remember_me_token" => remember_token}) do
    with {:ok, %{user: user, session_token: _session_token}} <-
           Token.verify_remember_me(remember_token),
         false <- user.is_suspended?,
         false <- user.is_deleted?,
         {:ok, session_key} <- derive_session_key_from_user(user) do
      {:ok, token} = Token.generate(user, session_key)

      conn
      |> put_status(:ok)
      |> json(%{
        token: token,
        user: serialize_user(user, session_key)
      })
    else
      {:error, :invalid_session} ->
        {:error, :invalid_remember_token}

      {:error, :expired} ->
        {:error, :remember_token_expired}

      {:error, _} ->
        {:error, :invalid_remember_token}

      true ->
        {:error, :account_unavailable}
    end
  end

  def refresh_from_remember_me(_conn, _params) do
    {:error, :missing_params}
  end

  defp derive_session_key_from_user(_user) do
    {:ok, nil}
  end

  def totp_status(conn, _params) do
    user = conn.assigns.current_user
    totp = Accounts.get_user_totp(user)

    conn
    |> put_status(:ok)
    |> json(%{
      enabled: not is_nil(totp),
      backup_codes_remaining:
        if(totp, do: Enum.count(totp.backup_codes, &is_nil(&1.used_at)), else: nil)
    })
  end

  def setup_totp(conn, _params) do
    user = conn.assigns.current_user
    secret = NimbleTOTP.secret()

    otpauth_url =
      NimbleTOTP.otpauth_uri("Mosslet:#{user.id}", secret, issuer: "Mosslet")

    conn
    |> put_status(:ok)
    |> json(%{
      secret: Base.encode32(secret, padding: false),
      otpauth_url: otpauth_url
    })
  end

  def enable_totp(conn, %{"secret" => secret_b32, "code" => code}) do
    user = conn.assigns.current_user

    with {:ok, secret} <- Base.decode32(secret_b32, padding: false),
         true <- NimbleTOTP.valid?(secret, code) do
      totp = %Mosslet.Accounts.UserTOTP{user_id: user.id, secret: secret}

      case Accounts.upsert_user_totp(totp, %{code: code}) do
        {:ok, user_totp} ->
          backup_codes =
            user_totp.backup_codes
            |> Enum.filter(&is_nil(&1.used_at))
            |> Enum.map(& &1.code)

          conn
          |> put_status(:created)
          |> json(%{
            enabled: true,
            backup_codes: backup_codes
          })

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      :error ->
        {:error, :invalid_secret}

      false ->
        {:error, :invalid_totp_code}
    end
  end

  def enable_totp(_conn, _params) do
    {:error, :missing_params}
  end

  def disable_totp(conn, %{"password" => password}) do
    user = conn.assigns.current_user

    with true <- User.valid_password?(user, password),
         totp when not is_nil(totp) <- Accounts.get_user_totp(user),
         {:ok, _} <- Accounts.delete_user_totp(totp) do
      conn
      |> put_status(:ok)
      |> json(%{enabled: false})
    else
      false ->
        {:error, :invalid_credentials}

      nil ->
        {:error, :totp_not_enabled}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def disable_totp(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    with totp when not is_nil(totp) <- Accounts.get_user_totp(user),
         result when result in [:valid_totp] or is_tuple(result) <-
           Accounts.validate_user_totp(user, code),
         true <- result == :valid_totp or match?({:valid_backup_code, _}, result),
         {:ok, _} <- Accounts.delete_user_totp(totp) do
      conn
      |> put_status(:ok)
      |> json(%{enabled: false})
    else
      nil ->
        {:error, :totp_not_enabled}

      :invalid ->
        {:error, :invalid_totp_code}

      false ->
        {:error, :invalid_totp_code}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def disable_totp(_conn, _params) do
    {:error, :missing_params}
  end

  def regenerate_backup_codes(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    with totp when not is_nil(totp) <- Accounts.get_user_totp(user),
         result when result == :valid_totp or is_tuple(result) <-
           Accounts.validate_user_totp(user, code),
         true <- result == :valid_totp or match?({:valid_backup_code, _}, result),
         {:ok, updated_totp} <- Accounts.regenerate_user_totp_backup_codes(totp) do
      backup_codes =
        updated_totp.backup_codes
        |> Enum.filter(&is_nil(&1.used_at))
        |> Enum.map(& &1.code)

      conn
      |> put_status(:ok)
      |> json(%{backup_codes: backup_codes})
    else
      nil ->
        {:error, :totp_not_enabled}

      :invalid ->
        {:error, :invalid_totp_code}

      false ->
        {:error, :invalid_totp_code}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def regenerate_backup_codes(_conn, _params) do
    {:error, :missing_params}
  end

  defp complete_login(conn, user, session_key, params, opts \\ []) do
    {:ok, token} = Token.generate(user, session_key)

    Accounts.user_lifecycle_action("after_sign_in", user, %{
      ip: get_ip(conn),
      key: session_key,
      platform: "api"
    })

    response = %{
      token: token,
      user: serialize_user(user, session_key)
    }

    response =
      if params["remember_me"] == true or params["remember_me"] == "true" do
        {:ok, remember_token} = Token.generate_remember_me(user)
        Map.put(response, :remember_me_token, remember_token)
      else
        response
      end

    response =
      case Keyword.get(opts, :backup_codes_remaining) do
        nil -> response
        remaining -> Map.put(response, :backup_codes_remaining, remaining)
      end

    conn
    |> put_status(:ok)
    |> json(response)
  end

  def register(conn, %{"user" => user_params}) do
    changeset = User.registration_changeset(%User{}, user_params)

    if changeset.valid? do
      c_attrs = Map.get(changeset.changes, :connection_map, %{})

      with {:ok, user} <- Accounts.register_user(changeset, c_attrs),
           {:ok, session_key} <- User.valid_key_hash?(user, user_params["password"]),
           {:ok, token} <- Token.generate(user, session_key) do
        response = %{
          token: token,
          user: serialize_user(user, session_key)
        }

        response =
          if user_params["remember_me"] == true or user_params["remember_me"] == "true" do
            {:ok, remember_token} = Token.generate_remember_me(user)
            Map.put(response, :remember_me_token, remember_token)
          else
            response
          end

        conn
        |> put_status(:created)
        |> json(response)
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

  def logout(conn, %{"remember_me_token" => remember_token}) do
    Token.revoke_remember_me(remember_token)

    conn
    |> put_status(:ok)
    |> json(%{message: "Logged out successfully"})
  end

  def logout(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{message: "Logged out successfully"})
  end

  def request_password_reset(conn, %{"email" => email}) do
    if user = Accounts.get_user_by_email(email) do
      if user.is_forgot_pwd? do
        Accounts.deliver_user_reset_password_instructions(
          user,
          email,
          &(MossletWeb.Endpoint.url() <> "/auth/reset-password/#{&1}")
        )
      end
    end

    conn
    |> put_status(:ok)
    |> json(%{
      message:
        "If your email is in our system and password reset is enabled, you will receive instructions shortly."
    })
  end

  def request_password_reset(_conn, _params), do: {:error, :missing_params}

  def verify_password_reset_token(conn, %{"token" => token}) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:error, :invalid_token}

      user ->
        if user.is_forgot_pwd? && user.key do
          conn
          |> put_status(:ok)
          |> json(%{valid: true, user_id: user.id})
        else
          {:error, :password_reset_disabled}
        end
    end
  end

  def verify_password_reset_token(_conn, _params), do: {:error, :missing_params}

  def reset_password_with_token(
        conn,
        %{"token" => token, "password" => password} = params
      ) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:error, :invalid_token}

      user ->
        if user.is_forgot_pwd? && user.key do
          attrs = %{
            "password" => password,
            "password_confirmation" => params["password_confirmation"] || password
          }

          case Accounts.reset_user_password(user, attrs,
                 user: user,
                 key: user.key,
                 reset_password: true
               ) do
            {:ok, _user} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Password reset successfully"})

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :password_reset_disabled}
        end
    end
  end

  def reset_password_with_token(_conn, _params), do: {:error, :missing_params}

  def resend_confirmation(conn, %{"email" => email}) do
    if user = Accounts.get_user_by_email(email) do
      if is_nil(user.confirmed_at) do
        Accounts.deliver_user_confirmation_instructions(
          user,
          email,
          &(MossletWeb.Endpoint.url() <> "/auth/confirm/#{&1}")
        )
      end
    end

    conn
    |> put_status(:ok)
    |> json(%{
      message:
        "If your email is in our system and has not been confirmed yet, you will receive instructions shortly."
    })
  end

  def resend_confirmation(_conn, _params), do: {:error, :missing_params}

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Email confirmed successfully"})

      :error ->
        {:error, :invalid_token}
    end
  end

  def confirm_email(_conn, _params), do: {:error, :missing_params}

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
