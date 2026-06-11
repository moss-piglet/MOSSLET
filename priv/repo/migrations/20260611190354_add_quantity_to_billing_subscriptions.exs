defmodule Mosslet.Repo.Migrations.AddQuantityToBillingSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:billing_subscriptions) do
      add :quantity, :integer, default: 1, null: false
    end
  end
end
