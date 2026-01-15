defmodule Mosslet.Notifications.Push.APNs do
  @moduledoc """
  Apple Push Notification service (APNs) provider.

  Uses HTTP/2 APNs API with JWT authentication.

  🔐 ZERO-KNOWLEDGE: Only sends generic content + metadata IDs.
  Actual notification content is fetched & decrypted on device.

  ## Configuration

      config :mosslet, Mosslet.Notifications.Push.APNs,
        key_id: "XXXXXXXXXX",
        team_id: "XXXXXXXXXX",
        bundle_id: "com.mosslet.app",
        private_key: \"\"\"
        -----BEGIN PRIVATE KEY-----
        ...
        -----END PRIVATE KEY-----
        \"\"\",
        environment: :production  # or :sandbox

  ## Push Payload Structure

  All pushes use the same zero-knowledge format:
  - Generic title/body (no sensitive content)
  - Data payload with type + resource IDs
  - content-available: 1 for background fetch
  - mutable-content: 1 for Notification Service Extension
  """

  require Logger

  @production_url "https://api.push.apple.com"
  @sandbox_url "https://api.sandbox.push.apple.com"

  @doc """
  Sends a push notification to an iOS device.

  ## Parameters

    * `device_token` - The APNs device token (decrypted)
    * `payload` - The notification payload map

  ## Returns

    * `{:ok, %{apns_id: id}}` - Successfully sent
    * `{:error, :invalid_token}` - Token is invalid/expired
    * `{:error, reason}` - Other failure
  """
  def send(device_token, payload) do
    if enabled?() do
      do_send(device_token, payload)
    else
      Logger.debug("APNs disabled, skipping push")
      {:ok, %{apns_id: "disabled"}}
    end
  end

  defp do_send(device_token, payload) do
    url = "#{api_base_url()}/3/device/#{device_token}"
    apns_payload = build_apns_payload(payload)

    headers = [
      {"authorization", "bearer #{generate_jwt()}"},
      {"apns-topic", bundle_id()},
      {"apns-push-type", push_type(payload)},
      {"apns-priority", "10"},
      {"apns-expiration", "0"}
    ]

    case Req.post(url, json: apns_payload, headers: headers) do
      {:ok, %{status: 200, headers: headers}} ->
        apns_id = get_header(headers, "apns-id")
        {:ok, %{apns_id: apns_id}}

      {:ok, %{status: 400, body: %{"reason" => "BadDeviceToken"}}} ->
        {:error, :invalid_token}

      {:ok, %{status: 400, body: %{"reason" => "Unregistered"}}} ->
        {:error, :invalid_token}

      {:ok, %{status: 410}} ->
        {:error, :invalid_token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("APNs send failed: #{status} - #{inspect(body)}")
        {:error, {:apns_error, status, body}}

      {:error, reason} ->
        Logger.error("APNs request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp build_apns_payload(payload) do
    %{
      "aps" => %{
        "alert" => %{
          "title" => payload.title,
          "body" => payload.body
        },
        "sound" => Map.get(payload, :sound, "default"),
        "badge" => Map.get(payload, :badge, 1),
        "content-available" => if(Map.get(payload, :content_available, true), do: 1, else: 0),
        "mutable-content" => if(Map.get(payload, :mutable_content, true), do: 1, else: 0)
      },
      "data" => Map.get(payload, :data, %{})
    }
  end

  defp push_type(payload) do
    if Map.get(payload, :content_available) and is_nil(payload[:title]) do
      "background"
    else
      "alert"
    end
  end

  defp generate_jwt do
    now = System.system_time(:second)

    header = %{
      "alg" => "ES256",
      "kid" => key_id(),
      "typ" => "JWT"
    }

    claims = %{
      "iss" => team_id(),
      "iat" => now
    }

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    claims_b64 = Base.url_encode64(Jason.encode!(claims), padding: false)
    signing_input = "#{header_b64}.#{claims_b64}"

    signature =
      signing_input
      |> sign_es256()
      |> Base.url_encode64(padding: false)

    "#{signing_input}.#{signature}"
  end

  defp sign_es256(data) do
    private_key_pem = private_key()

    [pem_entry] = :public_key.pem_decode(private_key_pem)
    private_key = :public_key.pem_entry_decode(pem_entry)

    :public_key.sign(data, :sha256, private_key)
    |> der_to_raw_ecdsa()
  end

  defp der_to_raw_ecdsa(der_signature) do
    {:ok, {r, s}} = decode_der_ecdsa(der_signature)
    pad_to_32(r) <> pad_to_32(s)
  end

  defp decode_der_ecdsa(
         <<0x30, _len, 0x02, r_len, r::binary-size(r_len), 0x02, s_len, s::binary>>
       ) do
    s_value = :binary.decode_unsigned(binary_part(s, 0, s_len))
    r_value = :binary.decode_unsigned(r)
    {:ok, {r_value, s_value}}
  end

  defp decode_der_ecdsa(_), do: {:error, :invalid_der}

  defp pad_to_32(int) when is_integer(int) do
    bin = :binary.encode_unsigned(int)
    pad_size = max(0, 32 - byte_size(bin))
    :binary.copy(<<0>>, pad_size) <> bin
  end

  defp get_header(headers, name) do
    Enum.find_value(headers, fn
      {^name, value} -> value
      _ -> nil
    end)
  end

  defp api_base_url do
    case config()[:environment] || :sandbox do
      :production -> @production_url
      _ -> @sandbox_url
    end
  end

  defp enabled?, do: config()[:enabled] != false and private_key() != nil
  defp key_id, do: config()[:key_id]
  defp team_id, do: config()[:team_id]
  defp bundle_id, do: config()[:bundle_id]
  defp private_key, do: config()[:private_key]

  defp config do
    Application.get_env(:mosslet, __MODULE__, [])
  end
end
