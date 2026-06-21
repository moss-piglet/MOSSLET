defmodule MossletWeb.PublicLive.BusinessPlanTest do
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "/business-plan (public)" do
    test "renders without authentication", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/business-plan")
      assert html =~ "Private collaboration that scales"
      assert html =~ "Private business circles"
      assert html =~ "Zero-knowledge file sharing"
      assert html =~ "audit log"
      assert html =~ "branding add-on" or html =~ "branding"
    end

    test "CTAs link to plan-aware signup and pricing", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/business-plan")
      assert html =~ "plan=business"
      assert html =~ ~s(href="/pricing")
    end

    test "footer surfaces Family, Business, and Safety links", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/business-plan")
      assert html =~ ~s(href="/family-plan")
      assert html =~ ~s(href="/business-plan")
      assert html =~ ~s(href="/safety")
    end
  end
end
