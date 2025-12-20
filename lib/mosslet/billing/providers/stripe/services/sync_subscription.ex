defmodule Mosslet.Billing.Providers.Stripe.Services.SyncSubscription do
  @moduledoc """
  Syncs a Stripe subscription with the local database.
  Stripe is the source of truth.
  Use it when a subscription has been updated on Stripe and needs to be synced locally.
  Subscription type: https://hexdocs.pm/stripity_stripe/Stripe.Subscription.html#t:t/0
  """
  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Providers.Stripe.Adapters.SubscriptionAdapter
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  require Logger

  def call(%Stripe.Subscription{} = stripe_subscription) do
    with {:customer, %Customer{} = customer} <-
           {:customer,
            Customers.get_customer_by_provider_customer_id!(stripe_subscription.customer)},
         {:source, _source} <-
           {:source, get_source(customer)} do
      subscription_attrs =
        stripe_subscription
        |> SubscriptionAdapter.attrs_from_stripe_subscription()
        |> Map.put(:billing_customer_id, customer.id)

      case Subscriptions.get_subscription_by_provider_subscription_id(stripe_subscription.id) do
        nil ->
          case Subscriptions.create_subscription(subscription_attrs) do
            {:ok, _subscription} ->
              :ok

            rest ->
              Logger.warning("Error creating subscription")
              Logger.debug("Error  creating subscription: #{inspect(rest)}")
              :ok
          end

        subscription ->
          case Subscriptions.update_subscription(subscription, subscription_attrs) do
            {:ok, _subscription} ->
              :ok

            rest ->
              Logger.warning("Error updating subscription")
              Logger.debug("Error  updating subscription: #{inspect(rest)}")
              :ok
          end
      end
    else
      error -> {:error, error}
    end
  end

  defp get_source(%Customer{org_id: nil, user_id: user_id}) do
    Accounts.get_user!(user_id)
  end

  defp get_source(%Customer{org_id: org_id}) do
    Orgs.get_org_by_id(org_id)
  end
end
