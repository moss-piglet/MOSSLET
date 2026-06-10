defmodule Mosslet.Repo.Migrations.AddAccessJwtExpiresAtToBlueskyAccounts do
  use Ecto.Migration

  def change do
    alter table(:bluesky_accounts) do
      add :access_jwt_expires_at, :utc_datetime
    end
  end
end
