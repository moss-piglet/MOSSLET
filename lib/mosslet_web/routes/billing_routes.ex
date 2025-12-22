defmodule MossletWeb.BillingRoutes do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      # :subscribe menu item is in MossletWeb.Menus
      live "/billing", BillingLive, :user
      live "/subscribe/success", SubscribeSuccessLive, :user
      live "/subscribe", SubscribeLive, :user
      live "/referrals", ReferralsLive, :index
      get "/checkout/:plan_id", SubscribeController, :checkout
      get "/referrals/connect/complete", ReferralConnectController, :complete
      get "/referrals/connect/refresh", ReferralConnectController, :refresh

      scope "/org/:org_slug" do
        # :org_subscribe menu item is in MossletWeb.OrgLayoutComponent
        live "/billing", BillingLive, :org
        live "/subscribe/success", SubscribeSuccessLive, :org
        live "/subscribe", SubscribeLive, :org
        get "/checkout/:plan_id", SubscribeController, :checkout
      end
    end
  end
end
