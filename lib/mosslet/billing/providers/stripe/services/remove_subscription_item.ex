defmodule Mosslet.Billing.Providers.Stripe.Services.RemoveSubscriptionItem do
  @moduledoc """
  Removes a line item from an EXISTING Stripe subscription (Task #240, Phase B —
  releasing the custom-subdomain add-on so the org stops paying for it).

  The inverse of `AddSubscriptionItem`: we locate the live subscription item
  whose `price.id` matches the add-on price and mark it `%{id: item_id, deleted:
  true}` in `Stripe.Subscription.update/2`. Every other item (the base plan, any
  seat add-on) is left untouched. Proration rides the org's existing payment
  method on the next invoice (`create_prorations`), so releasing the add-on
  credits the unused remainder toward the upcoming monthly/annual bill — no
  Checkout Session, no plan swap.

  Idempotent: if the add-on item is ABSENT (already removed / never present), we
  do NOT call Stripe and return `{:ok, :not_present}` so callers can release the
  subdomain cleanly either way.

  After Stripe confirms we re-sync the updated subscription locally so the
  server-authoritative entitlement (`Mosslet.Orgs.has_branding_addon?/1`) flips
  to `false` immediately, without waiting for the `customer.subscription.updated`
  webhook.
  """
  require Logger

  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncSubscription
  alias Mosslet.Billing.Subscriptions.Subscription

  def call(%Subscription{} = subscription, price_id) when is_binary(price_id) do
    with {:ok, %Stripe.Subscription{} = stripe_subscription} <-
           Provider.retrieve_subscription(subscription.provider_subscription_id) do
      case item_id(stripe_subscription, price_id) do
        nil ->
          # Nothing to remove — keep this best-effort/idempotent so the caller
          # can still clear the subdomain.
          {:ok, :not_present}

        id ->
          case Provider.update_subscription(
                 subscription.provider_subscription_id,
                 build_params(id)
               ) do
            {:ok, %Stripe.Subscription{} = updated} ->
              # Re-sync inline so the local row drops the line item right away
              # (the webhook remains the durable source of truth).
              SyncSubscription.call(updated)
              {:ok, updated}

            {:error, error} ->
              Logger.error(
                "Failed to remove subscription item #{inspect(price_id)}: #{inspect(error)}"
              )

              {:error, error}
          end
      end
    else
      {:error, error} ->
        Logger.error("Failed to retrieve subscription for item removal: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Builds the `Stripe.Subscription.update/2` params that DELETE a line item by id.

  Pure (no Stripe call) so the deletion can be unit-tested. Proration always
  rides the existing payment method's next invoice.
  """
  def build_params(item_id) when is_binary(item_id) do
    %{
      items: [%{id: item_id, deleted: true}],
      proration_behavior: "create_prorations"
    }
  end

  # The id of the live Stripe subscription's line item matching `price_id`, or
  # nil when it's not present.
  defp item_id(%Stripe.Subscription{items: %{data: data}}, price_id) do
    data
    |> Enum.find(fn item -> item.price.id == price_id end)
    |> case do
      nil -> nil
      item -> item.id
    end
  end
end
