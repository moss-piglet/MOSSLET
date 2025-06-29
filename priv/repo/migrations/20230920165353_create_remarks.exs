defmodule Mosslet.Repo.Local.Migrations.CreateRemarks do
  use Ecto.Migration

  def change do
    create table(:remarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :memory_id, references(:memories, type: :binary_id, on_delete: :delete_all)
      add :body, :binary
      add :mood, :string
      add :visibility, :string, null: false

      timestamps()
    end

    create unique_index(:remarks, [:id, :user_id])
    create unique_index(:remarks, [:id, :memory_id])
  end
end
