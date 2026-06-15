defmodule Mosslet.Files.SharedFile do
  @moduledoc """
  Org-scoped ZK file-sharing record (Task #221, see
  `docs/ZK_FILE_SHARING_DESIGN.md`).

  A `SharedFile` is the metadata for ONE browser-encrypted file shared into a
  business circle. The opaque encrypted blob lives on object storage (Tigris);
  only the Cloak-wrapped pointer + encrypted metadata live in Postgres. The
  per-recipient sealed `file_key` lives on `UserSharedFile.key` (mirrors
  `UserPost`/`UserGroup`). The server never sees the `file_key` or plaintext
  (invariants I2/I3).

  All FKs (`group_id`, `org_id`, `uploader_id`) are set programmatically by the
  context — never `cast` from user params (encryption/security guidelines).
  """
  use Mosslet.Schema

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Files.UserSharedFile
  alias Mosslet.Groups.Group
  alias Mosslet.Orgs.Org

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "shared_files" do
    # Cloak-wrapped ciphertext (`Encrypted.Binary`) — see migration for the
    # meaning of each field. `storage_path` is the only required encrypted
    # field; the rest are browser-encrypted-with-file_key and may be absent if
    # an older/limited client didn't provide them.
    field :storage_path, Encrypted.Binary, redact: true
    field :encrypted_filename, Encrypted.Binary, redact: true
    field :checksum, Encrypted.Binary, redact: true
    field :scan_verdict, Encrypted.Binary, redact: true

    # Plaintext system metric (non-sensitive) for quota/UX.
    field :size_bytes, :integer

    belongs_to :group, Group
    belongs_to :org, Org
    belongs_to :uploader, User

    has_many :user_shared_files, UserSharedFile

    timestamps()
  end

  @doc """
  ZK insert changeset for a shared file. The browser produced the opaque blob
  (already uploaded) and the encrypted metadata. `group_id`, `org_id`, and
  `uploader_id` are stamped server-side (server-authoritative — never trust the
  client for these). The raw `file_key` NEVER reaches the server.
  """
  def insert_changeset(%Group{} = group, %User{} = uploader, attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :storage_path,
      :encrypted_filename,
      :checksum,
      :scan_verdict,
      :size_bytes
    ])
    |> validate_required([:storage_path])
    |> put_change(:group_id, group.id)
    |> put_change(:org_id, group.org_id)
    |> put_change(:uploader_id, uploader.id)
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:org_id)
  end
end
