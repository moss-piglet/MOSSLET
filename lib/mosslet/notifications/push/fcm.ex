defmodule Mosslet.Notifications.Push.FCM do
  @moduledoc """
  Firebase Cloud Messaging (FCM) provider for Android push notifications.

  Uses FCM HTTP v1 API with OAuth 2.0 authentication.

  🔐 ZERO-KNOWLEDGE: Only sends generic content + metadata IDs.
  Actual notification content is fetched & decrypted on device.

  ## Configuration

      config :mosslet, Mosslet.Notifications.Push.FCM,
        project_id: "mosslet-app",
        service_account_json: \"\"\"
        {
          "type": "service_account",
          "project_id": "mosslet-app",
          ...
        }
        \"\"\"

  Or provide credentials directly:

      config :mosslet, Mosslet.Notifications.Push.FCM,
        project_id: "mosslet-app",
        client_email: "firebase-adminsdk-xxxxx@mosslet-app.iam.gserviceaccount.com",
        private_key: \"\"\"
        -----BEGIN PRIVATE KEY-----
        ...
        -----END PRIVATE KEY-----
        \"\"\"

  ## Push Payload Structure

  All pushes use the same zero-knowledge format:
  - Generic title/body (no sensitive content)
  - Data payload with type + resource IDs
  - High priority for immediate delivery
  """

  require Logger

  @fcm_api_url "https://fcm.googleapis.com/v1/projects"
  @oauth_token_url "https://oauth2.googleapis.com/token"
  @fcm_scope "https://www.googleapis.com/auth/firebase.messaging"

  @doc """
  Sends a push notification to an Android device.

  ## Parameters

    * `device_token` - The FCM registration token (decrypted)
    * `payload` - The notification payload map

  ## Returns

    * `{:ok, %{message_id: id}}` - Successfully sent
    * `{:error, :invalid_token}` - Token is invalid/expired
    * `{:error, reason}` - Other failure
  """
  def send(device_token, payload) do
    if enabled?() do
      do_send(device_token, payload)
    else
      Logger.debug("FCM disabled, skipping push")
      {:ok, %{message_id: "disabled"}}
    end
  end

  defp do_send(device_token, payload) do
    with {:ok, access_token} <- get_access_token() do
      url = "#{@fcm_api_url}/#{project_id()}/messages:send"
      fcm_message = build_fcm_message(device_token, payload)

      headers = [
        {"authorization", "Bearer #{access_token}"},
        {"content-type", "application/json"}
      ]

      case Req.post(url, json: %{"message" => fcm_message}, headers: headers) do
        {:ok, %{status: 200, body: %{"name" => message_id}}} ->
          {:ok, %{message_id: message_id}}

        {:ok, %{status: 400, body: %{"error" => %{"details" => details}}}} ->
          if invalid_token_error?(details) do
            {:error, :invalid_token}
          else
            Logger.error("FCM send failed: 400 - #{inspect(details)}")
            {:error, {:fcm_error, 400, details}}
          end

        {:ok, %{status: 404}} ->
          {:error, :invalid_token}

        {:ok, %{status: status, body: body}} ->
          Logger.error("FCM send failed: #{status} - #{inspect(body)}")
          {:error, {:fcm_error, status, body}}

        {:error, reason} ->
          Logger.error("FCM request failed: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp build_fcm_message(device_token, payload) do
    message = %{
      "token" => device_token,
      "notification" => %{
        "title" => payload.title,
        "body" => payload.body
      },
      "data" => Map.get(payload, :data, %{}),
      "android" => %{
        "priority" => "high",
        "notification" => %{
          "sound" => Map.get(payload, :sound, "default"),
          "channel_id" => "mosslet_notifications"
        }
      }
    }

    if Map.get(payload, :content_available, true) do
      put_in(message, ["android", "data"], message["data"])
    else
      message
    end
  end

  defp get_access_token do
    now = System.system_time(:second)

    case Process.get(:fcm_access_token) do
      {token, expires_at} when is_integer(expires_at) ->
        if expires_at > now do
          {:ok, token}
        else
          fetch_access_token()
        end

      _ ->
        fetch_access_token()
    end
  end

  defp fetch_access_token do
    jwt = generate_jwt()

    body = %{
      "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
      "assertion" => jwt
    }

    case Req.post(@oauth_token_url, form: body) do
      {:ok, %{status: 200, body: %{"access_token" => token, "expires_in" => expires_in}}} ->
        expires_at = System.system_time(:second) + expires_in - 60
        Process.put(:fcm_access_token, {token, expires_at})
        {:ok, token}

      {:ok, %{status: status, body: body}} ->
        Logger.error("FCM OAuth failed: #{status} - #{inspect(body)}")
        {:error, {:oauth_failed, status, body}}

      {:error, reason} ->
        Logger.error("FCM OAuth request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp generate_jwt do
    now = System.system_time(:second)

    header = %{
      "alg" => "RS256",
      "typ" => "JWT"
    }

    claims = %{
      "iss" => client_email(),
      "sub" => client_email(),
      "aud" => @oauth_token_url,
      "iat" => now,
      "exp" => now + 3600,
      "scope" => @fcm_scope
    }

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    claims_b64 = Base.url_encode64(Jason.encode!(claims), padding: false)
    signing_input = "#{header_b64}.#{claims_b64}"

    signature =
      signing_input
      |> sign_rs256()
      |> Base.url_encode64(padding: false)

    "#{signing_input}.#{signature}"
  end

  defp sign_rs256(data) do
    private_key_pem = private_key()

    [pem_entry] = :public_key.pem_decode(private_key_pem)
    private_key = :public_key.pem_entry_decode(pem_entry)

    :public_key.sign(data, :sha256, private_key)
  end

  defp invalid_token_error?(details) when is_list(details) do
    Enum.any?(details, fn detail ->
      case detail do
        %{"errorCode" => "UNREGISTERED"} -> true
        %{"errorCode" => "INVALID_ARGUMENT"} -> true
        _ -> false
      end
    end)
  end

  defp invalid_token_error?(_), do: false

  defp enabled?, do: config()[:enabled] != false and private_key() != nil
  defp project_id, do: config()[:project_id] || parse_service_account()["project_id"]
  defp client_email, do: config()[:client_email] || parse_service_account()["client_email"]
  defp private_key, do: config()[:private_key] || parse_service_account()["private_key"]

  defp parse_service_account do
    case config()[:service_account_json] do
      nil -> %{}
      json when is_binary(json) -> Jason.decode!(json)
      _ -> %{}
    end
  end

  defp config do
    Application.get_env(:mosslet, __MODULE__, [])
  end
end
