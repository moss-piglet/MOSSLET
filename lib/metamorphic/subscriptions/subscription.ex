defmodule Metamorphic.Subscriptions.Subscription do
  use Ecto.Schema
  alias Metamorphic.Subscriptions.SubscriptionItem

  schema "subscriptions" do
    field :name, :string
    field :ends_at, :utc_datetime
    field :trial_ends_at, :utc_datetime
    field :stripe_id, :string
    field :stripe_status, :string
    field :customer_id, :binary_id
    field :customer_type, :string

    has_many :subscription_items, SubscriptionItem

    timestamps(type: :utc_datetime)
  end
end
