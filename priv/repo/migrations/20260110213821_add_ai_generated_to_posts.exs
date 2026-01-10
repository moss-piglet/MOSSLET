defmodule Mosslet.Repo.Local.Migrations.AddAiGeneratedToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :ai_generated, :boolean, default: false, null: false
    end
  end
end
