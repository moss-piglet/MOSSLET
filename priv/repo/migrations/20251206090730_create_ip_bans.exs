defmodule Mosslet.Repo.Local.Migrations.CreateIpBans do
  use Ecto.Migration

  def change do
    create table(:ip_bans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ip_hash, :binary, null: false
      add :reason, :binary
      add :source, :string, null: false
      add :expires_at, :binary
      add :request_count, :integer, default: 0
      add :metadata, :binary
      add :banned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:ip_bans, [:ip_hash])
    create index(:ip_bans, [:source])
  end
end
