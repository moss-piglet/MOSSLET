defmodule Mosslet.Repo.Migrations.AddNeedsReauthToBlueskyAccounts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_accounts) do
      add :needs_reauth, :boolean, default: false, null: false
    end
  end
end
