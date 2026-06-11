defmodule Mosslet.Billing.Plans do
  @moduledoc """
  Add your subscription plans in config. This module provides helper functions for plans.

  While you could store plans in the database, it would take a lot of code to keep them in sync with external providers like Stripe.

  In reality most projects won't have many plans, and it's easier to CRUD them in your payment provider like Stripe and manually keep this file updated.
  """

  alias Mosslet.Billing.Subscriptions.Subscription

  @doc """
  ## Examples

      iex> Plans.products() |> Enum.map(& &1.id)
      ["prod1", "prod2", "stripe-test-plan-a"]
  """
  def products do
    Mosslet.config(:billing_products)
  end

  @doc """
  Returns all plans across all products.

  ## Examples

      iex> Plans.plans() |> Enum.map(& &1.id)
      ["plan1-1", "plan2-1", "plan2-2", "stripe-test-plan-a-monthly", "stripe-test-plan-a-yearly"]
  """
  def plans do
    Enum.flat_map(products(), & &1.line_items)
  end

  @doc """
  Returns only one-time payment plans.
  """
  def one_time_plans do
    Enum.filter(plans(), &(&1.interval == :one_time))
  end

  @doc """
  Returns only subscription plans.
  """
  def subscription_plans do
    Enum.filter(plans(), &(&1.interval in [:month, :year]))
  end

  @doc """
  ## Examples

      iex> "plan2-1" |> Plans.get_plan_by_id!() |> Plans.plan_items()
      ["item2-1-1", "item2-1-2"]
  """
  def plan_items(plan) do
    if Map.has_key?(plan, :items) do
      Enum.map(plan.items, & &1.price)
    else
      [plan.price]
    end
  end

  def get_plan_by_id(id) do
    Enum.find(plans(), &(&1.id == id))
  end

  def get_plan_by_id!(id) do
    get_plan_by_id(id) || raise "No plan found for id #{id}"
  end

  def get_plan_by_subscription!(%Subscription{plan_id: plan_id}) do
    get_plan_by_id!(plan_id)
  end

  def get_plan_by_stripe_subscription(%Stripe.Subscription{items: %{data: data}}) do
    price_ids =
      data
      |> Enum.map(& &1.price.id)
      |> MapSet.new()

    Enum.find(plans(), fn plan ->
      plan.price in price_ids
    end)
  end

  def get_plan_by_price_id(price_id) do
    Enum.find(plans(), &(&1.price == price_id))
  end

  def is_subscription_plan?(plan) do
    plan.interval in [:month, :year]
  end

  def is_one_time_plan?(plan) do
    plan.interval == :one_time
  end

  def get_product_by_plan_id(plan_id) do
    Enum.find(products(), fn product ->
      Enum.any?(product.line_items, &(&1.id == plan_id))
    end)
  end

  @doc """
  Returns true when a plan/line-item supports per-seat (member) billing.

  Per-seat plans declare an `:seat_addon_price` (the Stripe price ID used for
  additional seats beyond the base allotment). Single-seat plans (e.g. Personal)
  omit it and bill a single base line item.
  """
  def seat_based_plan?(plan) when is_map(plan) do
    is_binary(Map.get(plan, :seat_addon_price))
  end

  def seat_based_plan?(_), do: false

  @doc """
  The number of seats included in a plan's base price.

  Defaults to 1 for plans that don't declare `:included_seats`.
  """
  def included_seats(plan) when is_map(plan) do
    Map.get(plan, :included_seats, 1)
  end

  @doc """
  The maximum number of seats a per-seat plan allows.

  Defaults to `:infinity` when `:max_seats` is not declared.
  """
  def max_seats(plan) when is_map(plan) do
    Map.get(plan, :max_seats, :infinity)
  end

  @doc """
  Clamps a requested seat count to the plan's allowed range.

  Non-seat plans always resolve to 1 seat. Seat-based plans are clamped between
  the included seat count and `:max_seats` (when present).
  """
  def clamp_seats(plan, requested) when is_map(plan) do
    if seat_based_plan?(plan) do
      requested = to_integer(requested, included_seats(plan))
      requested = max(requested, included_seats(plan))

      case max_seats(plan) do
        :infinity -> requested
        max when is_integer(max) -> min(requested, max)
      end
    else
      1
    end
  end

  defp to_integer(value, _default) when is_integer(value), do: value

  defp to_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp to_integer(_value, default), do: default
end
