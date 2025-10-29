defmodule Mosslet.Repo.Local.Migrations.AddStatusPresenceVisibleToGroupsUserIdsToConnections do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      add :status_visible_to_groups_user_ids, :binary
      add :presence_visible_to_groups_user_ids, :binary
    end
  end
end
