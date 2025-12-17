defmodule Mosslet.Cache.CachedItem do
  @moduledoc """
  Schema for caching encrypted blobs from the cloud server.

  Stores enacl-encrypted data for offline viewing. The data received from
  the server is already enacl-encrypted, and we add an additional device-specific
  Cloak encryption layer for defense-in-depth.

  Fields:
  - `resource_type` - Type of resource (e.g., "post", "message", "group")
  - `resource_id` - UUID of the resource from the server
  - `encrypted_data` - The enacl-encrypted blob from server (wrapped with device key)
  - `encrypted_key` - The user's encrypted access key for this resource (wrapped with device key)
  - `etag` - For cache invalidation (server-provided)
  - `cached_at` - When the item was cached locally
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted.Native

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "cached_items" do
    field :resource_type, :string
    field :resource_id, :binary_id
    field :encrypted_data, Native.Binary
    field :encrypted_key, Native.Binary
    field :etag, :string
    field :cached_at, :utc_datetime
  end

  def changeset(cached_item, attrs) do
    cached_item
    |> cast(attrs, [
      :resource_type,
      :resource_id,
      :encrypted_data,
      :encrypted_key,
      :etag,
      :cached_at
    ])
    |> validate_required([:resource_type, :resource_id, :encrypted_data, :cached_at])
    |> unique_constraint([:resource_type, :resource_id])
  end
end
