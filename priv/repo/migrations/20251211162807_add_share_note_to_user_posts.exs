defmodule Mosslet.Repo.Migrations.AddShareNoteToUserPosts do
  use Ecto.Migration

  def change do
    alter table(:user_posts) do
      add :share_note, :binary
    end
  end
end
