defmodule Mosslet.Repo.Migrations.AddRssFeedVisibilityToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Controls who sees the "copy RSS feed link" affordance on this user's
      # public posts. The feed itself is always public-content-only. This is a
      # discoverability preference, not a content gate:
      #   :private     -> nobody sees the button (owner shares link manually)
      #   :connections -> only the user's connections see the button
      #   :public      -> everyone sees the button on the user's public posts
      add :rss_feed_visibility, :string, default: "private", null: false
    end
  end
end
