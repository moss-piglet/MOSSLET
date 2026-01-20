defmodule Mosslet.Repo.Local.Migrations.AddImportVisibilityToBlueskyAccounts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_accounts) do
      add :import_visibility, :string, default: "private"
    end
  end
end
