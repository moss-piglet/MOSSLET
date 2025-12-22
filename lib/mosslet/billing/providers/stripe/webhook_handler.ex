defmodule Mosslet.Billing.Providers.Stripe.WebhookHandler do
  @moduledoc """
  A plug in endpoint.ex forwards Stripe webhooks to here (Stripe.WebhookPlug)
  """

  @behaviour Stripe.WebhookHandler

  require Logger
  require Protocol

  @doc """
  Handle Stripe events here.

  This event is called when a subscription is created, updated, canceled.
  This could have happened from a user/org in a Stripe-hosted portal or by a site admin from the Stripe dashboard.

  Created is triggered for trial subscription only.
  Both Created and Updated are triggered for all other subscriptions.

  This means for a non-trial subscription, sync will be called twice, but given
  how sync works, the second call has no side effect.

  List of all Stripe events: https://stripe.com/docs/api/events/types
  """
  @impl true
  def handle_event(%Stripe.Event{type: "customer.subscription.created", data: %{object: object}}) do
    %{provider_subscription_id: object.id}
    |> Mosslet.Billing.Providers.Stripe.Workers.SubscriptionSyncWorker.new()
    |> Oban.insert()
  end

  @impl true
  def handle_event(%Stripe.Event{type: "customer.subscription.updated", data: %{object: object}}) do
    %{provider_subscription_id: object.id}
    |> Mosslet.Billing.Providers.Stripe.Workers.SubscriptionSyncWorker.new()
    |> Oban.insert()
  end

  @impl true
  def handle_event(%Stripe.Event{type: "customer.subscription.deleted", data: %{object: object}}) do
    %{provider_subscription_id: object.id}
    |> Mosslet.Billing.Providers.Stripe.Workers.SubscriptionSyncWorker.new()
    |> Oban.insert()
  end

  @impl true
  def handle_event(%Stripe.Event{type: "payment_intent.succeeded", data: %{object: object}}) do
    %{provider_payment_intent_id: object.id}
    |> Mosslet.Billing.Providers.Stripe.Workers.PaymentIntentSyncWorker.new()
    |> Oban.insert()

    unless object.invoice do
      %{
        provider_payment_intent_id: object.id,
        provider_customer_id: object.customer,
        amount: object.amount_received
      }
      |> Mosslet.Billing.Workers.OneTimePaymentCommissionWorker.new()
      |> Oban.insert()
    end

    :ok
  end

  @impl true
  def handle_event(%Stripe.Event{type: "invoice.paid", data: %{object: invoice}}) do
    if invoice.subscription do
      %{
        stripe_invoice_id: invoice.id,
        stripe_subscription_id: invoice.subscription,
        amount_paid: invoice.amount_paid,
        period_start: invoice.period_start,
        period_end: invoice.period_end
      }
      |> Mosslet.Billing.Workers.ReferralCommissionWorker.new()
      |> Oban.insert()
    end

    :ok
  end

  @impl true
  def handle_event(%Stripe.Event{type: "account.updated", data: %{object: account}}) do
    if account.charges_enabled && account.payouts_enabled do
      Logger.info("Stripe Connect account #{account.id} onboarding complete")
      Mosslet.Billing.Referrals.mark_connect_onboarding_complete(account.id)
    end

    :ok
  end

  @impl true
  def handle_event(%Stripe.Event{type: "customer.deleted", data: %{object: object}}) do
    Mosslet.Billing.Customers.delete_customer_by_provider_customer_id(object.id)
    :ok
  end

  def handle_event(_), do: :ok
end
