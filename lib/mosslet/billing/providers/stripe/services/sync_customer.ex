defmodule Mosslet.Billing.Providers.Stripe.Services.SyncCustomer do
  @moduledoc false
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncPaymentIntent

  def call(customer, user, session_key) do
    {:ok, %{data: stripe_payment_intents}} =
      Provider.list_payment_intents(
        MossletWeb.Helpers.maybe_decrypt_user_data(
          %{customer: customer.provider_customer_id},
          user,
          session_key
        )
      )

    Enum.each(stripe_payment_intents, fn stripe_payment_intent ->
      SyncPaymentIntent.call(stripe_payment_intent)
    end)

    :ok
  end
end
