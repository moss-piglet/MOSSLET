defmodule Mosslet.Repo.Local.Migrations.AddGroupIdToMemories do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all)
      add :user_group_id, references(:user_groups, type: :binary_id, on_delete: :delete_all)
    end
  end
end
