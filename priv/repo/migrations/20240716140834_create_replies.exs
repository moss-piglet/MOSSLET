defmodule Mosslet.Repo.Local.Migrations.CreateReplies do
  use Ecto.Migration

  def change do
    create table(:replies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :username, :binary, null: false
      add :username_hash, :binary, null: false
      add :body, :binary
      add :visibility, :string, null: false

      timestamps()
    end

    create index(:replies, [:username_hash])
    create unique_index(:replies, [:id, :user_id])
    create unique_index(:replies, [:id, :post_id])
  end
end
