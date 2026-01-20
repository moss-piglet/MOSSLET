defmodule Mosslet.Repo.Local.Migrations.CreateBlueskyAccounts do
  use Ecto.Migration

  def change do
    create table(:bluesky_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      add :did, :binary
      add :did_hash, :binary
      add :handle, :binary
      add :handle_hash, :binary

      add :access_jwt, :binary
      add :refresh_jwt, :binary
      add :signing_key, :binary

      add :pds_url, :binary
      add :pds_url_hash, :binary

      add :sync_enabled, :boolean, default: false, null: false
      add :sync_posts_to_bsky, :boolean, default: false, null: false
      add :sync_posts_from_bsky, :boolean, default: false, null: false
      add :auto_delete_from_bsky, :boolean, default: false, null: false

      add :last_synced_at, :utc_datetime
      add :last_cursor, :binary

      timestamps()
    end

    create unique_index(:bluesky_accounts, [:user_id])
    create index(:bluesky_accounts, [:did_hash])
    create index(:bluesky_accounts, [:handle_hash])
  end
end
