defmodule Mosslet.Announcements.Announcement do
  @moduledoc """
  Two-tier ZK announcement (Task #229c). An announcement is the metadata + the
  browser-encrypted title/body for ONE notice posted into either an org-wide
  dashboard (`org_id`) OR a single business circle (`group_id`) — never both
  (the XOR is enforced by the context + a DB CHECK constraint; see the
  `create_announcements` migration and `Mosslet.Announcements`).

  The `encrypted_title`/`encrypted_body` are `Encrypted.Binary`: the browser
  ciphertext (secretbox under the tier's shared key — the per-org `org_key` for
  the org tier, the circle's `group_key` for the circle tier) is additionally
  Cloak-wrapped server-side. The server never sees the plaintext or the key
  (invariants I2/I3) — exactly the pattern used by `Mosslet.Files.SharedFile`.

  `org_id`, `group_id`, and `author_id` are set programmatically by the context
  — never `cast` from user params (encryption/security guidelines).
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Announcements.AnnouncementRead
  alias Mosslet.Encrypted
  alias Mosslet.Groups.Group
  alias Mosslet.Orgs.Org

  @priorities [:normal, :pinned]

  def priorities, do: @priorities

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "announcements" do
    field :encrypted_title, Encrypted.Binary, redact: true
    field :encrypted_body, Encrypted.Binary, redact: true

    field :priority, Ecto.Enum, values: @priorities, default: :normal
    field :expires_at, :utc_datetime

    belongs_to :org, Org
    belongs_to :group, Group
    belongs_to :author, User

    has_many :announcement_reads, AnnouncementRead

    timestamps()
  end

  @doc """
  ZK insert changeset for an ORG-wide announcement. The browser produced the
  encrypted title/body; `org_id` + `author_id` are stamped server-side (never
  trusted from the client). The raw `org_key` NEVER reaches the server.
  """
  def org_insert_changeset(%Org{} = org, %User{} = author, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:encrypted_title, :encrypted_body, :priority, :expires_at])
    |> validate_required([:encrypted_body])
    |> put_change(:org_id, org.id)
    |> put_change(:author_id, author.id)
    |> foreign_key_constraint(:org_id)
  end

  @doc """
  ZK insert changeset for a CIRCLE-level announcement. The browser produced the
  encrypted title/body; `group_id` + `author_id` are stamped server-side. The
  raw `group_key` NEVER reaches the server.
  """
  def circle_insert_changeset(%Group{} = group, %User{} = author, attrs) do
    %__MODULE__{}
    |> cast(attrs, [:encrypted_title, :encrypted_body, :priority, :expires_at])
    |> validate_required([:encrypted_body])
    |> put_change(:group_id, group.id)
    |> put_change(:author_id, author.id)
    |> foreign_key_constraint(:group_id)
  end

  @doc """
  ZK update changeset (author edit). Only the encrypted content + surface
  metadata change; the scoping FKs and author are immutable.
  """
  def update_changeset(%__MODULE__{} = announcement, attrs) do
    announcement
    |> cast(attrs, [:encrypted_title, :encrypted_body, :priority, :expires_at])
    |> validate_required([:encrypted_body])
  end
end
