defmodule Mosslet.Repo.Local.Migrations.CreateBillingPaymentIntentTable do
  use Ecto.Migration

  def change do
    create table(:billing_payment_intents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_payment_intent_id, :string, null: false
      add :provider_customer_id, :string, null: false
      add :provider_latest_charge_id, :string, null: false
      add :provider_payment_method_id, :string, null: false
      add :provider_created_at, :naive_datetime
      add :amount, :integer, null: false
      add :amount_received, :integer, null: false
      add :status, :string, null: false

      add :billing_customer_id,
          references(:billing_customers, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps()
    end

    create index(:billing_payment_intents, [:billing_customer_id])
  end
end
