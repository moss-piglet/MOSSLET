defmodule Mosslet.Repo.Local.Migrations.ChangePaymentInfoToEncryptionOnUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :encrypted_payment_type, :binary
      add :encrypted_payment_id, :binary
      add :encrypted_payment_last_four, :binary
    end
  end
end
