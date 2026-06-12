defmodule Mosslet.OrgsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mosslet.Orgs` context.
  """

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  def unique_org_name, do: "Org #{System.unique_integer([:positive])}"
  def unique_org_slug, do: "org-#{System.unique_integer([:positive])}"

  def valid_org_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => unique_org_name(),
      "slug" => unique_org_slug()
    })
  end

  @doc """
  Ensures the user has an active personal (:user) subscription so they are
  allowed to create orgs (org creation requires the owner to have finalized
  their own subscription signup — Task #215 follow-up). Idempotent.
  """
  def ensure_user_subscription(user) do
    unless Orgs.user_has_active_billing?(user) do
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
    end

    user
  end

  @doc """
  Generate an organization for a user.
  """
  def org_fixture(user, attrs \\ %{}) do
    attrs = valid_org_attributes(attrs)
    ensure_user_subscription(user)

    {:ok, org} = Orgs.create_org(user, attrs)

    org
  end
end
