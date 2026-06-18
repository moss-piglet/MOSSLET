defmodule Mosslet.Repo.Migrations.CreateDashboardPins do
  use Ecto.Migration

  # Dashboard pinning for quick access (Task #229d, EPIC #207). Modeled on the
  # announcements (#229c) + shared_files (#221) migrations: any browser-encrypted
  # ciphertext is additionally Cloak-wrapped at the app layer (`Encrypted.Binary`),
  # so Postgres only ever holds opaque binary. The server never sees the plaintext
  # link label/URL or the key it was encrypted with (invariants I2/I3).
  #
  # A pin lives on ONE org's dashboard and has two orthogonal axes:
  #
  #   scope    — :personal (private to `user_id`, the per-member pin) OR
  #              :org_shared (curated by org owner/admin, visible org-wide).
  #   pin_type — :circle / :file (FK-only — `target_id` points at the group /
  #              shared_file; the NAME is reused from the already-decrypted
  #              client-side render, no new ciphertext) OR :link (a free URL —
  #              `encrypted_label`/`encrypted_url` encrypted in the browser with
  #              the user_key for personal scope or the org_key for org_shared).
  #
  # Authority (server-authoritative, I1): org_shared pins are creatable only by
  # an org owner/admin; personal pins by any member. The scope + ownership FKs are
  # stamped programmatically by `Mosslet.Pins`, never cast from user params.
  def change do
    create table(:dashboard_pins, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # The org dashboard this pin belongs to (stamped server-side, never cast).
      add :org_id, references(:orgs, type: :binary_id, on_delete: :delete_all), null: false

      # :personal | :org_shared (plaintext, non-sensitive surface metadata).
      add :scope, :string, null: false

      # Owner of a PERSONAL pin (null for :org_shared). Stamped server-side.
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      # Who created the pin (set programmatically, never cast). nilify on delete
      # so an org_shared pin survives the curator leaving.
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # :circle | :file | :link (plaintext).
      add :pin_type, :string, null: false

      # For :circle / :file pins, the polymorphic id of the pinned target (a
      # group_id or shared_file_id). Intentionally NOT a DB foreign key (it points
      # at different tables by pin_type); the context resolves + re-authorizes it.
      # Null for :link pins.
      add :target_id, :binary_id

      # Cloak-wrapped ciphertext (`Encrypted.Binary` at the app layer) — only set
      # for :link pins. The label + URL were encrypted in the browser with the
      # user_key (personal) or org_key (org_shared), so the server learns neither.
      add :encrypted_label, :binary
      add :encrypted_url, :binary

      # Plaintext ordering within a scope (lower = earlier in the strip).
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create index(:dashboard_pins, [:org_id])
    create index(:dashboard_pins, [:user_id])
    create index(:dashboard_pins, [:created_by_id])

    # The two listing queries: personal pins for a viewer in an org, and the
    # org-wide shared pins for an org — both ordered by position.
    create index(:dashboard_pins, [:org_id, :scope, :user_id, :position])

    # A personal pin always has a user_id; an org_shared pin never does. Defense
    # in depth alongside the context (which stamps these programmatically — I1).
    create constraint(:dashboard_pins, :dashboard_pins_scope_user,
             check:
               "(scope = 'personal' AND user_id IS NOT NULL) OR (scope = 'org_shared' AND user_id IS NULL)"
           )

    # A :link pin carries no target_id; a :circle/:file pin requires one.
    create constraint(:dashboard_pins, :dashboard_pins_type_target,
             check:
               "(pin_type = 'link' AND target_id IS NULL) OR (pin_type IN ('circle','file') AND target_id IS NOT NULL)"
           )
  end
end
