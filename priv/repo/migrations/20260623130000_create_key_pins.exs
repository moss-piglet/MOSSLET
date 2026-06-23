defmodule Mosslet.Repo.Migrations.CreateKeyPins do
  use Ecto.Migration

  # Unified TOFU key-pin store for interim key-authenticity (EPIC #291,
  # Phase 1 / #293, REVISED).
  #
  # Key authenticity is fundamentally per-(viewer_user, peer_user) and
  # INDEPENDENT of relationship type (personal connection, business/family org,
  # circle). Org/circle members seal a SHARED key (org_key / group_key) to each
  # member's USER public key (key_pair["public"] + pq_public_key) — the SAME
  # MITM surface as a personal connection, with a worse blast radius. So we pin
  # ONE fingerprint per peer, keyed by `peer_user_id`, NOT by a relationship row.
  #
  # `pinned_fingerprint` holds the viewer-sealed pin: a NaCl-secretbox blob
  # produced BROWSER-SIDE under the viewer's user_key, then Cloak-wrapped at-rest
  # (`Encrypted.Binary`). The server holds an opaque blob it can neither read (no
  # user_key in ZK mode) nor forge a valid pin for.
  #
  # This REVISES the prior #293 impl that used a
  # `user_connections.pinned_peer_fingerprint` column. That column is dropped
  # (idempotently, since the old migration may have already run in test/dev) and
  # replaced by this dedicated table. All operations are online-safe on Fly
  # PostgreSQL (new table + a metadata-only DROP COLUMN).
  def change do
    create table(:key_pins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The VIEWER who pinned the fingerprint (the user whose user_key sealed it).
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # The PEER whose hybrid public key was fingerprinted and pinned.
      add :peer_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Opaque, browser-sealed pin blob (Cloak `Encrypted.Binary` at-rest).
      add :pinned_fingerprint, :binary

      timestamps()
    end

    # One pin per (viewer, peer) — single source of truth across every
    # relationship/context. Enables insert-only first-write-wins upserts.
    create unique_index(:key_pins, [:user_id, :peer_user_id])

    # Reverse lookups (e.g. "who pinned this peer") for later phases.
    create index(:key_pins, [:peer_user_id])

    # Idempotently drop the unreleased prior-#293 column across envs where the
    # old migration already ran (test/dev). It never reached production.
    execute(
      "ALTER TABLE user_connections DROP COLUMN IF EXISTS pinned_peer_fingerprint",
      "ALTER TABLE user_connections ADD COLUMN IF NOT EXISTS pinned_peer_fingerprint bytea"
    )
  end
end
