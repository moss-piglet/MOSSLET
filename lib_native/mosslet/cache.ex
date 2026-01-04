defmodule Mosslet.Cache do
  @moduledoc """
  Local cache operations for desktop/mobile apps.

  This module provides functions to store/retrieve encrypted blobs from
  the local SQLite database for offline support.

  ## Usage

  The cache stores encrypted data as-is from the server. No additional
  encryption is applied here since the data is already enacl-encrypted.

  ## Cache Operations

  - `cache_item/4` - Cache an encrypted blob from the server
  - `get_cached_item/2` - Retrieve a cached item by type and ID
  - `invalidate_cache/2` - Remove a cached item
  - `clear_cache/0` - Clear all cached items

  ## Sync Queue Operations

  - `queue_for_sync/3` - Queue a local change for sync
  - `get_pending_sync_items/0` - Get all pending items to sync
  - `mark_synced/1` - Mark an item as successfully synced
  - `mark_sync_failed/2` - Mark an item as failed with error

  ## Local Settings

  - `get_setting/1` - Get a local setting value
  - `set_setting/2` - Set a local setting value
  """

  import Ecto.Query
  alias Mosslet.Cache.{CachedItem, SyncQueueItem, LocalSetting}
  alias Mosslet.Repo.SQLite

  @doc """
  Cache an encrypted blob from the server.

  ## Parameters

  - `resource_type` - Type of resource (e.g., "post", "message")
  - `resource_id` - UUID of the resource
  - `encrypted_data` - The enacl-encrypted blob
  - `opts` - Optional: `:encrypted_key`, `:etag`

  ## Examples

      iex> Mosslet.Cache.cache_item("post", post_id, encrypted_blob, encrypted_key: key, etag: "abc123")
      {:ok, %CachedItem{}}
  """
  def cache_item(resource_type, resource_id, encrypted_data, opts \\ []) do
    attrs = %{
      resource_type: resource_type,
      resource_id: normalize_id(resource_id),
      encrypted_data: encrypted_data,
      encrypted_key: opts[:encrypted_key],
      etag: opts[:etag],
      cached_at: DateTime.utc_now()
    }

    %CachedItem{}
    |> CachedItem.changeset(attrs)
    |> SQLite.insert(
      on_conflict: {:replace, [:encrypted_data, :encrypted_key, :etag, :cached_at]},
      conflict_target: [:resource_type, :resource_id]
    )
  end

  @doc """
  Retrieve a cached item by type and ID.
  """
  def get_cached_item(resource_type, resource_id) do
    SQLite.get_by(CachedItem,
      resource_type: resource_type,
      resource_id: normalize_id(resource_id)
    )
  end

  @doc """
  Get all cached items of a specific type.
  """
  def list_cached_items(resource_type, opts \\ []) do
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0

    CachedItem
    |> where([c], c.resource_type == ^resource_type)
    |> order_by([c], desc: c.cached_at)
    |> limit(^limit)
    |> offset(^offset)
    |> SQLite.all()
  end

  @doc """
  Check if a cached item is stale based on etag.
  """
  def cache_stale?(resource_type, resource_id, server_etag) do
    case get_cached_item(resource_type, resource_id) do
      nil -> true
      cached -> cached.etag != server_etag
    end
  end

  @doc """
  Delete a cached item. Alias for `invalidate_cache/2`.
  """
  def delete_cached_item(resource_type, resource_id) do
    invalidate_cache(resource_type, resource_id)
  end

  @doc """
  Remove a cached item.
  """
  def invalidate_cache(resource_type, resource_id) do
    CachedItem
    |> where([c], c.resource_type == ^resource_type)
    |> where([c], c.resource_id == ^normalize_id(resource_id))
    |> SQLite.delete_all()

    :ok
  end

  @doc """
  Clear all cached items, optionally filtered by type.
  """
  def clear_cache(resource_type \\ nil) do
    query =
      if resource_type do
        CachedItem |> where([c], c.resource_type == ^resource_type)
      else
        CachedItem
      end

    SQLite.delete_all(query)
    :ok
  end

  @doc """
  Queue a local change for sync when connectivity is restored.

  ## Parameters

  - `action` - "create", "update", or "delete"
  - `resource_type` - Type of resource being modified
  - `payload` - Encrypted payload to send to server
  - `opts` - Optional: `:resource_id` (for updates/deletes)
  """
  def queue_for_sync(action, resource_type, payload, opts \\ []) do
    attrs = %{
      action: action,
      resource_type: resource_type,
      resource_id: opts[:resource_id] && normalize_id(opts[:resource_id]),
      payload: payload,
      queued_at: DateTime.utc_now()
    }

    %SyncQueueItem{}
    |> SyncQueueItem.changeset(attrs)
    |> SQLite.insert()
  end

  @doc """
  Get all pending sync items, ordered by queue time.
  """
  def get_pending_sync_items(opts \\ []) do
    limit = opts[:limit] || 50

    SyncQueueItem
    |> where([s], s.status == "pending")
    |> order_by([s], asc: s.queued_at)
    |> limit(^limit)
    |> SQLite.all()
  end

  @doc """
  Get failed sync items for retry.
  """
  def get_failed_sync_items(max_retries \\ 3) do
    SyncQueueItem
    |> where([s], s.status == "failed")
    |> where([s], s.retry_count < ^max_retries)
    |> order_by([s], asc: s.queued_at)
    |> SQLite.all()
  end

  @doc """
  Mark a sync item as currently syncing.
  """
  def mark_syncing(%SyncQueueItem{} = item) do
    item
    |> SyncQueueItem.mark_syncing()
    |> SQLite.update()
  end

  @doc """
  Mark a sync item as successfully synced.
  """
  def mark_synced(%SyncQueueItem{} = item) do
    item
    |> SyncQueueItem.mark_completed()
    |> SQLite.update()
  end

  @doc """
  Mark a sync item as failed with an error message.
  """
  def mark_sync_failed(%SyncQueueItem{} = item, error_message) do
    item
    |> SyncQueueItem.mark_failed(error_message)
    |> SQLite.update()
  end

  @doc """
  Delete completed sync items older than the specified duration.
  """
  def cleanup_completed_sync_items(older_than_hours \\ 24) do
    cutoff = DateTime.utc_now() |> DateTime.add(-older_than_hours * 3600, :second)

    SyncQueueItem
    |> where([s], s.status == "completed")
    |> where([s], s.synced_at < ^cutoff)
    |> SQLite.delete_all()

    :ok
  end

  @doc """
  Get sync queue statistics.
  """
  def sync_queue_stats do
    SyncQueueItem
    |> group_by([s], s.status)
    |> select([s], {s.status, count(s.id)})
    |> SQLite.all()
    |> Map.new()
  end

  @doc """
  Get a local setting value.
  """
  def get_setting(key) do
    case SQLite.get_by(LocalSetting, key: key) do
      nil -> nil
      setting -> setting.value
    end
  end

  @doc """
  Set a local setting value.
  """
  def set_setting(key, value) do
    attrs = %{key: key, value: value}

    %LocalSetting{}
    |> LocalSetting.changeset(attrs)
    |> SQLite.insert(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:key]
    )
  end

  @doc """
  Delete a local setting.
  """
  def delete_setting(key) do
    LocalSetting
    |> where([s], s.key == ^key)
    |> SQLite.delete_all()

    :ok
  end

  @doc """
  Get all local settings as a map.
  """
  def all_settings do
    LocalSetting
    |> SQLite.all()
    |> Map.new(fn s -> {s.key, s.value} end)
  end

  defp normalize_id(id) when is_binary(id), do: id

  defp normalize_id(id) do
    case Ecto.UUID.dump(id) do
      {:ok, binary} -> binary
      :error -> id
    end
  end
end
