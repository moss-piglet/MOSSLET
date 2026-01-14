defmodule Mosslet.Repo.SQLite.Migrations.AddUserIdToCachedItems do
  use Ecto.Migration

  def change do
    alter table(:cached_items) do
      add :user_id, :binary_id
    end

    drop unique_index(:cached_items, [:resource_type, :resource_id])

    create unique_index(:cached_items, [:resource_type, :resource_id, :user_id],
      name: :cached_items_resource_user_unique
    )

    create index(:cached_items, [:user_id])
    create index(:cached_items, [:resource_type, :user_id])
  end
end
