defmodule Mosslet.Orgs.OrgBrandingAddonTest do
  @moduledoc """
  Task #240 / #243 (Phase B, slice D): server-authoritative branding-add-on
  entitlement. `Orgs.has_branding_addon?/1` reads the org's `:org`-source
  subscription line items and gates ONLY the custom subdomain (claim + serve).
  The brand logo is NOT gated here (it stays free for all Business orgs).
  `Orgs.subdomain_live?/1` additionally requires a claimed subdomain.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Billing.Plans
  alias Mosslet.Orgs

  defp confirmed_user(seed) do
    user_fixture(%{email: "#{seed}#{System.unique_integer([:positive])}@example.com"})
  end

  defp business_org(opts \\ []) do
    name = Keyword.get(opts, :name, "Acme #{System.unique_integer([:positive])}")
    {:ok, org} = Orgs.create_org(confirmed_user("owner"), %{"name" => name, "type" => "business"})
    org
  end

  defp monthly_addon_price,
    do: Plans.subdomain_addon_price(Plans.get_plan_by_id!("business-monthly"))

  defp yearly_addon_price,
    do: Plans.subdomain_addon_price(Plans.get_plan_by_id!("business-yearly"))

  describe "has_branding_addon?/1" do
    test "true when the org's active sub carries the (monthly) subdomain add-on line item" do
      org = business_org()

      ensure_org_subscription(org,
        plan_id: "business-monthly",
        status: "active",
        items: [%{"price_id" => "price_business_base"}, %{"price_id" => monthly_addon_price()}]
      )

      assert Orgs.has_branding_addon?(org)
    end

    test "true for a yearly add-on too (interval-agnostic read)" do
      org = business_org()

      ensure_org_subscription(org,
        plan_id: "business-yearly",
        status: "active",
        items: [%{"price_id" => yearly_addon_price()}]
      )

      assert Orgs.has_branding_addon?(org)
    end

    test "true while trialing and during the past_due grace window" do
      trialing = business_org()

      ensure_org_subscription(trialing,
        status: "trialing",
        items: [%{"price_id" => monthly_addon_price()}]
      )

      assert Orgs.has_branding_addon?(trialing)

      grace = business_org()

      ensure_org_subscription(grace,
        status: "past_due",
        items: [%{"price_id" => monthly_addon_price()}]
      )

      assert Orgs.has_branding_addon?(grace)
    end

    test "false when the sub has NO add-on line item (logo-only Business org)" do
      org = business_org()
      ensure_org_subscription(org, items: [%{"price_id" => "price_business_base"}])
      refute Orgs.has_branding_addon?(org)
    end

    test "false when the org has no subscription at all (inert)" do
      refute Orgs.has_branding_addon?(business_org())
    end

    test "false once the sub lapses (canceled), even if it once carried the add-on" do
      org = business_org()

      ensure_org_subscription(org,
        status: "canceled",
        items: [%{"price_id" => monthly_addon_price()}]
      )

      refute Orgs.has_branding_addon?(org)
    end
  end

  describe "subdomain_live?/1 (serve gate = add-on + claimed subdomain)" do
    test "true only when entitled AND a subdomain is claimed" do
      org = business_org()
      ensure_org_subscription(org, items: [%{"price_id" => monthly_addon_price()}])

      # Entitled but no subdomain claimed yet -> not live.
      refute Orgs.subdomain_live?(org)

      {:ok, org} = Orgs.set_org_subdomain(org, %{"subdomain" => "acmeco"})
      assert Orgs.subdomain_live?(org)
    end

    test "false when a subdomain is claimed but the org is NOT entitled (logo-only)" do
      org = business_org()
      ensure_org_subscription(org, items: [%{"price_id" => "price_business_base"}])
      {:ok, org} = Orgs.set_org_subdomain(org, %{"subdomain" => "noaddonco"})

      refute Orgs.has_branding_addon?(org)
      refute Orgs.subdomain_live?(org)
    end

    test "add-on lapse stops serving but keeps the reserved subdomain row" do
      org = business_org()

      {_customer, subscription} =
        ensure_org_subscription(org, items: [%{"price_id" => monthly_addon_price()}])

      {:ok, org} = Orgs.set_org_subdomain(org, %{"subdomain" => "lapseco"})
      assert Orgs.subdomain_live?(org)

      {:ok, _} = Mosslet.Billing.Subscriptions.cancel_subscription_immediately(subscription)

      reloaded = Orgs.get_org_by_id(org.id)
      # Row is kept (still reserved for the org)...
      assert reloaded.subdomain == "lapseco"
      # ...but serving stops because the add-on entitlement lapsed.
      refute Orgs.has_branding_addon?(reloaded)
      refute Orgs.subdomain_live?(reloaded)
    end
  end
end
