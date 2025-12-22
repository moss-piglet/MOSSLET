defmodule Mosslet.Repo.Local.Migrations.CreateBillingPayouts do
  use Ecto.Migration

  def change do
    create table(:billing_payouts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :referral_code_id,
          references(:billing_referral_codes, type: :binary_id, on_delete: :delete_all),
          null: false

      add :amount, :integer, null: false
      add :status, :string, null: false, default: "pending"
      add :stripe_transfer_id, :binary
      add :stripe_transfer_id_hash, :binary
      add :failure_reason, :binary
      add :processed_at, :utc_datetime
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false

      timestamps()
    end

    create index(:billing_payouts, [:referral_code_id])
    create index(:billing_payouts, [:status])
    create index(:billing_payouts, [:stripe_transfer_id_hash])
  end
end
