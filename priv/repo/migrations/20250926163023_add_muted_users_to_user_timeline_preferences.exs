defmodule Mosslet.Repo.Local.Migrations.AddMutedUsersToUSerTimelinePreference do
  use Ecto.Migration

  def change do
    alter table(:user_timeline_preferences) do
      add :muted_users, :binary
      add :muted_users_hash, :binary
    end
  end
end
