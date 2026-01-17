defmodule Mosslet.Repo.Local.Migrations.AddRemovedByUserIdsToBookmarks do
  use Ecto.Migration

  def change do
    alter table(:bookmarks) do
      add :removed_by_user_ids, :binary
      add :removed_by_user_ids_hash, :binary
    end
  end
end
