defmodule Mosslet.Billing.Providers.Stripe.Workers.SubscriptionSyncWorker do
  @moduledoc """
  Handle the Stripe webhook event: "customer.subscription.*"
  Stripe Subscription fields: https://hexdocs.pm/stripity_stripe/Stripe.Subscription.html#t:t/0
  """
  use Oban.Worker, queue: :default

  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncSubscription

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider_subscription_id" => provider_subscription_id}}) do
    Logger.info("#{__MODULE__} running...")

    case Provider.retrieve_subscription(provider_subscription_id) do
      {:ok, stripe_subscription} ->
        SyncSubscription.call(stripe_subscription)

      {:error, error} ->
        raise("Error fetching the stripe subscription.\n\n #{inspect(error)}")
    end
  end
end
