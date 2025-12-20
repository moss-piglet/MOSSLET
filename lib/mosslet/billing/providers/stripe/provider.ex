defmodule Mosslet.Billing.Providers.Stripe.Provider do
  @moduledoc """
  An interface to the Stripe API.

  Use this instead of StripityStripe directly because it allows you to mock responses in tests (thanks to mox).

  For example:

      alias Mosslet.Billing.Providers.Stripe.Provider

      expect(Provider, :create_checkout_session, fn _ ->
        mocked_session_response()
      end)
  """
  # alias Mosslet.Billing.Providers.Stripe
  @behaviour Mosslet.Billing.Providers.Stripe.ProviderBehaviour

  @impl true
  def create_customer(params) do
    Stripe.Customer.create(params)
  end

  @impl true
  def retrieve_customer(customer_id) do
    Stripe.Customer.retrieve(customer_id)
  end

  @impl true
  def create_portal_session(params) do
    Stripe.BillingPortal.Session.create(params)
  end

  @impl true
  def create_checkout_session(params) do
    Stripe.Checkout.Session.create(params)
  end

  @impl true
  def retrieve_product(stripe_product_id) do
    Stripe.Product.retrieve(stripe_product_id)
  end

  @impl true
  def retrieve_charge(provider_charge_id) do
    Stripe.Charge.retrieve(provider_charge_id)
  end

  @impl true
  def retrieve_payment_intent(provider_payment_intent_id) do
    Stripe.PaymentIntent.retrieve(provider_payment_intent_id)
  end

  @impl true
  def list_charges(customer_id) do
    Stripe.Charge.list(%{customer: customer_id})
  end

  @impl true
  def list_subscriptions(params) do
    Stripe.Subscription.list(params)
  end

  @impl true
  def list_payment_intents(params) do
    Stripe.PaymentIntent.list(params)
  end

  @impl true
  def retrieve_subscription(provider_subscription_id) do
    Stripe.Subscription.retrieve(provider_subscription_id)
  end

  @impl true
  def cancel_subscription(id) do
    Stripe.Subscription.update(id, %{cancel_at_period_end: true})
  end

  @impl true
  def cancel_subscription_immediately(id) do
    Stripe.Subscription.cancel(id)
  end

  @impl true
  def resume_subscription(id) do
    Stripe.Subscription.update(id, %{cancel_at_period_end: false})
  end

  @impl true
  def upcoming_invoice(params) do
    Stripe.Invoice.upcoming(params)
  end

  @impl true
  def list_invoices(params) do
    Stripe.Invoice.list(params)
  end
end
