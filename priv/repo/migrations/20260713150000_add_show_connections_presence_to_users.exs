defmodule Mosslet.Repo.Migrations.AddShowConnectionsPresenceToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :show_connections_presence, :boolean, default: false, null: false
    end
  end
end
