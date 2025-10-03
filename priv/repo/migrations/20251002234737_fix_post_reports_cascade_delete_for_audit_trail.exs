defmodule Mosslet.Repo.Local.Migrations.FixPostReportsCascadeDeleteForAuditTrail do
  use Ecto.Migration

  def change do
    # Remove the CASCADE delete constraints and replace with SET NULL
    # This preserves reports for audit trail when posts/replies are deleted

    # Drop existing foreign key constraints with CASCADE
    drop constraint(:post_reports, "post_reports_post_id_fkey")
    drop constraint(:post_reports, "post_reports_reply_id_fkey")

    # Add new foreign key constraints with SET NULL for audit trail preservation
    alter table(:post_reports) do
      modify :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all), null: true
      modify :reply_id, references(:replies, type: :binary_id, on_delete: :nilify_all), null: true
    end

    # Keep the existing indexes for performance
    # They already exist so no need to recreate them
  end
end
