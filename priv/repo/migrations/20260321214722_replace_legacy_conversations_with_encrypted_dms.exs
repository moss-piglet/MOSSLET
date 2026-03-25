defmodule Mosslet.Repo.Local.Migrations.ReplaceLegacyConversationsWithEncryptedDms do
  use Ecto.Migration

  def up do
    drop_if_exists table(:messages)
    drop_if_exists table(:conversations)

    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_connection_id,
          references(:user_connections, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:conversations, [:user_connection_id])

    create table(:user_conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :binary, null: false
      add :last_read_at, :naive_datetime
      add :archived, :boolean, default: false, null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:user_conversations, [:conversation_id])
    create index(:user_conversations, [:user_id])
    create unique_index(:user_conversations, [:conversation_id, :user_id])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :binary, null: false
      add :edited, :boolean, default: false, null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:sender_id])
    create index(:messages, [:conversation_id, :inserted_at])
  end

  def down do
    drop_if_exists table(:messages)
    drop_if_exists table(:user_conversations)
    drop_if_exists table(:conversations)

    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :name, :binary
      add :model, :binary
      add :temperature, :float, default: 1.0
      add :frequency_penalty, :float, default: 0.0

      timestamps()
    end

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :nothing),
        null: false

      add :role, :string
      add :content, :binary
      add :edited, :boolean, default: false, null: false
      add :status, :string
      add :tokens, :decimal

      timestamps()
    end
  end
end
