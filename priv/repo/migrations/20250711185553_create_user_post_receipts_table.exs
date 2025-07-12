defmodule Mosslet.Repo.Local.Migrations.CreateUserPostReceiptsTable do
  use Ecto.Migration

  def change do
    create table(:user_post_receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :user_post_id, references(:user_posts, type: :binary_id, on_delete: :delete_all)
      add :is_read?, :boolean
      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:user_post_receipts, [:id])
    create index(:user_post_receipts, [:is_read?])
    create index(:user_post_receipts, [:read_at])
    create unique_index(:user_post_receipts, [:user_id, :user_post_id])
  end
end
