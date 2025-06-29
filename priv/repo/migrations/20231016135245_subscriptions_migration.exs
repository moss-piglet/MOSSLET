defmodule Mosslet.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions) do
      add :name, :string, null: false
      add :ends_at, :utc_datetime
      add :trial_ends_at, :utc_datetime
      add :stripe_id, :string
      add :stripe_status, :string
      add :customer_id, :binary_id, null: false
      add :customer_type, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:stripe_id])

    create table(:subscription_items) do
      add :subscription_id, references(:subscriptions, on_delete: :delete_all), null: false

      add :stripe_id, :string, null: false
      add :stripe_product_id, :string, null: false
      add :stripe_price_id, :string, null: false
      add :quantity, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscription_items, [:stripe_id])
  end
end
