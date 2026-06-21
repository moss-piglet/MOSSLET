defmodule Mosslet.Orgs.Membership do
  @moduledoc false
  use Mosslet.Schema

  import Ecto.Query
  use Gettext, backend: MossletWeb.Gettext

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Orgs.Org

  @role_options ~w(admin member guardian managed_member)a
  @default_role :member
  @admin_role :admin

  def role_options, do: @role_options

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orgs_memberships" do
    field :role, Ecto.Enum, values: @role_options

    # Org-scoped ZK identity (Task #225). See docs/ORG_DISPLAY_NAME_DESIGN.md.
    #
    # `key` — the per-org symmetric `org_key`, sealed FOR this member via
    # `sealForUser` (Cat-5 hybrid). Every member's `key` unseals to the SAME
    # `org_key`, so any member can decrypt any member's `display_name`. Null
    # until an existing key-holder seals it (lazy, browser-driven). Set ONLY via
    # the programmatic ZK seal path (never `cast` from user params).
    #
    # `display_name` — the member's org-facing persona (e.g. "Mark —
    # Engineering"), encrypted WITH the `org_key` (secretbox) in the browser.
    # Null until the member sets one. Server never sees plaintext.
    #
    # `avatar` — the member's org-facing display avatar (Task #277): the resized
    # WebP bytes encrypted WITH the `org_key` (secretbox) in the browser, base64.
    # Null until the member sets one (fallback is initials derived from the org
    # `display_name`, never the bare Mosslet logo). Lets members keep their
    # personal and org personas separate. Server never sees the plaintext image.
    field :key, Encrypted.Binary, redact: true
    field :display_name, Encrypted.Binary, redact: true
    field :avatar, Encrypted.Binary, redact: true

    belongs_to :user, User
    belongs_to :org, Org

    timestamps()
  end

  def by_user_and_org_slug(%User{} = user, org_slug) do
    from(ms in __MODULE__,
      join: org in assoc(ms, :org),
      on: [slug: ^org_slug],
      where: ms.user_id == ^user.id
    )
  end

  def all_by_org(%Org{} = org) do
    from(m in __MODULE__,
      join: u in assoc(m, :user),
      join: o in assoc(m, :org),
      on: o.id == ^org.id,
      preload: [:user]
    )
  end

  def insert_changeset(org, user, role \\ @default_role) do
    %__MODULE__{
      org_id: org.id,
      user_id: user.id,
      role: role
    }
    |> change()
    |> unique_constraint([:org_id, :user_id])
    |> validate_inclusion(:role, @role_options)
  end

  def update_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, @role_options)
    |> prepare_changes(fn changeset ->
      current_role = membership.role
      new_role = get_change(changeset, :role)

      if current_role == @admin_role && new_role != current_role do
        validate_at_least_one_admin(changeset)
      else
        changeset
      end
    end)
  end

  def delete_changeset(%__MODULE__{} = membership) do
    membership
    |> change()
    |> prepare_changes(&validate_at_least_one_admin/1)
  end

  @doc """
  ZK changeset that stores the per-org `org_key` sealed FOR this member
  (Task #225). The browser sealed the raw `org_key` to the member's public key
  via `sealForUser`; the raw key never reaches the server. `sealed_key` is the
  opaque base64 sealed blob. Set programmatically (never via `cast` of user
  params) per the encryption/security guidelines.
  """
  def seal_key_changeset(%__MODULE__{} = membership, sealed_key) when is_binary(sealed_key) do
    change(membership, %{key: sealed_key})
  end

  @doc """
  ZK changeset that stores the member's org-facing `display_name`, encrypted
  WITH the `org_key` (secretbox) in the browser (Task #225). `encrypted_name` is
  the opaque base64 ciphertext — the server never sees plaintext, so
  length/character/expletive validation happens client-side (consistent with all
  other ZK-encrypted name fields, e.g. `UserGroup.name`). Set programmatically
  (never via `cast`).
  """
  def display_name_changeset(%__MODULE__{} = membership, encrypted_name)
      when is_binary(encrypted_name) do
    change(membership, %{display_name: encrypted_name})
  end

  @doc """
  ZK changeset that stores the member's org-facing `avatar` — the resized WebP
  bytes encrypted WITH the `org_key` (secretbox) in the browser, base64
  (Task #277). `encrypted_avatar` is the opaque ciphertext; the server never
  sees the plaintext image, so size/format validation happens client-side
  (consistent with `display_name` and all other ZK image/name fields). Set
  programmatically (never via `cast` of user params).
  """
  def avatar_changeset(%__MODULE__{} = membership, encrypted_avatar)
      when is_binary(encrypted_avatar) do
    change(membership, %{avatar: encrypted_avatar})
  end

  @doc """
  ZK changeset that CLEARS the member's org-facing `avatar` (Task #277), so the
  display falls back to initials derived from the org `display_name`.
  """
  def clear_avatar_changeset(%__MODULE__{} = membership) do
    change(membership, %{avatar: nil})
  end

  defp validate_at_least_one_admin(changeset) do
    org_id = changeset.data.org_id
    user_id = changeset.data.user_id

    query =
      from(m in __MODULE__,
        where: m.org_id == ^org_id and m.role == @admin_role and m.user_id != ^user_id,
        select: count(1)
      )

    if changeset.repo.one!(query) > 0 do
      changeset
    else
      add_error(changeset, :role, gettext("cannot remove last admin of the organization"))
    end
  end
end
