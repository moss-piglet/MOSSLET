defmodule Mosslet.Billing.Providers.MobileIAP do
  @moduledoc """
  Shared utilities for mobile in-app purchase providers (Apple IAP and Google Play).

  Mobile billing works differently from Stripe:
  1. User purchases in native app via StoreKit (iOS) or Google Play Billing (Android)
  2. Native app receives purchase token/receipt
  3. Native app sends token to our API for validation
  4. Server validates with Apple/Google and creates/updates subscription

  Unlike Stripe, there's no "checkout URL" - the purchase happens entirely
  in the native app UI provided by Apple/Google.
  """

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Subscriptions.Subscription
  alias Mosslet.Billing.PaymentIntents

  @type receipt_data :: %{
          required(:transaction_id) => String.t(),
          required(:product_id) => String.t(),
          required(:purchase_token) => String.t(),
          optional(:original_transaction_id) => String.t(),
          optional(:expires_at) => DateTime.t(),
          optional(:is_trial) => boolean()
        }

  @doc """
  Map Apple/Google product IDs to our internal plan IDs.

  Configure in config.exs:
    config :mosslet, :mobile_product_mapping, %{
      "com.mosslet.personal.monthly" => "personal-monthly",
      "com.mosslet.personal.yearly" => "personal-yearly",
      "com.mosslet.personal.lifetime" => "personal-lifetime"
    }
  """
  def get_plan_id_for_product(product_id) do
    mapping = Mosslet.config(:mobile_product_mapping) || %{}
    Map.get(mapping, product_id)
  end

  @doc """
  Reverse mapping: get mobile product ID from our plan ID.
  """
  def get_product_id_for_plan(plan_id) do
    mapping = Mosslet.config(:mobile_product_mapping) || %{}

    mapping
    |> Enum.find(fn {_product_id, internal_id} -> internal_id == plan_id end)
    |> case do
      {product_id, _} -> product_id
      nil -> nil
    end
  end

  @doc """
  Creates or updates a subscription based on validated receipt data.

  This is called after the provider (Apple/Google) validates the receipt.
  """
  def process_validated_receipt(user, receipt_data, provider, session_key) do
    plan_id = get_plan_id_for_product(receipt_data.product_id)

    unless plan_id do
      {:error, :unknown_product}
    else
      plan = Mosslet.Billing.Plans.get_plan_by_id(plan_id)
      source = Customers.entity()
      source_id = get_source_id(user, source)

      with {:ok, customer} <-
             find_or_create_customer(user, source, source_id, provider, session_key) do
        if plan && plan.interval == :one_time do
          create_payment_intent(customer, receipt_data, plan_id, user, session_key)
        else
          create_or_update_subscription(customer, receipt_data, plan_id, user, session_key)
        end
      end
    end
  end

  defp get_source_id(user, :user), do: user.id
  defp get_source_id(user, :org), do: user.org_id

  defp find_or_create_customer(user, source, source_id, provider, session_key) do
    case Customers.get_customer_by_source(source, source_id) do
      %Customer{} = customer ->
        {:ok, customer}

      nil ->
        Customers.create_customer_for_source(
          source,
          source_id,
          %{
            email: user.email,
            provider: Atom.to_string(provider),
            provider_customer_id: "#{provider}_#{user.id}"
          },
          user,
          session_key
        )
    end
  end

  defp create_or_update_subscription(customer, receipt_data, plan_id, _user, _session_key) do
    transaction_id = receipt_data.original_transaction_id || receipt_data.transaction_id

    case Subscriptions.get_subscription_by(%{provider_subscription_id_hash: transaction_id}) do
      %Subscription{} = subscription ->
        Subscriptions.update_subscription(subscription, %{
          status: subscription_status(receipt_data),
          current_period_end_at: receipt_data[:expires_at],
          cancel_at: nil
        })

      nil ->
        Subscriptions.create_subscription(%{
          billing_customer_id: customer.id,
          plan_id: plan_id,
          status: subscription_status(receipt_data),
          provider_subscription_id: transaction_id,
          provider_subscription_items: [%{product_id: receipt_data.product_id}],
          current_period_start: DateTime.utc_now() |> DateTime.to_naive(),
          current_period_end_at: receipt_data[:expires_at]
        })
    end
  end

  defp create_payment_intent(customer, receipt_data, plan_id, user, session_key) do
    plan = Mosslet.Billing.Plans.get_plan_by_id!(plan_id)

    PaymentIntents.create_payment_intent!(
      %{
        billing_customer_id: customer.id,
        provider_payment_intent_id: receipt_data.transaction_id,
        provider_customer_id: customer.id,
        provider_latest_charge_id: receipt_data.transaction_id,
        provider_payment_method_id: receipt_data.purchase_token,
        provider_created_at: DateTime.utc_now(),
        amount: plan.amount,
        amount_received: plan.amount,
        status: "succeeded"
      },
      user,
      session_key
    )
  end

  defp subscription_status(receipt_data) do
    cond do
      receipt_data[:is_trial] -> "trialing"
      true -> "active"
    end
  end

  @doc """
  Determines if a subscription/purchase is still valid based on expiration.
  """
  def is_valid_subscription?(nil), do: false

  def is_valid_subscription?(%Subscription{} = sub) do
    sub.status in ["active", "trialing"] and
      (is_nil(sub.current_period_end_at) or
         NaiveDateTime.compare(sub.current_period_end_at, NaiveDateTime.utc_now()) == :gt)
  end

  @doc """
  Handles subscription expiration/cancellation from Apple/Google server notifications.
  """
  def handle_subscription_expired(transaction_id) do
    case Subscriptions.get_subscription_by(%{provider_subscription_id_hash: transaction_id}) do
      %Subscription{} = subscription ->
        Subscriptions.update_subscription(subscription, %{
          status: "expired",
          canceled_at: NaiveDateTime.utc_now()
        })

      nil ->
        {:error, :subscription_not_found}
    end
  end

  @doc """
  Handles subscription renewal from Apple/Google server notifications.
  """
  def handle_subscription_renewed(transaction_id, new_expires_at) do
    case Subscriptions.get_subscription_by(%{provider_subscription_id_hash: transaction_id}) do
      %Subscription{} = subscription ->
        Subscriptions.update_subscription(subscription, %{
          status: "active",
          current_period_end_at: new_expires_at,
          cancel_at: nil
        })

      nil ->
        {:error, :subscription_not_found}
    end
  end
end
