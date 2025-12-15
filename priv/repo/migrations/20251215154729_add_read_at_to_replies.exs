defmodule Mosslet.Repo.Local.Migrations.AddReadAtToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :read_at, :utc_datetime
    end

    create index(:replies, [:post_id, :read_at])
  end
end
