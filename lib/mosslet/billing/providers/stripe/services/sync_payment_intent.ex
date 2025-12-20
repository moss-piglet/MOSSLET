defmodule Mosslet.Billing.Providers.Stripe.Services.SyncPaymentIntent do
  @moduledoc """
  Syncs a Stripe payment_intent with the local database.
  Stripe is the source of truth.
  Use it when a payment_intent has been updated on Stripe and needs to be synced locally.
  PaymentIntent type: https://hexdocs.pm/stripity_stripe/Stripe.PaymentIntent.html#t:t/0
  """
  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Providers.Stripe.Adapters.PaymentIntentAdapter
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.PaymentIntents.PaymentIntent
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  require Logger

  def call(%Stripe.PaymentIntent{} = stripe_payment_intent) do
    if stripe_payment_intent.invoice do
      Logger.debug(
        "Skipping payment intent #{stripe_payment_intent.id} - associated with invoice #{stripe_payment_intent.invoice}"
      )

      :ok
    else
      sync_payment_intent(stripe_payment_intent)
    end
  end

  defp sync_payment_intent(%Stripe.PaymentIntent{} = stripe_payment_intent) do
    with {:customer, %Customer{} = customer} <-
           {:customer,
            Customers.get_customer_by_provider_customer_id!(stripe_payment_intent.customer)},
         {:source, _source} <-
           {:source, get_source(customer)} do
      payment_intent_attrs =
        stripe_payment_intent
        |> PaymentIntentAdapter.attrs_from_stripe_payment_intent()
        |> Map.put(:billing_customer_id, customer.id)

      result =
        case PaymentIntents.get_payment_intent_by_provider_payment_intent_id(
               stripe_payment_intent.id
             ) do
          nil ->
            case PaymentIntents.create_payment_intent!(payment_intent_attrs) do
              {:ok, _payment_intent} ->
                :ok

              rest ->
                Logger.warning("Error creating payment intent")
                Logger.debug("Error creating payment intent: #{inspect(rest)}")
                :ok
            end

          %PaymentIntent{} = payment_intent ->
            case PaymentIntents.update_payment_intent(payment_intent, payment_intent_attrs) do
              {:ok, _payment_intent} ->
                :ok

              rest ->
                Logger.warning("Error updating payment intent")
                Logger.debug("Error updating payment intent: #{inspect(rest)}")
                :ok
            end

          {:ok, payment_intent} ->
            case PaymentIntents.update_payment_intent(payment_intent, payment_intent_attrs) do
              {:ok, _payment_intent} ->
                :ok

              rest ->
                Logger.warning("Error updating payment intent")
                Logger.debug("Error updating payment intent: #{inspect(rest)}")
                :ok
            end
        end

      if stripe_payment_intent.status == "succeeded" do
        cancel_active_subscription(customer)
      end

      result
    else
      error -> {:error, error}
    end
  end

  defp cancel_active_subscription(%Customer{id: customer_id}) do
    case Subscriptions.get_active_subscription_by_customer_id(customer_id) do
      nil ->
        :ok

      subscription ->
        Logger.info(
          "Canceling subscription #{subscription.provider_subscription_id} for customer #{customer_id} due to lifetime purchase"
        )

        case Provider.cancel_subscription(subscription.provider_subscription_id) do
          {:ok, _} ->
            Subscriptions.cancel_subscription(subscription)
            :ok

          {:error, error} ->
            Logger.error(
              "Failed to cancel subscription #{subscription.provider_subscription_id}: #{inspect(error)}"
            )

            :ok
        end
    end
  end

  defp get_source(%Customer{org_id: nil, user_id: user_id}) do
    Accounts.get_user!(user_id)
  end

  defp get_source(%Customer{org_id: org_id}) do
    Orgs.get_org_by_id(org_id)
  end
end
