defmodule Metamorphic.Subscriptions.SubscriptionItem do
  use Ecto.Schema
  alias Metamorphic.Subscriptions.Subscription

  schema "subscription_items" do
    field :stripe_id, :string
    field :stripe_product_id, :string
    field :stripe_price_id, :string
    field :quantity, :integer

    belongs_to :subscription, Subscription

    timestamps(type: :utc_datetime)
  end
end
