defmodule Mosslet.Billing.Providers.Stripe.Services.SetSeatQuantity do
  @moduledoc """
  Adjusts the SEAT line-item quantity on an EXISTING Stripe subscription (Task
  #247, Phase B — the one-click owner-only "add seats" flow for an already-active
  org).

  Per-seat plans (Family/Business) bill a base plan line item that includes a
  seat allotment, plus a separate seat ADD-ON line item whose quantity is the
  number of seats beyond that allotment. To change the total seat count we
  therefore set the quantity of the add-on item to `extra_seats` (the target
  total minus the plan's included seats):

    * if the add-on item already exists, we UPDATE it by `id` (mirroring
      `CreatePortalSession`'s by-`id` reference, but a direct
      `Stripe.Subscription.update/2` rather than a Billing Portal hop);
    * if it's ABSENT (the org was sitting at its included seats), we APPEND it
      with `%{price: seat_addon_price, quantity: extra_seats}` and NO `id`
      (mirroring `AddSubscriptionItem`, which is what makes Stripe add rather
      than replace);
    * if `extra_seats` drops to 0, we DELETE the add-on item (`deleted: true`)
      so the org returns cleanly to its included-seat baseline.

  Like the other in-place add-on services this is NOT a new Checkout Session
  (the controller refuses while an active sub exists) and NOT a plan swap.
  Proration rides the org's existing payment method on the next invoice
  (`create_prorations`). After Stripe confirms we re-sync the updated
  subscription locally so `Mosslet.Orgs.seat_cap/1` reflects the new quantity
  immediately, without waiting for the `customer.subscription.updated` webhook.
  """
  require Logger

  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.SyncSubscription
  alias Mosslet.Billing.Subscriptions.Subscription

  def call(%Subscription{} = subscription, seat_addon_price, extra_seats)
      when is_binary(seat_addon_price) and is_integer(extra_seats) and extra_seats >= 0 do
    with {:ok, %Stripe.Subscription{} = stripe_subscription} <-
           Provider.retrieve_subscription(subscription.provider_subscription_id) do
      item_id = seat_item_id(stripe_subscription, seat_addon_price)
      params = build_params(seat_addon_price, item_id, extra_seats)

      case Provider.update_subscription(subscription.provider_subscription_id, params) do
        {:ok, %Stripe.Subscription{} = updated} ->
          # Re-sync inline so the local seat quantity reflects the change right
          # away (the webhook remains the durable source of truth).
          SyncSubscription.call(updated)
          {:ok, updated}

        {:error, error} ->
          Logger.error(
            "Failed to set seat quantity (#{extra_seats} add-on seats): #{inspect(error)}"
          )

          {:error, error}
      end
    else
      {:error, error} ->
        Logger.error("Failed to retrieve subscription for seat update: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Builds the `Stripe.Subscription.update/2` params for the seat add-on item.

  Pure (no Stripe call) so the add-vs-update-vs-delete distinction can be
  unit-tested:

    * `item_id` present, `extra_seats > 0` -> UPDATE the existing item's quantity
      (carries `id`);
    * `item_id` present, `extra_seats == 0` -> DELETE the item (`deleted: true`),
      returning the org to its included-seat baseline;
    * `item_id` nil, `extra_seats > 0` -> APPEND a new item (`price`, NO `id`),
      which is what makes Stripe add it;
    * `item_id` nil, `extra_seats == 0` -> no-op (nothing to add or remove).

  Proration always rides the existing payment method's next invoice.
  """
  def build_params(seat_addon_price, item_id, extra_seats)

  def build_params(_seat_addon_price, item_id, extra_seats)
      when is_binary(item_id) and extra_seats > 0 do
    %{
      items: [%{id: item_id, quantity: extra_seats}],
      proration_behavior: "create_prorations"
    }
  end

  def build_params(_seat_addon_price, item_id, 0) when is_binary(item_id) do
    %{
      items: [%{id: item_id, deleted: true}],
      proration_behavior: "create_prorations"
    }
  end

  def build_params(seat_addon_price, nil, extra_seats)
      when is_binary(seat_addon_price) and extra_seats > 0 do
    %{
      items: [%{price: seat_addon_price, quantity: extra_seats}],
      proration_behavior: "create_prorations"
    }
  end

  def build_params(_seat_addon_price, nil, 0) do
    %{items: [], proration_behavior: "create_prorations"}
  end

  # The id of the live Stripe subscription's seat add-on line item (matched by
  # price), or nil when the org is sitting at its included seats (no add-on item
  # yet). Used to decide update-vs-append.
  defp seat_item_id(%Stripe.Subscription{items: %{data: data}}, seat_addon_price) do
    data
    |> Enum.find(fn item -> item.price.id == seat_addon_price end)
    |> case do
      nil -> nil
      item -> item.id
    end
  end
end
