defmodule Mosslet.Repo.Local.Migrations.AddReplyNotificationFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_reply_notification_received_at, :utc_datetime
      add :last_replies_seen_at, :utc_datetime
    end

    alter table(:posts) do
      add :last_reply_at, :utc_datetime
    end
  end
end
