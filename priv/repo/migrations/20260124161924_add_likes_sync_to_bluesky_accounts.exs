defmodule Mosslet.Repo.Local.Migrations.AddLikesSyncToBlueskyAccounts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_accounts) do
      add :sync_likes, :boolean, default: false
      add :last_likes_cursor, :binary
    end
  end
end
