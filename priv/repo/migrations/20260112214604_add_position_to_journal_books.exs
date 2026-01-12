defmodule Mosslet.Repo.Local.Migrations.AddPositionToJournalBooks do
  use Ecto.Migration

  def change do
    alter table(:journal_books) do
      add :position, :integer, default: 0
    end

    create index(:journal_books, [:user_id, :position])
  end
end
