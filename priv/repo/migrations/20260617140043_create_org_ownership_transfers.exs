defmodule Mosslet.Repo.Migrations.CreateOrgOwnershipTransfers do
  use Ecto.Migration

  @moduledoc """
  Org ownership-transfer handshake (Task #237, Option C).

  A two-step request -> accept transfer of org ownership (`orgs.created_by_id`)
  from the current owner to an existing confirmed member. The handshake lets the
  ZK-safe Stripe email sync run in the NEW owner's authenticated session (where
  their `session_key` exists), and acts as a consent gate so org billing is never
  forced onto anyone.

  ZK-safe: this table holds ONLY internal ids, a system status enum, and
  timestamps — no plaintext, email, key material, or secrets ever. The email
  reconciliation to Stripe happens later, in-session, never persisted here.
  """

  def change do
    create table(:org_ownership_transfers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false
      add :from_user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :to_user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      # System enum (non-sensitive). :pending -> :accepted / :declined / :cancelled.
      add :status, :string, null: false, default: "pending"

      add :accepted_at, :utc_datetime
      add :declined_at, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps()
    end

    create index(:org_ownership_transfers, [:org_id])
    create index(:org_ownership_transfers, [:to_user_id])
    create index(:org_ownership_transfers, [:from_user_id])

    # At most ONE active (:pending) transfer per org. Accepted/declined/cancelled
    # rows are retained for audit, so a partial unique index keys only on pending.
    create unique_index(:org_ownership_transfers, [:org_id],
             where: "status = 'pending'",
             name: :org_ownership_transfers_one_pending_per_org
           )
  end
end
