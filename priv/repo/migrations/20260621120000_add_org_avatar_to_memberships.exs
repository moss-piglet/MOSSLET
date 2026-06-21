defmodule Mosslet.Repo.Migrations.AddOrgAvatarToMemberships do
  use Ecto.Migration

  def change do
    # Org-scoped ZK display avatar (Task #277), the sequel to the org display
    # name (#225/#283). Holds Cloak-wrapped ciphertext (`Encrypted.Binary`) at
    # the app layer; the DB only sees opaque binary. Nullable: null until the
    # member sets an org avatar (fallback is initials derived from the org
    # display name, never the bare Mosslet logo).
    alter table(:orgs_memberships) do
      # The member's org-facing avatar: the resized WebP bytes encrypted WITH the
      # per-org `org_key` (secretbox) in the browser, then base64. Every org-mate
      # holds the `org_key` (Membership.key) so they can decrypt it. Server never
      # sees the plaintext image.
      add :avatar, :binary
    end
  end
end
