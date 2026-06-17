defmodule Mosslet.Billing.Providers.Stripe do
  @moduledoc false
  require Logger

  use Mosslet.Billing.Providers.Behaviour

  alias Mosslet.Accounts.User
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Providers.Stripe.Services.AddSubscriptionItem
  alias Mosslet.Billing.Providers.Stripe.Services.CreateCheckoutSession
  alias Mosslet.Billing.Providers.Stripe.Services.CreatePortalSession
  alias Mosslet.Billing.Providers.Stripe.Services.FindOrCreateCustomer
  alias Mosslet.Billing.Providers.Stripe.Services.SyncCustomer
  alias Mosslet.Billing.Subscriptions.Subscription

  def checkout(
        %User{} = user,
        plan,
        source,
        source_id,
        session_key,
        referral \\ nil,
        seats \\ 1,
        addons \\ []
      ) do
    mode = determine_checkout_mode(plan)
    line_items = build_line_items(plan, seats, addons)

    case validate_line_item_prices(line_items) do
      :ok ->
        do_checkout(user, plan, source, source_id, session_key, referral, mode, line_items)

      {:error, bad_price} ->
        Logger.error(
          "Refusing checkout for plan #{inspect(plan.id)}: price #{inspect(bad_price)} " <>
            "is not a configured Stripe price (set the STRIPE_PRICE_* env var)."
        )

        {:error, {:stripe_price_misconfigured, bad_price}}
    end
  end

  defp do_checkout(user, plan, source, source_id, session_key, referral, mode, line_items) do
    with {:ok, customer} <- FindOrCreateCustomer.call(user, source, source_id, session_key) do
      trial_days = determine_trial_days(plan, customer)

      # provider_customer_id is now Cloak-only — read directly
      case CreateCheckoutSession.call(%CreateCheckoutSession{
             customer_id: customer.id,
             source: source,
             source_id: source_id,
             provider_customer_id: customer.provider_customer_id,
             success_url: success_url(source, source_id, customer.id),
             cancel_url: cancel_url(source, source_id),
             allow_promotion_codes: Map.get(plan, :allow_promotion_codes, false),
             trial_period_days: trial_days,
             line_items: line_items,
             mode: mode,
             referral: referral
           }) do
        {:ok, session} -> {:ok, customer, session}
        {:error, error} -> {:error, error}
      end
    else
      {:error, error} ->
        Logger.error("Failed to create Stripe Customer")
        Logger.debug("Failed to create Stripe Customer: #{inspect(error)}")
        {:error, :stripe_customer_creation_failed}
    end
  end

  # Guards against the dev/test fallback price IDs (e.g. "price_*_test") that
  # are used when the real STRIPE_PRICE_* env vars are unset. Hitting Stripe with
  # one of these yields a confusing generic failure; instead we fail fast with a
  # tagged, actionable error (Task #215).
  defp validate_line_item_prices(line_items) do
    Enum.reduce_while(line_items, :ok, fn item, _acc ->
      price = Map.get(item, :price)

      if is_binary(price) and configured_stripe_price?(price) do
        {:cont, :ok}
      else
        {:halt, {:error, price}}
      end
    end)
  end

  defp configured_stripe_price?(price) do
    String.starts_with?(price, "price_") and not String.ends_with?(price, "_test") and
      price not in [
        "price_family_monthly_test",
        "price_family_yearly_test",
        "price_business_monthly_test",
        "price_business_yearly_test",
        "price_family_seat_monthly_test",
        "price_family_seat_yearly_test",
        "price_business_seat_monthly_test",
        "price_business_seat_yearly_test"
      ]
  end

  defp determine_trial_days(plan, customer) do
    plan_trial_days = Map.get(plan, :trial_days)

    if plan_trial_days && Customers.trial_used?(customer) do
      nil
    else
      plan_trial_days
    end
  end

  defp determine_checkout_mode(plan) do
    case plan.interval do
      :one_time -> "payment"
      :month -> "subscription"
      :year -> "subscription"
      _ -> "payment"
    end
  end

  # Builds the Stripe `line_items` list for a checkout session.
  #
  # Single-seat plans (e.g. Personal) emit a single base line item — unchanged
  # behaviour. Per-seat plans (Family/Business, declared via `:seat_addon_price`
  # in config) emit the base plan line item plus an add-on seat line item for any
  # seats requested beyond the plan's included allotment. Optional `addons`
  # (e.g. `[:subdomain]`) append further add-on line items, each interval-matched
  # to the base plan via its own configured price ID (Task #240, Phase B).
  #
  # Pure (no Stripe call) so it can be unit-tested directly.
  @doc false
  def build_line_items(plan, seats, addons) do
    base_item =
      Map.drop(plan, [
        :id,
        :interval,
        :amount,
        :allow_promotion_codes,
        :trial_days,
        :save_percent,
        :included_seats,
        :seat_addon_price,
        :subdomain_addon_price,
        :max_seats,
        :monthly_equivalent
      ])

    [base_item] ++ seat_line_items(plan, seats) ++ subdomain_line_items(plan, addons)
  end

  defp seat_line_items(plan, seats) do
    if Plans.seat_based_plan?(plan) do
      seats = Plans.clamp_seats(plan, seats)
      extra_seats = seats - Plans.included_seats(plan)

      if extra_seats > 0 do
        [%{price: plan.seat_addon_price, quantity: extra_seats}]
      else
        []
      end
    else
      []
    end
  end

  # The paid custom-subdomain branding add-on (Task #240, Phase B). Emitted only
  # when explicitly requested AND the plan offers it (Business). Quantity 1 — a
  # single subdomain per org. The price is interval-matched (monthly/yearly) by
  # config, so it always rides the base plan's billing cycle. The brand LOGO is
  # never gated this way; it stays free for all Business orgs.
  defp subdomain_line_items(plan, addons) do
    if :subdomain in addons and Plans.subdomain_addon_plan?(plan) do
      [%{price: Plans.subdomain_addon_price(plan), quantity: 1}]
    else
      []
    end
  end

  def checkout_url(session), do: session.url

  def change_plan(%Customer{} = customer, %Subscription{} = subscription, plan) do
    CreatePortalSession.call(
      customer,
      subscription,
      Plans.plan_items(plan)
    )
  end

  # Appends a new add-on line item to an active subscription WITHOUT swapping the
  # existing items (Task #240, Phase B one-click subdomain add-on). Distinct from
  # `change_plan/3`, which routes a plan SWITCH through the Billing Portal.
  def add_subscription_item(%Subscription{} = subscription, price_id) do
    AddSubscriptionItem.call(subscription, price_id)
  end

  def payment_intent_adapter do
    Mosslet.Billing.Providers.Stripe.Adapters.PaymentIntentAdapter
  end

  def subscription_adapter do
    Mosslet.Billing.Providers.Stripe.Adapters.SubscriptionAdapter
  end

  def sync_payment_intent(%Customer{} = customer) do
    SyncCustomer.call(customer)
  end

  def sync_subscription(%Customer{} = customer) do
    SyncCustomer.call(customer)
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
    # In stripity_stripe 3.3.1, current_period_end moved to subscription items
    period_end =
      case stripe_subscription.items.data do
        [item | _] -> item.current_period_end
        _ -> stripe_subscription.trial_end
      end

    Util.unix_to_naive_datetime(period_end)
  end

  # In stripity_stripe 3.3.1, `charges` was removed from PaymentIntent.
  # `latest_charge` is now a charge ID string — retrieve the full Charge.
  def get_payment_intent_charge_price(payment_intent) do
    case get_payment_intent_charge(payment_intent) do
      {:ok, charge} -> charge.amount
      _ -> nil
    end
  end

  def get_payment_intent_charge_created(payment_intent) do
    case get_payment_intent_charge(payment_intent) do
      {:ok, charge} -> charge.created
      _ -> nil
    end
  end

  defp get_subscription_item(stripe_subscription) do
    List.first(stripe_subscription.items.data)
  end

  defp get_payment_intent_charge(payment_intent) do
    Provider.retrieve_charge(payment_intent.latest_charge)
  end

  defdelegate retrieve_charge(id), to: Provider
  defdelegate retrieve_payment_intent(id), to: Provider
  defdelegate list_charges(id), to: Provider
  defdelegate retrieve_product(id), to: Provider
  defdelegate retrieve_subscription(id), to: Provider
  defdelegate cancel_subscription(id), to: Provider
  defdelegate cancel_subscription_immediately(id), to: Provider
  defdelegate resume_subscription(id), to: Provider
  defdelegate upcoming_invoice(params), to: Provider
  defdelegate list_invoices(params), to: Provider
  defdelegate create_portal_session(params), to: Provider
end
