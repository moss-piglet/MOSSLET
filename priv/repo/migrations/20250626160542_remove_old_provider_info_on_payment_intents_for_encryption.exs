defmodule Mosslet.Repo.Local.Migrations.RemoveOldProviderInfoOnPaymentIntentsForEncryption do
  use Ecto.Migration

  def change do
    alter table(:billing_payment_intents) do
      remove :provider_payment_intent_id
      remove :provider_customer_id
      remove :provider_latest_charge_id
      remove :provider_payment_method_id
    end

    rename table(:billing_payment_intents), :encrypted_provider_payment_intent_id,
      to: :provider_payment_intent_id

    rename table(:billing_payment_intents), :encrypted_provider_customer_id,
      to: :provider_customer_id

    rename table(:billing_payment_intents), :encrypted_provider_latest_charge_id,
      to: :provider_latest_charge_id

    rename table(:billing_payment_intents), :encrypted_provider_payment_method_id,
      to: :provider_payment_method_id
  end
end
