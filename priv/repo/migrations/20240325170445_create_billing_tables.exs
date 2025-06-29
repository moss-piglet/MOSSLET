defmodule Mosslet.Repo.Local.Migrations.CreateBillingTables do
  use Ecto.Migration

  def change do
    create table(:billing_customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext
      add :provider, :string, null: false
      add :provider_customer_id, :string, null: false

      # Add foreign keys for sources of customers here. In our case either a user or an org can be a source of a customer.
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:billing_customers, [:user_id, :org_id])
    create index(:billing_customers, [:provider])

    create table(:billing_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :plan_id, :string, null: false
      add :provider_subscription_id, :string, null: false
      add :provider_subscription_items, {:array, :map}, null: false
      add :cancel_at, :naive_datetime
      add :canceled_at, :naive_datetime
      add :current_period_end_at, :naive_datetime
      add :current_period_start, :naive_datetime

      add :billing_customer_id,
          references(:billing_customers, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps()
    end

    create index(:billing_subscriptions, [:billing_customer_id])
  end
end
