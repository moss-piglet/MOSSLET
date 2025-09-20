defmodule Mosslet.Repo.Local.Migrations.AddTimelineNavigationSystem do
  use Ecto.Migration

  def change do
    # Create user preferences for timeline navigation
    create table(:user_timeline_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Timeline tab preferences (plaintext - UI preferences, not sensitive)
      # Default timeline tab
      add :default_tab, :string, default: "home"

      add :tab_order, {:array, :string},
        default: ["home", "connections", "groups", "bookmarks", "discover"]

      # Tabs user has hidden
      add :hidden_tabs, {:array, :string}, default: []

      # View preferences (plaintext - UI settings)
      # How many posts to load
      add :posts_per_page, :integer, default: 25
      # Auto-refresh timeline
      add :auto_refresh, :boolean, default: true
      # Show counts on tabs
      add :show_post_counts, :boolean, default: true
      # Hide shared/reposted content
      add :hide_reposts, :boolean, default: false
      # Hide mature content
      add :hide_mature_content, :boolean, default: false

      # Content filtering preferences (encrypted - potentially sensitive)
      # Encrypted list of muted keywords (user_key)
      add :mute_keywords, :binary
      # Hash for keyword matching
      add :mute_keywords_hash, :binary

      timestamps()
    end

    # Create timeline view cache table for performance
    create table(:timeline_view_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Cache data for different timeline tabs
      # "home", "connections", etc.
      add :tab_name, :string, null: false
      # Cached post count for tab
      add :post_count, :integer, default: 0
      # When newest post was created
      add :last_post_at, :naive_datetime
      # When cache should be refreshed
      add :cache_expires_at, :naive_datetime
      # JSON cache of post IDs/metadata
      add :cache_data, :text

      timestamps()
    end

    # Add indexes for timeline navigation performance
    create unique_index(:user_timeline_preferences, [:user_id])
    create unique_index(:timeline_view_cache, [:user_id, :tab_name])
    create index(:timeline_view_cache, [:cache_expires_at])
    create index(:timeline_view_cache, [:last_post_at])
    create index(:user_timeline_preferences, [:default_tab])
  end
end
