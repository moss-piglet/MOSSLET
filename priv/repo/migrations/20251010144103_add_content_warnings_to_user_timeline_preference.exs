defmodule Mosslet.Repo.Local.Migrations.AddContentWarningsToUserTimelinePreference do
  use Ecto.Migration

  def change do
    alter table(:user_timeline_preferences) do
      add(:hide_content_warnings, :boolean, default: false)
    end
  end
end
