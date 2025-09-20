defmodule Mosslet.Repo.Local.Migrations.AddContentModerationSystem do
  use Ecto.Migration

  def change do
    # Post reports (users reporting harmful content)
    create table(:post_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (user-generated sensitive data - use enacl with user keys)
      # Report reason (enacl encrypted)
      add :reason, :binary
      # Additional details (enacl encrypted)
      add :details, :binary

      # HASHED FIELDS (for admin searching/filtering - use Cloak)
      # Searchable hash for categorizing reports
      add :reason_hash, :binary

      # PLAINTEXT FIELDS (system data for moderation workflow)
      # pending, reviewed, resolved, dismissed
      add :status, :string, default: "pending"
      # low, medium, high, critical
      add :severity, :string, default: "low"
      # content, harassment, spam, other
      add :report_type, :string, default: "content"

      # FOREIGN KEYS
      add :reporter_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :reported_user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    # User blocks (users blocking other users)
    create table(:user_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (user-generated data - use enacl with user keys)
      # Why they blocked (enacl encrypted)
      add :reason, :binary

      # PLAINTEXT FIELDS (system data)
      # full, posts_only, replies_only
      add :block_type, :string, default: "full"

      # FOREIGN KEYS
      add :blocker_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :blocked_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    # Post hides (users hiding specific posts)
    create table(:post_hides, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (user preference data - use enacl with user keys)
      # Why they hid it (enacl encrypted)
      add :reason, :binary

      # PLAINTEXT FIELDS (system data)
      # post, user_posts, similar_content
      add :hide_type, :string, default: "post"

      # FOREIGN KEYS
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    # Indexes for performance and constraints
    create index(:post_reports, [:status, :severity])
    create index(:post_reports, [:reported_user_id])
    create index(:post_reports, [:reporter_id])
    create index(:post_reports, [:post_id])
    # For searching reports by type
    create index(:post_reports, [:reason_hash])
    # For chronological sorting
    create index(:post_reports, [:inserted_at])

    create unique_index(:user_blocks, [:blocker_id, :blocked_id])
    # For checking if user is blocked
    create index(:user_blocks, [:blocked_id])
    # For listing user's blocks
    create index(:user_blocks, [:blocker_id])

    create unique_index(:post_hides, [:user_id, :post_id])
    # For filtering hidden posts
    create index(:post_hides, [:user_id])
    # For checking post visibility
    create index(:post_hides, [:post_id])
  end
end
