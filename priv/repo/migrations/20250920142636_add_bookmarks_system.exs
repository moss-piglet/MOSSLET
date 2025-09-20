defmodule Mosslet.Repo.Local.Migrations.AddBookmarksSystem do
  use Ecto.Migration

  def change do
    # Bookmark categories (user-defined categories for organizing bookmarks)
    create table(:bookmark_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (Cloak - user-specific but searchable)
      # Category name (Cloak encrypted)
      add :name, :binary
      # Searchable hash
      add :name_hash, :binary
      # Category description (Cloak encrypted)
      add :description, :binary

      # PLAINTEXT FIELDS (system data, not sensitive)
      # Color enum
      add :color, :string
      # Hero icon name
      add :icon, :string

      # FOREIGN KEYS
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    # Bookmarks (user's saved posts with optional notes)
    create table(:bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (using post_key - same encryption as post.body)
      # User's private notes (enacl encrypted with post_key)
      add :notes, :binary

      # HASHED FIELDS (searchable if needed)
      # Searchable hash for notes
      add :notes_hash, :binary

      # FOREIGN KEYS
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :category_id, references(:bookmark_categories, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    # Indexes for performance and constraints
    create unique_index(:bookmarks, [:user_id, :post_id], name: :bookmarks_user_post_index)
    create index(:bookmarks, [:user_id])
    create index(:bookmarks, [:post_id])
    create index(:bookmarks, [:category_id])

    create index(:bookmark_categories, [:user_id])
    # For searching categories by name
    create index(:bookmark_categories, [:user_id, :name_hash])
  end
end
