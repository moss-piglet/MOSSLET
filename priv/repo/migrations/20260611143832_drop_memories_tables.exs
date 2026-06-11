defmodule Mosslet.Repo.Migrations.DropMemoriesTables do
  use Ecto.Migration

  @moduledoc """
  Drops the legacy Memories feature tables (`remarks`, `user_memories`,
  `memories`). The Memories feature has been removed from the application
  (no routes, no UI, no nav). These tables are empty.

  Tables are dropped in FK-safe order: `remarks` and `user_memories` both
  reference `memories` (ON DELETE CASCADE), so they must go first.

  This migration is intentionally irreversible — recreating the full legacy
  schema is not worthwhile and there is no data to restore.
  """

  def up do
    drop table(:remarks)
    drop table(:user_memories)
    drop table(:memories)
  end

  def down do
    raise Ecto.MigrationError,
      message:
        "Dropping the legacy Memories tables is irreversible. " <>
          "Restore from a database backup if you need this data."
  end
end
