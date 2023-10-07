defmodule Metamorphic.Repo.Local.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :string
      add :model, :string
      add :temperature, :float, default: 1.0
      add :frequency_penalty, :float, default: 0.0

      timestamps()
    end

    create index(:conversations, [:name])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :role, :string
      add :content, :string
      add :edited, :boolean, default: false, null: false
      add :status, :string

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:status])
  end
end
