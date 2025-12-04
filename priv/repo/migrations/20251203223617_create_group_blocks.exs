defmodule Mosslet.Repo.Local.Migrations.CreateGroupBlocks do
  use Ecto.Migration

  def change do
    create table(:group_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reason, :binary
      add :group_id, references(:groups, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :blocked_by_id, references(:users, on_delete: :nilify_all, type: :binary_id),
        null: false

      timestamps()
    end

    create unique_index(:group_blocks, [:group_id, :user_id])
    create index(:group_blocks, [:user_id])
    create index(:group_blocks, [:blocked_by_id])
  end
end
