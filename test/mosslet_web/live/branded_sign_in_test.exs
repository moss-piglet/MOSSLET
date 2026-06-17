defmodule MossletWeb.BrandedSignInTest do
  @moduledoc """
  Task #240 / #243 (Phase B, slice D): org-branded sign-in accent.

  On a LIVE org subdomain host the Mosslet sign-in page shows the org NAME as an
  accent, alongside a persistent, non-hideable Mosslet identity ("Secured by
  MOSSLET"). Anti-impersonation: it is always unmistakably a Mosslet page, the
  form still authenticates against Mosslet, and a resolved-but-unentitled org
  (add-on lapsed) shows NO branding (resolve-but-don't-serve).

  `async: false` — sets the global `:canonical_host` config.
  """
  use MossletWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @base_host "mosslet.com"

  setup do
    previous = Application.get_env(:mosslet, :canonical_host)
    Application.put_env(:mosslet, :canonical_host, @base_host)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:mosslet, :canonical_host, previous),
        else: Application.delete_env(:mosslet, :canonical_host)
    end)

    :ok
  end

  defp addon_price,
    do:
      Mosslet.Billing.Plans.subdomain_addon_price(
        Mosslet.Billing.Plans.get_plan_by_id!("business-monthly")
      )

  defp business_org_named(name) do
    {:ok, org} = Orgs.create_org(user_fixture(), %{"name" => name, "type" => "business"})
    org
  end

  defp set_subdomain!(org, subdomain) do
    {:ok, {:ok, org}} =
      Repo.transaction_on_primary(fn ->
        org |> Org.subdomain_changeset(%{"subdomain" => subdomain}) |> Repo.update()
      end)

    org
  end

  defp on_subdomain(conn, subdomain), do: %{conn | host: "#{subdomain}.#{@base_host}"}

  test "a LIVE org subdomain shows the org name accent + persistent Secured by MOSSLET", %{
    conn: conn
  } do
    org = business_org_named("Branded Acme Co")
    set_subdomain!(org, "brandedacme")
    ensure_org_subscription(org, items: [%{"price_id" => addon_price()}])

    {:ok, _lv, html} = conn |> on_subdomain("brandedacme") |> live(~p"/auth/sign_in")

    assert html =~ "Branded Acme Co"
    assert html =~ "Secured by MOSSLET"
    assert html =~ "org-branded-signin"
    # Still a real Mosslet sign-in form (auth not weakened/replaced).
    assert html =~ "login_form"
  end

  test "a resolved-but-UNENTITLED org (no add-on) shows NO branding (resolve-but-don't-serve)", %{
    conn: conn
  } do
    org = business_org_named("Lapsed Co")
    set_subdomain!(org, "lapsedco")
    ensure_org_subscription(org, items: [%{"price_id" => "price_base_only"}])

    {:ok, _lv, html} = conn |> on_subdomain("lapsedco") |> live(~p"/auth/sign_in")

    refute html =~ "org-branded-signin"
    refute html =~ "Lapsed Co"
    # The cold/plain Mosslet sign-in still renders.
    assert html =~ "Sign in"
  end

  test "the apex host stays the plain Mosslet-forward sign-in (no org branding)", %{conn: conn} do
    org = business_org_named("Apex Hidden Co")
    set_subdomain!(org, "apexhidden")
    ensure_org_subscription(org, items: [%{"price_id" => addon_price()}])

    {:ok, _lv, html} = %{conn | host: @base_host} |> live(~p"/auth/sign_in")

    refute html =~ "org-branded-signin"
    refute html =~ "Apex Hidden Co"
  end

  test "the registration page mirrors the branded accent on a live subdomain (Task #243)", %{
    conn: conn
  } do
    org = business_org_named("Branded Register Co")
    set_subdomain!(org, "brandedregister")
    ensure_org_subscription(org, items: [%{"price_id" => addon_price()}])

    {:ok, _lv, html} = conn |> on_subdomain("brandedregister") |> live(~p"/auth/register")

    assert html =~ "org-branded-register"
    assert html =~ "Branded Register Co"
    assert html =~ "Secured by MOSSLET"
  end

  test "registration on an unentitled subdomain shows NO branding", %{conn: conn} do
    org = business_org_named("Lapsed Register Co")
    set_subdomain!(org, "lapsedregister")
    ensure_org_subscription(org, items: [%{"price_id" => "price_base_only"}])

    {:ok, _lv, html} = conn |> on_subdomain("lapsedregister") |> live(~p"/auth/register")

    refute html =~ "org-branded-register"
    refute html =~ "Lapsed Register Co"
  end

  test "the forgot-password page shows the branded accent on a live subdomain", %{conn: conn} do
    org = business_org_named("Branded Reset Co")
    set_subdomain!(org, "brandedreset")
    ensure_org_subscription(org, items: [%{"price_id" => addon_price()}])

    {:ok, _lv, html} = conn |> on_subdomain("brandedreset") |> live(~p"/auth/reset-password")

    assert html =~ "org-branded-reset"
    assert html =~ "Branded Reset Co"
    assert html =~ "Secured by MOSSLET"
  end
end
