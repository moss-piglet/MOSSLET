defmodule Mosslet.Repo.Local.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string
      add :user_type, :string, default: "user"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :target_user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :metadata, :map

      timestamps()
    end

    create index(:logs, [:action])
    create index(:logs, [:user_type])
    create index(:logs, [:user_id])
    create index(:logs, [:target_user_id])
  end
end
