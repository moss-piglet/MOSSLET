defmodule Mosslet.Repo.Migrations.AddSubdomainToOrgs do
  use Ecto.Migration

  def change do
    # Custom subdomain (Task #240, branding add-on Phase B — Business only).
    #
    # Unlike `name`/`logo_url`, the subdomain hostname label is a NON-SENSITIVE
    # plaintext system field: it is published in the URL the org shares
    # (acmebiz.mosslet.com), so it is safe to store, index, route, and log on in
    # the clear. Mirrors `slug` (`:citext` + unique index) for case-insensitive
    # uniqueness that complements the lowercase changeset validation. Null until
    # an owner/admin with the paid subdomain add-on claims one.
    alter table(:orgs) do
      add :subdomain, :citext
    end

    create unique_index(:orgs, [:subdomain])
  end
end
