defmodule Mosslet.Repo.Local.Migrations.RemoveOldProviderInfoOnCustomersForEncryption do
  use Ecto.Migration

  def change do
    alter table(:billing_customers) do
      remove :provider
      remove :provider_customer_id
    end

    rename table(:billing_customers), :encrypted_provider, to: :provider
    rename table(:billing_customers), :encrypted_provider_customer_id, to: :provider_customer_id
  end
end
