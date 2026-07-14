defmodule Mosslet.Repo.Migrations.CreateNudges do
  use Ecto.Migration

  # Content-free "thinking of you" nudge (EPIC #377, task #399, follow-on to the
  # deferred outbound gesture from #381).
  #
  # A nudge is PURE METADATA: who sent it, who received it, and when. There is no
  # message, no encryption, and no per-connection key — mirroring the
  # rituals/presence plaintext-metadata model, NOT the UserConnection
  # encrypted-fields model. The server never sees a message because there isn't
  # one. The sender's NAME shown to the recipient ("Poppy was thinking of you")
  # is resolved CLIENT-SIDE via the existing connection ZK path — it is never
  # stored on this row.
  #
  # All operations are online-safe on Fly PostgreSQL (new table + nullable
  # column adds only).
  def change do
    create table(:nudges, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Who sent the nudge and who receives it — plaintext UUIDs, no content.
      add :from_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :to_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # When the recipient acknowledged it on their dashboard (nil = unseen).
      add :seen_at, :utc_datetime

      timestamps()
    end

    # Recipient dashboard: "my recent (unseen) nudges" ordered by recency.
    create index(:nudges, [:to_user_id, :inserted_at])

    # Rate-limit / dedupe lookup: "did from_user recently nudge to_user?"
    create index(:nudges, [:from_user_id, :to_user_id, :inserted_at])

    alter table(:users) do
      # Recipient opt-out for nudges. Default ON — a wordless hello is calm and
      # welcome by default, but trivially disabled in notification settings.
      add :nudges_enabled, :boolean, null: false, default: true

      # Daily cap for the calm offline email fallback (max 1 nudge email/day),
      # mirroring last_mention_email_received_at.
      add :last_nudge_email_received_at, :utc_datetime
    end
  end
end
