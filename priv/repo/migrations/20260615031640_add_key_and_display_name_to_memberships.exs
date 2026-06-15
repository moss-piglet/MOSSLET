defmodule Mosslet.Repo.Migrations.AddKeyAndDisplayNameToMemberships do
  use Ecto.Migration

  def change do
    # Org-scoped ZK identity (Task #225). Both columns hold Cloak-wrapped
    # ciphertext (`Encrypted.Binary`) at the app layer; the DB only sees opaque
    # binary. Nullable: a member's `key` is null until an existing key-holder
    # seals the per-org `org_key` for them (lazy, browser-driven — no server-side
    # key generation possible under ZK). `display_name` is null until the member
    # sets their org persona.
    alter table(:orgs_memberships) do
      # The per-org symmetric `org_key`, sealed FOR this member via sealForUser
      # (Cat-5 hybrid ML-KEM-1024 + X25519). Mirrors UserGroup.key.
      add :key, :binary
      # The member's org-facing display name, encrypted WITH the org_key
      # (secretbox) in the browser. Server never sees plaintext.
      add :display_name, :binary
    end
  end
end
