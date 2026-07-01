defmodule Mosslet.Repo.Migrations.CreateUserKeyWraps do
  use Ecto.Migration

  # WebAuthn PRF device-bound wrapping factor for user_key (board #362 / #363).
  #
  # See docs/WEBAUTHN_PRF_DESIGN.md §5. The user's encryption root (user_key) is
  # unwrapped client-side from an opaque wrap blob. Today there is exactly ONE
  # such wrap (the password-derived `users.key_hash`). This table generalizes the
  # wrapping seam into a COLLECTION of per-unlock-door wraps so a user can opt in
  # to binding user_key to a device's WebAuthn PRF (secure enclave/TPM).
  #
  # THE central invariant (the whole point — flip OR→AND, never both doors open):
  #
  #   * NON-ENROLLED  => exactly ONE `:password` wrap  (user_key <= Argon2id(password))
  #   * ENROLLED      => ZERO `:password` wraps, one-or-more `:prf` wraps
  #                      (user_key <= KDF(password ‖ prf_output) per device)
  #
  # The ZK recovery key (users.recovery_key_hash / encrypted_recovery_private_key)
  # is the ALWAYS-PRESENT 256-bit fallback and is unchanged by this table.
  #
  # I6 preserved: every wrapped_user_key / wrap_salt / prf_salt / credential_id is
  # OPAQUE to the server — it stores and serves blobs, never key material. The
  # partial unique index below is the DB-level guard on the "one password wrap"
  # half of the invariant; the OR→AND flip itself is enforced transactionally in
  # Mosslet.Accounts.
  #
  # Additive + online-safe on Fly PostgreSQL (new table only).
  def change do
    create table(:user_key_wraps, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      # Which unlock door this wrap represents: "password" | "prf".
      add :kind, :string, null: false

      # secretbox(user_key, wrapping_key) — opaque to the server.
      add :wrapped_user_key, :binary, null: false

      # KDF salt used to derive the wrapping key for THIS wrap (base64 string).
      add :wrap_salt, :string, null: false

      # WebAuthn credential id this :prf wrap is bound to (nil for :password).
      add :credential_id, :binary

      # Per-credential PRF eval salt (base64 string; nil for :password).
      add :prf_salt, :string

      # User-facing device nickname, sealed under user_key (nil for :password).
      add :label, :binary

      # Best-effort, NON-authoritative ecosystem hint for synced passkeys:
      # "apple" | "google" | "cross-platform". PRF output is stable across synced
      # copies WITHIN one ecosystem, not across (Apple <-> Google) — see design §4.
      add :ecosystem_hint, :string

      add :last_used_at, :utc_datetime

      timestamps()
    end

    create index(:user_key_wraps, [:user_id])

    # DB guard on the invariant: at most ONE :password wrap per user. Enrolled
    # users have zero. (The :prf side is intentionally unconstrained — multi-device.)
    create unique_index(:user_key_wraps, [:user_id],
             where: "kind = 'password'",
             name: :user_key_wraps_one_password_wrap_index
           )
  end
end
