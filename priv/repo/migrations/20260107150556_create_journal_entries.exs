defmodule Mosslet.Repo.Local.Migrations.CreateJournalEntries do
  use Ecto.Migration

  def change do
    create table(:journal_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :binary
      add :title_hash, :binary
      add :body, :binary, null: false
      add :mood, :string
      add :is_favorite, :boolean, default: false, null: false
      add :word_count, :integer, default: 0
      add :entry_date, :date, null: false

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:journal_entries, [:user_id])
    create index(:journal_entries, [:user_id, :entry_date])
    create index(:journal_entries, [:user_id, :is_favorite])
  end
end
