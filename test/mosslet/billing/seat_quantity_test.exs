defmodule Mosslet.Billing.SeatQuantityTest do
  @moduledoc """
  Task #247 (Phase B): the one-click owner-only ADD-SEATS flow. Verifies
  `Mosslet.Billing.Providers.Stripe.Services.SetSeatQuantity.build_params/3`
  (pure, no Stripe call) emits the right `Stripe.Subscription.update/2` params
  for the three cases — UPDATE an existing seat add-on item, APPEND a new one,
  or DELETE it — always prorating onto the next invoice.

  The success path (the actual Stripe call) is untestable here: Stripe test-mode
  returns 401, mirroring `subdomain_addon_test.exs`/`org_checkout_test.exs`.
  """
  use ExUnit.Case, async: true

  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Providers.Stripe.Services.SetSeatQuantity

  defp seat_price,
    do: Plans.get_plan_by_id!("business-monthly").seat_addon_price

  describe "build_params/3 — seat add-on quantity" do
    test "UPDATES an existing seat item by id when extra_seats > 0 (no price, no new item)" do
      params = SetSeatQuantity.build_params(seat_price(), "si_existing", 7)

      assert [item] = params.items
      assert item.id == "si_existing"
      assert item.quantity == 7
      # An UPDATE references the item by id and must NOT carry a price (that would
      # be an ADD).
      refute Map.has_key?(item, :price)
      assert params.proration_behavior == "create_prorations"
    end

    test "APPENDS a new seat item (price, NO id) when none exists yet" do
      price = seat_price()
      params = SetSeatQuantity.build_params(price, nil, 3)

      assert [item] = params.items
      assert item.price == price
      assert item.quantity == 3
      # The distinguishing trait of an ADD vs. an UPDATE: NO id.
      refute Map.has_key?(item, :id)
      assert params.proration_behavior == "create_prorations"
    end

    test "DELETES the seat item when dropping back to the included baseline (extra_seats == 0)" do
      params = SetSeatQuantity.build_params(seat_price(), "si_existing", 0)

      assert [item] = params.items
      assert item.id == "si_existing"
      assert item.deleted == true
      refute Map.has_key?(item, :quantity)
      assert params.proration_behavior == "create_prorations"
    end

    test "is a no-op when there is no item and no extra seats" do
      params = SetSeatQuantity.build_params(seat_price(), nil, 0)
      assert params.items == []
      assert params.proration_behavior == "create_prorations"
    end
  end
end
