defmodule Mosslet.Repo.Local.Migrations.AddContentDeletionTrackingToPostReports do
  use Ecto.Migration

  def change do
    alter table(:post_reports) do
      # Boolean flags to track if content was deleted by admin action
      add :post_deleted?, :boolean, default: false, null: false
      add :reply_deleted?, :boolean, default: false, null: false
    end

    # Index for querying deletion patterns
    create index(:post_reports, [:post_deleted?])
    create index(:post_reports, [:reply_deleted?])
  end
end
