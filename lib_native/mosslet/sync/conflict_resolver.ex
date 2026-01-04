defmodule Mosslet.Sync.ConflictResolver do
  @moduledoc """
  Conflict resolution for sync operations.

  Implements Last-Write-Wins (LWW) strategy with server timestamp as the
  authoritative source. When a local change conflicts with a server change:

  1. Compare timestamps (server's `updated_at` vs local `queued_at`)
  2. Server wins ties (it has canonical time)
  3. If local change is rejected, update local cache with server version

  ## Conflict Scenarios

  - **No conflict**: Local create/update succeeds, server returns the saved resource
  - **Update conflict**: Resource was modified on server since local change was queued
  - **Delete conflict**: Resource was deleted on server, local update is rejected
  - **Stale data**: Server returns newer version, local cache is updated

  ## Future Enhancements

  - Optional conflict logging for user review
  - Merge strategies for specific resource types
  - Conflict notification to UI
  """

  require Logger

  alias Mosslet.Cache

  @doc """
  Resolve any conflicts after a sync operation completes.

  Called after server accepts or rejects a local change. Updates local
  cache to match server state.

  ## Parameters

  - `sync_item` - The SyncQueueItem that was synced
  - `server_response` - The response from the server API

  ## Returns

  - `:ok` - Resolution complete (may have updated cache)
  - `{:conflict, :server_wins}` - Server had newer data, cache updated
  - `{:conflict, :deleted}` - Resource was deleted on server
  """
  def resolve(sync_item, server_response) do
    case sync_item.action do
      "create" -> resolve_create(sync_item, server_response)
      "update" -> resolve_update(sync_item, server_response)
      "delete" -> resolve_delete(sync_item, server_response)
    end
  end

  defp resolve_create(sync_item, server_response) do
    case server_response do
      %{id: server_id} = resource ->
        Cache.cache_item(
          sync_item.resource_type,
          server_id,
          Jason.encode!(resource),
          etag: resource[:etag]
        )

        :ok

      _ ->
        :ok
    end
  end

  defp resolve_update(sync_item, server_response) do
    case server_response do
      %{id: _id, updated_at: server_updated_at} = resource ->
        local_queued_at = sync_item.queued_at

        if server_wins?(server_updated_at, local_queued_at) do
          Logger.info(
            "Conflict resolved: server wins for #{sync_item.resource_type}:#{sync_item.resource_id}"
          )

          Cache.cache_item(
            sync_item.resource_type,
            sync_item.resource_id,
            Jason.encode!(resource),
            etag: resource[:etag]
          )

          {:conflict, :server_wins}
        else
          Cache.cache_item(
            sync_item.resource_type,
            sync_item.resource_id,
            Jason.encode!(resource),
            etag: resource[:etag]
          )

          :ok
        end

      %{error: "not_found"} ->
        Logger.info(
          "Conflict resolved: resource deleted on server #{sync_item.resource_type}:#{sync_item.resource_id}"
        )

        Cache.invalidate_cache(sync_item.resource_type, sync_item.resource_id)
        {:conflict, :deleted}

      _ ->
        :ok
    end
  end

  defp resolve_delete(sync_item, server_response) do
    case server_response do
      %{error: "not_found"} ->
        :ok

      _ ->
        Cache.invalidate_cache(sync_item.resource_type, sync_item.resource_id)
        :ok
    end
  end

  defp server_wins?(server_updated_at, local_queued_at) do
    server_dt = parse_datetime(server_updated_at)
    local_dt = parse_datetime(local_queued_at)

    case {server_dt, local_dt} do
      {nil, _} -> false
      {_, nil} -> true
      {s, l} -> DateTime.compare(s, l) in [:gt, :eq]
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
