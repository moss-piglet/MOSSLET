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
  Ensures the user has an active personal (`:user`) subscription.

  NOTE: As of Task #235, this is NOT required to create an org — personal and
  org billing are fully independent. This helper remains only for tests that
  specifically need a personal plan on the user. Idempotent.
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
  Attaches an active `:org`-source subscription to `org`, so it counts as
  covered/paid. This is the billing relationship that activates an org and
  covers its member seats (Task #235). Idempotent on customer creation.

  Options:
    * `:plan_id` — defaults to a plan matching the org type
      (`"family-monthly"`/`"business-monthly"`).
    * `:status` — defaults to `"active"`.
    * `:quantity` — seat count, defaults to `1`.
  """
  def ensure_org_subscription(org, opts \\ []) do
    plan_id = Keyword.get(opts, :plan_id, "#{org.type}-monthly")
    status = Keyword.get(opts, :status, "active")
    quantity = Keyword.get(opts, :quantity, 1)

    customer =
      case Customers.get_customer_by_source(:org, org.id) do
        nil ->
          {:ok, customer} =
            Customers.create_customer_for_source(:org, org.id, %{
              email: "billing-#{System.unique_integer([:positive])}@example.com",
              provider: "stripe",
              provider_customer_id: "cus_#{System.unique_integer([:positive])}"
            })

          customer

        customer ->
          customer
      end

    {:ok, subscription} =
      Subscriptions.create_subscription(%{
        billing_customer_id: customer.id,
        plan_id: plan_id,
        status: status,
        quantity: quantity,
        provider_subscription_id: "sub_#{System.unique_integer([:positive])}",
        provider_subscription_items: [%{price: "price_test"}],
        current_period_start: NaiveDateTime.utc_now()
      })

    {customer, subscription}
  end

  @doc """
  Generate an organization for a user.

  Org creation no longer requires the owner to have a personal subscription
  (Task #235) — only a confirmed user. Use `ensure_org_subscription/2` when the
  org needs active coverage.
  """
  def org_fixture(user, attrs \\ %{}) do
    attrs = valid_org_attributes(attrs)

    {:ok, org} = Orgs.create_org(user, attrs)

    org
  end
end
