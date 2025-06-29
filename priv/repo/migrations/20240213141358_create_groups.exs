defmodule Mosslet.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :binary
      add :name_hash, :binary
      add :description, :binary
      add :hashed_password, :string
      add :require_password?, :boolean
      add :public?, :boolean

      timestamps()
    end
  end
end
