defmodule MossletWeb.Desktop.WindowTest do
  use ExUnit.Case, async: true

  @moduletag :desktop

  if Code.ensure_loaded?(Desktop.Window) do
    alias MossletWeb.Desktop.Window

    describe "child_spec/0" do
      test "returns valid Desktop.Window child spec" do
        {module, opts} = Window.child_spec()

        assert module == Desktop.Window
        assert Keyword.get(opts, :app) == :mosslet
        assert Keyword.get(opts, :id) == MossletWindow
        assert Keyword.get(opts, :title) == "MOSSLET"
        assert Keyword.get(opts, :size) == {1200, 800}
        assert Keyword.get(opts, :min_size) == {800, 600}
        assert Keyword.get(opts, :menubar) == MossletWeb.Desktop.MenuBar
        assert is_function(Keyword.get(opts, :url), 0)
      end

      test "icon path points to priv directory" do
        {_module, opts} = Window.child_spec()
        icon_path = Keyword.get(opts, :icon)

        assert String.contains?(icon_path, "priv")
        assert String.ends_with?(icon_path, "icon.png")
      end
    end

    describe "options/0" do
      test "returns same configuration as child_spec" do
        {_module, child_opts} = Window.child_spec()
        opts = Window.options()

        assert Keyword.get(opts, :app) == Keyword.get(child_opts, :app)
        assert Keyword.get(opts, :id) == Keyword.get(child_opts, :id)
        assert Keyword.get(opts, :title) == Keyword.get(child_opts, :title)
        assert Keyword.get(opts, :size) == Keyword.get(child_opts, :size)
      end
    end
  end
end
