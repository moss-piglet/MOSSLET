defmodule Mosslet.Repo.Local.Migrations.AddContentWarningsSystem do
  use Ecto.Migration

  def change do
    # Add content warning fields to existing posts table
    alter table(:posts) do
      # ENCRYPTED FIELDS (user-generated content - use post_key for consistency)
      # Custom warning text (enacl encrypted with post_key)
      add :content_warning_text, :binary

      # SEARCHABLE FIELDS (for filtering/searching - use Cloak)
      # Category like "mental_health", etc (Cloak encrypted)
      add :content_warning_category, :binary
      # Searchable hash for filtering by warning type
      add :content_warning_hash, :binary

      # PLAINTEXT FIELDS (system flags for quick filtering)
      # Quick filter flag
      add :has_content_warning, :boolean, default: false
    end

    # Content warning categories (predefined and user-custom categories)
    create table(:content_warning_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # ENCRYPTED FIELDS (category data - use Cloak for searchability)
      # Category name (Cloak encrypted)
      add :name, :binary
      # Searchable hash
      add :name_hash, :binary
      # Category description (Cloak encrypted)
      add :description, :binary

      # PLAINTEXT FIELDS (system data)
      # System vs user-defined
      add :is_system_category, :boolean, default: false
      # Display color
      add :color, :string, default: "amber"
      # Display icon
      add :icon, :string, default: "hero-exclamation-triangle"
      # low, medium, high
      add :severity_level, :string, default: "medium"

      # FOREIGN KEYS (null for system categories)
      # null for system categories
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    # Indexes for performance
    create index(:posts, [:has_content_warning])
    create index(:posts, [:content_warning_hash])
    # For filtered timelines
    create index(:posts, [:has_content_warning, :inserted_at])

    create index(:content_warning_categories, [:is_system_category])
    # For user categories
    create index(:content_warning_categories, [:user_id])
    # For searching categories
    create index(:content_warning_categories, [:name_hash])
    # For filtering by severity
    create index(:content_warning_categories, [:severity_level])
  end
end
