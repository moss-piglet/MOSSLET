defmodule Mosslet.Repo.SQLite.Migrations.CreateCacheTables do
  use Ecto.Migration

  def change do
    create table(:cached_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :resource_type, :string, null: false
      add :resource_id, :binary, null: false
      add :encrypted_data, :binary, null: false
      add :encrypted_key, :binary
      add :etag, :string
      add :cached_at, :utc_datetime, null: false
    end

    create unique_index(:cached_items, [:resource_type, :resource_id])
    create index(:cached_items, [:resource_type])
    create index(:cached_items, [:cached_at])

    create table(:sync_queue, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary
      add :payload, :binary, null: false
      add :status, :string, null: false, default: "pending"
      add :retry_count, :integer, null: false, default: 0
      add :error_message, :string
      add :queued_at, :utc_datetime, null: false
      add :synced_at, :utc_datetime
    end

    create index(:sync_queue, [:status])
    create index(:sync_queue, [:queued_at])

    create table(:local_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :string

      timestamps()
    end

    create unique_index(:local_settings, [:key])
  end
end
