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
  - `get_cached_item/3` - Retrieve a user-scoped cached item
  - `get_cached_items_by_type/2` - Get all cached items of a type with options
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
  - `opts` - Optional: `:encrypted_key`, `:etag`, `:user_id`

  ## Examples

      iex> Mosslet.Cache.cache_item("post", post_id, encrypted_blob, encrypted_key: key, etag: "abc123")
      {:ok, %CachedItem{}}

      iex> Mosslet.Cache.cache_item("journal_entry", entry_id, data, user_id: user_id)
      {:ok, %CachedItem{}}
  """
  def cache_item(resource_type, resource_id, encrypted_data, opts \\ []) do
    attrs = %{
      resource_type: resource_type,
      resource_id: normalize_id(resource_id),
      user_id: opts[:user_id] && normalize_id(opts[:user_id]),
      encrypted_data: encrypted_data,
      encrypted_key: opts[:encrypted_key],
      etag: opts[:etag],
      cached_at: DateTime.utc_now()
    }

    conflict_target =
      if opts[:user_id] do
        [:resource_type, :resource_id, :user_id]
      else
        [:resource_type, :resource_id]
      end

    %CachedItem{}
    |> CachedItem.changeset(attrs)
    |> SQLite.insert(
      on_conflict: {:replace, [:encrypted_data, :encrypted_key, :etag, :cached_at]},
      conflict_target: conflict_target
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
  Retrieve a user-scoped cached item by type, ID and user_id.
  """
  def get_cached_item(resource_type, resource_id, opts) when is_list(opts) do
    user_id = opts[:user_id]

    if user_id do
      SQLite.get_by(CachedItem,
        resource_type: resource_type,
        resource_id: normalize_id(resource_id),
        user_id: normalize_id(user_id)
      )
    else
      get_cached_item(resource_type, resource_id)
    end
  end

  @doc """
  Get all cached items of a specific type.
  """
  def list_cached_items(resource_type, opts \\ []) do
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0
    user_id = opts[:user_id]

    query =
      CachedItem
      |> where([c], c.resource_type == ^resource_type)
      |> order_by([c], desc: c.cached_at)
      |> limit(^limit)
      |> offset(^offset)

    query =
      if user_id do
        where(query, [c], c.user_id == ^normalize_id(user_id))
      else
        query
      end

    SQLite.all(query)
  end

  @doc """
  Get all cached items of a specific type with user_id filtering.
  Alias for list_cached_items with user_id option.
  """
  def get_cached_items_by_type(resource_type, opts \\ []) do
    list_cached_items(resource_type, opts)
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
  Delete a cached item.
  """
  def delete_cached_item(resource_type, resource_id) do
    invalidate_cache(resource_type, resource_id)
  end

  @doc """
  Delete a user-scoped cached item.
  """
  def delete_cached_item(resource_type, resource_id, opts) when is_list(opts) do
    user_id = opts[:user_id]

    if user_id do
      CachedItem
      |> where([c], c.resource_type == ^resource_type)
      |> where([c], c.resource_id == ^normalize_id(resource_id))
      |> where([c], c.user_id == ^normalize_id(user_id))
      |> SQLite.delete_all()

      :ok
    else
      delete_cached_item(resource_type, resource_id)
    end
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
  Remove a user-scoped cached item.
  """
  def invalidate_cache(resource_type, resource_id, opts) when is_list(opts) do
    delete_cached_item(resource_type, resource_id, opts)
  end

  @doc """
  Clear all cached items, optionally filtered by type and/or user_id.
  """
  def clear_cache(resource_type \\ nil, opts \\ []) do
    user_id = opts[:user_id]

    query =
      CachedItem
      |> then(fn q ->
        if resource_type, do: where(q, [c], c.resource_type == ^resource_type), else: q
      end)
      |> then(fn q ->
        if user_id, do: where(q, [c], c.user_id == ^normalize_id(user_id)), else: q
      end)

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

  defp normalize_id(nil), do: nil
  defp normalize_id(id) when is_binary(id), do: id

  defp normalize_id(id) do
    case Ecto.UUID.dump(id) do
      {:ok, binary} -> binary
      :error -> id
    end
  end
end
