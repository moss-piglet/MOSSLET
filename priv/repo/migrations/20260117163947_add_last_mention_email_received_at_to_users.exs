defmodule Mosslet.Repo.Local.Migrations.AddLastMentionEmailReceivedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_mention_email_received_at, :utc_datetime
    end
  end
end
