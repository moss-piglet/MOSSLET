defmodule Mosslet.Billing.Providers.Stripe.Adapters.SubscriptionAdapter do
  @moduledoc """
  This module is responsible for converting a Stripe Subscription into attrs
  matching the Mosslet.Billing.Subscriptions.Subscription struct.
  """
  alias Mosslet.Billing.Plans

  def attrs_from_stripe_subscription(stripe_subscription) do
    %{
      provider_subscription_id: stripe_subscription.id,
      provider_subscription_items: provider_subscription_items(stripe_subscription),
      status: stripe_subscription.status,
      cancel_at: cancel_at(stripe_subscription),
      canceled_at: canceled_at(stripe_subscription)
    }
    |> Util.maybe_put(:plan_id, plan_id(stripe_subscription))
    |> Util.maybe_put(:current_period_start, current_period_start(stripe_subscription))
    |> Util.maybe_put(:current_period_end_at, current_period_end_at(stripe_subscription))
  end

  def plan_id(stripe_subscription) do
    case Plans.get_plan_by_stripe_subscription(stripe_subscription) do
      nil -> nil
      plan -> plan.id
    end
  end

  def current_period_start(stripe_subscription) do
    Util.unix_to_naive_datetime(get_current_period_start(stripe_subscription))
  end

  def current_period_end_at(stripe_subscription) do
    Util.unix_to_naive_datetime(get_current_period_end(stripe_subscription))
  end

  def cancel_at(stripe_subscription) do
    if stripe_subscription.cancel_at_period_end do
      Util.unix_to_naive_datetime(get_current_period_end(stripe_subscription))
    else
      Util.unix_to_naive_datetime(stripe_subscription.cancel_at)
    end
  end

  def canceled_at(stripe_subscription) do
    cond do
      stripe_subscription.status == "canceled" && stripe_subscription.cancel_at_period_end ->
        Util.unix_to_naive_datetime(get_current_period_end(stripe_subscription))

      stripe_subscription.status == "canceled" ->
        Util.unix_to_naive_datetime(stripe_subscription.cancel_at)

      true ->
        nil
    end
  end

  def provider_subscription_items(stripe_subscription) do
    Enum.map(stripe_subscription.items.data, fn item ->
      %{
        price_id: item.price.id,
        product_id: item.price.product
      }
    end)
  end

  # In stripity_stripe 3.3.1, current_period_start and current_period_end
  # were removed from the top-level Subscription struct. They now live on
  # each SubscriptionItem. We read from the first item.
  defp get_current_period_start(stripe_subscription) do
    case stripe_subscription.items.data do
      [item | _] -> item.current_period_start
      _ -> stripe_subscription.start_date
    end
  end

  defp get_current_period_end(stripe_subscription) do
    case stripe_subscription.items.data do
      [item | _] -> item.current_period_end
      _ -> stripe_subscription.trial_end
    end
  end
end
