defmodule Mosslet.Billing.Providers.Stripe.Services.CreatePortalSession do
  @moduledoc false
  use MossletWeb, :verified_routes

  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Providers.Behaviour.UrlHelpers
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Subscriptions.Subscription

  def call(%Customer{} = customer, %Subscription{} = subscription, items) do
    subscription_item_id =
      subscription.provider_subscription_id
      |> Stripe.Subscription.retrieve()
      |> then(fn {:ok, stripe_subscription} -> stripe_subscription end)
      |> get_subscription_item()

    # Reflect the subscription's actual seat count (per-seat plans). Single-seat
    # plans (e.g. Personal) keep quantity 1 via the schema default.
    quantity = subscription.quantity || 1

    # provider_customer_id is now Cloak-only — read directly
    Provider.create_portal_session(%{
      customer: customer.provider_customer_id,
      flow_data: %{
        type: :subscription_update_confirm,
        subscription_update_confirm: %{
          subscription: subscription.provider_subscription_id,
          items: Enum.map(items, &%{id: subscription_item_id, price: &1, quantity: quantity})
        },
        after_completion: %{
          type: :redirect,
          redirect: %{
            return_url: return_url(customer)
          }
        }
      }
    })
  end

  # Derive the source from the customer itself (its own user_id/org_id), NOT the
  # global `:billing_entity` config flag. An org customer (user_id: nil) managing
  # an active org subscription must return to the org's subscribe success page,
  # regardless of how the personal-only UI flag is set.
  defp return_url(%Customer{org_id: org_id} = customer) when is_binary(org_id) do
    UrlHelpers.success_url(:org, org_id, customer.id) <> "&switch_plan=true"
  end

  defp return_url(%Customer{user_id: user_id} = customer) when is_binary(user_id) do
    UrlHelpers.success_url(:user, user_id, customer.id) <> "&switch_plan=true"
  end

  defp get_subscription_item(stripe_subscription) do
    stripe_subscription.items.data
    |> List.first()
    |> Map.get(:id)
  end
end
