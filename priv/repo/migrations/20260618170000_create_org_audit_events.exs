defmodule Mosslet.Repo.Migrations.CreateOrgAuditEvents do
  use Ecto.Migration

  # ZK admin audit log (Task #212 / EPIC #207, §12 of docs/BUSINESS_CIRCLES_DESIGN.md).
  #
  # Option B (metadata-only): a server-authoritative, APPEND-ONLY activity log of
  # business org admin actions. We store ONLY opaque random UUIDs + a
  # non-sensitive plaintext action category + timestamp. NO human-readable
  # content (names, labels, file/circle names) ever reaches the server — those
  # stay encrypted at rest elsewhere and the human-readable description is
  # reconstructed CLIENT-SIDE by an admin from data they already hold keys for.
  #
  # Why no Cloak/Encrypted.Binary here: every column is an opaque identifier or a
  # non-sensitive system category. Encrypting a random UUID buys zero
  # confidentiality (it carries no embedded meaning) and would break the FK
  # constraints, the on_delete cascade, and the ability to join/query. ZK in our
  # architecture means no readable CONTENT at rest — structural ids are already
  # plaintext throughout the schema (orgs_memberships, groups, user_groups,
  # user_shared_files), so this is consistent.
  #
  # Tamper-resistance: there is NO updated_at (events are immutable) and the
  # `Mosslet.Orgs` context exposes only insert + read (no update/delete API).
  # Writes are server-authoritative (actor resolved from the authenticated
  # caller) so a rogue admin cannot suppress or forge their own entry.
  #
  # No orphans: org_id cascades (:delete_all) so deleting an org permanently wipes
  # its entire audit trail (our ZK value — we want nothing to do with the logs of
  # an org that no longer exists). The owner can download a final human-readable
  # copy client-side BEFORE teardown (export-first, Task #227 pattern).
  def change do
    create table(:org_audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The org this event belongs to. Cascade => deleting the org wipes its log
      # (no orphaned logs). Stamped programmatically by the context, never cast.
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false

      # Who performed the action (server-authoritative). nilify on user-account
      # deletion so the immutable event row survives (audit integrity) while the
      # personal reference drops.
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # Non-sensitive system category (whitelisted enum-like string), e.g.
      # "member_added", "role_changed", "circle_created", "file_shared".
      add :action, :string, null: false

      # Polymorphic target of the action (opaque UUID, NO hard FK because it may
      # point at users / groups / shared_files). Nullable. The matching
      # target_type names which table it references so the client can resolve it.
      add :target_id, :binary_id
      add :target_type, :string

      # APPEND-ONLY: inserted_at only, no updated_at (events are immutable).
      timestamps(updated_at: false)
    end

    create index(:org_audit_events, [:org_id])
    # Composite index drives the admin panel's "most recent first" listing.
    create index(:org_audit_events, [:org_id, :inserted_at])
  end
end
