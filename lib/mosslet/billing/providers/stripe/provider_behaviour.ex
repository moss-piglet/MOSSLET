defmodule Mosslet.Billing.Providers.Stripe.ProviderBehaviour do
  @moduledoc false
  @type params :: map()
  @type id :: Stripe.id()
  @type customer :: Stripe.Customer.t()
  @type session :: Stripe.Checkout.Session.t()
  @type product :: Stripe.Product.t()
  @type subscription :: Stripe.Subscription.t()
  @type charge :: Stripe.Charge.t()
  @type payment_intent :: Stripe.PaymentIntent.t()
  @type error :: Stripe.Error.t()

  @callback create_customer(params) :: {:ok, customer} | {:error, error}
  @callback retrieve_customer(id) :: {:ok, customer} | {:error, error}
  @callback create_portal_session(params) :: {:ok, session} | {:error, error}
  @callback create_checkout_session(params) :: {:ok, session} | {:error, error}
  @callback retrieve_product(id) :: {:ok, product} | {:error, error}
  @callback retrieve_charge(id) :: {:ok, charge} | {:error, error}
  @callback retrieve_payment_intent(id) :: {:ok, payment_intent} | {:error, error}
  @callback list_charges(id) :: {:ok, [charge]} | {:error, error}
  @callback list_subscriptions(params) :: {:ok, product} | {:error, error}
  @callback list_payment_intents(params) :: {:ok, [payment_intent]} | {:error, error}
  @callback retrieve_subscription(id) :: {:ok, subscription} | {:error, error}
  @callback cancel_subscription(id) :: {:ok, subscription} | {:error, error}
  @callback cancel_subscription_immediately(id) :: {:ok, subscription} | {:error, error}
  @callback resume_subscription(id) :: {:ok, subscription} | {:error, error}
  @callback upcoming_invoice(params) :: {:ok, Stripe.Invoice.t()} | {:error, error}
  @callback list_invoices(params) :: {:ok, Stripe.List.t(Stripe.Invoice.t())} | {:error, error}
end
