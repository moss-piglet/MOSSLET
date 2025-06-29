defmodule Mosslet.Repo.Local.Migrations.AddImageUrlsUpdatedAtToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :image_urls_updated_at, :naive_datetime
    end
  end
end
