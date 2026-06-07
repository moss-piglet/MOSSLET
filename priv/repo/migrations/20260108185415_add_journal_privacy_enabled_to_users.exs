defmodule Mosslet.Repo.Migrations.AddJournalPrivacyEnabledToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :journal_privacy_enabled, :boolean, default: false, null: false
    end
  end
end
