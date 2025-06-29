defmodule Mosslet.Repo.Local.Migrations.CreateOrgsMemberships do
  use Ecto.Migration

  def change do
    create table(:orgs_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false

      timestamps()
    end

    create unique_index(:orgs_memberships, [:org_id, :user_id])
  end
end
