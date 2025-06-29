defmodule Mosslet.Repo.Local.Migrations.ChangeLastSignedInOnUsersToEncrypted do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :encrypted_last_signed_in_ip, :binary
      add :last_signed_in_ip_hash, :binary
    end
  end
end
