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
  alias Mosslet.Billing.Referrals
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
            {:ok, subscription} ->
              maybe_mark_trial_used(customer, subscription)
              maybe_broadcast_referral_update(customer.user_id)
              :ok

            rest ->
              Logger.warning("Error creating subscription")
              Logger.debug("Error  creating subscription: #{inspect(rest)}")
              :ok
          end

        subscription ->
          old_status = subscription.status

          case Subscriptions.update_subscription(subscription, subscription_attrs) do
            {:ok, updated_subscription} ->
              maybe_mark_trial_used(customer, updated_subscription)
              maybe_handle_cancellation(customer, old_status, updated_subscription)

              maybe_broadcast_referral_status_change(
                customer.user_id,
                old_status,
                updated_subscription.status
              )

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

  defp maybe_mark_trial_used(customer, subscription) do
    if subscription.status == "trialing" && !Customers.trial_used?(customer) do
      Customers.mark_trial_used(customer)
    end
  end

  defp maybe_handle_cancellation(customer, old_status, subscription) do
    if subscription.status == "canceled" && old_status != "canceled" do
      handle_referral_cancellation(customer.user_id)
    end
  end

  defp handle_referral_cancellation(user_id) when is_binary(user_id) do
    case Referrals.get_referral_by_user(user_id) do
      nil ->
        :ok

      referral ->
        Logger.info("Cancelling referral for user #{user_id} due to subscription cancellation")
        Referrals.cancel_referral(referral)
        Referrals.void_pending_commissions(referral)

        referral = Mosslet.Repo.preload(referral, :referral_code)

        if referral.referral_code do
          Referrals.broadcast_referral_update(
            referral.referral_code.user_id,
            :referral_updated
          )
        end
    end
  end

  defp handle_referral_cancellation(_), do: :ok

  defp maybe_broadcast_referral_update(user_id) when is_binary(user_id) do
    case Referrals.get_referral_by_user(user_id) do
      nil ->
        :ok

      referral ->
        referral = Mosslet.Repo.preload(referral, :referral_code)

        if referral.referral_code do
          Referrals.broadcast_referral_update(
            referral.referral_code.user_id,
            :referral_updated
          )
        end
    end
  end

  defp maybe_broadcast_referral_update(_), do: :ok

  defp maybe_broadcast_referral_status_change(user_id, old_status, new_status)
       when old_status != new_status do
    maybe_broadcast_referral_update(user_id)
  end

  defp maybe_broadcast_referral_status_change(_, _, _), do: :ok

  defp get_source(%Customer{org_id: nil, user_id: user_id}) do
    Accounts.get_user!(user_id)
  end

  defp get_source(%Customer{org_id: org_id}) do
    Orgs.get_org_by_id(org_id)
  end
end
