defmodule Mosslet.Repo.Local.Migrations.AddOrgsToLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add(:org_id, references(:orgs, type: :binary_id, on_delete: :delete_all))
    end

    create(index(:logs, [:org_id]))
  end
end
