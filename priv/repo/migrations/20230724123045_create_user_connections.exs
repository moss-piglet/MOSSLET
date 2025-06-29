defmodule Mosslet.Repo.Local.Migrations.CreateUserConnections do
  use Ecto.Migration

  def change do
    create table(:user_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :connection_id, references(:connections, type: :binary_id, on_delete: :delete_all),
        null: false

      add :key, :binary, null: false
      add :label, :binary
      add :photos?, :boolean
      add :zen?, :boolean
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create index(:user_connections, [:connection_id])

    create unique_index(:user_connections, [:connection_id, :user_id])
  end
end
