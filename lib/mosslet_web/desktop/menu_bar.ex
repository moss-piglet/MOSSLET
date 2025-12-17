defmodule MossletWeb.Desktop.MenuBar do
  @moduledoc """
  Native application menu bar for the Mosslet desktop app.

  Uses the Desktop.Menu behaviour with ~H sigil for HEEx templates
  (manual approach to avoid deprecated sigil_E/sigil_L issues).
  """
  @behaviour Desktop.Menu

  import Desktop.Menu, only: [assign: 2]
  import Phoenix.Component, only: [sigil_H: 2]

  @impl true
  def mount(menu) do
    menu = assign(menu, app_name: "MOSSLET")
    {:ok, menu}
  end

  @impl true
  def handle_event(command, menu) do
    case command do
      "quit" ->
        Desktop.Window.quit()

      "about" ->
        Desktop.Window.show(MossletWindow, base_url() <> "/about")

      "help" ->
        Desktop.Window.show(MossletWindow, base_url() <> "/support")

      "home" ->
        Desktop.Window.show(MossletWindow, base_url() <> "/")

      "settings" ->
        Desktop.Window.show(MossletWindow, base_url() <> "/app/users/edit-details")

      "sync_now" ->
        Mosslet.Sync.sync_now()

      "check_updates" ->
        Desktop.Window.show(MossletWindow, base_url() <> "/updates")

      _ ->
        :ok
    end

    {:noreply, menu}
  end

  @impl true
  def handle_info(_msg, menu) do
    {:noreply, menu}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <menubar>
      <menu label={@app_name}>
        <item onclick="about">About {@app_name}</item>
        <hr />
        <item onclick="settings">Settings...</item>
        <hr />
        <item onclick="quit">Quit {@app_name}</item>
      </menu>
      <menu label="File">
        <item onclick="home">Home</item>
        <hr />
        <item onclick="sync_now">Sync Now</item>
      </menu>
      <menu label="Help">
        <item onclick="help">Mosslet Support</item>
        <item onclick="check_updates">Check for Updates...</item>
      </menu>
    </menubar>
    """
  end

  defp base_url do
    {:ok, {_ip, port}} = MossletWeb.Endpoint.server_info(:http)
    "http://localhost:#{port}"
  end
end
