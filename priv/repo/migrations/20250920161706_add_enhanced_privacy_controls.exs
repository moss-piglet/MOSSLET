defmodule Mosslet.Repo.Local.Migrations.AddEnhancedPrivacyControls do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      # Enhanced privacy controls - granular visibility
      # Connection groups that can see this post
      add :visibility_groups, {:array, :string}, default: []
      # Specific users that can see this post
      add :visibility_users, {:array, :binary_id}, default: []

      # Interaction controls
      # Whether replies are allowed
      add :allow_replies, :boolean, default: true
      # Whether sharing/reposts are allowed
      add :allow_shares, :boolean, default: true
      # Whether bookmarking is allowed
      add :allow_bookmarks, :boolean, default: true
      # Must be connection to reply
      add :require_follow_to_reply, :boolean, default: false

      # Content flags
      # Mature content flag
      add :mature_content, :boolean, default: false
      # For temporary posts
      add :is_ephemeral, :boolean, default: false

      # Post expiration - auto-deletion after time
      # When post gets auto-deleted
      add :expires_at, :naive_datetime

      # Future-proofing
      # Don't federate (future federation)
      add :local_only, :boolean, default: false
    end

    # Add indexes for privacy filtering performance
    create index(:posts, [:visibility, :inserted_at])
    create index(:posts, [:expires_at])
    create index(:posts, [:allow_replies])
    create index(:posts, [:allow_shares])
    create index(:posts, [:allow_bookmarks])
    create index(:posts, [:mature_content])
    create index(:posts, [:is_ephemeral])
    create index(:posts, [:require_follow_to_reply])
    create index(:posts, [:local_only])
  end
end
