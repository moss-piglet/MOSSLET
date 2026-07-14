defmodule Mosslet.Repo.Migrations.CreateUserVoiceNotes do
  use Ecto.Migration

  # Per-recipient sealed `file_key` for a voice note (Task #383,
  # docs/VOICE_NOTES_DESIGN.md §3.2). Mirrors `user_shared_files` /
  # `user_conversations` / `user_groups` exactly: one row per cohort member,
  # holding the `file_key` sealed FOR that member's public key via `sealForUser`
  # (Cat-5 hybrid ML-KEM-1024 + X25519). Each member unseals it with their OWN
  # private key in the browser; the server can never assemble a usable
  # `file_key`.
  #
  # `user_id` is set programmatically (never cast).
  def change do
    create table(:user_voice_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :voice_note_id,
          references(:voice_notes, type: :binary_id, on_delete: :delete_all),
          null: false

      # Recipient (set programmatically, never cast). Plaintext FK.
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # The file_key sealed for this user's public key via sealForUser. Cloak-
      # wrapped ciphertext (`Encrypted.Binary`).
      add :key, :binary, null: false

      timestamps()
    end

    create unique_index(:user_voice_notes, [:voice_note_id, :user_id])
    create index(:user_voice_notes, [:user_id])
  end
end
