defmodule Mosslet.Repo.Migrations.AddVoiceNoteIdToGroupMessages do
  use Ecto.Migration

  # A voice note is delivered AS a group message referencing its VoiceNote (Task
  # #383, docs/VOICE_NOTES_DESIGN.md §3.3), so it reuses the existing group
  # message stream, broadcast, ordering, and deletion machinery. Nullable FK: a
  # normal text message has no voice_note_id. Set programmatically, never cast.
  def change do
    alter table(:group_messages) do
      add :voice_note_id,
          references(:voice_notes, type: :binary_id, on_delete: :delete_all)
    end

    create index(:group_messages, [:voice_note_id])
  end
end
