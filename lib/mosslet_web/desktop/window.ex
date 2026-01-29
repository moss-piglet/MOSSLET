if Code.ensure_loaded?(Desktop.Window) do
  defmodule MossletWeb.Desktop.Window do
    @moduledoc """
    Desktop window configuration for the native Mosslet app.

    This module defines the native window settings used by elixir-desktop
    when running as a desktop application.
    """

    @doc """
    Returns the child specification for the Desktop.Window process.
    """
    def child_spec do
      {Desktop.Window,
       [
         app: :mosslet,
         id: MossletWindow,
         title: "MOSSLET",
         size: {1200, 800},
         min_size: {800, 600},
         icon: icon_path(),
         menubar: MossletWeb.Desktop.MenuBar,
         url: &base_url/0
       ]}
    end

    @doc """
    Returns the window options for dynamic configuration.
    """
    def options do
      [
        app: :mosslet,
        id: MossletWindow,
        title: "MOSSLET",
        size: {1200, 800},
        min_size: {800, 600},
        icon: icon_path(),
        menubar: MossletWeb.Desktop.MenuBar,
        url: &base_url/0
      ]
    end

    defp base_url do
      {:ok, {_ip, port}} = MossletWeb.Endpoint.server_info(:http)
      "http://localhost:#{port}/users/log-in"
    end

    defp icon_path do
      priv_path = :code.priv_dir(:mosslet)
      Path.join([priv_path, "static", "images", "icon.png"])
    end
  end
end
