defmodule MossletWeb.SyncHelpers do
  @moduledoc """
  Helpers for sync status in LiveViews.

  Provides a unified interface for subscribing to sync status updates
  that works for both web (no-op) and native (actual subscription) deployments.

  ## Usage in LiveView

      def mount(_params, _session, socket) do
        sync_status = MossletWeb.SyncHelpers.subscribe_to_sync(socket)
        {:ok, assign(socket, sync_status: sync_status)}
      end

      def handle_info({:sync_status, status}, socket) do
        {:noreply, MossletWeb.SyncHelpers.handle_sync_status(socket, status)}
      end
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [connected?: 1, push_event: 3]

  @doc """
  Subscribes to sync status updates if running on native platform.

  Returns the initial sync status map or nil for web deployments.
  Should be called in LiveView mount/3.
  """
  def subscribe_to_sync(socket) do
    if connected?(socket) && Mosslet.Platform.native?() do
      case apply(sync_module(), :subscribe_and_get_status, []) do
        {:ok, status} -> status
        {:error, :not_running} -> nil
      end
    else
      nil
    end
  end

  @doc """
  Handles incoming sync status updates.

  Updates the socket assigns and pushes an event to the JS hook.
  """
  def handle_sync_status(socket, status) do
    socket
    |> assign(:sync_status, status)
    |> push_event("sync_status", status)
  end

  @doc """
  Handles network online event from browser.
  Triggers an immediate sync check.
  """
  def handle_network_online(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :sync_now, [])
    end

    socket
  end

  @doc """
  Handles network offline event from browser.
  Updates the sync status to offline.
  """
  def handle_network_offline(socket) do
    status = %{
      online: false,
      syncing: false,
      last_sync: socket.assigns[:sync_status][:last_sync],
      pending_count: socket.assigns[:sync_status][:pending_count] || 0
    }

    socket
    |> assign(:sync_status, status)
    |> push_event("sync_status", status)
  end

  defp sync_module do
    if Code.ensure_loaded?(Mosslet.Sync) do
      Mosslet.Sync
    else
      raise "Mosslet.Sync is not available in this deployment"
    end
  end
end
