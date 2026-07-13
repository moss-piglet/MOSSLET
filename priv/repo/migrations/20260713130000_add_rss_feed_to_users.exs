defmodule Mosslet.Repo.Migrations.AddRssFeedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :rss_feed_enabled, :boolean, default: false, null: false
      add :rss_feed_token, :string
    end

    create unique_index(:users, [:rss_feed_token])
  end
end
