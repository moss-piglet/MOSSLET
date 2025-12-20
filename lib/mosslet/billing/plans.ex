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

  def get_plan_by_id!(id) do
    Enum.find(plans(), &(&1.id == id)) || raise "No plan found for id #{id}"
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
end
