defmodule Mosslet.Repo.Local.Migrations.AddJournalBooks do
  use Ecto.Migration

  def change do
    create table(:journal_books, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :binary, null: false
      add :title_hash, :binary
      add :description, :binary
      add :cover_color, :string, default: "emerald"
      add :cover_image_url, :binary

      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create index(:journal_books, [:user_id])

    alter table(:journal_entries) do
      add :book_id, references(:journal_books, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:journal_entries, [:book_id])
    create index(:journal_entries, [:user_id, :book_id])
  end
end
