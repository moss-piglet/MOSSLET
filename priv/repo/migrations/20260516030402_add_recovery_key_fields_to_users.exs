defmodule Mosslet.Repo.Local.Migrations.AddRecoveryKeyFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Argon2 hash of the recovery secret — for server-side verification
      add :recovery_key_hash, :string
      # Private key encrypted with the recovery secret (secretbox blob, Cloak-wrapped)
      add :encrypted_recovery_private_key, :binary
      # When the recovery key was set up
      add :recovery_key_created_at, :utc_datetime
    end
  end
end
