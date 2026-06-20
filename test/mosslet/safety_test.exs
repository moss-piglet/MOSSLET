defmodule Mosslet.SafetyTest do
  use ExUnit.Case, async: true

  alias Mosslet.Safety

  describe "resolve_us_state/1" do
    test "resolves well-known ZIPs to the correct state" do
      assert {:ok, "California"} = Safety.resolve_us_state("94103")
      assert {:ok, "New York"} = Safety.resolve_us_state("10001")
      assert {:ok, "Massachusetts"} = Safety.resolve_us_state("02139")
      assert {:ok, "Alaska"} = Safety.resolve_us_state("99501")
      assert {:ok, "Illinois"} = Safety.resolve_us_state("60601")
      assert {:ok, "Florida"} = Safety.resolve_us_state("33101")
    end

    test "tolerates ZIP+4 and surrounding whitespace" do
      assert {:ok, "California"} = Safety.resolve_us_state(" 90210-1234 ")
    end

    test "returns :error for non-ZIP input" do
      assert :error = Safety.resolve_us_state("abc")
      assert :error = Safety.resolve_us_state("")
      assert :error = Safety.resolve_us_state(nil)
      assert :error = Safety.resolve_us_state("12")
    end
  end

  describe "data" do
    test "us_resources and global_resources are non-empty and well-formed" do
      for r <- Safety.us_resources() ++ Safety.global_resources() do
        assert is_binary(r.name) and r.name != ""
        assert is_binary(r.url) and String.starts_with?(r.url, "https://")
        assert is_binary(r.icon) and String.starts_with?(r.icon, "hero-")
        assert is_binary(r.gradient)
      end

      assert [_ | _] = Safety.us_resources()
      assert [_ | _] = Safety.global_resources()
    end

    test "countries/0 includes the US and a fallback option" do
      codes = Enum.map(Safety.countries(), &elem(&1, 1))
      assert "US" in codes
      assert "OTHER" in codes
    end

    test "us?/1 only matches the US code" do
      assert Safety.us?("US")
      refute Safety.us?("CA")
      refute Safety.us?(nil)
    end
  end
end
