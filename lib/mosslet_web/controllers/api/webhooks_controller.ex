defmodule MossletWeb.API.WebhooksController do
  @moduledoc """
  Webhook endpoints for Apple and Google billing notifications.

  These endpoints receive server-to-server notifications about subscription events
  like renewals, cancellations, and refunds.

  ## Apple App Store Server Notifications V2

  Configure in App Store Connect:
    Production: https://your-domain.com/api/webhooks/apple
    Sandbox: https://your-domain.com/api/webhooks/apple

  ## Google Play Real-time Developer Notifications (RTDN)

  Configure in Google Play Console:
    https://your-domain.com/api/webhooks/google-play

  ## Security

  - Apple: Notifications are JWS-signed, verified via Apple's public keys
  - Google: Notifications come from Pub/Sub with configurable verification
  """

  use MossletWeb, :controller

  require Logger

  alias Mosslet.Billing.Providers.AppleIAP
  alias Mosslet.Billing.Providers.GooglePlay

  @doc """
  Handles Apple App Store Server Notifications V2.

  Apple sends a JWS (JSON Web Signature) in the `signedPayload` field.
  """
  def apple(conn, %{"signedPayload" => signed_payload}) do
    Logger.info("Received Apple webhook notification")

    case AppleIAP.handle_webhook(signed_payload) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        Logger.error("Apple webhook processing failed: #{inspect(reason)}")

        conn
        |> put_status(:ok)
        |> json(%{status: "error", message: inspect(reason)})

      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})
    end
  end

  def apple(conn, params) do
    Logger.warning("Received Apple webhook with unexpected format: #{inspect(params)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_format", message: "Expected signedPayload field"})
  end

  @doc """
  Handles Google Play Real-time Developer Notifications (RTDN).

  Google sends notifications via Cloud Pub/Sub. The message data is base64 encoded.

  ## Message Format

      {
        "message": {
          "data": "<base64-encoded-notification>",
          "messageId": "...",
          "publishTime": "..."
        },
        "subscription": "projects/.../subscriptions/..."
      }
  """
  def google_play(conn, %{"message" => %{"data" => data}}) do
    Logger.info("Received Google Play webhook notification")

    case GooglePlay.handle_webhook(data) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        Logger.error("Google Play webhook processing failed: #{inspect(reason)}")

        conn
        |> put_status(:ok)
        |> json(%{status: "error", message: inspect(reason)})

      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})
    end
  end

  def google_play(conn, params) do
    case GooglePlay.handle_webhook(params) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{status: "ok"})

      {:error, reason} ->
        Logger.warning(
          "Received Google Play webhook with unexpected format: #{inspect(params)}, error: #{inspect(reason)}"
        )

        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_format"})
    end
  end
end
