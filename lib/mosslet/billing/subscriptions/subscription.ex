defmodule Mosslet.Billing.Subscriptions.Subscription do
  @moduledoc false
  use Mosslet.Schema
  alias Mosslet.Encrypted

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
    # Number of seats/members on the subscription (per-seat billing). Defaults to
    # 1 for single-seat plans (e.g. Personal). Family/Business plans set this to
    # the chosen member/seat count at checkout and keep it in sync with Stripe.
    field :quantity, :integer, default: 1
    field :cancel_at, :naive_datetime
    field :canceled_at, :naive_datetime
    field :current_period_end_at, :naive_datetime
    field :current_period_start, :naive_datetime
    field :plan, :map, virtual: true

    field :provider_subscription_id, Encrypted.Binary, redact: true
    field :provider_subscription_id_hash, Encrypted.HMAC, redact: true
    field :provider_subscription_items, Encrypted.MapList, redact: true

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
      :quantity,
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
    |> validate_number(:quantity, greater_than_or_equal_to: 1)
    |> put_hashed_fields()
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> put_change(:provider_subscription_id_hash, get_field(changeset, :provider_subscription_id))
  end
end
