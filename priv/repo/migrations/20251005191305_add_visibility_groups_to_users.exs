defmodule Mosslet.Repo.Migrations.AddVisibilityGroupsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :visibility_groups, :map
    end
  end
end
