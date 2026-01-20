defmodule Mosslet.Bluesky.Account do
  @moduledoc """
  Schema for storing Bluesky account credentials and sync settings.
  All sensitive data (DID, handle, tokens, keys) is encrypted at rest.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bluesky_accounts" do
    field :did, Encrypted.Binary, redact: true
    field :did_hash, Encrypted.HMAC, redact: true
    field :handle, Encrypted.Binary, redact: true
    field :handle_hash, Encrypted.HMAC, redact: true

    field :access_jwt, Encrypted.Binary, redact: true
    field :refresh_jwt, Encrypted.Binary, redact: true
    field :signing_key, Encrypted.Binary, redact: true

    field :pds_url, Encrypted.Binary, redact: true
    field :pds_url_hash, Encrypted.HMAC, redact: true

    field :sync_enabled, :boolean, default: false
    field :sync_posts_to_bsky, :boolean, default: false
    field :sync_posts_from_bsky, :boolean, default: false
    field :auto_delete_from_bsky, :boolean, default: false

    field :import_visibility, Ecto.Enum,
      values: [:public, :private, :connections],
      default: :private

    field :last_synced_at, :utc_datetime
    field :last_cursor, Encrypted.Binary, redact: true

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :did,
      :handle,
      :access_jwt,
      :refresh_jwt,
      :signing_key,
      :pds_url,
      :sync_enabled,
      :sync_posts_to_bsky,
      :sync_posts_from_bsky,
      :auto_delete_from_bsky,
      :last_synced_at,
      :last_cursor
    ])
    |> validate_required([:did, :handle])
    |> add_did_hash()
    |> add_handle_hash()
    |> add_pds_url_hash()
  end

  @doc false
  def create_changeset(account, attrs) do
    account
    |> cast(attrs, [
      :did,
      :handle,
      :access_jwt,
      :refresh_jwt,
      :signing_key,
      :pds_url
    ])
    |> validate_required([:did, :handle, :access_jwt, :refresh_jwt])
    |> add_did_hash()
    |> add_handle_hash()
    |> add_pds_url_hash()
  end

  @doc false
  def sync_settings_changeset(account, attrs) do
    account
    |> cast(attrs, [
      :sync_enabled,
      :sync_posts_to_bsky,
      :sync_posts_from_bsky,
      :auto_delete_from_bsky,
      :import_visibility
    ])
  end

  @doc false
  def refresh_tokens_changeset(account, attrs) do
    account
    |> cast(attrs, [:access_jwt, :refresh_jwt])
    |> validate_required([:access_jwt, :refresh_jwt])
  end

  @doc false
  def sync_cursor_changeset(account, attrs) do
    account
    |> cast(attrs, [:last_synced_at, :last_cursor])
  end

  defp add_did_hash(changeset) do
    case get_change(changeset, :did) do
      nil -> changeset
      did -> put_change(changeset, :did_hash, String.downcase(did))
    end
  end

  defp add_handle_hash(changeset) do
    case get_change(changeset, :handle) do
      nil -> changeset
      handle -> put_change(changeset, :handle_hash, String.downcase(handle))
    end
  end

  defp add_pds_url_hash(changeset) do
    case get_change(changeset, :pds_url) do
      nil -> changeset
      pds_url -> put_change(changeset, :pds_url_hash, String.downcase(pds_url))
    end
  end
end
