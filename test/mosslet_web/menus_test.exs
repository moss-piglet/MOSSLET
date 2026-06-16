defmodule MossletWeb.MenusTest do
  @moduledoc """
  Covers the plan-aware helpers that tailor the settings page and sidebar to a
  user's Personal/Family/Business plan (EPIC #207, Task #217).
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias MossletWeb.Menus

  # Gives the user an active (:user-source) subscription whose plan_id carries
  # the given prefix, exercising the `active_plan_type` resolution path without
  # needing to spin up a full (crypto-heavy) org.
  defp active_subscription(user, plan_id) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: plan_id,
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    user
  end

  describe "plan_type/1" do
    test "nil user is personal" do
      assert Menus.plan_type(nil) == :personal
    end

    test "a user without an org or plan is personal" do
      user = user_fixture()
      assert Menus.plan_type(user) == :personal
    end

    test "an active family subscriber is family" do
      user = user_fixture() |> active_subscription("family-monthly")
      assert Menus.plan_type(user) == :family
    end

    test "an active business subscriber is business" do
      user = user_fixture() |> active_subscription("business-monthly")
      assert Menus.plan_type(user) == :business
    end
  end

  describe "plan_label/1" do
    test "labels match the plan type" do
      assert Menus.plan_label(nil) == "Personal"
      assert Menus.plan_label(user_fixture()) == "Personal"
      assert Menus.plan_label(user_fixture() |> active_subscription("family-monthly")) == "Family"

      assert Menus.plan_label(user_fixture() |> active_subscription("business-monthly")) ==
               "Business"
    end
  end

  describe "has_pending_invitations?/1" do
    test "false for nil and for a user with no invitations" do
      refute Menus.has_pending_invitations?(nil)
      refute Menus.has_pending_invitations?(user_fixture())
    end
  end

  describe "get_link/2 Plan & Organization entries" do
    test "billing link is present (user-source billing)" do
      user = user_fixture()
      assert %{name: :billing, path: "/app/billing"} = Menus.get_link(:billing, user)
    end

    test "org_invitations link is nil without pending invitations" do
      assert Menus.get_link(:org_invitations, user_fixture()) == nil
    end

    test "manage_family link only appears for family users" do
      assert Menus.get_link(:manage_family, user_fixture()) == nil

      family_user = user_fixture() |> active_subscription("family-monthly")

      assert %{name: :manage_family, path: "/app/family"} =
               Menus.get_link(:manage_family, family_user)
    end

    test "manage_business link only appears for business users" do
      assert Menus.get_link(:manage_business, user_fixture()) == nil

      business_user = user_fixture() |> active_subscription("business-monthly")

      assert %{name: :manage_business, path: "/app/business"} =
               Menus.get_link(:manage_business, business_user)
    end
  end
end
