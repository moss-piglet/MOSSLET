defmodule Mosslet.Repo.Local.Migrations.CreateUserProfileAndAddPubKeyToConnection do
  use Ecto.Migration

  def change do
    alter table(:connections) do
      add :profile, :map
    end
  end
end
