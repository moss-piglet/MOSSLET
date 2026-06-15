defmodule Mosslet.Repo.Migrations.CreateSharedFiles do
  use Ecto.Migration

  # Org-scoped ZK file sharing (Task #221, docs/ZK_FILE_SHARING_DESIGN.md §5.1).
  #
  # A `shared_files` row is the metadata for ONE browser-encrypted file shared
  # into a business circle. The opaque encrypted blob lives on object storage
  # (Tigris); only the Cloak-wrapped pointer + encrypted metadata live here. The
  # server never holds the `file_key` or plaintext (I2/I3).
  def change do
    create table(:shared_files, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The business circle this file belongs to (must have org_id set). Pinned
      # to ONE circle — no cross-circle leakage (I-non-goal). Plaintext FK.
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false

      # Denormalized org for org-scoped queries/cleanup (set in context, not cast).
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false

      # Who uploaded it (set programmatically, never cast).
      add :uploader_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # All of the following are Cloak-wrapped ciphertext at the app layer
      # (`Encrypted.Binary`); the DB only ever sees opaque binary.
      #
      # storage_path       — the object-store key for the opaque blob (low
      #                       sensitivity pointer, but no reason to leak it).
      # encrypted_filename — original filename, encrypted WITH the file_key in
      #                      the browser (so even the name is ZK).
      # checksum           — browser-computed SHA-256 of the PLAINTEXT, encrypted
      #                      with the file_key. Recipient recomputes + verifies
      #                      after decrypt (anti-tamper, I7).
      # scan_verdict       — optional client-side threat-scan result, encrypted
      #                      with the file_key (recipients see "scanned ✓/⚠";
      #                      server reads nothing — I8).
      add :storage_path, :binary, null: false
      add :encrypted_filename, :binary
      add :checksum, :binary
      add :scan_verdict, :binary

      # Plaintext system metric (for quota/UX). Non-sensitive.
      add :size_bytes, :integer

      timestamps()
    end

    create index(:shared_files, [:group_id])
    create index(:shared_files, [:org_id])
    create index(:shared_files, [:uploader_id])
  end
end
