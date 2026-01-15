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

  ## Background Sync Events

  To handle background sync events from the BackgroundSyncHook, add event handlers:

      def handle_event("app_state_changed", %{"state" => state}, socket) do
        {:noreply, MossletWeb.SyncHelpers.handle_app_state_change(socket, state)}
      end

      def handle_event("network_reconnected", _params, socket) do
        {:noreply, MossletWeb.SyncHelpers.handle_network_reconnected(socket)}
      end

      def handle_event("background_sync_triggered", _params, socket) do
        {:noreply, MossletWeb.SyncHelpers.handle_background_sync(socket)}
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
  Handles app state change events from BackgroundSyncHook.

  Updates the Sync GenServer with the new app state and triggers
  sync when app becomes active.
  """
  def handle_app_state_change(socket, state) when is_binary(state) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :set_app_state, [state])
    end

    socket
    |> assign(:app_state, String.to_atom(state))
  end

  @doc """
  Handles app becoming active from background.

  Triggers an immediate sync to refresh data.
  """
  def handle_app_became_active(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :set_app_state, [:active])
      apply(sync_module(), :sync_now, [])
    end

    socket
    |> assign(:app_state, :active)
  end

  @doc """
  Handles network reconnection event.

  Notifies the Sync GenServer that connectivity was restored.
  """
  def handle_network_reconnected(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :network_restored, [])
    end

    socket
  end

  @doc """
  Handles background sync triggered by OS.

  Called when iOS Background Fetch or Android WorkManager triggers a sync.
  """
  def handle_background_sync(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :background_sync, [])
    end

    socket
  end

  @doc """
  Handles network online event from browser.
  Triggers an immediate sync check.
  """
  def handle_network_online(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :network_restored, [])
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
      pending_count: socket.assigns[:sync_status][:pending_count] || 0,
      app_state: socket.assigns[:sync_status][:app_state] || :active
    }

    socket
    |> assign(:sync_status, status)
    |> push_event("sync_status", status)
  end

  @doc """
  Requests a manual sync.

  Can be called from a LiveView in response to user action (e.g., pull-to-refresh).
  """
  def request_sync(socket) do
    if Mosslet.Platform.native?() do
      apply(sync_module(), :sync_now, [])
    end

    socket
  end

  @doc """
  Returns the current app state from socket assigns.

  Defaults to :active if not set.
  """
  def app_state(socket) do
    socket.assigns[:app_state] || :active
  end

  @doc """
  Checks if the app is currently in the foreground.
  """
  def app_in_foreground?(socket) do
    app_state(socket) == :active
  end

  defp sync_module do
    if Code.ensure_loaded?(Mosslet.Sync) do
      Mosslet.Sync
    else
      raise "Mosslet.Sync is not available in this deployment"
    end
  end
end
