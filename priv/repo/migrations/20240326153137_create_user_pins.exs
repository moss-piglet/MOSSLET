defmodule Mosslet.Repo.Local.Migrations.CreateUserPins do
  use Ecto.Migration

  def change do
    create table(:users_pins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :hashed_pin, :binary, null: false
      add :attempts, :integer, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:users_pins, [:user_id])
  end
end
