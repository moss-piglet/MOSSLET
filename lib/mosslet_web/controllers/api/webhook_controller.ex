defmodule MossletWeb.API.WebhookController do
  @moduledoc """
  Webhook handlers for external billing notifications.

  These endpoints receive server-to-server notifications from Apple and Google
  about subscription status changes (renewals, cancellations, refunds, etc.).

  ## Apple App Store Server Notifications V2

  Configure in App Store Connect > App > App Store Server Notifications:
  - Production URL: https://your-domain.com/api/webhooks/apple
  - Sandbox URL: https://your-domain.com/api/webhooks/apple

  ## Google Real-time Developer Notifications (RTDN)

  Configure in Google Play Console > Monetization setup > Real-time developer notifications:
  - Topic: projects/your-project/topics/play-billing
  - Subscription endpoint: https://your-domain.com/api/webhooks/google-play
  """

  use MossletWeb, :controller

  require Logger

  alias Mosslet.Billing.Providers.AppleIAP
  alias Mosslet.Billing.Providers.GooglePlay

  @doc """
  Handles Apple App Store Server Notifications V2.

  Apple sends a JWS-signed payload containing transaction and renewal info.
  """
  def apple(conn, %{"signedPayload" => signed_payload}) do
    case AppleIAP.handle_webhook(signed_payload) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:ok, _} ->
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Apple webhook error: #{inspect(reason)}")
        send_resp(conn, 200, "OK")
    end
  end

  def apple(conn, params) do
    Logger.warning("Apple webhook received unexpected payload: #{inspect(params)}")
    send_resp(conn, 200, "OK")
  end

  @doc """
  Handles Google Play Real-time Developer Notifications.

  Google sends a Pub/Sub message with base64-encoded JSON payload.
  """
  def google_play(conn, %{"message" => %{"data" => data}}) do
    case GooglePlay.handle_webhook(data) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:ok, _} ->
        send_resp(conn, 200, "OK")

      {:error, reason} ->
        Logger.error("Google Play webhook error: #{inspect(reason)}")
        send_resp(conn, 200, "OK")
    end
  end

  def google_play(conn, params) do
    Logger.warning("Google Play webhook received unexpected payload: #{inspect(params)}")
    send_resp(conn, 200, "OK")
  end
end
