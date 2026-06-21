defmodule Mosslet.Orgs.Guardianship do
  @moduledoc """
  The consent record linking a managed member to a guardian within a family org.

  This schema stores the *consent relationship* only — never any key material.
  The actual co-sealing of a managed member's context keys (`post_key`,
  `conversation_key`) for the guardian's PUBLIC key is ephemeral and happens
  per-content in the member's browser, exactly like any other recipient.

  Statuses:

    * `:pending`  — awaiting managed-member consent (no co-sealing yet).
    * `:active`   — consented, co-sealing on.
    * `:paused`   — privacy toggle ON (stop FUTURE co-seals; past stays shared).
    * `:declined` — managed member refused (never co-sealed).

  Co-sealing happens **only** when `status == :active` (the cryptographic consent
  gate). All business logic, queries, and transactions live in `Mosslet.Orgs`.
  """
  use Mosslet.Schema

  import Ecto.Query

  alias Mosslet.Encrypted
  alias Mosslet.Orgs.{Membership, Org}

  @status_options ~w(pending active paused declined)a

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orgs_guardianships" do
    field :status, Ecto.Enum, values: @status_options, default: :pending
    field :requires_consent, :boolean, default: true

    field :established_at, :utc_datetime
    field :consented_at, :utc_datetime
    field :paused_at, :utc_datetime

    # Family guardian safety override (Task #284). The MANAGED member's canonical
    # raw `conn_key`, sealed FOR the GUARDIAN of THIS guardianship via
    # `sealForUser` in the managed member's browser. Lets the guardian decrypt
    # the managed member's PERSONAL avatar (secretbox-encrypted with that
    # `conn_key`) so a minor can't hide behind a misleading org avatar. Null
    # until the managed member's browser seals it; set ONLY via the programmatic
    # ZK seal path (`seal_avatar_key_changeset/2`), never `cast` from params.
    field :managed_avatar_key, Encrypted.Binary, redact: true

    belongs_to :org, Org
    belongs_to :guardian_membership, Membership
    belongs_to :managed_membership, Membership

    timestamps()
  end

  def status_options, do: @status_options

  ## Queries

  def by_org(%Org{} = org) do
    from(g in __MODULE__, where: g.org_id == ^org.id)
  end

  def active_for_managed_membership(managed_membership_id) do
    from(g in __MODULE__,
      where: g.managed_membership_id == ^managed_membership_id and g.status == :active
    )
  end

  def for_managed_membership(managed_membership_id) do
    from(g in __MODULE__, where: g.managed_membership_id == ^managed_membership_id)
  end

  def for_guardian_membership(guardian_membership_id) do
    from(g in __MODULE__, where: g.guardian_membership_id == ^guardian_membership_id)
  end

  @doc """
  Active guardianships for which the given user is the MANAGED member and the
  guardian's avatar key has NOT yet been sealed (Task #284). Joins the guardian
  user so the browser seal flow can read `public_key` + `pq_public_key`.
  """
  def active_needing_avatar_key_for_managed_user(managed_user_id) do
    from(g in __MODULE__,
      join: managed in Membership,
      on: managed.id == g.managed_membership_id,
      join: guardian in Membership,
      on: guardian.id == g.guardian_membership_id,
      join: guardian_user in assoc(guardian, :user),
      where:
        g.status == :active and managed.user_id == ^managed_user_id and
          is_nil(g.managed_avatar_key),
      select: %{guardianship_id: g.id, guardian_user: guardian_user}
    )
  end

  @doc """
  An :active guardianship linking the given guardian user (as guardian) to the
  given managed user (as managed member), with a sealed `managed_avatar_key`
  present (Task #284). Used by the read path to surface the managed member's
  personal avatar to their guardian, server-authoritative (I1).
  """
  def active_avatar_key_for(guardian_user_id, managed_user_id) do
    from(g in __MODULE__,
      join: guardian in Membership,
      on: guardian.id == g.guardian_membership_id,
      join: managed in Membership,
      on: managed.id == g.managed_membership_id,
      where:
        g.status == :active and guardian.user_id == ^guardian_user_id and
          managed.user_id == ^managed_user_id and not is_nil(g.managed_avatar_key),
      select: g.managed_avatar_key,
      limit: 1
    )
  end

  @doc """
  Builds a new guardianship. `status` and `requires_consent` are set explicitly
  by the context (`establish_guardianship/3`), never cast from user input.
  """
  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :org_id,
      :guardian_membership_id,
      :managed_membership_id,
      :status,
      :requires_consent,
      :established_at,
      :consented_at,
      :paused_at
    ])
    |> validate_required([:org_id, :guardian_membership_id, :managed_membership_id, :status])
    |> validate_inclusion(:status, @status_options)
    |> validate_distinct_memberships()
    |> unique_constraint([:guardian_membership_id, :managed_membership_id],
      name: :orgs_guardianships_guardian_managed_index,
      message: "guardianship already exists"
    )
    |> foreign_key_constraint(:org_id)
    |> foreign_key_constraint(:guardian_membership_id)
    |> foreign_key_constraint(:managed_membership_id)
  end

  @doc """
  Status transition changeset. Only `status` and the related timestamps are
  cast — never the membership/org references.
  """
  def status_changeset(guardianship, attrs) do
    guardianship
    |> cast(attrs, [:status, :consented_at, :paused_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @status_options)
  end

  @doc """
  ZK changeset that stores the MANAGED member's `conn_key` sealed FOR the
  guardian of this guardianship (Task #284). `sealed_key` is the opaque base64
  sealed blob produced by the managed member's browser via `sealForUser` — the
  raw `conn_key` never reaches the server. Set programmatically (never via
  `cast` of user params) per the encryption/security guidelines.
  """
  def seal_avatar_key_changeset(%__MODULE__{} = guardianship, sealed_key)
      when is_binary(sealed_key) do
    change(guardianship, %{managed_avatar_key: sealed_key})
  end

  defp validate_distinct_memberships(changeset) do
    guardian_id = get_field(changeset, :guardian_membership_id)
    managed_id = get_field(changeset, :managed_membership_id)

    if guardian_id && managed_id && guardian_id == managed_id do
      add_error(changeset, :managed_membership_id, "guardian and managed member must differ")
    else
      changeset
    end
  end
end
