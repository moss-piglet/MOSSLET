defmodule Mosslet.Repo.Local.Migrations.AddBlurThumbnailToMemories do
  use Ecto.Migration

  def change do
    alter table(:memories) do
      add :blur, :boolean, default: false
    end
  end
end
