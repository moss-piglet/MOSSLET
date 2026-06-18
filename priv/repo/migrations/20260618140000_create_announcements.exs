defmodule Mosslet.Repo.Migrations.CreateAnnouncements do
  use Ecto.Migration

  # Two-tier ZK announcements (Task #229c, EPIC #207). Modeled on the
  # shared_files table (Task #221): browser-encrypted ciphertext is additionally
  # Cloak-wrapped at the app layer (`Encrypted.Binary`), so Postgres only ever
  # holds opaque binary. The server never sees the plaintext title/body or the
  # org_key/group_key it was encrypted with (invariants I2/I3).
  #
  # An announcement is scoped to EXACTLY ONE of:
  #   * org_id  — the org-wide dashboard tier, authored by an org owner/admin and
  #               encrypted with the per-org `org_key`.
  #   * group_id — a circle-level announcement, authored by that circle's
  #               UserGroup owner/admin/moderator ("team lead") and encrypted
  #               with that circle's `group_key`.
  # The XOR is enforced in the `Mosslet.Announcements` context (the scoping FK is
  # stamped programmatically, never cast — same rule as shared_files.org_id /
  # uploader_id) AND with a DB CHECK constraint here as defense in depth.
  def change do
    create table(:announcements, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Exactly one of these is set (see CHECK constraint below). Both stamped
      # server-side by the context, never cast from user params.
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all)
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all)

      # The authoring member (set programmatically, never cast). nilify on delete
      # so the announcement survives the author leaving (history stays intact).
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # Cloak-wrapped ciphertext (`Encrypted.Binary` at the app layer). The title
      # is optional; the body is required. Both were encrypted in the browser
      # with the tier's shared key (org_key / group_key) — ZK.
      add :encrypted_title, :binary
      add :encrypted_body, :binary, null: false

      # Plaintext, non-sensitive surface metadata:
      #   priority  — "normal" | "pinned" (one pinned renders as a highlighted
      #               banner, the rest in a "Recent" list).
      #   expires_at — optional auto-hide time (UTC). Past announcements drop out
      #               of the listing in the context query.
      add :priority, :string, null: false, default: "normal"
      add :expires_at, :utc_datetime

      timestamps()
    end

    create index(:announcements, [:org_id])
    create index(:announcements, [:group_id])
    create index(:announcements, [:author_id])

    # XOR scoping: exactly one of org_id / group_id is present (I1 — every
    # announcement belongs to a single org or circle, never both, never neither).
    create constraint(:announcements, :announcements_org_xor_group,
             check:
               "(org_id IS NOT NULL AND group_id IS NULL) OR (org_id IS NULL AND group_id IS NOT NULL)"
           )

    # Tiny ZK-safe read receipts (ids + timestamps only — no plaintext, no keys).
    # Drives the per-tier unread badge + the realtime "new announcement" toast.
    create table(:announcement_reads, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :announcement_id,
          references(:announcements, type: :binary_id, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    # One read row per (announcement, user) — idempotent marking via upsert.
    create unique_index(:announcement_reads, [:announcement_id, :user_id])
    create index(:announcement_reads, [:user_id])
  end
end
