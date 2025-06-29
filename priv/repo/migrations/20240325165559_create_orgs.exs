defmodule Mosslet.Repo.Local.Migrations.CreateOrgs do
  use Ecto.Migration

  def change do
    create table(:orgs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :binary, null: false
      add :name_hash, :binary, null: false
      add :slug, :citext, null: false

      timestamps()
    end

    create unique_index(:orgs, [:slug])
  end
end
