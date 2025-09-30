defmodule Mosslet.Repo.Local.Migrations.ChangeVisibilityFieldsToEncryptedToPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      # Drop existing array columns since they're not being used yet
      remove :visibility_groups
      remove :visibility_users

      # Add them back as binary fields for Cloak encryption
      add :visibility_groups, :binary
      add :visibility_users, :binary

      # Add searchable hash fields for quick database queries
      add :visibility_groups_hash, :binary
      add :visibility_users_hash, :binary
    end

    # Create indexes on hash fields for faster searching
    create index(:posts, [:visibility_groups_hash])
    create index(:posts, [:visibility_users_hash])
  end

  def down do
    # Drop indexes
    drop index(:posts, [:visibility_groups_hash])
    drop index(:posts, [:visibility_users_hash])

    alter table(:posts) do
      # Remove new fields
      remove :visibility_groups_hash
      remove :visibility_users_hash
      remove :visibility_groups
      remove :visibility_users

      # Add back as original array type
      add :visibility_groups, {:array, :string}, default: []
      add :visibility_users, {:array, :string}, default: []
    end
  end
end
