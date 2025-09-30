defmodule Mosslet.Repo.Local.Migrations.ChangeFavsRepostsToEncryptedForPosts do
  use Ecto.Migration

  def up do
    alter table(:posts) do
      add :encrypted_favs_list, :binary
      add :encrypted_reposts_list, :binary
      add :favs_list_hash, :binary
      add :reposts_list_hash, :binary
    end

    create index(:posts, [:favs_list_hash])
    create index(:posts, [:reposts_list_hash])
  end

  def down do
    drop index(:posts, [:favs_list_hash])
    drop index(:posts, [:reposts_list_hash])

    alter table(:posts) do
      remove :encrypted_favs_list, :binary
      remove :encrypted_reposts_list, :binary
      remove :favs_list_hash, :binary
      remove :reposts_list_hash, :binary
    end
  end
end
