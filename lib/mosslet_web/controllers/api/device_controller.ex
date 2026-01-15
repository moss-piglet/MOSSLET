defmodule MossletWeb.API.DeviceController do
  @moduledoc """
  API endpoints for device token management (push notifications).

  🔐 ZERO-KNOWLEDGE ARCHITECTURE:
  - Device tokens are encrypted at rest
  - Push payloads contain only generic content + metadata IDs
  - Device fetches & decrypts actual content locally
  """
  use MossletWeb, :controller

  alias Mosslet.Notifications.Push

  action_fallback MossletWeb.API.FallbackController

  @doc """
  Registers a device token for push notifications.

  POST /api/devices/token

  Body:
    - token: string (required) - The APNs or FCM device token
    - platform: string (required) - "ios" or "android"
    - device_name: string (optional) - Human-readable device name
    - app_version: string (optional) - App version
    - os_version: string (optional) - OS version
  """
  def register_token(conn, params) do
    user = conn.assigns.current_user

    attrs = %{
      token: params["token"],
      platform: String.to_existing_atom(params["platform"]),
      device_name: params["device_name"],
      app_version: params["app_version"],
      os_version: params["os_version"]
    }

    case Push.register_device_token(user.id, attrs) do
      {:ok, device_token} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          device_token_id: device_token.id,
          platform: device_token.platform
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Unregisters a device token (e.g., on logout).

  DELETE /api/devices/token

  Body:
    - token: string (required) - The device token to unregister
  """
  def unregister_token(conn, %{"token" => token}) do
    case Push.unregister_device_token(token) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true})

      {:error, :not_found} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists the current user's registered device tokens.

  GET /api/devices/tokens
  """
  def list_tokens(conn, _params) do
    user = conn.assigns.current_user
    tokens = Push.list_user_device_tokens(user.id)

    conn
    |> put_status(:ok)
    |> json(%{
      tokens:
        Enum.map(tokens, fn t ->
          %{
            id: t.id,
            platform: t.platform,
            device_name: t.device_name,
            app_version: t.app_version,
            os_version: t.os_version,
            active: t.active,
            last_used_at: t.last_used_at,
            inserted_at: t.inserted_at
          }
        end)
    })
  end

  @doc """
  Sends a test notification to verify push setup.

  POST /api/devices/test-push

  Body:
    - token: string (optional) - Specific token to test, or all tokens if omitted
  """
  def test_push(conn, params) do
    user = conn.assigns.current_user

    results =
      case params["token"] do
        nil ->
          Push.send_notification(user.id, :test, %{test: "true"})

        token ->
          case Push.get_device_token_by_hash(token) do
            nil ->
              [{:error, :not_found}]

            device_token ->
              if device_token.user_id == user.id do
                [Push.send_notification(user.id, :test, %{test: "true"})]
              else
                [{:error, :unauthorized}]
              end
          end
      end

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    conn
    |> put_status(:ok)
    |> json(%{
      success: error_count == 0,
      sent: success_count,
      failed: error_count
    })
  end
end
