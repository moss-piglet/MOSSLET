defmodule MossletWeb.ConnectionComponentsTest do
  @moduledoc """
  Component-level coverage for `MossletWeb.ConnectionComponents`.
  """
  use MossletWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias MossletWeb.ConnectionComponents

  describe "key_verification_panel/1 transparency-log states" do
    setup do
      [
        assigns: %{
          id: "kvp-test",
          peer_user_id: Ecto.UUID.generate(),
          peer_public_key: "cGVlci1wdWJsaWMta2V5",
          peer_pq_public_key: "cGVlci1wcS1wdWJsaWMta2V5",
          sealed_peer_pin: nil
        }
      ]
    end

    test "anchored log state carries the witness cosignature line, hidden by default", %{
      assigns: assigns
    } do
      html = render_component(&ConnectionComponents.key_verification_panel/1, assigns)

      assert html =~ ~s(data-log-state="anchored")

      # The hook fills + unhides this line client-side ONLY when >= 1
      # pinned-witness cosignature verifies; server-side it must render
      # hidden so an empty witness network is byte-identical to today's UI.
      document = LazyHTML.from_fragment(html)
      line = LazyHTML.query(document, "[data-log-state='anchored'] > p[data-log-witnesses]")

      assert LazyHTML.to_html(line) =~ "data-log-witnesses-text"
      assert LazyHTML.attribute(line, "hidden") == [""]
    end

    test "non-anchored log states render no witness line", %{assigns: assigns} do
      html = render_component(&ConnectionComponents.key_verification_panel/1, assigns)

      document = LazyHTML.from_fragment(html)

      for state <- ~w(pending_checkpoint not_published key_mismatch proof_invalid unavailable) do
        block = LazyHTML.query(document, "[data-log-state='#{state}']")
        assert LazyHTML.query(block, "[data-log-witnesses]") |> LazyHTML.to_html() == ""
      end
    end
  end
end
