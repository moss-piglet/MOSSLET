defmodule Mosslet.Repo.Local.Migrations.AddAvatarAltTextToConnections do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      add :avatar_alt_text, :binary
    end
  end
end
