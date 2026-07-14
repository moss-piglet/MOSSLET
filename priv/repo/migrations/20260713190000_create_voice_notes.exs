defmodule Mosslet.Repo.Migrations.CreateVoiceNotes do
  use Ecto.Migration

  # E2EE voice notes v1 (Task #383, docs/VOICE_NOTES_DESIGN.md §3.1). Reuses the
  # ZK file-sharing model (docs/ZK_FILE_SHARING_DESIGN.md) verbatim: a fresh
  # per-note `file_key` (NaCl secretbox) encrypts the audio blob in the browser;
  # the opaque ciphertext lives on object storage (Tigris). Only the Cloak-
  # wrapped pointer + encrypted checksum live here. The per-recipient sealed
  # `file_key` lives on `user_voice_notes.key`. The server never sees the
  # `file_key` or the plaintext audio (invariants I2/I3).
  #
  # A voice note is delivered into EXACTLY ONE cohort: a Conversation (DM) OR a
  # Group (covers personal/family/business circles). Enforced by a CHECK
  # constraint + changeset validation. All FKs are stamped server-side, never
  # cast from user params.
  def change do
    create table(:voice_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Who recorded it (set programmatically, never cast).
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Exactly one of the following is set (see CHECK below). Plaintext FKs.
      add :conversation_id,
          references(:conversations, type: :binary_id, on_delete: :delete_all)

      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all)

      # Cloak-wrapped ciphertext (`Encrypted.Binary` at the app layer).
      #
      # storage_path — the object-store key for the opaque blob.
      # checksum     — browser-computed SHA-256 of the PLAINTEXT audio, encrypted
      #                with the file_key. Recipient recomputes + verifies after
      #                decrypt (anti-tamper, I7).
      add :storage_path, :binary, null: false
      add :checksum, :binary

      # Plaintext, non-secret media metadata for playback + UX.
      #
      # media_type  — "audio" (video v2 will add "video").
      # mime_hint   — e.g. "audio/webm;codecs=opus" — for the <audio> element.
      # duration_ms — player scrubber length.
      # size_bytes  — system metric for quota/UX.
      add :media_type, :string, null: false, default: "audio"
      add :mime_hint, :string
      add :duration_ms, :integer
      add :size_bytes, :integer

      timestamps()
    end

    create index(:voice_notes, [:sender_id])
    create index(:voice_notes, [:conversation_id])
    create index(:voice_notes, [:group_id])

    # Exactly one of conversation_id / group_id is set. Defense in depth
    # alongside the context (which stamps these programmatically — I1).
    create constraint(:voice_notes, :voice_notes_exactly_one_cohort,
             check:
               "(conversation_id IS NOT NULL AND group_id IS NULL) OR (conversation_id IS NULL AND group_id IS NOT NULL)"
           )
  end
end
