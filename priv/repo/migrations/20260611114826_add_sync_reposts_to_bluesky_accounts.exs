defmodule Mosslet.Repo.Migrations.AddSyncRepostsToBlueskyAccounts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_accounts) do
      add :sync_reposts, :boolean, default: false, null: false
    end
  end
end
