defmodule MossletWeb.PublicLive.FamilyPlanTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "/family-plan (public)" do
    test "renders without authentication", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/family-plan")
      assert html =~ "Stay close, without surveillance"
      assert html =~ "Consent-based guardianship"
      assert html =~ "no master key"
      assert html =~ "transparency"
    end

    test "CTAs link to plan-aware signup and pricing", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/family-plan")

      assert html =~ ~s(href="/auth/register?billing=year&amp;plan=family") or
               html =~ "plan=family"

      assert html =~ ~s(href="/pricing")
    end

    test "links to the public safety page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/family-plan")
      assert html =~ ~s(href="/safety")
    end

    test "footer surfaces Family, Business, and Safety links", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/family-plan")
      assert html =~ ~s(href="/family-plan")
      assert html =~ ~s(href="/business-plan")
      assert html =~ ~s(href="/safety")
    end
  end
end
