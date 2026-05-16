defmodule Mosslet.Billing.Providers.Stripe.Services.SyncCustomer do
  @moduledoc false
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncPaymentIntent

  def call(customer) do
    # provider_customer_id is now Cloak-only — read directly
    {:ok, %{data: stripe_payment_intents}} =
      Provider.list_payment_intents(%{customer: customer.provider_customer_id})

    Enum.each(stripe_payment_intents, fn stripe_payment_intent ->
      SyncPaymentIntent.call(stripe_payment_intent)
    end)

    :ok
  end
end
