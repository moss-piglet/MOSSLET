defmodule Mosslet.Repo.Migrations.AddOrgCircleTypeToGroups do
  use Ecto.Migration

  def change do
    alter table(:groups) do
      # Classifies an org-scoped (business) circle (#229b):
      #   "team"      => official department/team circle (org owner/admin curated)
      #   "community" => member-made, social circle
      #
      # Meaningful ONLY when org_id is set; personal circles (org_id nil) leave
      # this nil. Stamped programmatically in the Groups context (never via cast)
      # — see Group schema + docs/BUSINESS_CIRCLES_DESIGN.md. Stored as a plain
      # string (mapped to an Ecto.Enum in the schema); not encrypted because the
      # classification is non-sensitive org structure, not member content.
      add :org_circle_type, :string, null: true
    end

    create index(:groups, [:org_circle_type])

    # Backfill: existing business circles predate the distinction, so classify
    # them as the lighter, non-official "community" tier. Personal circles
    # (org_id IS NULL) stay nil. Down: clear the value for business circles.
    execute(
      "UPDATE groups SET org_circle_type = 'community' WHERE org_id IS NOT NULL",
      "UPDATE groups SET org_circle_type = NULL WHERE org_id IS NOT NULL"
    )
  end
end
