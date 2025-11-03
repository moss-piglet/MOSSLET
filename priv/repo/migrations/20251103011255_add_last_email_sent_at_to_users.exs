defmodule Mosslet.Repo.Local.Migrations.AddLastEmailSentAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_email_notification_received_at, :utc_datetime
    end

    create index(:users, [:last_email_notification_received_at])
  end
end
