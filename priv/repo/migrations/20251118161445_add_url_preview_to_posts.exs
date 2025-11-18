defmodule Mosslet.Repo.Local.Migrations.AddUrlPreviewToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :url_preview, :binary
      add :url_preview_fetched_at, :binary
    end
  end
end
