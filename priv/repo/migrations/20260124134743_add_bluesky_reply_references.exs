defmodule Mosslet.Repo.Local.Migrations.AddBlueskyReplyReferences do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :external_reply_root_uri, :binary
      add :external_reply_root_cid, :binary
      add :external_reply_parent_uri, :binary
      add :external_reply_parent_cid, :binary
    end

    alter table(:replies) do
      add :external_uri, :binary
      add :external_cid, :binary
      add :external_reply_root_uri, :binary
      add :external_reply_root_cid, :binary
      add :external_reply_parent_uri, :binary
      add :external_reply_parent_cid, :binary

      add :bluesky_account_id,
          references(:bluesky_accounts, type: :binary_id, on_delete: :nilify_all)

      add :source, :string, default: "mosslet"
    end

    create index(:replies, [:external_uri])
    create index(:replies, [:bluesky_account_id])
    create index(:replies, [:source])
  end
end
