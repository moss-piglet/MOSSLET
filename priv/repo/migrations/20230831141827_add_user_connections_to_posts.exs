defmodule Mosslet.Repo.Migrations.AddUserConnectionsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :shared_users, :map
    end
  end
end
