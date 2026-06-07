defmodule Mosslet.Repo.Migrations.AddShowDmLinkPreviewsToUserTimelinePreferences do
  use Ecto.Migration

  def change do
    alter table(:user_timeline_preferences) do
      add :show_dm_link_previews, :boolean, default: false, null: false
    end
  end
end
