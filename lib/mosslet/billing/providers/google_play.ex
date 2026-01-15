defmodule Mosslet.Billing.Providers.GooglePlay do
  @moduledoc """
  Google Play Billing provider for Android native apps.

  Uses Google Play Developer API for purchase validation and
  Real-time Developer Notifications (RTDN) for subscription updates.

  ## Configuration

      config :mosslet, Mosslet.Billing.Providers.GooglePlay,
        package_name: "com.mosslet.app",
        service_account_json: "/path/to/service-account.json"
        # OR provide credentials directly:
        # client_email: "xxx@xxx.iam.gserviceaccount.com",
        # private_key: "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----"

  ## Flow

  1. Android app purchases via Google Play Billing Library
  2. App receives Purchase object with `purchaseToken`
  3. App sends `purchaseToken` + `productId` to our API
  4. Server calls Google Play Developer API to validate
  5. Server creates/updates local subscription record
  6. Server configures RTDN for renewals/cancellations
  """

  require Logger

  use Mosslet.Billing.Providers.Behaviour

  alias Mosslet.Billing.Providers.MobileIAP

  @google_api_base "https://androidpublisher.googleapis.com/androidpublisher/v3"
  @oauth_token_url "https://oauth2.googleapis.com/token"

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
  Validates a purchase with Google and creates/updates the subscription.

  Called from the API endpoint after the native app completes a purchase.

  ## Parameters

    * `user` - The current user
    * `product_id` - The Google Play product ID (SKU)
    * `purchase_token` - The purchaseToken from Google Play
    * `session_key` - User's session key for encryption
    * `opts` - Options:
      * `:is_subscription` - true for subscriptions, false for one-time purchases

  ## Returns

    * `{:ok, subscription}` - Purchase validated and subscription created/updated
    * `{:error, reason}` - Validation failed
  """
  def validate_and_process_purchase(user, product_id, purchase_token, session_key, opts \\ []) do
    is_subscription = Keyword.get(opts, :is_subscription, true)

    validation_result =
      if is_subscription do
        validate_subscription(product_id, purchase_token)
      else
        validate_product_purchase(product_id, purchase_token)
      end

    with {:ok, purchase_info} <- validation_result,
         {:ok, receipt_data} <- parse_purchase_info(purchase_info, product_id, purchase_token) do
      result = MobileIAP.process_validated_receipt(user, receipt_data, :google, session_key)

      if is_subscription && purchase_info["acknowledgementState"] == 0 do
        acknowledge_subscription(product_id, purchase_token)
      end

      result
    end
  end

  @doc """
  Validates a subscription purchase with Google Play Developer API.
  """
  def validate_subscription(product_id, purchase_token) do
    package_name = config()[:package_name]

    url =
      "#{@google_api_base}/applications/#{package_name}/purchases/subscriptions/#{product_id}/tokens/#{purchase_token}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Google Play subscription validation failed: #{status} - #{inspect(body)}")
        {:error, {:google_error, status, body}}

      {:error, reason} ->
        Logger.error("Google Play request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Validates a one-time product purchase with Google Play Developer API.
  """
  def validate_product_purchase(product_id, purchase_token) do
    package_name = config()[:package_name]

    url =
      "#{@google_api_base}/applications/#{package_name}/purchases/products/#{product_id}/tokens/#{purchase_token}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Google Play product validation failed: #{status} - #{inspect(body)}")
        {:error, {:google_error, status, body}}

      {:error, reason} ->
        Logger.error("Google Play request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Acknowledges a subscription purchase.

  Required within 3 days of purchase or Google will refund.
  """
  def acknowledge_subscription(product_id, purchase_token) do
    package_name = config()[:package_name]

    url =
      "#{@google_api_base}/applications/#{package_name}/purchases/subscriptions/#{product_id}/tokens/#{purchase_token}:acknowledge"

    case Req.post(url, headers: auth_headers(), json: %{}) do
      {:ok, %{status: status}} when status in [200, 204] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Google Play acknowledge failed: #{status} - #{inspect(body)}")
        {:error, {:google_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Acknowledges a one-time product purchase.
  """
  def acknowledge_product(product_id, purchase_token) do
    package_name = config()[:package_name]

    url =
      "#{@google_api_base}/applications/#{package_name}/purchases/products/#{product_id}/tokens/#{purchase_token}:acknowledge"

    case Req.post(url, headers: auth_headers(), json: %{}) do
      {:ok, %{status: status}} when status in [200, 204] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:google_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Handles Real-time Developer Notification (RTDN) webhooks from Google Play.

  Configure your webhook URL in Google Play Console:
  https://your-domain.com/api/webhooks/google-play

  ## Notification Types

    * `SUBSCRIPTION_RECOVERED` - Subscription recovered from hold
    * `SUBSCRIPTION_RENEWED` - Subscription renewed
    * `SUBSCRIPTION_CANCELED` - Subscription canceled
    * `SUBSCRIPTION_PURCHASED` - New subscription
    * `SUBSCRIPTION_ON_HOLD` - Subscription on hold (payment issue)
    * `SUBSCRIPTION_IN_GRACE_PERIOD` - In grace period
    * `SUBSCRIPTION_RESTARTED` - Subscription restarted
    * `SUBSCRIPTION_REVOKED` - Subscription revoked (refund)
    * `SUBSCRIPTION_EXPIRED` - Subscription expired
  """
  def handle_webhook(data) when is_binary(data) do
    with {:ok, decoded} <- Base.decode64(data),
         {:ok, payload} <- Jason.decode(decoded) do
      handle_webhook(payload)
    end
  end

  def handle_webhook(%{"subscriptionNotification" => notification}) do
    notification_type = notification["notificationType"]
    purchase_token = notification["purchaseToken"]

    case notification_type do
      type when type in [2, 4, 7] ->
        with {:ok, subscription_info} <-
               validate_subscription(notification["subscriptionId"], purchase_token) do
          MobileIAP.handle_subscription_renewed(
            purchase_token,
            parse_google_timestamp(subscription_info["expiryTimeMillis"])
          )
        end

      type when type in [3, 10, 12, 13] ->
        MobileIAP.handle_subscription_expired(purchase_token)

      _ ->
        Logger.info("Ignoring Google notification type: #{notification_type}")
        :ok
    end
  end

  def handle_webhook(%{"oneTimeProductNotification" => notification}) do
    Logger.info("Google one-time product notification: #{inspect(notification)}")
    :ok
  end

  def handle_webhook(%{"testNotification" => _}) do
    Logger.info("Google Play test notification received")
    :ok
  end

  def handle_webhook(payload) do
    Logger.warning("Unknown Google Play webhook payload: #{inspect(payload)}")
    :ok
  end

  defp parse_purchase_info(purchase_info, product_id, purchase_token) do
    order_id = purchase_info["orderId"]
    linked_token = purchase_info["linkedPurchaseToken"]

    expires_at =
      case purchase_info["expiryTimeMillis"] do
        nil -> nil
        ms -> parse_google_timestamp(ms)
      end

    is_trial = purchase_info["paymentState"] == 2

    {:ok,
     %{
       transaction_id: order_id || purchase_token,
       original_transaction_id: linked_token || purchase_token,
       product_id: product_id,
       purchase_token: purchase_token,
       expires_at: expires_at,
       is_trial: is_trial
     }}
  end

  defp parse_google_timestamp(nil), do: nil

  defp parse_google_timestamp(ms) when is_binary(ms) do
    ms |> String.to_integer() |> parse_google_timestamp()
  end

  defp parse_google_timestamp(ms) when is_integer(ms) do
    DateTime.from_unix!(div(ms, 1000)) |> DateTime.to_naive()
  end

  defp auth_headers do
    [
      {"Authorization", "Bearer #{get_access_token()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp get_access_token do
    cfg = config()

    {client_email, private_key} =
      if cfg[:service_account_json] do
        json = File.read!(cfg[:service_account_json]) |> Jason.decode!()
        {json["client_email"], json["private_key"]}
      else
        {cfg[:client_email], cfg[:private_key]}
      end

    jwt = generate_google_jwt(client_email, private_key)

    case Req.post(@oauth_token_url,
           form: [
             grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
             assertion: jwt
           ]
         ) do
      {:ok, %{status: 200, body: %{"access_token" => token}}} ->
        token

      {:ok, response} ->
        Logger.error("Failed to get Google access token: #{inspect(response)}")
        raise "Failed to get Google access token"

      {:error, reason} ->
        Logger.error("Google OAuth request failed: #{inspect(reason)}")
        raise "Google OAuth request failed"
    end
  end

  defp generate_google_jwt(client_email, private_key) do
    now = System.system_time(:second)

    header = %{
      "alg" => "RS256",
      "typ" => "JWT"
    }

    payload = %{
      "iss" => client_email,
      "scope" => "https://www.googleapis.com/auth/androidpublisher",
      "aud" => @oauth_token_url,
      "iat" => now,
      "exp" => now + 3600
    }

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)
    signing_input = "#{header_b64}.#{payload_b64}"

    signature =
      signing_input
      |> sign_with_rsa_key(private_key)
      |> Base.url_encode64(padding: false)

    "#{signing_input}.#{signature}"
  end

  defp sign_with_rsa_key(data, private_key_pem) do
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
  def get_subscription_product(purchase_info) do
    purchase_info["productId"]
  end

  @impl true
  def get_subscription_price(_), do: 0

  @impl true
  def get_subscription_cycle(purchase_info) do
    case purchase_info["priceCurrencyCode"] do
      _ -> "month"
    end
  end

  @impl true
  def get_subscription_next_charge(purchase_info) do
    parse_google_timestamp(purchase_info["expiryTimeMillis"])
  end

  @impl true
  def retrieve_subscription(purchase_token) do
    plan_id = MobileIAP.get_product_id_for_plan("personal-monthly")

    if plan_id do
      validate_subscription(plan_id, purchase_token)
    else
      {:error, :unknown_subscription}
    end
  end

  @impl true
  def cancel_subscription(purchase_token) do
    MobileIAP.handle_subscription_expired(purchase_token)
  end

  @impl true
  def cancel_subscription_immediately(purchase_token) do
    cancel_subscription(purchase_token)
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
