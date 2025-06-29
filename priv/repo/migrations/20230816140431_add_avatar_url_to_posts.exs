defmodule Mosslet.Repo.Local.Migrations.AddAvatarUrlToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :avatar_url, :binary
    end
  end
end
