defmodule Mosslet.Repo.Local.Migrations.AddImageUrlsUpdatedAtToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :image_urls_updated_at, :naive_datetime
    end
  end
end
