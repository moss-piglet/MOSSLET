defmodule Mosslet.Repo.Local.Migrations.CreateBillingCommissions do
  use Ecto.Migration

  def change do
    create table(:billing_commissions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :referral_id,
          references(:billing_referrals, type: :binary_id, on_delete: :delete_all),
          null: false

      add :subscription_id,
          references(:billing_subscriptions, type: :binary_id, on_delete: :nilify_all)

      add :stripe_invoice_id, :binary
      add :stripe_invoice_id_hash, :binary
      add :gross_amount, :integer, null: false
      add :commission_amount, :integer, null: false
      add :status, :string, null: false, default: "pending"
      add :period_start, :utc_datetime
      add :period_end, :utc_datetime

      timestamps()
    end

    create index(:billing_commissions, [:referral_id])
    create index(:billing_commissions, [:subscription_id])
    create index(:billing_commissions, [:status])
    create index(:billing_commissions, [:stripe_invoice_id_hash])
  end
end
