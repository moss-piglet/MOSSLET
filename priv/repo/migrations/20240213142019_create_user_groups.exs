defmodule Mosslet.Repo.Migrations.CreateUserGroups do
  use Ecto.Migration

  def change do
    create table(:user_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :binary
      add :role, :string
      add :name, :binary
      add :name_hash, :binary
      add :moniker, :binary
      add :confirmed_at, :naive_datetime

      timestamps()
    end
  end
end
