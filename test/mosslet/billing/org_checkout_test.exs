defmodule Mosslet.Billing.OrgCheckoutTest do
  @moduledoc """
  Section C of Task #235: verify the `:org`-source billing path is source-keyed
  end-to-end.

    * `CreateCheckoutSession.build_options/1` stamps the org's local customer id
      as `client_reference_id`, the source metadata (incl. an explicit `org_id`
      for :org sessions), and the trial `subscription_data` — without hitting
      Stripe.
    * A `customer.subscription.created`-style sync for the org's OWN `:org`
      customer creates an `:org` subscription and flips `Orgs.org_active?/1`
      to `true`.

  ZK guardrail (Task #235): billing metadata carries only internal ids +
  provider refs — never names/keys/emails.
  """
  use Mosslet.DataCase, async: true

  import Mosslet.AccountsFixtures

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Providers.Stripe.Services.CreateCheckoutSession
  alias Mosslet.Billing.Providers.Stripe.Services.SyncSubscription
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  defp confirmed_user(seed) do
    email = "#{seed}#{System.unique_integer([:positive])}@example.com"

    user_fixture(%{email: email, password: "hello world hello world!"})
    |> Accounts.confirm_user!()
  end

  defp family_org(user) do
    {:ok, org} =
      Orgs.create_org(user, %{
        "name" => "Org #{System.unique_integer([:positive])}",
        "type" => "family"
      })

    org
  end

  describe "CreateCheckoutSession.build_options/1 for an :org session" do
    test "stamps client_reference_id, source metadata, org_id, and trial data" do
      org_session = %CreateCheckoutSession{
        customer_id: "local_cust_123",
        source: :org,
        source_id: "org-uuid-abc",
        provider_customer_id: "cus_stripe_xyz",
        success_url: "http://x/success",
        cancel_url: "http://x/cancel",
        allow_promotion_codes: false,
        trial_period_days: 14,
        line_items: [%{price: "price_family_monthly", quantity: 1}],
        mode: "subscription",
        referral: nil
      }

      options = CreateCheckoutSession.build_options(org_session)

      # client_reference_id resolves to the org's OWN local customer id
      assert options.client_reference_id == "local_cust_123"
      assert options.customer == "cus_stripe_xyz"

      # source-keyed metadata, with explicit org_id for :org sessions
      assert options.metadata.source == :org
      assert options.metadata.source_id == "org-uuid-abc"
      assert options.metadata.org_id == "org-uuid-abc"

      # ZK guardrail: only ids in metadata — no names/keys/emails
      refute Map.has_key?(options.metadata, :email)
      refute Map.has_key?(options.metadata, :name)

      # trial threaded through for subscription mode
      assert options.subscription_data == %{trial_period_days: 14}
      assert options.payment_method_collection == "if_required"
    end

    test "omits org_id for a :user session and omits trial data in payment mode" do
      user_session = %CreateCheckoutSession{
        customer_id: "local_cust_456",
        source: :user,
        source_id: "user-uuid-1",
        provider_customer_id: "cus_stripe_personal",
        success_url: "http://x/success",
        cancel_url: "http://x/cancel",
        allow_promotion_codes: false,
        trial_period_days: nil,
        line_items: [%{price: "price_personal_lifetime", quantity: 1}],
        mode: "payment",
        referral: nil
      }

      options = CreateCheckoutSession.build_options(user_session)

      assert options.metadata.source == :user
      assert options.metadata.source_id == "user-uuid-1"
      refute Map.has_key?(options.metadata, :org_id)

      refute Map.has_key?(options, :subscription_data)
      refute Map.has_key?(options, :payment_method_collection)
    end
  end

  describe "webhook subscription sync for an org customer" do
    test "creates an :org subscription on the org's customer and flips org_active?/1 true" do
      user = confirmed_user("org-owner")
      org = family_org(user)

      # Inert org: no :org subscription yet.
      refute Orgs.org_active?(org)

      provider_customer_id = "cus_org_#{System.unique_integer([:positive])}"

      {:ok, customer} =
        Customers.create_customer_for_source(:org, org.id, %{
          email: "billing-#{System.unique_integer([:positive])}@example.com",
          provider: "stripe",
          provider_customer_id: provider_customer_id
        })

      now = System.system_time(:second)
      stripe_subscription_id = "sub_#{System.unique_integer([:positive])}"

      # Resolve the configured family-monthly price id from billing config so the
      # sync matches the plan regardless of which (env-driven) Stripe price id is
      # set in dev/test/CI.
      family_monthly = Plans.get_plan_by_id!("family-monthly")

      stripe_subscription = %Stripe.Subscription{
        id: stripe_subscription_id,
        customer: provider_customer_id,
        status: "trialing",
        cancel_at_period_end: false,
        cancel_at: nil,
        trial_end: now + 14 * 86_400,
        start_date: now,
        items: %{
          data: [
            %{
              id: "si_test",
              quantity: 1,
              current_period_start: now,
              current_period_end: now + 14 * 86_400,
              price: %{
                id: family_monthly.price,
                product: "prod_Ugc48UDU9hdbji"
              }
            }
          ]
        }
      }

      assert :ok = SyncSubscription.call(stripe_subscription)

      # The sub is created on the org's OWN customer and resolves to family-monthly.
      subscription =
        Subscriptions.get_subscription_by_provider_subscription_id(stripe_subscription_id)

      assert subscription
      assert subscription.billing_customer_id == customer.id
      assert subscription.plan_id == "family-monthly"
      assert subscription.status == "trialing"

      # Trialing on the org's own customer marks the trial used per-customer
      # (independent of the owner's personal customer).
      assert Customers.trial_used?(Customers.get_customer_by_source(:org, org.id))

      # Org now reads as active (trialing counts).
      assert Orgs.org_active?(Orgs.get_org_by_id(org.id))
    end

    test "returns {:error, :customer_not_found} when no local customer exists (#348)" do
      # Models the orphaned-webhook case: the local billing customer was removed
      # (e.g. org reclaimed mid-checkout) before the subscription webhook lands.
      # SyncSubscription must NOT raise so the worker can snooze/cancel cleanly.
      now = System.system_time(:second)

      stripe_subscription = %Stripe.Subscription{
        id: "sub_#{System.unique_integer([:positive])}",
        customer: "cus_missing_#{System.unique_integer([:positive])}",
        status: "trialing",
        cancel_at_period_end: false,
        cancel_at: nil,
        trial_end: now + 14 * 86_400,
        start_date: now,
        items: %{data: []}
      }

      assert {:error, :customer_not_found} = SyncSubscription.call(stripe_subscription)
    end
  end
end
