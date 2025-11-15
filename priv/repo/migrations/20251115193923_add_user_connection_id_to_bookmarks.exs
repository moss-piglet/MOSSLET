defmodule Mosslet.Repo.Local.Migrations.AddUserConnectionIdToBookmarks do
  use Ecto.Migration

  def change do
    # Bookmarks (user's saved posts with optional notes)
    alter table(:bookmarks) do
      # FOREIGN KEYS
      add :user_connection_id,
          references(:user_connections, type: :binary_id, on_delete: :delete_all)
    end

    create index(:bookmarks, [:user_connection_id])
  end
end
