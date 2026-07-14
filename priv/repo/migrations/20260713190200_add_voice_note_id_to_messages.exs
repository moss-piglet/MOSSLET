defmodule Mosslet.Repo.Migrations.AddVoiceNoteIdToMessages do
  use Ecto.Migration

  # A voice note is delivered AS a DM message referencing its VoiceNote (Task
  # #383, docs/VOICE_NOTES_DESIGN.md §3.3), so it reuses the existing message
  # stream, broadcast, ordering, and deletion machinery. Nullable FK: a normal
  # text/image message has no voice_note_id. Set programmatically, never cast.
  def change do
    alter table(:messages) do
      add :voice_note_id,
          references(:voice_notes, type: :binary_id, on_delete: :delete_all)
    end

    create index(:messages, [:voice_note_id])
  end
end
