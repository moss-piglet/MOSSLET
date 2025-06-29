defmodule Mosslet.Repo.Local.Migrations.ChangeProviderInfoToEncryptionOnPaymentIntents do
  use Ecto.Migration

  def change do
    alter table(:billing_payment_intents) do
      add :encrypted_provider_payment_intent_id, :binary
      add :provider_payment_intent_id_hash, :binary
      add :encrypted_provider_customer_id, :binary
      add :provider_customer_id_hash, :binary
      add :encrypted_provider_latest_charge_id, :binary
      add :provider_latest_charge_id_hash, :binary
      add :encrypted_provider_payment_method_id, :binary
      add :provider_payment_method_id_hash, :binary
    end
  end
end
