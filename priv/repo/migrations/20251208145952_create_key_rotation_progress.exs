defmodule Mosslet.Repo.Local.Migrations.CreateKeyRotationProgress do
  use Ecto.Migration

  def change do
    create table(:key_rotation_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :schema_name, :string, null: false
      add :table_name, :string, null: false
      add :from_cipher_tag, :string, null: false
      add :to_cipher_tag, :string, null: false
      add :total_records, :integer, default: 0
      add :processed_records, :integer, default: 0
      add :failed_records, :integer, default: 0
      add :last_processed_id, :binary_id
      add :status, :string, default: "pending"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :error_log, :text

      timestamps()
    end

    create unique_index(:key_rotation_progress, [:schema_name, :from_cipher_tag, :to_cipher_tag])
    create index(:key_rotation_progress, [:status])
  end
end
