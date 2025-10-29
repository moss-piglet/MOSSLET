defmodule Mosslet.Repo.Local.Migrations.AddStatusVisibilityControlsToConnections do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      # Status Visibility Controls - shared based on user.visibility
      add :status_visibility, :string, default: "nobody", null: false
      # Encrypted lists of group/user IDs who can see status (encrypted with conn_key)
      add :status_visible_to_groups, :binary
      add :status_visible_to_users, :binary
      # Online presence controls
      add :show_online_presence, :boolean, default: false, null: false
      add :presence_visible_to_groups, :binary
      add :presence_visible_to_users, :binary
    end

    # Add indexes for status visibility queries
    create index(:connections, [:status_visibility])
    create index(:connections, [:show_online_presence])
  end
end
