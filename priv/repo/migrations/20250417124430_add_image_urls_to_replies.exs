defmodule Mosslet.Repo.Local.Migrations.AddImageUrlsToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :image_urls, :binary
    end
  end
end
