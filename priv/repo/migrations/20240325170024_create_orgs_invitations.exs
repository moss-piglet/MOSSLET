defmodule Mosslet.Repo.Local.Migrations.CreateOrgsInvitations do
  use Ecto.Migration

  def change do
    create table(:orgs_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sent_to, :binary
      add :sent_to_hash, :binary
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:orgs_invitations, [:sent_to_hash, :org_id])
    create index(:orgs_invitations, [:user_id])
  end
end
