defmodule Mosslet.Repo.Local.Migrations.AddBlockedMonikerToGroupBlocks do
  use Ecto.Migration

  def change do
    alter table(:group_blocks) do
      add :blocked_moniker, :binary
    end
  end
end
