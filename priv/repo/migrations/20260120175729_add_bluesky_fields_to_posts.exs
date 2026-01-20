defmodule Mosslet.Repo.Local.Migrations.AddBlueskyFieldsToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :source, :string, default: "mosslet", null: false
      add :external_uri, :binary
      add :external_cid, :binary

      add :bluesky_account_id,
          references(:bluesky_accounts, on_delete: :nilify_all, type: :binary_id)
    end

    create index(:posts, [:source])
    create index(:posts, [:bluesky_account_id])
  end
end
