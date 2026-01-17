defmodule Mosslet.Repo.Local.Migrations.AddRemovedByUserIdsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :removed_by_user_ids, :binary
      add :removed_by_user_ids_hash, :binary
    end
  end
end
