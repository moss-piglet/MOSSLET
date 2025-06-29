defmodule Mosslet.Billing.Subscriptions.Subscription do
  @moduledoc false
  use Mosslet.Schema

  @status_options [
    "incomplete",
    "incomplete_expired",
    "trialing",
    "active",
    "past_due",
    "canceled",
    "unpaid",
    "expired"
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_subscriptions" do
    field :status, :string
    field :plan_id, :string
    field :provider_subscription_id, :string
    field :provider_subscription_items, {:array, :map}
    field :cancel_at, :naive_datetime
    field :canceled_at, :naive_datetime
    field :current_period_end_at, :naive_datetime
    field :current_period_start, :naive_datetime
    field :plan, :map, virtual: true

    belongs_to :customer, Mosslet.Billing.Customers.Customer,
      foreign_key: :billing_customer_id,
      type: :binary_id

    timestamps()
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :status,
      :plan_id,
      :provider_subscription_id,
      :provider_subscription_items,
      :cancel_at,
      :canceled_at,
      :current_period_end_at,
      :current_period_start,
      :billing_customer_id
    ])
    |> validate_required([
      :status,
      :plan_id,
      :provider_subscription_id,
      :provider_subscription_items,
      :current_period_start,
      :billing_customer_id
    ])
    |> validate_inclusion(:status, @status_options)
  end
end
