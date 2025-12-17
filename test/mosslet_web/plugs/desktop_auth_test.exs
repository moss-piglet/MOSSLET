defmodule MossletWeb.Plugs.DesktopAuthTest do
  use MossletWeb.ConnCase, async: true

  alias MossletWeb.Plugs.DesktopAuth

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [some: :option]
      assert DesktopAuth.init(opts) == opts
    end

    test "returns empty opts" do
      assert DesktopAuth.init([]) == []
    end
  end

  describe "module behavior" do
    test "implements Plug behaviour" do
      behaviours = MossletWeb.Plugs.DesktopAuth.__info__(:attributes)[:behaviour] || []
      assert Plug in behaviours
    end

    test "exports init/1 and call/2" do
      exports = MossletWeb.Plugs.DesktopAuth.__info__(:functions)
      assert {:init, 1} in exports
      assert {:call, 2} in exports
    end
  end
end
