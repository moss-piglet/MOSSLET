defmodule MossletWeb.SyncStatusHook do
  @moduledoc """
  LiveView hook for subscribing to sync status updates.

  This hook subscribes to the `Mosslet.Sync` GenServer's status broadcasts
  and assigns the sync status to the socket. Only active on native platforms
  where the Sync GenServer is running.

  ## Usage

  Add to a `live_session` in your router:

      live_session :authenticated,
        on_mount: [
          {MossletWeb.UserOnMountHooks, :require_authenticated_user},
          MossletWeb.SyncStatusHook
        ] do
        live "/timeline", TimelineLive.Index
      end

  Then use in your template:

      <.layout sync_status={@sync_status} ...>
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    if Mosslet.Platform.native?() do
      socket =
        socket
        |> assign(:sync_status, nil)
        |> attach_hook(:sync_status_connected, :handle_info, &handle_info/2)

      if connected?(socket) do
        sync_status =
          case apply(Mosslet.Sync, :subscribe_and_get_status, []) do
            {:ok, status} -> status
            {:error, :not_running} -> nil
          end

        {:cont, assign(socket, :sync_status, sync_status)}
      else
        {:cont, socket}
      end
    else
      {:cont, assign(socket, :sync_status, nil)}
    end
  end

  defp handle_info({:sync_status, status}, socket) do
    {:cont, assign(socket, :sync_status, status)}
  end

  defp handle_info(_message, socket) do
    {:cont, socket}
  end
end
