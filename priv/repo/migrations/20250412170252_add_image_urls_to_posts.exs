defmodule Mosslet.Repo.Local.Migrations.AddImageUrlsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :image_urls, :binary
    end
  end
end
