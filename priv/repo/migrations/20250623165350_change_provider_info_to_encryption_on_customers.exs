defmodule Mosslet.Repo.Local.Migrations.ChangeProviderInfoToEncryptionOnCustomers do
  use Ecto.Migration

  def change do
    alter table(:billing_customers) do
      add :encrypted_provider, :binary
      add :provider_hash, :binary
      add :encrypted_provider_customer_id, :binary
      add :provider_customer_id_hash, :binary
    end
  end
end
