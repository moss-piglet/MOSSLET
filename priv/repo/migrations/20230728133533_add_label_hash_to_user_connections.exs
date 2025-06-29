defmodule Mosslet.Repo.Local.Migrations.AddLabelHashToUserConnections do
  use Ecto.Migration

  def change do
    alter table(:user_connections) do
      add :label_hash, :binary, null: false
    end

    create index(:user_connections, [:label_hash])
  end
end
