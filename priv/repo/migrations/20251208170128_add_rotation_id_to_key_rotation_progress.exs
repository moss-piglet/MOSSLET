defmodule Mosslet.Repo.Local.Migrations.AddRotationIdToKeyRotationProgress do
  use Ecto.Migration

  def change do
    alter table(:key_rotation_progress) do
      add :rotation_id, :binary_id
    end

    create index(:key_rotation_progress, [:rotation_id])
  end
end
