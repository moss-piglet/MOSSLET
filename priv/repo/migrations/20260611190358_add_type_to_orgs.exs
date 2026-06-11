defmodule Mosslet.Repo.Migrations.AddTypeToOrgs do
  use Ecto.Migration

  def change do
    alter table(:orgs) do
      add :type, :string, default: "family", null: false
    end
  end
end
