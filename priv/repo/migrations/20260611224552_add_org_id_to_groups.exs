defmodule Mosslet.Repo.Migrations.AddOrgIdToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      # Nullable: nil => personal circle (unchanged behavior); set => business
      # circle scoped to a :business org. On org deletion we NILIFY rather than
      # cascade-delete so member content is never silently destroyed
      # (see docs/BUSINESS_CIRCLES_DESIGN.md §8, Q3).
      add :org_id, references(:orgs, type: :binary_id, on_delete: :nilify_all), null: true
    end

    create index(:groups, [:org_id])
  end
end
