defmodule Mosslet.Repo.Local.Migrations.CreateUserMemories do
  use Ecto.Migration

  def change do
    create table(:user_memories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :memory_id, references(:memories, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :binary, null: false

      timestamps()
    end

    create unique_index(:user_memories, [:memory_id, :user_id])
  end
end
