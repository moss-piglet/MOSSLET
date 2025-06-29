defmodule Mosslet.Repo.Local.Migrations.ChangeEmailOnBillingCustomersToEncryption do
  use Ecto.Migration

  def change do
    alter table(:billing_customers) do
      add :encrypted_email, :binary
      add :email_hash, :binary
    end
  end
end
