defmodule Mosslet.Repo.Local.Migrations.AddMessageReactions do
  use Ecto.Migration

  def change do
    create table(:message_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :binary, null: false

      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:message_reactions, [:message_id, :user_id])
    create index(:message_reactions, [:message_id])
  end
end
