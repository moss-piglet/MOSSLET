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
  def perform(%Oban.Job{
        args: %{"provider_subscription_id" => provider_subscription_id},
        attempt: attempt
      }) do
    Logger.info("#{__MODULE__} running...")

    case Provider.retrieve_subscription(provider_subscription_id) do
      {:ok, stripe_subscription} ->
        handle_sync(SyncSubscription.call(stripe_subscription), provider_subscription_id, attempt)

      {:error, error} ->
        raise("Error fetching the stripe subscription.\n\n #{inspect(error)}")
    end
  end

  # No local billing customer for the subscription's Stripe customer. This is
  # normally a brief race (webhook arriving before the customer commit), so we
  # snooze a few times to let it settle. If it still isn't there, the customer
  # was almost certainly removed (e.g. an org reclaimed mid-checkout, Task #348)
  # and will never appear — cancel cleanly instead of crash-looping to
  # `max_attempts`.
  defp handle_sync({:error, :customer_not_found}, subscription_id, attempt)
       when attempt < 5 do
    Logger.warning(
      "No local billing customer yet for subscription #{subscription_id} " <>
        "(attempt #{attempt}); snoozing."
    )

    {:snooze, 15}
  end

  defp handle_sync({:error, :customer_not_found}, subscription_id, _attempt) do
    Logger.error(
      "No local billing customer for subscription #{subscription_id} after retries; " <>
        "giving up (customer likely removed)."
    )

    {:cancel, :customer_not_found}
  end

  defp handle_sync(:ok, _subscription_id, _attempt), do: :ok
  defp handle_sync({:error, _} = error, _subscription_id, _attempt), do: error
end
