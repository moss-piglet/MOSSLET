defmodule Mosslet.Repo.Local.Migrations.AddRequestUserIdToUserConnections do
  use Ecto.Migration

  def change do
    alter table(:user_connections) do
      add :reverse_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create unique_index(:user_connections, [:user_id, :reverse_user_id])
    create unique_index(:user_connections, [:reverse_user_id, :user_id])
  end
end
