defmodule Mosslet.Repo.Migrations.AddCreatedByIdToOrgs do
  use Ecto.Migration

  @moduledoc """
  Adds an explicit `created_by_id` owner reference to orgs.

  "Ownership" (used by the org-limit + multi-business gating in
  `Mosslet.Orgs`) is defined as `orgs.created_by_id == user.id`, set at creation
  time. We intentionally avoid conflating ownership with the `:admin` membership
  role (a user can be promoted to admin of an org they did not create).

  The column is nullable so the change is non-destructive for any pre-existing
  orgs; we backfill from the earliest admin membership (the creator) where one
  exists. `on_delete: :nilify_all` keeps orgs intact if a creator account is ever
  deleted.
  """

  def up do
    alter table(:orgs) do
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:orgs, [:created_by_id])

    # Backfill existing orgs: the creator is the admin membership with the
    # earliest inserted_at for each org.
    execute """
    UPDATE orgs o
    SET created_by_id = sub.user_id
    FROM (
      SELECT DISTINCT ON (m.org_id) m.org_id, m.user_id
      FROM orgs_memberships m
      WHERE m.role = 'admin'
      ORDER BY m.org_id, m.inserted_at ASC
    ) sub
    WHERE sub.org_id = o.id AND o.created_by_id IS NULL
    """
  end

  def down do
    drop index(:orgs, [:created_by_id])

    alter table(:orgs) do
      remove :created_by_id
    end
  end
end
