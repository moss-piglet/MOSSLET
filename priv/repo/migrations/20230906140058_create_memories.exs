defmodule Mosslet.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :memory_url, :binary
      add :memory_url_hash, :binary
      add :username, :binary, null: false
      add :username_hash, :binary, null: false
      add :favs_list, {:array, :binary_id}
      add :favs_count, :integer
      add :visibility, :string, null: false
      add :size, :decimal
      add :type, :string
      add :blurb, :binary
      add :shared_users, :map

      timestamps()
    end

    create index(:memories, [:username_hash])
    create index(:memories, [:favs_list])
    create index(:memories, [:visibility])

    create unique_index(:memories, [:id, :user_id])
  end
end
