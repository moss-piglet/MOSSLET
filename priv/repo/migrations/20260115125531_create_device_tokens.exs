defmodule Mosslet.Repo.Local.Migrations.CreateDeviceTokens do
  use Ecto.Migration

  def change do
    create table(:device_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :token, :binary, null: false
      add :token_hash, :binary, null: false
      add :platform, :string, null: false
      add :device_name, :binary
      add :app_version, :string
      add :os_version, :string
      add :active, :boolean, default: true, null: false
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:device_tokens, [:user_id])
    create unique_index(:device_tokens, [:token_hash])
    create index(:device_tokens, [:platform])
    create index(:device_tokens, [:active])
  end
end
