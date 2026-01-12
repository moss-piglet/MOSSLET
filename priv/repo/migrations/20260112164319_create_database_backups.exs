defmodule Mosslet.Repo.Local.Migrations.CreateDatabaseBackups do
  use Ecto.Migration

  def change do
    create table(:database_backups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :storage_key, :string, null: false
      add :size_bytes, :bigint, null: false
      add :status, :string, null: false, default: "completed"
      add :backup_type, :string, null: false, default: "scheduled"
      add :error_message, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:database_backups, [:status])
    create index(:database_backups, [:backup_type])
    create index(:database_backups, [:inserted_at])
  end
end
