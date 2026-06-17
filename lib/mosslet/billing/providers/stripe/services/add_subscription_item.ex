defmodule Mosslet.Billing.Providers.Stripe.Services.AddSubscriptionItem do
  @moduledoc """
  Adds a NEW line item to an EXISTING Stripe subscription (Task #240 / #243,
  Phase B — the one-click custom-subdomain add-on for an already-active org).

  Unlike `CreatePortalSession` (which SWAPS the existing item for a plan switch),
  this appends a brand-new item — `%{price: price_id, quantity: 1}` WITHOUT an
  `id` — to `Stripe.Subscription.update/2`. Stripe treats item maps that carry a
  `price` but no `id` as additions, leaving every existing item (the base plan,
  any seat add-on) untouched. Proration rides the org's existing payment method
  on the next invoice (`create_prorations`), so no second Checkout Session and no
  duplicate subscription are created.

  After Stripe confirms, we re-sync the updated subscription locally so the
  server-authoritative entitlement (`Mosslet.Orgs.has_branding_addon?/1`) flips
  to `true` immediately, without waiting for the `customer.subscription.updated`
  webhook.
  """
  require Logger

  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncSubscription
  alias Mosslet.Billing.Subscriptions.Subscription

  def call(%Subscription{} = subscription, price_id) when is_binary(price_id) do
    case Provider.update_subscription(
           subscription.provider_subscription_id,
           build_params(price_id)
         ) do
      {:ok, %Stripe.Subscription{} = stripe_subscription} ->
        # Re-sync inline so the local row reflects the new line item right away
        # (the webhook is the durable source of truth, this is the fast path).
        SyncSubscription.call(stripe_subscription)
        {:ok, stripe_subscription}

      {:error, error} ->
        Logger.error("Failed to add subscription item #{inspect(price_id)}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Builds the `Stripe.Subscription.update/2` params that APPEND a new line item.

  Pure (no Stripe call) so the add-vs-swap distinction can be unit-tested: the
  item map carries a `price` but deliberately NO `id`, which is what makes Stripe
  add it instead of replacing an existing item.
  """
  def build_params(price_id) when is_binary(price_id) do
    %{
      items: [%{price: price_id, quantity: 1}],
      proration_behavior: "create_prorations"
    }
  end
end
