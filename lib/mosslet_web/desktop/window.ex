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
       title: "Mosslet",
       size: {1200, 800},
       min_size: {800, 600},
       icon: icon_path(),
       menubar: MossletWeb.Desktop.MenuBar,
       url: &MossletWeb.Endpoint.url/0
     ]}
  end

  @doc """
  Returns the window options for dynamic configuration.
  """
  def options do
    [
      app: :mosslet,
      id: MossletWindow,
      title: "Mosslet",
      size: {1200, 800},
      min_size: {800, 600},
      icon: icon_path(),
      menubar: MossletWeb.Desktop.MenuBar,
      url: &MossletWeb.Endpoint.url/0
    ]
  end

  defp icon_path do
    priv_path = :code.priv_dir(:mosslet)
    Path.join([priv_path, "static", "images", "icon.png"])
  end
end
