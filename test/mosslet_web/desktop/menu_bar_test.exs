if System.get_env("MOSSLET_NATIVE") == "true" do
  defmodule MossletWeb.Desktop.MenuBarTest do
    use ExUnit.Case, async: true

    alias MossletWeb.Desktop.MenuBar

    describe "mount/1" do
      test "assigns app_name" do
        menu = %Desktop.Menu{assigns: %{}}
        {:ok, menu} = MenuBar.mount(menu)

        assert menu.assigns.app_name == "MOSSLET"
      end
    end

    describe "handle_event/2" do
      test "handles unknown commands gracefully" do
        menu = %Desktop.Menu{assigns: %{app_name: "MOSSLET"}}
        {:noreply, _menu} = MenuBar.handle_event("unknown_command", menu)
      end
    end

    describe "handle_info/2" do
      test "handles messages without crashing" do
        menu = %Desktop.Menu{assigns: %{app_name: "MOSSLET"}}
        {:noreply, returned_menu} = MenuBar.handle_info(:some_message, menu)

        assert returned_menu.assigns.app_name == "MOSSLET"
      end
    end

    describe "render/1" do
      test "returns HEEx template with menu structure" do
        assigns = %{app_name: "MOSSLET"}
        rendered = MenuBar.render(assigns)

        assert %Phoenix.LiveView.Rendered{} = rendered
      end
    end
  end
end
