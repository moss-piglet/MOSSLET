defmodule Mosslet.API.Token do
  @moduledoc """
  JWT token generation and verification for API authentication.

  Tokens include:
  - `sub` - User ID
  - `key` - Encrypted session key (for decrypting user data)
  - `iat` - Issued at timestamp
  - `exp` - Expiration timestamp
  """

  @token_validity_seconds 60 * 60 * 24 * 30

  def generate(user, session_key) do
    now = System.system_time(:second)

    claims = %{
      "sub" => user.id,
      "key" => encode_key(session_key),
      "iat" => now,
      "exp" => now + @token_validity_seconds
    }

    {:ok, sign(claims)}
  end

  def verify(token) do
    with {:ok, claims} <- decode(token),
         :ok <- verify_expiration(claims) do
      claims = Map.update(claims, "key", nil, &decode_key/1)
      {:ok, claims}
    end
  end

  def refresh(token) do
    with {:ok, claims} <- verify(token),
         {:ok, user} <- get_user(claims["sub"]) do
      generate(user, claims["key"])
    end
  end

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
