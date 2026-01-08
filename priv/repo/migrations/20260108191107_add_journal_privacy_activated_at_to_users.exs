defmodule Mosslet.Repo.Local.Migrations.AddJournalPrivacyActivatedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :journal_privacy_activated_at, :utc_datetime
    end
  end
end
