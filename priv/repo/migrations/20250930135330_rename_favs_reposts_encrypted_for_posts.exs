defmodule Mosslet.Repo.Local.Migrations.RenameFavsRepostsEncryptedForPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      remove :favs_list
      remove :reposts_list
    end

    rename table(:posts), :encrypted_favs_list, to: :favs_list
    rename table(:posts), :encrypted_reposts_list, to: :reposts_list
  end
end
