defmodule MossletWeb.BotDefenseHook do
  @moduledoc """
  LiveView on_mount hook to block banned IPs at the socket level.

  This hook extracts the client IP from connect_info (using x_headers for
  proxied requests or peer_data for direct connections) and checks against
  the BotDefense ban list.

  ## Requirements

  The socket must be configured with `:x_headers` and `:peer_data` in connect_info:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [:peer_data, :x_headers, :user_agent, session: @session_options]]

  ## Usage

  Add to live_session in your router:

      live_session :default,
        on_mount: [{MossletWeb.BotDefenseHook, :check_banned}] do
        ...
      end
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Mosslet.Security.BotDefense

  require Logger

  @doc """
  Checks if the connecting IP is banned and halts the socket if so.
  """
  def on_mount(:check_banned, _params, _session, socket) do
    case get_client_ip(socket) do
      nil ->
        {:cont, socket}

      ip ->
        if BotDefense.banned?(ip) do
          BotDefense.increment_blocked_request(ip)
          Logger.warning("BotDefenseHook: Blocked banned IP #{format_ip(ip)} from LiveView")
          {:halt, socket}
        else
          {:cont, assign(socket, :client_ip, ip)}
        end
    end
  end

  defp get_client_ip(socket) do
    if connected?(socket) do
      get_connected_ip(socket)
    else
      nil
    end
  end

  defp get_connected_ip(socket) do
    x_headers = get_connect_info(socket, :x_headers) || []
    peer_data = get_connect_info(socket, :peer_data)

    cond do
      ip = extract_ip_from_headers(x_headers) ->
        ip

      peer_data && peer_data.address ->
        peer_data.address

      true ->
        nil
    end
  end

  defp extract_ip_from_headers(headers) do
    configured_headers = Application.get_env(:mosslet, :remote_ip_headers, ~w[fly-client-ip])
    configured_proxies = Application.get_env(:mosslet, :remote_ip_proxies, [])

    RemoteIp.from(headers, headers: configured_headers, proxies: configured_proxies)
  end

  defp format_ip(ip) when is_tuple(ip) do
    :inet.ntoa(ip) |> to_string()
  end

  defp format_ip(_), do: "unknown"
end
