defmodule Mosslet.Notifications.DeviceToken do
  @moduledoc """
  Schema for storing device push notification tokens.

  🔐 ZERO-KNOWLEDGE ARCHITECTURE:
  - Device tokens are encrypted at rest (Cloak)
  - Token hash allows lookup without decryption
  - Push payloads contain ONLY generic content + metadata IDs
  - Actual notification content is fetched & decrypted on device

  Platforms:
  - :ios - Apple Push Notification service (APNs)
  - :android - Firebase Cloud Messaging (FCM)
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "device_tokens" do
    field :token, Encrypted.Binary, redact: true
    field :token_hash, Encrypted.HMAC, redact: true
    field :platform, Ecto.Enum, values: [:ios, :android]
    field :device_name, Encrypted.Binary, redact: true
    field :app_version, :string
    field :os_version, :string
    field :active, :boolean, default: true
    field :last_used_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:token, :platform, :user_id]
  @optional_fields [:device_name, :app_version, :os_version, :active, :last_used_at]

  def changeset(device_token, attrs) do
    device_token
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:platform, [:ios, :android])
    |> put_token_hash()
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:token_hash)
  end

  def update_changeset(device_token, attrs) do
    device_token
    |> cast(attrs, [:device_name, :app_version, :os_version, :active, :last_used_at])
  end

  def deactivate_changeset(device_token) do
    change(device_token, active: false)
  end

  def touch_changeset(device_token) do
    change(device_token, last_used_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp put_token_hash(changeset) do
    case get_change(changeset, :token) do
      nil -> changeset
      token -> put_change(changeset, :token_hash, token)
    end
  end
end
