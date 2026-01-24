defmodule Mosslet.Repo.Local.Migrations.AddImageAltTextsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :image_alt_texts, :binary
    end
  end
end
