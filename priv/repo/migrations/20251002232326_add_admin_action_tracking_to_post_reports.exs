defmodule Mosslet.Repo.Local.Migrations.AddAdminActionTrackingToPostReports do
  use Ecto.Migration

  def change do
    alter table(:post_reports) do
      # ENCRYPTED FIELDS (sensitive admin reasoning - use server public key)
      # Encrypted with server public key for admin access
      add :admin_notes, :binary

      # HASHED FIELDS (for searching/filtering - use Cloak)
      # Hash for searching admin notes
      add :admin_notes_hash, :binary

      # PLAINTEXT FIELDS (system data for tracking)
      # Enum: none, warning, content_deleted, user_suspended
      add :admin_action, :string, null: true
      # 1-5 scale for violation severity
      add :severity_score, :integer, null: true
      # Which admin took action
      add :admin_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      # When admin action was taken
      add :admin_action_at, :utc_datetime

      # TRACKING FIELDS (for improved scoring)
      # How this report affects reporter score
      add :reporter_score_impact, :integer, default: 0
      # How this affects reported user score
      add :reported_user_score_impact, :integer, default: 0
    end

    # Index for admin queries
    create index(:post_reports, [:admin_action])
    create index(:post_reports, [:severity_score])
    create index(:post_reports, [:admin_user_id])
    create index(:post_reports, [:admin_action_at])

    # Index for scoring queries
    create index(:post_reports, [:reporter_id, :status, :admin_action])
    create index(:post_reports, [:reported_user_id, :status, :admin_action])
  end
end
