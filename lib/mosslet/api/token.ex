defmodule Mosslet.API.Token do
  @moduledoc """
  JWT token generation and verification for API authentication.

  ## Token Types

  ### Access Token (default)
  Short-lived token for API requests.
  - `type` - "access"
  - `sub` - User ID
  - `key` - Encrypted session key (for decrypting user data)
  - `iat` - Issued at timestamp
  - `exp` - Expiration timestamp (30 days)

  ### Remember Me Token
  Long-lived token for persistent authentication (like web remember_me cookie).
  - `type` - "remember"
  - `sub` - User ID
  - `session_token` - Encrypted session token for DB validation
  - `iat` - Issued at timestamp
  - `exp` - Expiration timestamp (60 days)

  ### TOTP Pending Token
  Short-lived token proving email/password auth, requires 2FA completion.
  - `type` - "totp_pending"
  - `sub` - User ID
  - `key` - Encrypted session key
  - `iat` - Issued at timestamp
  - `exp` - Expiration timestamp (5 minutes)
  """

  alias Mosslet.Accounts

  @access_token_validity_seconds 60 * 60 * 24 * 30
  @remember_token_validity_seconds 60 * 60 * 24 * 60
  @totp_pending_validity_seconds 60 * 5

  def generate(user, session_key) do
    now = System.system_time(:second)

    claims = %{
      "type" => "access",
      "sub" => user.id,
      "key" => encode_key(session_key),
      "iat" => now,
      "exp" => now + @access_token_validity_seconds
    }

    {:ok, sign(claims)}
  end

  def generate_remember_me(user) do
    session_token = Accounts.generate_user_session_token(user)
    now = System.system_time(:second)

    claims = %{
      "type" => "remember",
      "sub" => user.id,
      "session_token" => encode_key(session_token),
      "iat" => now,
      "exp" => now + @remember_token_validity_seconds
    }

    {:ok, sign(claims)}
  end

  def generate_totp_pending(user, session_key) do
    now = System.system_time(:second)

    claims = %{
      "type" => "totp_pending",
      "sub" => user.id,
      "key" => encode_key(session_key),
      "iat" => now,
      "exp" => now + @totp_pending_validity_seconds
    }

    {:ok, sign(claims)}
  end

  def verify(token) do
    with {:ok, claims} <- decode(token),
         :ok <- verify_expiration(claims),
         :ok <- verify_type(claims, "access") do
      claims = Map.update(claims, "key", nil, &decode_key/1)
      {:ok, claims}
    end
  end

  def verify_remember_me(token) do
    with {:ok, claims} <- decode(token),
         :ok <- verify_expiration(claims),
         :ok <- verify_type(claims, "remember"),
         session_token <- decode_key(claims["session_token"]),
         user when not is_nil(user) <- Accounts.get_user_by_session_token(session_token) do
      {:ok, %{user: user, session_token: session_token}}
    else
      nil -> {:error, :invalid_session}
      error -> error
    end
  end

  def verify_totp_pending(token) do
    with {:ok, claims} <- decode(token),
         :ok <- verify_expiration(claims),
         :ok <- verify_type(claims, "totp_pending") do
      {:ok, %{user_id: claims["sub"], session_key: decode_key(claims["key"])}}
    end
  end

  def refresh(token) do
    with {:ok, claims} <- verify(token),
         {:ok, user} <- get_user(claims["sub"]) do
      generate(user, claims["key"])
    end
  end

  def revoke_remember_me(token) do
    with {:ok, claims} <- decode(token),
         :ok <- verify_type(claims, "remember"),
         session_token <- decode_key(claims["session_token"]) do
      Accounts.delete_user_session_token(session_token)
      :ok
    else
      _ -> :ok
    end
  end

  defp verify_type(%{"type" => type}, expected) when type == expected, do: :ok
  defp verify_type(%{"type" => _}, _expected), do: {:error, :wrong_token_type}
  defp verify_type(_claims, "access"), do: :ok
  defp verify_type(_claims, _expected), do: {:error, :wrong_token_type}

  defp sign(claims) do
    secret = secret_key()
    header = %{"alg" => "HS256", "typ" => "JWT"}

    header_b64 = header |> Jason.encode!() |> Base.url_encode64(padding: false)
    payload_b64 = claims |> Jason.encode!() |> Base.url_encode64(padding: false)

    message = "#{header_b64}.#{payload_b64}"
    signature = :crypto.mac(:hmac, :sha256, secret, message) |> Base.url_encode64(padding: false)

    "#{message}.#{signature}"
  end

  defp decode(token) do
    case String.split(token, ".") do
      [header_b64, payload_b64, signature_b64] ->
        message = "#{header_b64}.#{payload_b64}"

        expected_sig =
          :crypto.mac(:hmac, :sha256, secret_key(), message) |> Base.url_encode64(padding: false)

        if secure_compare(signature_b64, expected_sig) do
          case Base.url_decode64(payload_b64, padding: false) do
            {:ok, payload_json} -> Jason.decode(payload_json)
            :error -> {:error, :invalid_token}
          end
        else
          {:error, :invalid_token}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  defp verify_expiration(%{"exp" => exp}) do
    if System.system_time(:second) < exp do
      :ok
    else
      {:error, :expired}
    end
  end

  defp verify_expiration(_), do: {:error, :invalid_token}

  defp get_user(user_id) do
    case Mosslet.Accounts.get_user(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp encode_key(nil), do: nil
  defp encode_key(key) when is_binary(key), do: Base.encode64(key)

  defp decode_key(nil), do: nil

  defp decode_key(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, key} -> key
      :error -> nil
    end
  end

  defp secret_key do
    Application.get_env(:mosslet, :api_token_secret) ||
      Application.get_env(:mosslet, MossletWeb.Endpoint)[:secret_key_base]
  end

  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp secure_compare(_, _), do: false
end
