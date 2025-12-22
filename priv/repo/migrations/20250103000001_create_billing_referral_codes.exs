defmodule Mosslet.Repo.Local.Migrations.CreateBillingReferralCodes do
  use Ecto.Migration

  def change do
    create table(:billing_referral_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :code, :binary, null: false
      add :code_hash, :binary, null: false
      add :payout_email, :binary
      add :payout_email_hash, :binary
      add :stripe_connect_account_id, :binary
      add :stripe_connect_account_id_hash, :binary
      add :connect_onboarding_complete, :boolean, default: false, null: false
      add :connect_payouts_enabled, :boolean, default: false, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:billing_referral_codes, [:user_id])
    create unique_index(:billing_referral_codes, [:code_hash])
    create index(:billing_referral_codes, [:stripe_connect_account_id_hash])
    create index(:billing_referral_codes, [:is_active])
  end
end
