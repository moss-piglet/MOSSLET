defmodule Mosslet.Repo.Migrations.AddManagedAvatarKeyToGuardianships do
  use Ecto.Migration

  def change do
    # Family guardian safety override (Task #284): a guardian must be able to see
    # their MANAGED member's PERSONAL avatar so a minor can't obscure their
    # identity behind a misleading org avatar/initials. The personal avatar blob
    # is secretbox-encrypted with the OWNER's `conn_key`, and a guardian has NO
    # personal `UserConnection` to the managed member — so no sealed copy of the
    # managed member's `conn_key` exists for the guardian.
    #
    # This column holds the MANAGED member's canonical raw `conn_key`, sealed FOR
    # the GUARDIAN via `sealForUser` (Cat-5 hybrid) in the MANAGED member's
    # browser (the only place `conn_key` exists). Cloak-wrapped ciphertext
    # (`Encrypted.Binary`) at the app layer; the DB only sees opaque binary.
    # Nullable: null until the managed member's browser seals it.
    #
    # Per-guardianship so revoking a guardianship drops exactly that guardian's
    # access (FK on_delete cascade), and rotating/re-sealing is server-gated by
    # the active guardianship set (I1). `conn_key` was chosen over a dedicated
    # avatar key because it is the established connection-level sharing unit
    # (`UserConnection.key`), is stable across avatar changes (no stale duplicate
    # blobs), and reuses the existing DecryptAvatar unseal path verbatim.
    alter table(:orgs_guardianships) do
      add :managed_avatar_key, :binary
    end
  end
end
