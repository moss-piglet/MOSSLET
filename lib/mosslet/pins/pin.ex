defmodule Mosslet.Pins.Pin do
  @moduledoc """
  A dashboard pin (Task #229d): one quick-access shortcut on a business org's
  dashboard. A pin has two orthogonal axes:

    * `scope` — `:personal` (private to `user_id`, the per-member pin) or
      `:org_shared` (curated by an org owner/admin, visible to the whole org).
    * `pin_type` — `:circle` / `:file` (FK-only: `target_id` points at the
      pinned group / shared_file and the NAME is reused from the already-
      decrypted client-side render — no new ciphertext) or `:link` (a free URL
      whose `encrypted_label`/`encrypted_url` are encrypted in the browser).

  For `:link` pins, `encrypted_label`/`encrypted_url` are `Encrypted.Binary`:
  the browser ciphertext (secretbox under the viewer's `user_key` for personal
  scope, or the per-org `org_key` for org-wide scope) is additionally Cloak-
  wrapped server-side. The server never sees the plaintext or the key
  (invariants I2/I3) — the same pattern as `Mosslet.Announcements.Announcement`.

  `org_id`, `scope`, `user_id`, and `created_by_id` are set programmatically by
  `Mosslet.Pins` — never `cast` from user params (encryption/security
  guidelines, I1).
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Orgs.Org

  @scopes [:personal, :org_shared]
  @pin_types [:circle, :file, :link]

  def scopes, do: @scopes
  def pin_types, do: @pin_types

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "dashboard_pins" do
    field :scope, Ecto.Enum, values: @scopes
    field :pin_type, Ecto.Enum, values: @pin_types
    field :target_id, :binary_id

    field :encrypted_label, Encrypted.Binary, redact: true
    field :encrypted_url, Encrypted.Binary, redact: true

    field :position, :integer, default: 0

    belongs_to :org, Org
    belongs_to :user, User
    belongs_to :created_by, User

    timestamps()
  end

  @doc """
  ZK insert changeset for a PERSONAL pin (private to `user`). `org_id`, `scope`,
  `user_id`, and `created_by_id` are all stamped server-side. For a `:link` pin
  the browser produced the encrypted label/URL with the viewer's `user_key`;
  for `:circle`/`:file` only the `target_id` is stored.
  """
  def personal_insert_changeset(%Org{} = org, %User{} = user, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:pin_type, :target_id, :encrypted_label, :encrypted_url, :position])
    |> put_change(:scope, :personal)
    |> put_change(:org_id, org.id)
    |> put_change(:user_id, user.id)
    |> put_change(:created_by_id, user.id)
    |> shared_validations()
    |> foreign_key_constraint(:org_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  ZK insert changeset for an ORG-WIDE (shared) pin. `org_id`, `scope`, and
  `created_by_id` are stamped server-side; `user_id` stays nil. For a `:link`
  pin the browser produced the encrypted label/URL with the per-org `org_key`.
  """
  def org_shared_insert_changeset(%Org{} = org, %User{} = creator, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:pin_type, :target_id, :encrypted_label, :encrypted_url, :position])
    |> put_change(:scope, :org_shared)
    |> put_change(:org_id, org.id)
    |> put_change(:created_by_id, creator.id)
    |> shared_validations()
    |> foreign_key_constraint(:org_id)
  end

  defp shared_validations(changeset) do
    changeset
    |> validate_required([:pin_type])
    |> validate_by_type()
  end

  # `:link` pins must carry the encrypted URL (and label) but no target;
  # `:circle`/`:file` pins must carry a target and no link ciphertext.
  defp validate_by_type(changeset) do
    case get_field(changeset, :pin_type) do
      :link ->
        changeset
        |> validate_required([:encrypted_label, :encrypted_url])
        |> put_change(:target_id, nil)

      type when type in [:circle, :file] ->
        changeset
        |> validate_required([:target_id])
        |> put_change(:encrypted_label, nil)
        |> put_change(:encrypted_url, nil)

      _ ->
        changeset
    end
  end
end
