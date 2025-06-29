defmodule Mosslet.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # hashed_* means it is unknowable/unsearchable
    # *_hash means it is a hash that can be searched

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :binary, null: false
      add :email_hash, :binary, null: false
      add :hashed_password, :string, null: false
      add :is_admin?, :boolean, null: false, default: false
      add :is_suspended?, :boolean, null: false, default: false
      add :is_deleted?, :boolean, null: false, default: false
      add :is_onboarded?, :boolean, null: false, default: false
      add :is_forgot_pwd?, :boolean, null: false, default: false
      add :key_hash, :binary, null: false
      add :key, :binary
      add :key_pair, {:map, :binary}, null: false
      add :name, :binary
      add :name_hash, :binary
      add :username, :binary, null: false
      add :username_hash, :binary, null: false
      add :user_key, :binary, null: false
      add :conn_key, :binary, null: false
      add :visibility, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email_hash])
    create unique_index(:users, [:username_hash])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :binary
      add :sent_to_hash, :binary
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:users_totps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :secret, :binary
      add :backup_codes, {:map, :binary}

      timestamps()
    end

    create unique_index(:users_totps, [:user_id])
  end
end
