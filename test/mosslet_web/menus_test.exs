defmodule MossletWeb.MenusTest do
  @moduledoc """
  Covers the plan-aware helpers that tailor the settings page and sidebar to a
  user's Personal/Family/Business plan (EPIC #207, Task #217).
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs
  alias MossletWeb.Menus

  # Makes the user own an ACTIVE org of the given type — the basis for
  # Family/Business UI under the Option B model (Task #235). Org membership +
  # an active `:org`-source subscription is what surfaces org nav; the owner's
  # personal plan is irrelevant. Returns the (unchanged) user.
  defp active_org(user, type) do
    {:ok, org} =
      Orgs.create_org(user, %{
        "name" => "Org #{System.unique_integer([:positive])}",
        "type" => Atom.to_string(type)
      })

    {:ok, customer} =
      Customers.create_customer_for_source(:org, org.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "#{type}-monthly",
        status: "active",
        quantity: 1,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    user
  end

  # An active personal (:user) subscription. Independent of org status — used to
  # prove a personal plan does NOT make a user appear Family/Business.
  defp personal_subscription(user) do
    {:ok, customer} =
      Customers.create_customer_for_source(:user, user.id, %{
        email: "billing-#{System.unique_integer([:positive])}@example.com",
        provider: "stripe",
        provider_customer_id: "cus_#{System.unique_integer([:positive])}"
      })

    {:ok, _subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: "personal-monthly",
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

    test "a personal subscriber (no org) is still personal" do
      user = user_fixture() |> personal_subscription()
      assert Menus.plan_type(user) == :personal
    end

    test "an active family org owner is family" do
      user = user_fixture() |> active_org(:family)
      assert Menus.plan_type(user) == :family
    end

    test "an active business org owner is business" do
      user = user_fixture() |> active_org(:business)
      assert Menus.plan_type(user) == :business
    end
  end

  describe "plan_label/1" do
    test "labels match the plan type" do
      assert Menus.plan_label(nil) == "Personal"
      assert Menus.plan_label(user_fixture()) == "Personal"
      assert Menus.plan_label(user_fixture() |> active_org(:family)) == "Family"
      assert Menus.plan_label(user_fixture() |> active_org(:business)) == "Business"
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

    test "manage_family link only appears for active family org users" do
      assert Menus.get_link(:manage_family, user_fixture()) == nil

      family_user = user_fixture() |> active_org(:family)

      assert %{name: :manage_family, path: "/app/family"} =
               Menus.get_link(:manage_family, family_user)
    end

    test "manage_business link only appears for active business org users" do
      assert Menus.get_link(:manage_business, user_fixture()) == nil

      business_user = user_fixture() |> active_org(:business)

      assert %{name: :manage_business, path: "/app/business"} =
               Menus.get_link(:manage_business, business_user)
    end
  end
end
