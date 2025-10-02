defmodule Mosslet.Repo.Migrations.AddReplyIdToPostReports do
  @moduledoc """
  Adds reply_id field to post_reports table to distinguish between post and reply reports.

  This allows admins to:
  - Know if a report is about a post or a reply
  - Take targeted action (delete reply vs delete post)
  - Better understand the context of reports
  """
  use Ecto.Migration

  def change do
    alter table(:post_reports) do
      # Add optional reply_id field
      # When null: report is about the post
      # When present: report is about the specific reply
      add :reply_id, references(:replies, type: :binary_id, on_delete: :delete_all), null: true
    end

    # Add index for efficient querying of reply reports
    create index(:post_reports, [:reply_id])

    # Add composite index for unique reply reports per reporter
    create unique_index(:post_reports, [:reporter_id, :reply_id],
             name: :post_reports_reporter_reply_index,
             where: "reply_id IS NOT NULL"
           )
  end
end
