defmodule Mosslet.Billing.Providers.Stripe.Adapters.PaymentIntentAdapter do
  @moduledoc """
  This module is responsible for converting a Stripe PaymentIntent into attrs
  matching the Mosslet.Billing.PaymentIntents.PaymentIntent struct.
  """
  alias Mosslet.Billing.Customers

  def attrs_from_stripe_payment_intent(stripe_payment_intent) do
    attrs = %{
      provider_payment_intent_id: stripe_payment_intent.id,
      provider_customer_id: stripe_payment_intent.customer,
      provider_latest_charge_id: stripe_payment_intent.latest_charge,
      provider_payment_method_id: stripe_payment_intent.payment_method,
      amount: stripe_payment_intent.amount,
      amount_received: stripe_payment_intent.amount_received,
      status: stripe_payment_intent.status
    }

    attrs
    |> Util.maybe_put(:provider_created_at, created_at(stripe_payment_intent))
    |> Util.maybe_put(
      :billing_customer_id,
      Customers.get_customer_by_provider_customer_id!(stripe_payment_intent.customer).id
    )
  end

  def created_at(stripe_payment_intent),
    do: Util.unix_to_naive_datetime(stripe_payment_intent.created)
end
