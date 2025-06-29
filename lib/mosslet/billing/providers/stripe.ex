defmodule Mosslet.Billing.Providers.Stripe do
  @moduledoc false
  require Logger

  use Mosslet.Billing.Providers.Behaviour

  alias Mosslet.Accounts.User
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.CreateCheckoutSession
  alias Mosslet.Billing.Providers.Stripe.Services.CreatePortalSession
  alias Mosslet.Billing.Providers.Stripe.Services.FindOrCreateCustomer
  alias Mosslet.Billing.Providers.Stripe.Services.SyncCustomer
  alias Mosslet.Billing.Subscriptions.Subscription

  def checkout(%User{} = user, plan, source, source_id, session_key) do
    with {:ok, customer} <- FindOrCreateCustomer.call(user, source, source_id, session_key),
         {:ok, session} <-
           CreateCheckoutSession.call(%CreateCheckoutSession{
             customer_id: customer.id,
             source: source,
             source_id: source_id,
             provider_customer_id:
               MossletWeb.Helpers.maybe_decrypt_user_data(
                 customer.provider_customer_id,
                 user,
                 session_key
               ),
             success_url: success_url(source, source_id, customer.id),
             cancel_url: cancel_url(source, source_id),
             allow_promotion_codes: plan.allow_promotion_codes,
             trial_period_days: Map.get(plan, :trial_days),
             line_items: update_plan_items_for_one_time_payment(plan)
           }) do
      {:ok, customer, session}
    else
      {:error, error} ->
        Logger.error("Failed to create Stripe Customer")
        Logger.debug("Failed to create Stripe Customer: #{inspect(error)}")
        raise "Failed to create Stripe Customer"
    end
  end

  defp update_plan_items_for_one_time_payment(plan) do
    plan = Map.drop(plan, [:id, :interval, :amount, :allow_promotion_codes])
    [plan]
  end

  def checkout_url(session), do: session.url

  def change_plan(%Customer{} = customer, %Subscription{} = subscription, plan) do
    CreatePortalSession.call(
      customer,
      subscription,
      Plans.plan_items(plan)
    )
  end

  def payment_intent_adapter do
    Mosslet.Billing.Providers.Stripe.Adapters.PaymentIntentAdapter
  end

  def subscription_adapter do
    Mosslet.Billing.Providers.Stripe.Adapters.SubscriptionAdapter
  end

  def sync_payment_intent(%Customer{} = customer, user, session_key) do
    SyncCustomer.call(customer, user, session_key)
  end

  def sync_subscription(%Customer{} = customer, user, session_key) do
    SyncCustomer.call(customer, user, session_key)
  end

  def get_subscription_product(stripe_subscription) do
    get_subscription_item(stripe_subscription).price.product
  end

  def get_subscription_price(stripe_subscription) do
    get_subscription_item(stripe_subscription).price.unit_amount
  end

  def get_subscription_cycle(stripe_subscription) do
    get_subscription_item(stripe_subscription).plan.interval
  end

  def get_subscription_next_charge(stripe_subscription) do
    Util.unix_to_naive_datetime(stripe_subscription.current_period_end)
  end

  def get_payment_intent_charge_price(payment_intent) do
    get_payment_intent_charge(payment_intent).amount
  end

  def get_payment_intent_charge_created(payment_intent) do
    get_payment_intent_charge(payment_intent).created
  end

  defp get_subscription_item(stripe_subscription) do
    List.first(stripe_subscription.items.data)
  end

  defp get_payment_intent_charge(payment_intent) do
    List.first(payment_intent.charges.data)
  end

  defdelegate retrieve_charge(id), to: Provider
  defdelegate retrieve_payment_intent(id), to: Provider
  defdelegate list_charges(id), to: Provider
  defdelegate retrieve_product(id), to: Provider
  defdelegate retrieve_subscription(id), to: Provider
  defdelegate cancel_subscription(id), to: Provider
end
