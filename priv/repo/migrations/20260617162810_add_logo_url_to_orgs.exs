defmodule Mosslet.Repo.Migrations.AddLogoUrlToOrgs do
  use Ecto.Migration

  def change do
    # Org brand logo (Task #228, branding add-on). Stores the Tigris object-storage
    # path for the org's uploaded logo, encrypted at rest via Cloak vault
    # (Encrypted.Binary). The image bytes themselves are ZK-encrypted browser-side
    # with the per-org org_key (#225) — the server never sees the plaintext logo.
    # :binary because Cloak stores ciphertext. Null until an owner/admin uploads.
    alter table(:orgs) do
      add :logo_url, :binary
    end
  end
end
