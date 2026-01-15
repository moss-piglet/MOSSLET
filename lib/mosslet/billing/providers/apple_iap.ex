defmodule Mosslet.Billing.Providers.AppleIAP do
  @moduledoc """
  Apple In-App Purchase provider for iOS native apps.

  Uses Apple's App Store Server API (v2) for receipt validation and
  App Store Server Notifications V2 for real-time subscription updates.

  ## Configuration

      config :mosslet, Mosslet.Billing.Providers.AppleIAP,
        bundle_id: "com.mosslet.app",
        issuer_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
        key_id: "XXXXXXXXXX",
        private_key: \"\"\"
        -----BEGIN PRIVATE KEY-----
        ...
        -----END PRIVATE KEY-----
        \"\"\",
        environment: :production  # or :sandbox

  ## Flow

  1. iOS app purchases via StoreKit 2
  2. App receives Transaction and sends `transactionId` + `originalTransactionId` to API
  3. Server calls Apple's `/inApps/v1/transactions/{transactionId}` to validate
  4. Server creates/updates local subscription record
  5. Server configures App Store Server Notifications for renewals/cancellations
  """

  require Logger

  use Mosslet.Billing.Providers.Behaviour

  alias Mosslet.Billing.Providers.MobileIAP

  @app_store_api_url "https://api.storekit.itunes.apple.com"
  @sandbox_api_url "https://api.storekit-sandbox.itunes.apple.com"

  @impl true
  def checkout(_user, _plan, _source, _source_id, _session_key) do
    {:error, :not_supported_use_native_ui}
  end

  @impl true
  def change_plan(_customer, _subscription, _plan, _user, _session_key) do
    {:error, :not_supported_use_native_ui}
  end

  @impl true
  def checkout_url(_session), do: ""

  @doc """
  Validates a purchase with Apple and creates/updates the subscription.

  Called from the API endpoint after the native app completes a purchase.

  ## Parameters

    * `user` - The current user
    * `transaction_id` - The StoreKit 2 transactionId
    * `session_key` - User's session key for encryption

  ## Returns

    * `{:ok, subscription}` - Purchase validated and subscription created/updated
    * `{:error, reason}` - Validation failed
  """
  def validate_and_process_purchase(user, transaction_id, session_key) do
    with {:ok, transaction_info} <- get_transaction_info(transaction_id),
         {:ok, receipt_data} <- parse_transaction_info(transaction_info) do
      MobileIAP.process_validated_receipt(user, receipt_data, :apple, session_key)
    end
  end

  @doc """
  Fetches transaction info from Apple's App Store Server API.
  """
  def get_transaction_info(transaction_id) do
    url = "#{api_base_url()}/inApps/v1/transactions/#{transaction_id}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200, body: body}} ->
        parse_signed_transaction(body["signedTransactionInfo"])

      {:ok, %{status: status, body: body}} ->
        Logger.error("Apple IAP validation failed: #{status} - #{inspect(body)}")
        {:error, {:apple_error, status, body}}

      {:error, reason} ->
        Logger.error("Apple IAP request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Fetches subscription status from Apple.
  """
  def get_subscription_status(original_transaction_id) do
    url = "#{api_base_url()}/inApps/v1/subscriptions/#{original_transaction_id}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:apple_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Handles App Store Server Notification V2 webhooks.

  Configure your webhook URL in App Store Connect:
  https://your-domain.com/api/webhooks/apple

  ## Notification Types

    * `DID_RENEW` - Subscription renewed
    * `EXPIRED` - Subscription expired
    * `DID_CHANGE_RENEWAL_STATUS` - Auto-renew toggled
    * `REFUND` - Purchase refunded
    * `SUBSCRIBED` - New subscription
  """
  def handle_webhook(signed_payload) do
    with {:ok, payload} <- decode_signed_payload(signed_payload),
         {:ok, notification} <- parse_notification(payload) do
      process_notification(notification)
    end
  end

  defp process_notification(%{notification_type: "DID_RENEW"} = notification) do
    transaction = notification.data.signed_transaction_info

    MobileIAP.handle_subscription_renewed(
      transaction["originalTransactionId"],
      parse_apple_timestamp(transaction["expiresDate"])
    )
  end

  defp process_notification(%{notification_type: type} = notification)
       when type in ["EXPIRED", "REFUND"] do
    transaction = notification.data.signed_transaction_info
    MobileIAP.handle_subscription_expired(transaction["originalTransactionId"])
  end

  defp process_notification(%{notification_type: "DID_CHANGE_RENEWAL_STATUS"} = notification) do
    transaction = notification.data.signed_transaction_info
    renewal_info = notification.data.signed_renewal_info

    if renewal_info["autoRenewStatus"] == 0 do
      case Mosslet.Billing.Subscriptions.get_subscription_by(%{
             provider_subscription_id_hash: transaction["originalTransactionId"]
           }) do
        %Mosslet.Billing.Subscriptions.Subscription{} = sub ->
          Mosslet.Billing.Subscriptions.cancel_subscription(sub)

        nil ->
          {:error, :subscription_not_found}
      end
    else
      MobileIAP.handle_subscription_renewed(
        transaction["originalTransactionId"],
        parse_apple_timestamp(transaction["expiresDate"])
      )
    end
  end

  defp process_notification(%{notification_type: type}) do
    Logger.info("Ignoring Apple notification type: #{type}")
    :ok
  end

  defp parse_transaction_info(transaction_info) do
    {:ok,
     %{
       transaction_id: transaction_info["transactionId"],
       original_transaction_id: transaction_info["originalTransactionId"],
       product_id: transaction_info["productId"],
       purchase_token: transaction_info["transactionId"],
       expires_at: parse_apple_timestamp(transaction_info["expiresDate"]),
       is_trial: transaction_info["offerType"] == 2
     }}
  end

  defp parse_signed_transaction(nil), do: {:error, :no_transaction_info}

  defp parse_signed_transaction(signed_transaction) do
    case decode_jws(signed_transaction) do
      {:ok, payload} -> {:ok, payload}
      error -> error
    end
  end

  defp decode_signed_payload(signed_payload) do
    decode_jws(signed_payload)
  end

  defp parse_notification(payload) do
    data =
      if payload["data"]["signedTransactionInfo"] do
        %{
          signed_transaction_info:
            case decode_jws(payload["data"]["signedTransactionInfo"]) do
              {:ok, info} -> info
              _ -> %{}
            end,
          signed_renewal_info:
            case decode_jws(payload["data"]["signedRenewalInfo"]) do
              {:ok, info} -> info
              _ -> %{}
            end
        }
      else
        %{}
      end

    {:ok,
     %{
       notification_type: payload["notificationType"],
       subtype: payload["subtype"],
       data: data
     }}
  end

  defp decode_jws(jws) when is_binary(jws) do
    [_header, payload, _signature] = String.split(jws, ".")

    case Base.url_decode64(payload, padding: false) do
      {:ok, json} -> Jason.decode(json)
      error -> error
    end
  end

  defp parse_apple_timestamp(nil), do: nil

  defp parse_apple_timestamp(ms) when is_integer(ms) do
    DateTime.from_unix!(div(ms, 1000)) |> DateTime.to_naive()
  end

  defp parse_apple_timestamp(ms) when is_binary(ms) do
    ms |> String.to_integer() |> parse_apple_timestamp()
  end

  defp api_base_url do
    if config()[:environment] == :sandbox do
      @sandbox_api_url
    else
      @app_store_api_url
    end
  end

  defp auth_headers do
    [
      {"Authorization", "Bearer #{generate_jwt()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp generate_jwt do
    now = System.system_time(:second)
    cfg = config()

    header = %{
      "alg" => "ES256",
      "kid" => cfg[:key_id],
      "typ" => "JWT"
    }

    payload = %{
      "iss" => cfg[:issuer_id],
      "iat" => now,
      "exp" => now + 3600,
      "aud" => "appstoreconnect-v1",
      "bid" => cfg[:bundle_id]
    }

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)
    signing_input = "#{header_b64}.#{payload_b64}"

    signature =
      signing_input
      |> sign_with_private_key(cfg[:private_key])
      |> Base.url_encode64(padding: false)

    "#{signing_input}.#{signature}"
  end

  defp sign_with_private_key(data, private_key_pem) do
    [entry] = :public_key.pem_decode(private_key_pem)
    private_key = :public_key.pem_entry_decode(entry)
    :public_key.sign(data, :sha256, private_key)
  end

  defp config do
    Application.get_env(:mosslet, __MODULE__, [])
  end

  @impl true
  def retrieve_charge(_id), do: {:error, :not_supported}

  @impl true
  def retrieve_payment_intent(_id), do: {:error, :not_supported}

  @impl true
  def retrieve_product(product_id) do
    {:ok, %{id: product_id, name: product_id}}
  end

  @impl true
  def payment_intent_adapter, do: __MODULE__

  @impl true
  def subscription_adapter, do: __MODULE__

  @impl true
  def get_payment_intent_charge_price(_), do: 0

  @impl true
  def get_payment_intent_charge_created(_), do: DateTime.utc_now()

  @impl true
  def get_subscription_product(transaction_info) do
    transaction_info["productId"]
  end

  @impl true
  def get_subscription_price(_), do: 0

  @impl true
  def get_subscription_cycle(transaction_info) do
    case transaction_info["subscriptionPeriod"] do
      "P1M" -> "month"
      "P1Y" -> "year"
      _ -> "month"
    end
  end

  @impl true
  def get_subscription_next_charge(transaction_info) do
    parse_apple_timestamp(transaction_info["expiresDate"])
  end

  @impl true
  def retrieve_subscription(original_transaction_id) do
    get_subscription_status(original_transaction_id)
  end

  @impl true
  def cancel_subscription(original_transaction_id) do
    MobileIAP.handle_subscription_expired(original_transaction_id)
  end

  @impl true
  def cancel_subscription_immediately(original_transaction_id) do
    cancel_subscription(original_transaction_id)
  end

  @impl true
  def resume_subscription(_id) do
    {:error, :must_resubscribe_in_app}
  end

  @impl true
  def sync_subscription(_customer, _user, _session_key), do: :ok

  @impl true
  def sync_payment_intent(_customer, _user, _session_key), do: :ok
end
