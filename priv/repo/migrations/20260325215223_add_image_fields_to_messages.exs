defmodule Mosslet.Repo.Local.Migrations.AddImageFieldsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :image_url, :binary
      add :image_key, :binary
    end
  end
end
