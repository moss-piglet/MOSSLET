defmodule Mosslet.Billing.Providers.Stripe.Workers.PaymentIntentSyncWorker do
  @moduledoc """
  Handle the Stripe webhook event: "payment_intent.succeeded"
  """
  use Oban.Worker, queue: :default

  alias Mosslet.Billing.Providers.Stripe.Services.SyncPaymentIntent

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider_payment_intent_id" => provider_payment_intent_id}}) do
    Logger.info("#{__MODULE__} running...")

    case Stripe.PaymentIntent.retrieve(provider_payment_intent_id) do
      {:ok, stripe_payment_intent} ->
        SyncPaymentIntent.call(stripe_payment_intent)

      {:error, error} ->
        raise("Error fetching the stripe payment_intent.\n\n #{inspect(error)}")
    end
  end
end
