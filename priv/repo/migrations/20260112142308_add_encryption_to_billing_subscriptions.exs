defmodule Mosslet.Repo.Local.Migrations.AddEncryptionToBillingSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:billing_subscriptions) do
      add :encrypted_provider_subscription_id, :binary
      add :provider_subscription_id_hash, :binary
      add :encrypted_provider_subscription_items, :binary
    end

    create index(:billing_subscriptions, [:provider_subscription_id_hash])
  end
end
