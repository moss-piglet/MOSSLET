defmodule Mosslet.Repo.Local.Migrations.CreateBillingReferrals do
  use Ecto.Migration

  def change do
    create table(:billing_referrals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :referral_code_id,
          references(:billing_referral_codes, type: :binary_id, on_delete: :delete_all),
          null: false

      add :referred_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "pending"
      add :referred_at, :utc_datetime, null: false
      add :qualified_at, :utc_datetime
      add :commission_rate, :decimal, null: false
      add :discount_percent, :integer, null: false
      add :beta_referral, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:billing_referrals, [:referred_user_id])
    create index(:billing_referrals, [:referral_code_id])
    create index(:billing_referrals, [:status])
  end
end
