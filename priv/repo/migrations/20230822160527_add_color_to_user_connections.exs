defmodule Mosslet.Repo.Local.Migrations.AddColorToUserConnections do
  use Ecto.Migration

  def change do
    alter table(:user_connections) do
      add :color, :string
    end

    create index(:user_connections, [:color])
  end
end
