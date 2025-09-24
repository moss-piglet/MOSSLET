defmodule Mosslet.Repo.Local.Migrations.AddParentReplyToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :parent_reply_id, references(:replies, type: :binary_id, on_delete: :delete_all)
      add :thread_depth, :integer, default: 0
    end

    create index(:replies, [:parent_reply_id])
    create index(:replies, [:post_id, :parent_reply_id])
    create index(:replies, [:post_id, :thread_depth])
  end
end
