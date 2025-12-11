defmodule Mosslet.Repo.Local.Migrations.AddShareNoteToUserPosts do
  use Ecto.Migration

  def change do
    alter table(:user_posts) do
      add :share_note, :binary
    end
  end
end
