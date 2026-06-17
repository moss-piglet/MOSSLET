defmodule MossletWeb.BillingLiveOrphanGuardTest do
  @moduledoc """
  Orphan guard (Task #237): an owner canceling the org's `:org`-source plan while
  other members still depend on its coverage is intercepted with a friendly
  "transfer ownership or delete" notice — BEFORE any Stripe call. Single-member
  orgs (owner only) can cancel freely.
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

  defp subscribe_org(org) do
    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "business-monthly",
        status: "active",
        quantity: 20,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    subscription
  end

  describe "org-cancel orphan guard" do
    test "owner of a multi-member org is blocked with the transfer/delete notice", %{conn: conn} do
      {owner, owner_key} = onboarded_user("owner")
      {member, _mk} = onboarded_user("member")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Acme", "type" => "business"})
      add_member(org, member)
      subscription = subscribe_org(org)

      {:ok, lv, _html} =
        conn |> log_in(owner, owner_key) |> live(~p"/app/org/#{org.slug}/billing")

      render_hook(lv, "cancel_subscription", %{"subscription-id" => subscription.id})

      assert has_element?(lv, "#orphan-guard-modal")
      assert has_element?(lv, "#orphan-guard-transfer")
      # The delete affordance is now LIVE (Task #227): it deep-links to the org
      # dashboard's danger zone rather than being a disabled "coming soon" stub.
      assert has_element?(lv, "#orphan-guard-delete[href$='#org-danger-zone']")

      # The subscription is untouched — no Stripe cancel happened.
      assert Subscriptions.get_subscription!(subscription.id).status == "active"
    end

    test "owner of a single-member org is NOT blocked (no one stranded)", %{conn: conn} do
      {owner, owner_key} = onboarded_user("solo")
      {:ok, org} = Orgs.create_org(owner, %{"name" => "Solo Co", "type" => "business"})
      subscription = subscribe_org(org)

      {:ok, lv, _html} =
        conn |> log_in(owner, owner_key) |> live(~p"/app/org/#{org.slug}/billing")

      # No guard modal — cancellation proceeds (the Stripe call fails in test with
      # no API key, surfacing an error flash, but crucially NOT the orphan guard).
      render_hook(lv, "cancel_subscription", %{"subscription-id" => subscription.id})

      refute has_element?(lv, "#orphan-guard-modal")
    end
  end
end
