defmodule Mosslet.Repo.Local.Migrations.AddMoodInsightsEnabledToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :mood_insights_enabled, :boolean, default: false, null: false
    end
  end
end
