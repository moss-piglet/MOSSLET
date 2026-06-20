defmodule MossletWeb.PublicLive.SafetyTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "/safety (public)" do
    test "renders without authentication", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/safety")
      assert html =~ "You&#39;re not alone" or html =~ "You're not alone"
      # Emergency guidance is always present.
      assert html =~ "emergency"
      # US resources are shown by default (US-first).
      assert html =~ "988"
      assert html =~ "Childhelp"
    end

    test "ZIP search surfaces the resolved US state", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/safety")

      html =
        lv
        |> form("#safety-area-form", area: %{country: "US", query: "10001"})
        |> render_submit()

      assert html =~ "New York, United States"
      assert html =~ "United States resources"
    end

    test "selecting a non-US country shows global directories and hides the ZIP field",
         %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/safety")

      html =
        lv
        |> form("#safety-area-form", area: %{country: "CA", query: ""})
        |> render_change()

      assert html =~ "Resources for Canada"
      assert html =~ "Find A Helpline"
      assert html =~ "Child Helpline International"
      # US-only crisis line is not shown for a non-US country.
      refute html =~ "988 Suicide"
      # ZIP input is only rendered for the US.
      refute html =~ ~s(name="area[query]")
    end

    test "links to terms and support", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/safety")
      assert html =~ ~s(href="/terms")
      assert html =~ ~s(href="/support")
    end
  end
end
