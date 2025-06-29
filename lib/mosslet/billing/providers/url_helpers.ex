defmodule Mosslet.Billing.Providers.Behaviour.UrlHelpers do
  @moduledoc false
  use MossletWeb, :controller

  def success_url(:user, _user_id, customer_id) do
    url(MossletWeb.Endpoint, ~p"/app/subscribe/success?customer_id=#{customer_id}")
  end

  def success_url(:org, org_id, customer_id) do
    org = Mosslet.Orgs.get_org_by_id(org_id)

    url(
      MossletWeb.Endpoint,
      ~p"/app/org/#{org.slug}/subscribe/success?customer_id=#{customer_id}"
    )
  end

  def cancel_url(:user, _user_id), do: url(MossletWeb.Endpoint, ~p"/app/subscribe")

  def cancel_url(:org, org_id) do
    org = Mosslet.Orgs.get_org_by_id(org_id)

    url(MossletWeb.Endpoint, ~p"/app/org/#{org.slug}/subscribe")
  end
end
