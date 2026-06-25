defmodule Mosslet.Repo.Migrations.AddSignedKeyHistory do
  use Ecto.Migration

  # Signed key history (EPIC #291 / #290 step 4 / board #315).
  #
  # Upgrades interim TOFU pinning (#293-296) into a signed, append-only,
  # hash-chained key history so a client can cryptographically distinguish a
  # legitimate key rotation from a server key-substitution attack (§7, #290).
  #
  # TWO additions:
  #
  # 1. Per-user HYBRID PQ SIGNING KEYPAIR (ML-DSA-87 + Ed25519, Cat-5), generated
  #    client-side at the same ZK moment as the encryption keypair:
  #      - `signing_public_key`            : the public key peers pin (public material)
  #      - `encrypted_signing_private_key` : secret key sealed under the user's
  #                                          user_key (exactly like the existing
  #                                          encrypted_pq_private_key). Both are
  #                                          additionally Cloak-wrapped at-rest via
  #                                          `Encrypted.Binary` (-> :binary columns),
  #                                          mirroring add_pq_key_fields_to_users.
  #
  # 2. `key_history_entries`: the per-user, append-only chain of signed PUBLIC
  #    leaves (mosslet/key-history/v1). Entries hold ONLY public material
  #    (encryption + signing public keys, prev-hash, timestamp, signature) so they
  #    can be served to connections for client-side monitoring AND become a
  #    metamorphic-log leaf later with ZERO reformatting (#299/#316). Cloak-wrapped
  #    at-rest as defense-in-depth (consistent with how public keys are already
  #    stored), but never ZK-sealed — the AUTHENTICITY comes from the signature
  #    chain, not from secrecy. The per-user table stays small (Postgres-trivial);
  #    billions-of-appends is metamorphic-log's problem, not this table's (#299).
  #
  # All operations are online-safe on Fly PostgreSQL (additive columns + new table).
  def change do
    alter table(:users) do
      add :signing_public_key, :binary
      add :encrypted_signing_private_key, :binary
    end

    create table(:key_history_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The user whose key-history chain this entry belongs to.
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Monotonic position in the chain (genesis = 0). Plain integer so it can be
      # ordered and uniquely constrained per user.
      add :seq, :integer, null: false

      # The full serialized PUBLIC leaf (mosslet/key-history/v1 JSON record):
      # {v, seq, ts, enc_x25519, enc_pq, sign_pub, prev_hash, entry_hash, sig}.
      add :entry, :binary, null: false

      # Denormalized signing public key this entry pins — lets the server hand out
      # the chain head's signing key without parsing the JSON blob.
      add :signing_public_key, :binary

      # Append-only: entries are never updated, only inserted.
      timestamps(updated_at: false)
    end

    # One entry per (user, seq) — enforces append-only ordering + first-write-wins
    # inserts (on_conflict: :nothing). A replayed/duplicate append is a no-op.
    create unique_index(:key_history_entries, [:user_id, :seq])
  end
end
