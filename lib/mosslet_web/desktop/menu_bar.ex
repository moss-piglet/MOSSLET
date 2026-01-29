if Code.ensure_loaded?(Desktop.Menu) do
  defmodule MossletWeb.Desktop.MenuBar do
    @moduledoc """
    Native application menu bar for the Mosslet desktop app.

    Uses the Desktop.Menu behaviour with ~H sigil for HEEx templates.
    Marketing pages open in the user's default external browser.
    """
    @behaviour Desktop.Menu

    import Desktop.Menu, only: [assign: 2]
    import Phoenix.Component, only: [sigil_H: 2]

    @marketing_base_url "https://mosslet.com"

    @marketing_paths ~w(/about /blog /discover /faq /features / /pricing /privacy /referrals /terms /updates)

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

        "settings" ->
          Desktop.Window.show(MossletWindow, app_url("/app/users/edit-details"))

        "sync_now" ->
          Mosslet.Sync.sync_now()

        "about" ->
          open_external("/about")

        "blog" ->
          open_external("/blog")

        "discover" ->
          open_external("/discover")

        "faq" ->
          open_external("/faq")

        "features" ->
          open_external("/features")

        "home" ->
          open_external("/")

        "pricing" ->
          open_external("/pricing")

        "privacy" ->
          open_external("/privacy")

        "referrals" ->
          open_external("/referrals")

        "terms" ->
          open_external("/terms")

        "updates" ->
          open_external("/updates")

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
          <item onclick="sync_now">Sync Now</item>
        </menu>
        <menu label="Help">
          <item onclick="faq">FAQ</item>
          <item onclick="features">Features</item>
          <item onclick="blog">Blog</item>
          <hr />
          <item onclick="pricing">Pricing</item>
          <item onclick="referrals">Referrals</item>
          <hr />
          <item onclick="updates">Check for Updates...</item>
        </menu>
        <menu label="Legal">
          <item onclick="terms">Terms of Service</item>
          <item onclick="privacy">Privacy Policy</item>
        </menu>
      </menubar>
      """
    end

    defp app_url(path) do
      {:ok, {_ip, port}} = MossletWeb.Endpoint.server_info(:http)
      "http://localhost:#{port}#{path}"
    end

    defp open_external(path) when path in @marketing_paths do
      url = @marketing_base_url <> path
      :wx_misc.launchDefaultBrowser(String.to_charlist(url))
    end
  end
end
