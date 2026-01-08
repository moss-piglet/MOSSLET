defmodule Mosslet.Repo.Local.Migrations.CreateJournalInsights do
  use Ecto.Migration

  def change do
    create table(:journal_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :insight, :binary, null: false
      add :generated_at, :utc_datetime_usec, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:journal_insights, [:user_id])
  end
end
