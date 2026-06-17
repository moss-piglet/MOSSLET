defmodule MossletWeb.SubscribeControllerTest do
  @moduledoc """
  Checkout guard (Task #239): starting a NEW Stripe Checkout Session while an
  active/trialing subscription already exists would create a SECOND live Stripe
  subscription (duplicate charge). Both the `:user` and `:org` checkout clauses
  must refuse and redirect to billing instead. Interval/plan changes go through
  SubscribeLive's in-place `change_plan` (Stripe Billing Portal update), not here.
  """
  use MossletWeb.ConnCase

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions

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

  defp subscribe_user(user, status) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
        status: status,
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    subscription
  end

  describe "GET /app/checkout/:plan_id (:user)" do
    test "refuses a new checkout when an ACTIVE :user sub exists and keeps the local row",
         %{conn: conn} do
      {user, key} = onboarded_user("active")
      subscription = subscribe_user(user, "active")

      conn = conn |> log_in(user, key) |> get(~p"/app/checkout/personal-monthly")

      assert redirected_to(conn) == ~p"/app/billing"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "existing active subscription"

      # The local Subscription row must NOT be deleted (the old bug deleted it,
      # then opened a fresh Checkout -> duplicate live Stripe sub).
      assert Subscriptions.get_subscription!(subscription.id).status == "active"
    end

    test "refuses a new checkout when a TRIALING :user sub exists", %{conn: conn} do
      {user, key} = onboarded_user("trial")
      subscription = subscribe_user(user, "trialing")

      conn = conn |> log_in(user, key) |> get(~p"/app/checkout/personal-monthly")

      assert redirected_to(conn) == ~p"/app/billing"
      assert Subscriptions.get_subscription!(subscription.id).status == "trialing"
    end
  end
end
