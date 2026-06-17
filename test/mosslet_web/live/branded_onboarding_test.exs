defmodule MossletWeb.BrandedOnboardingTest do
  @moduledoc """
  Task #240 / #243 (Phase B, slice D — flagship): org-branded ONBOARDING.

  Unlike the pre-auth sign-in/registration accent (org NAME only), the onboarding
  surface is reached by a LOGGED-IN member who holds their `Membership.key` (the
  org key sealed for them). So here we can show the actual ZERO-KNOWLEDGE brand
  LOGO: the `OrgLogoDisplay` hook fetches the org_key-encrypted blob and decrypts
  it client-side. Anti-impersonation constraints still hold: persistent,
  non-hideable "Secured by MOSSLET", accent only, never a whitelabel.

  `async: false` — sets the global `:canonical_host` config.
  """
  use MossletWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures
  import Mosslet.OrgsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Org
  alias Mosslet.Repo

  @base_host "mosslet.com"
  @password valid_user_password()

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

  defp member_with_key do
    user = user_fixture(%{password: @password}) |> Accounts.confirm_user!()
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    {user, key}
  end

  defp live_business_org(owner, name) do
    {:ok, org} = Orgs.create_org(owner, %{"name" => name, "type" => "business"})

    {:ok, {:ok, org}} =
      Repo.transaction_on_primary(fn ->
        org |> Org.subdomain_changeset(%{"subdomain" => "team"}) |> Repo.update()
      end)

    ensure_org_subscription(org, items: [%{"price_id" => addon_price()}])
    org
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp on_subdomain(conn, subdomain), do: %{conn | host: "#{subdomain}.#{@base_host}"}

  test "a key-holding member sees the ZK brand logo + org name on the branded subdomain", %{
    conn: conn
  } do
    {owner, key} = member_with_key()
    org = live_business_org(owner, "Onboarding Acme Co")

    # Org has a logo (org_key-encrypted blob) and the viewer holds the sealed key.
    {:ok, _org} = Orgs.set_org_logo(org, "uploads/files/#{Ecto.UUID.generate()}.bin")

    {:ok, _count} =
      Orgs.seal_org_key_for_members(org, [
        %{user_id: owner.id, sealed_key: "sealed-org-key-#{System.unique_integer([:positive])}"}
      ])

    {:ok, lv, html} =
      conn |> log_in(owner, key) |> on_subdomain("team") |> live(~p"/app/users/onboarding")

    assert html =~ "org-branded-onboarding"
    assert html =~ "Onboarding Acme Co"
    assert html =~ "Secured by MOSSLET"
    # The ZK logo decrypt hook is wired (member holds the key) — never a raw URL.
    assert has_element?(lv, "#org-branded-onboarding-logo[phx-hook='OrgLogoDisplay']")
  end

  test "the apex host stays plain (no branded onboarding)", %{conn: conn} do
    {owner, key} = member_with_key()
    org = live_business_org(owner, "Apex Onboard Co")
    {:ok, _org} = Orgs.set_org_logo(org, "uploads/files/#{Ecto.UUID.generate()}.bin")

    {:ok, _lv, html} =
      %{log_in(conn, owner, key) | host: @base_host} |> live(~p"/app/users/onboarding")

    refute html =~ "org-branded-onboarding"
    refute html =~ "Apex Onboard Co"
  end
end
