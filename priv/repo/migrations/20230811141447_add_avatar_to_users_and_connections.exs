defmodule Mosslet.Repo.Local.Migrations.AddAvatarToUsersAndConnections do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_url, :binary
      add :avatar_url_hash, :binary
    end

    alter table(:connections) do
      add :avatar_url, :binary
      add :avatar_url_hash, :binary
    end
  end
end
