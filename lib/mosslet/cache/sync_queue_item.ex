defmodule Mosslet.Cache.SyncQueueItem do
  @moduledoc """
  Schema for queuing pending changes when offline.

  When the device is offline, local changes are queued here and
  synced to the cloud server when connectivity is restored.

  The payload is already enacl-encrypted before being stored here,
  and we add device-specific Cloak encryption for defense-in-depth.

  Fields:
  - `action` - The operation type ("create", "update", "delete")
  - `resource_type` - Type of resource being modified
  - `resource_id` - UUID of the resource (nil for creates)
  - `payload` - Encrypted payload to send to server (wrapped with device key)
  - `status` - Current sync status ("pending", "syncing", "failed", "completed")
  - `retry_count` - Number of sync attempts
  - `error_message` - Last error message if failed (wrapped with device key)
  - `queued_at` - When the item was queued
  - `synced_at` - When the item was successfully synced
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Mosslet.Encrypted.Native

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sync_queue" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :payload, Native.Binary
    field :status, :string, default: "pending"
    field :retry_count, :integer, default: 0
    field :error_message, Native.Binary
    field :queued_at, :utc_datetime
    field :synced_at, :utc_datetime
  end

  @valid_actions ~w(create update delete)
  @valid_statuses ~w(pending syncing failed completed)

  def changeset(sync_item, attrs) do
    sync_item
    |> cast(attrs, [
      :action,
      :resource_type,
      :resource_id,
      :payload,
      :status,
      :retry_count,
      :error_message,
      :queued_at,
      :synced_at
    ])
    |> validate_required([:action, :resource_type, :payload, :queued_at])
    |> validate_inclusion(:action, @valid_actions)
    |> validate_inclusion(:status, @valid_statuses)
  end

  def mark_syncing(sync_item) do
    sync_item
    |> change(%{status: "syncing"})
  end

  def mark_completed(sync_item) do
    sync_item
    |> change(%{status: "completed", synced_at: DateTime.utc_now()})
  end

  def mark_failed(sync_item, error_message) do
    sync_item
    |> change(%{
      status: "failed",
      error_message: error_message,
      retry_count: sync_item.retry_count + 1
    })
  end
end
