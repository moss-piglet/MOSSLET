defmodule Mosslet.Repo.Local.Migrations.RemoveOldCustomerFieldsForEncryptedFields do
  use Ecto.Migration

  def change do
    alter table(:billing_customers) do
      remove :email
    end

    rename table(:billing_customers), :encrypted_email, to: :email
  end
end
