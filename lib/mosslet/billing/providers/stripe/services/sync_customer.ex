defmodule Mosslet.Billing.Providers.Stripe.Services.SyncCustomer do
  @moduledoc false
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncPaymentIntent

  require Logger

  def call(customer, user, session_key) do
    Logger.info("Syncing customer #{customer.id}...")

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

    Logger.info(
      "Customer #{customer.id}: #{length(stripe_payment_intents)} payment_intents found and synced."
    )

    :ok
  end
end
