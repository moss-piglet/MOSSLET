defmodule MossletWeb.BillingLiveMembershipsTest do
  @moduledoc """
  Personal billing page (Task #239 follow-up): the `/app/billing` page surfaces
  the user's family/business seats + ownership alongside their personal plan, so
  the page stays coherent after an ownership transfer. A member with no personal
  plan still sees they hold an org seat; an owner sees their org (even trialing).
  """
  use MossletWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  @password "hello world hello world!"

  defp get_key(user) do
    {:ok, key} = Accounts.User.valid_key_hash?(user, @password)
    key
  end

  defp log_in(conn, user, key) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, Accounts.generate_user_session_token(user))
    |> Plug.Conn.put_session(:key, key)
  end

  defp onboarded_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: email, password: @password})
    user = Accounts.confirm_user!(user)
    {:ok, user} = Accounts.update_user_onboarding(user, %{is_onboarded?: true})
    {user, get_key(user)}
  end

  defp add_member(org, user) do
    {:ok, {:ok, _ms}} =
      Mosslet.Repo.transaction_on_primary(fn ->
        Orgs.Membership.insert_changeset(org, user, :member) |> Mosslet.Repo.insert()
      end)

    :ok
  end

  defp subscribe_org(org, status) do
    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "business-monthly",
        status: status,
        quantity: 20,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    :ok
  end

  describe "personal billing page org-membership section" do
    test "an owner of a trialing org sees their membership card and is NOT told they have no membership",
         %{conn: conn} do
      {owner, owner_key} = onboarded_user("owner")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Co", "type" => "business"})
      subscribe_org(org, "trialing")

      {:ok, lv, _html} = conn |> log_in(owner, owner_key) |> live(~p"/app/billing")

      assert has_element?(lv, "#org-memberships-card")
      assert has_element?(lv, "#org-membership-#{org.id}")

      # No personal plan, but covered by the org seat -> the amber notice must be
      # the softened "No Personal Plan", never the stark "No Active Membership".
      html = render(lv)
      assert html =~ "No Personal Plan"
      refute html =~ "No Active Membership"
    end

    test "a plain member with no personal plan sees their seat card", %{conn: conn} do
      {owner, _ok} = onboarded_user("owner")
      {member, member_key} = onboarded_user("member")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme Co", "type" => "business"})
      add_member(org, member)
      subscribe_org(org, "active")

      {:ok, lv, _html} = conn |> log_in(member, member_key) |> live(~p"/app/billing")

      assert has_element?(lv, "#org-membership-#{org.id}")
      assert render(lv) =~ "No Personal Plan"
    end

    test "a user with no orgs sees no membership card and the standard notice", %{conn: conn} do
      {user, key} = onboarded_user("solo")

      {:ok, lv, _html} = conn |> log_in(user, key) |> live(~p"/app/billing")

      refute has_element?(lv, "#org-memberships-card")
      assert render(lv) =~ "No Active Membership"
    end
  end
end
