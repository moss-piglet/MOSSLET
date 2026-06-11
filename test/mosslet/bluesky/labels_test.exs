defmodule Mosslet.Bluesky.LabelsTest do
  use ExUnit.Case, async: true

  alias Mosslet.Bluesky.Labels

  describe "self_labels_for_export/2" do
    test "returns a graphic-media self-label when mature_content is true" do
      assert %{
               "$type" => "com.atproto.label.defs#selfLabels",
               "values" => [%{"val" => "graphic-media"}]
             } = Labels.self_labels_for_export(true, false)
    end

    test "returns a self-label when content_warning? is true" do
      assert %{"values" => [%{"val" => "graphic-media"}]} =
               Labels.self_labels_for_export(false, true)
    end

    test "returns nil when neither flag is set" do
      assert Labels.self_labels_for_export(false, false) == nil
    end
  end

  describe "sensitive?/1" do
    test "true for atomized labels with a sensitive value" do
      assert Labels.sensitive?(%{values: [%{val: "graphic-media"}]})
      assert Labels.sensitive?(%{values: [%{val: "porn"}]})
      assert Labels.sensitive?(%{values: [%{val: "nudity"}]})
      assert Labels.sensitive?(%{values: [%{val: "sexual"}]})
    end

    test "true for string-keyed labels" do
      assert Labels.sensitive?(%{"values" => [%{"val" => "graphic-media"}]})
    end

    test "false for non-sensitive values" do
      refute Labels.sensitive?(%{values: [%{val: "spam"}]})
    end

    test "false for nil or malformed labels" do
      refute Labels.sensitive?(nil)
      refute Labels.sensitive?(%{})
      refute Labels.sensitive?(%{values: "not-a-list"})
      refute Labels.sensitive?(%{values: [%{wrong: "shape"}]})
    end
  end
end
