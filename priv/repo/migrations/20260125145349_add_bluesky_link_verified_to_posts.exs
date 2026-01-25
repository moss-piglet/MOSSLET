defmodule Mosslet.Repo.Local.Migrations.AddBlueskyLinkVerifiedToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :bluesky_link_verified, :boolean, default: true
    end

    alter table(:replies) do
      add :bluesky_link_verified, :boolean, default: true
    end
  end
end
