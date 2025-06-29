defmodule Mosslet.Repo.Local.Migrations.CreateConnections do
  use Ecto.Migration

  def change do
    create table(:connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :binary
      add :name_hash, :binary
      add :email, :binary
      add :email_hash, :binary
      add :username, :binary
      add :username_hash, :binary

      timestamps()
    end

    create index(:connections, [:name_hash])
    create index(:connections, [:email_hash])
    create index(:connections, [:username_hash])

    create unique_index(:connections, [:user_id])
  end
end
