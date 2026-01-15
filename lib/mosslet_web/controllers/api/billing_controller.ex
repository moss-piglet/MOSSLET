defmodule MossletWeb.API.BillingController do
  @moduledoc """
  API endpoints for mobile in-app purchase validation.

  Mobile apps (iOS/Android) submit purchase receipts here after completing
  a purchase via StoreKit 2 (iOS) or Google Play Billing (Android).

  ## Endpoints

    * `POST /api/billing/apple/validate` - Validate Apple IAP purchase
    * `POST /api/billing/google/validate` - Validate Google Play purchase
    * `GET /api/billing/subscription` - Get current subscription status
    * `GET /api/billing/products` - Get available products for mobile
  """

  use MossletWeb, :controller

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Providers.AppleIAP
  alias Mosslet.Billing.Providers.GooglePlay
  alias Mosslet.Billing.Providers.MobileIAP

  action_fallback MossletWeb.API.FallbackController

  @doc """
  Validates an Apple In-App Purchase and creates/updates subscription.

  ## Parameters

    * `transaction_id` - The StoreKit 2 transactionId

  ## Response

    * `200` - `{subscription: %{id, status, plan_id, expires_at}}`
    * `400` - Invalid request
    * `401` - Unauthorized
    * `422` - Validation failed
  """
  def validate_apple(conn, %{"transaction_id" => transaction_id}) do
    user = conn.assigns.current_user
    session_key = conn.assigns[:session_key]

    case AppleIAP.validate_and_process_purchase(user, transaction_id, session_key) do
      {:ok, subscription_or_payment} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: serialize_billing_result(subscription_or_payment)
        })

      {:error, :unknown_product} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "unknown_product", message: "Product ID not recognized"})

      {:error, {:apple_error, status, body}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "apple_validation_failed", status: status, details: body})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", message: inspect(reason)})
    end
  end

  def validate_apple(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_parameter", message: "transaction_id is required"})
  end

  @doc """
  Validates a Google Play purchase and creates/updates subscription.

  ## Parameters

    * `product_id` - The Google Play product ID (SKU)
    * `purchase_token` - The purchaseToken from Google Play
    * `is_subscription` - (optional) true for subscriptions, false for one-time

  ## Response

    * `200` - `{subscription: %{id, status, plan_id, expires_at}}`
    * `400` - Invalid request
    * `401` - Unauthorized
    * `422` - Validation failed
  """
  def validate_google(
        conn,
        %{"product_id" => product_id, "purchase_token" => purchase_token} = params
      ) do
    user = conn.assigns.current_user
    session_key = conn.assigns[:session_key]
    is_subscription = Map.get(params, "is_subscription", true)

    case GooglePlay.validate_and_process_purchase(
           user,
           product_id,
           purchase_token,
           session_key,
           is_subscription: is_subscription
         ) do
      {:ok, subscription_or_payment} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: serialize_billing_result(subscription_or_payment)
        })

      {:error, :unknown_product} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "unknown_product", message: "Product ID not recognized"})

      {:error, {:google_error, status, body}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "google_validation_failed", status: status, details: body})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", message: inspect(reason)})
    end
  end

  def validate_google(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_parameter", message: "product_id and purchase_token are required"})
  end

  @doc """
  Gets the current user's subscription status.

  ## Response

    * `200` - `{has_subscription: bool, subscription: %{...} | nil, payment_intent: %{...} | nil}`
  """
  def subscription_status(conn, _params) do
    user = conn.assigns.current_user
    source = Customers.entity()
    source_id = get_source_id(user, source)

    {subscription, payment_intent} =
      case Customers.get_customer_by_source(source, source_id) do
        nil ->
          {nil, nil}

        customer ->
          sub = Subscriptions.get_active_subscription_by_customer_id(customer.id)
          pi = PaymentIntents.get_active_payment_intent_by_customer_id(customer.id)
          {sub, pi}
      end

    has_access = subscription != nil or payment_intent != nil

    conn
    |> put_status(:ok)
    |> json(%{
      has_subscription: has_access,
      subscription: subscription && serialize_subscription(subscription),
      payment_intent: payment_intent && serialize_payment_intent(payment_intent)
    })
  end

  @doc """
  Gets available products for mobile apps.

  Returns products with their mobile product IDs for StoreKit/Google Play.

  ## Response

    * `200` - `{products: [%{id, mobile_product_id, name, interval, amount}]}`
  """
  def products(conn, _params) do
    products =
      Mosslet.Billing.Plans.plans()
      |> Enum.map(fn plan ->
        mobile_product_id = MobileIAP.get_product_id_for_plan(plan.id)

        %{
          id: plan.id,
          mobile_product_id: mobile_product_id,
          name: plan[:name] || plan.id,
          interval: plan.interval,
          amount: plan.amount,
          trial_days: plan[:trial_days]
        }
      end)
      |> Enum.filter(fn p -> p.mobile_product_id != nil end)

    conn
    |> put_status(:ok)
    |> json(%{products: products})
  end

  @doc """
  Restores purchases for a user.

  Called when user reinstalls app or signs in on new device.
  Verifies ownership of purchases with Apple/Google and syncs subscription status.

  ## Parameters

    * `platform` - "apple" or "google"
    * `transactions` - List of transaction IDs (Apple) or purchase tokens (Google)

  ## Response

    * `200` - `{restored: count, subscription: %{...} | nil}`
  """
  def restore_purchases(conn, %{"platform" => "apple", "transactions" => transactions})
      when is_list(transactions) do
    user = conn.assigns.current_user
    session_key = conn.assigns[:session_key]

    results =
      Enum.map(transactions, fn transaction_id ->
        AppleIAP.validate_and_process_purchase(user, transaction_id, session_key)
      end)

    successful = Enum.filter(results, &match?({:ok, _}, &1))

    latest_subscription =
      successful
      |> Enum.map(fn {:ok, sub} -> sub end)
      |> Enum.filter(&is_struct(&1, Mosslet.Billing.Subscriptions.Subscription))
      |> Enum.sort_by(& &1.current_period_end_at, {:desc, NaiveDateTime})
      |> List.first()

    conn
    |> put_status(:ok)
    |> json(%{
      restored: length(successful),
      subscription: latest_subscription && serialize_subscription(latest_subscription)
    })
  end

  def restore_purchases(conn, %{"platform" => "google", "purchases" => purchases})
      when is_list(purchases) do
    user = conn.assigns.current_user
    session_key = conn.assigns[:session_key]

    results =
      Enum.map(purchases, fn %{"product_id" => product_id, "purchase_token" => token} = purchase ->
        is_subscription = Map.get(purchase, "is_subscription", true)

        GooglePlay.validate_and_process_purchase(
          user,
          product_id,
          token,
          session_key,
          is_subscription: is_subscription
        )
      end)

    successful = Enum.filter(results, &match?({:ok, _}, &1))

    latest_subscription =
      successful
      |> Enum.map(fn {:ok, sub} -> sub end)
      |> Enum.filter(&is_struct(&1, Mosslet.Billing.Subscriptions.Subscription))
      |> Enum.sort_by(& &1.current_period_end_at, {:desc, NaiveDateTime})
      |> List.first()

    conn
    |> put_status(:ok)
    |> json(%{
      restored: length(successful),
      subscription: latest_subscription && serialize_subscription(latest_subscription)
    })
  end

  def restore_purchases(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_request", message: "platform and transactions/purchases required"})
  end

  defp get_source_id(user, :user), do: user.id
  defp get_source_id(user, :org), do: user.org_id

  defp serialize_billing_result(%Mosslet.Billing.Subscriptions.Subscription{} = sub) do
    %{type: "subscription", subscription: serialize_subscription(sub)}
  end

  defp serialize_billing_result(%Mosslet.Billing.PaymentIntents.PaymentIntent{} = pi) do
    %{type: "payment_intent", payment_intent: serialize_payment_intent(pi)}
  end

  defp serialize_subscription(sub) do
    %{
      id: sub.id,
      status: sub.status,
      plan_id: sub.plan_id,
      current_period_start: sub.current_period_start,
      current_period_end_at: sub.current_period_end_at,
      cancel_at: sub.cancel_at,
      canceled_at: sub.canceled_at
    }
  end

  defp serialize_payment_intent(pi) do
    %{
      id: pi.id,
      status: pi.status,
      amount: pi.amount,
      amount_received: pi.amount_received,
      created_at: pi.provider_created_at
    }
  end
end
