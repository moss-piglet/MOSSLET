defmodule Mosslet.Orgs.Org do
  @moduledoc false
  use Mosslet.Schema

  alias Mosslet.Extensions.Ecto.ChangesetExt
  alias Mosslet.Accounts.User
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Encrypted
  alias Mosslet.Orgs.Invitation
  alias Mosslet.Orgs.Membership

  # Reserved subdomain labels (Task #240). These are denied as org subdomains
  # because they collide with platform/infra hosts, would be confusing, or are
  # security-sensitive. Matched case-insensitively against the lowercased label.
  # Keep in sync with any future infra/marketing host additions.
  @reserved_subdomains ~w(
    www app api admin administrator mail email smtp imap pop webmail
    mx ns ns1 ns2 dns ftp sftp ssh vpn proxy gateway
    blog dev staging stage test testing demo sandbox preview beta alpha
    status health metrics monitoring grafana prometheus
    billing payments pay checkout stripe invoice invoices
    support help docs documentation kb wiki faq
    account accounts auth login logout signin signup register oauth sso
    static assets cdn media files uploads download downloads img images
    public private internal secure security root system
    mosslet mossletapp mossletapps
  )

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "orgs" do
    field :name, Encrypted.Binary
    field :name_hash, Encrypted.HMAC
    field :slug, :string

    # Custom subdomain (Task #240, branding add-on Phase B — Business only, paid
    # add-on). The hostname LABEL the org chooses for its branded URL
    # (`acmebiz` -> acmebiz.mosslet.com).
    #
    # Unlike `name`/`logo_url`, this is a NON-SENSITIVE PLAINTEXT system field: it
    # is published in the URL the org shares publicly, so it is safe to store,
    # index, route, and log on in the clear (per the encryption architecture
    # guidelines — only sensitive brand TEXT stays encrypted). It mirrors `slug`:
    # `:citext` column + unique index for case-insensitive uniqueness, set via the
    # owner/admin UI through `subdomain_changeset/2` (`cast` is OK here precisely
    # because the value is non-sensitive plaintext, unlike `logo_url`). Null until
    # an owner/admin with the active subdomain add-on claims one.
    field :subdomain, :string

    # Org kind drives plan/feature differentiation (Phase 2/3):
    #   :family   -> Family plan (consent-based guardianship, family features)
    #   :business -> Business plan (private business circles, ZK file sharing)
    # Plaintext system enum (non-sensitive) per encryption architecture guidelines.
    field :type, Ecto.Enum, values: [:family, :business], default: :family

    # Org brand logo (Task #228, branding add-on — Business only).
    #
    # `logo_url` is the Tigris object-storage path (e.g.
    # "uploads/files/<uuid>.bin") for the org's uploaded brand logo. Stored as
    # `Encrypted.Binary` (Cloak vault, at-rest encryption) so the path is not
    # readable in the DB — mirroring `name`.
    #
    # ZK invariant: the IMAGE BYTES at that path are encrypted browser-side with
    # the per-org `org_key` (NaCl secretbox, #225), so the server never sees the
    # plaintext logo. This `logo_url` is the at-rest-encrypted POINTER to the
    # opaque blob; reads go through a short-lived presigned GET URL and the
    # browser decrypts with the `org_key` it already holds. Null until an
    # owner/admin uploads a logo. Set ONLY via the programmatic ZK path
    # (`put_logo_changeset/1` / `clear_logo_changeset/1`), never via `cast`.
    field :logo_url, Encrypted.Binary, redact: true

    # Explicit ownership: the user who created the org. Set programmatically at
    # creation (never via user params) and used by the org-limit + multi-business
    # gating in `Mosslet.Orgs`. Ownership is intentionally NOT the `:admin`
    # membership role (a user may be promoted to admin of an org they did not
    # create).
    belongs_to :created_by, User, foreign_key: :created_by_id

    has_many :memberships, Membership
    has_many :invitations, Invitation
    many_to_many :users, User, join_through: "orgs_memberships", unique: true
    has_one :customer, Customer

    timestamps()
  end

  def insert_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:name, :type])
    |> validate_name()
    |> validate_type()
    |> add_name_hash()
    |> name_to_slug()
    |> unique_constraint(:slug)
    |> unsafe_validate_unique(:slug, Mosslet.Repo)
  end

  @doc """
  Stamps the creator/owner on an org changeset.

  `created_by_id` is set programmatically (never from user params) per the
  encryption/security guidelines, so it lives outside `cast/3`.
  """
  def put_creator(changeset, %User{id: user_id}) do
    changeset
    |> put_change(:created_by_id, user_id)
    |> assoc_constraint(:created_by)
  end

  def validate_name(changeset) do
    changeset
    |> ChangesetExt.ensure_trimmed(:name)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 160)
  end

  def validate_type(changeset) do
    changeset
    |> validate_required([:type])
    |> validate_inclusion(:type, [:family, :business])
  end

  def update_changeset(org, attrs) do
    org
    |> cast(attrs, [:name, :type])
    |> validate_name()
    |> validate_type()
    |> add_name_hash()
  end

  @doc """
  ZK changeset that stamps the org brand-logo storage path (Task #228).

  `storage_path` is the opaque Tigris object key returned by
  `SharedFileStorage.put_encrypted_blob/1`; the image bytes there were already
  encrypted browser-side with the per-org `org_key`. Set programmatically (never
  via `cast` of user params) per the encryption/security guidelines — the path
  is stamped server-side after the upload, exactly like `created_by_id`.
  """
  def put_logo_changeset(%__MODULE__{} = org, storage_path) when is_binary(storage_path) do
    change(org, %{logo_url: storage_path})
  end

  @doc """
  ZK changeset that clears the org brand logo (Task #228). The opaque blob is
  deleted from object storage separately (fire-and-forget) by the caller.
  """
  def clear_logo_changeset(%__MODULE__{} = org) do
    change(org, %{logo_url: nil})
  end

  @doc """
  Changeset for setting/claiming the org's custom subdomain (Task #240, Phase B).

  The subdomain hostname label is non-sensitive plaintext, so — unlike
  `logo_url` — it is cast from the owner/admin UI params directly. Validation
  enforces a single DNS-safe label:

    * lowercased (canonicalized via `cast` + downcase before validation)
    * RFC-ish hostname label: `a-z`, `0-9`, and internal hyphens only; cannot
      start or end with a hyphen; no consecutive `--`
    * length 3..63 (DNS label max is 63 octets)
    * not in the reserved-word denylist (`www`, `app`, `api`, `admin`, `mail`, …)

  Uniqueness is enforced both at the DB (`:citext` unique index) and best-effort
  in the changeset (`unsafe_validate_unique`), mirroring `slug`. The
  add-on/billing entitlement gate (only orgs with the active subdomain add-on may
  claim one) lives in the context/UI layer, not here.
  """
  def subdomain_changeset(%__MODULE__{} = org, attrs) do
    org
    |> cast(attrs, [:subdomain])
    |> validate_required([:subdomain])
    |> downcase_subdomain()
    |> validate_subdomain()
    |> unique_constraint(:subdomain)
    |> unsafe_validate_unique(:subdomain, Mosslet.Repo)
  end

  @doc """
  Clears the org's custom subdomain (Task #240), e.g. on add-on cancellation or
  owner/admin removal. Programmatic — no user params.
  """
  def clear_subdomain_changeset(%__MODULE__{} = org) do
    change(org, %{subdomain: nil})
  end

  # Canonicalize to lowercase before validation so the stored value and all
  # hostname routing/comparisons are consistent (DNS is case-insensitive).
  defp downcase_subdomain(changeset) do
    case get_change(changeset, :subdomain) do
      value when is_binary(value) ->
        put_change(changeset, :subdomain, value |> String.trim() |> String.downcase())

      _ ->
        changeset
    end
  end

  defp validate_subdomain(changeset) do
    changeset
    |> validate_length(:subdomain, min: 3, max: 63)
    |> validate_format(
      :subdomain,
      ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/,
      message:
        "may only contain lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen"
    )
    |> validate_format(:subdomain, ~r/^(?!.*--).*$/,
      message: "cannot contain consecutive hyphens"
    )
    |> validate_exclusion(:subdomain, @reserved_subdomains, message: "is reserved")
  end

  # Blind index for the encrypted name (HMAC). Lets us look up an org by name
  # without decrypting. Only set when the name changes.
  defp add_name_hash(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :name_hash, String.downcase(name))
    end
  end

  defp name_to_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      new_name ->
        change(changeset, %{slug: friendly_slug(new_name)})
    end
  end

  # We currently don't use the org name in the slug
  # for privacy. The name of the org will stay encrypted
  # and a random slug will be used for sharing urls.
  defp friendly_slug(_new_name) do
    new_name_slug = FriendlyID.generate(4, separator: "-")
    Slug.slugify(new_name_slug)
  end
end
