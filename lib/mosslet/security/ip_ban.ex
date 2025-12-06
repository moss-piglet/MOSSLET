defmodule Mosslet.Security.IpBan do
  @moduledoc """
  Schema for tracking banned IP addresses.

  IP addresses are stored as HMAC hashes for privacy - we can check if an IP
  is banned without storing the actual IP address in plaintext.

  All sensitive fields (reason, expires_at, metadata) are encrypted with Cloak
  for server-side encryption.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ip_bans" do
    field :ip_hash, Encrypted.HMAC
    field :reason, Encrypted.Binary
    field :source, Ecto.Enum, values: [:manual, :rate_limit, :honeypot, :cloud_ip, :suspicious]
    field :expires_at, Encrypted.DateTime
    field :request_count, :integer, default: 0
    field :metadata, Encrypted.Map

    belongs_to :banned_by, Mosslet.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(ip_ban, attrs) do
    ip_ban
    |> cast(attrs, [
      :ip_hash,
      :reason,
      :source,
      :expires_at,
      :request_count,
      :metadata,
      :banned_by_id
    ])
    |> validate_required([:ip_hash, :source])
    |> unique_constraint(:ip_hash)
  end

  def increment_request_count_changeset(ip_ban) do
    ip_ban
    |> change(request_count: ip_ban.request_count + 1)
  end
end
