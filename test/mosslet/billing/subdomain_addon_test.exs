defmodule Mosslet.Billing.SubdomainAddonTest do
  @moduledoc """
  Task #240 / #243 (Phase B, slice D): the paid custom-subdomain branding add-on
  line item. Verifies `Mosslet.Billing.Providers.Stripe.build_line_items/3`
  (pure, no Stripe call) emits the add-on interval-matched to the base plan, only
  when requested and only for plans that offer it — and never for the logo (which
  is free).
  """
  use ExUnit.Case, async: true

  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Providers.Stripe
  alias Mosslet.Billing.Providers.Stripe.Services.AddSubscriptionItem

  defp prices(line_items), do: Enum.map(line_items, & &1.price)

  describe "build_line_items/3 — subdomain add-on" do
    test "monthly Business checkout includes the MONTHLY subdomain add-on when requested" do
      plan = Plans.get_plan_by_id!("business-monthly")
      items = Stripe.build_line_items(plan, Plans.included_seats(plan), [:subdomain])

      assert plan.price in prices(items)
      assert Plans.subdomain_addon_price(plan) in prices(items)

      addon = Enum.find(items, &(&1.price == Plans.subdomain_addon_price(plan)))
      assert addon.quantity == 1
    end

    test "yearly Business checkout includes the YEARLY subdomain add-on (interval-matched)" do
      monthly = Plans.get_plan_by_id!("business-monthly")
      yearly = Plans.get_plan_by_id!("business-yearly")
      items = Stripe.build_line_items(yearly, Plans.included_seats(yearly), [:subdomain])

      assert Plans.subdomain_addon_price(yearly) in prices(items)
      # The monthly add-on price must NOT leak into a yearly checkout.
      refute Plans.subdomain_addon_price(monthly) in prices(items)
    end

    test "omits the add-on when not requested (logo stays free — no add-on)" do
      plan = Plans.get_plan_by_id!("business-monthly")
      items = Stripe.build_line_items(plan, Plans.included_seats(plan), [])

      refute Plans.subdomain_addon_price(plan) in prices(items)
      assert prices(items) == [plan.price]
    end

    test "ignores the add-on for a plan that doesn't offer it (Personal)" do
      plan = Plans.get_plan_by_id!("personal-monthly")
      items = Stripe.build_line_items(plan, 1, [:subdomain])

      assert prices(items) == [plan.price]
    end

    test "add-on composes with extra seats (both line items present)" do
      plan = Plans.get_plan_by_id!("business-monthly")
      seats = Plans.included_seats(plan) + 3
      items = Stripe.build_line_items(plan, seats, [:subdomain])

      assert plan.price in prices(items)
      assert plan.seat_addon_price in prices(items)
      assert Plans.subdomain_addon_price(plan) in prices(items)

      seat_item = Enum.find(items, &(&1.price == plan.seat_addon_price))
      assert seat_item.quantity == 3
    end
  end

  describe "AddSubscriptionItem.build_params/1 — one-click add-on for active orgs" do
    test "APPENDS a new item (price, no id) so existing items stay intact" do
      price_id = Plans.subdomain_addon_price(Plans.get_plan_by_id!("business-monthly"))
      params = AddSubscriptionItem.build_params(price_id)

      assert [item] = params.items
      assert item.price == price_id
      assert item.quantity == 1

      # The distinguishing trait vs. CreatePortalSession's plan SWAP: NO `id`,
      # which is what makes Stripe add the item rather than replace one.
      refute Map.has_key?(item, :id)

      # Prorate onto the existing payment method's next invoice (no new checkout).
      assert params.proration_behavior == "create_prorations"
    end
  end
end
