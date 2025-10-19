defmodule Mosslet.Repo.Local.Migrations.AddStatusVisibilityControlsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Status Visibility Controls - Privacy-first presence system
      add :status_visibility, :string, default: "nobody", null: false
      # Online presence controls (separate from status message)
      add :show_online_presence, :boolean, default: false, null: false
    end
    
    # Add index for status visibility queries
    create index(:users, [:status_visibility])
    create index(:users, [:show_online_presence])
  end
end
