defmodule Mosslet.Repo.Local.Migrations.AllowNullJournalEntryBody do
  use Ecto.Migration

  def change do
    alter table(:journal_entries) do
      modify :body, :binary, null: true
    end
  end
end
