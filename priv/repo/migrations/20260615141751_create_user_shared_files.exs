defmodule Mosslet.Repo.Migrations.CreateUserSharedFiles do
  use Ecto.Migration

  # Per-recipient sealed `file_key` (Task #221, docs/ZK_FILE_SHARING_DESIGN.md
  # §5.2). Mirrors `user_groups`/`user_posts` exactly: one row per circle member,
  # holding the `file_key` sealed FOR that member's public key via `sealForUser`
  # (Cat-5 hybrid). Each member unseals it with their OWN private key in the
  # browser. The server can never assemble a usable `file_key`.
  def change do
    create table(:user_shared_files, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :shared_file_id,
          references(:shared_files, type: :binary_id, on_delete: :delete_all),
          null: false

      # Recipient (set programmatically, never cast). Plaintext FK.
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # The file_key sealed for this user's public key via sealForUser. Cloak-
      # wrapped ciphertext at the app layer (`Encrypted.Binary`).
      add :key, :binary, null: false

      timestamps()
    end

    create unique_index(:user_shared_files, [:shared_file_id, :user_id])
    create index(:user_shared_files, [:user_id])
  end
end
