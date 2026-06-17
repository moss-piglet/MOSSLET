defmodule MossletWeb.SubscribeController do
  use MossletWeb, :controller
  require Logger

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Orgs

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @doc """
  Redirect here when someone wants to purchase a subscription.
  If the purchaser is an org, include "org_slug" in the params.
  """
  def checkout(conn, %{"org_slug" => org_slug, "plan_id" => plan_id} = params) do
    plan = Plans.get_plan_by_id!(plan_id)
    org = Orgs.get_org!(org_slug)
    seats = parse_seats(plan, params)

    case get_subscription(:org, org.id) do
      nil -> handle_checkout(conn, plan, :org, org.id, seats)
      _sub -> handle_subscription(conn, :org, org.id)
    end
  end

  def checkout(conn, %{"plan_id" => plan_id} = params) do
    plan = Plans.get_plan_by_id!(plan_id)
    user = conn.assigns.current_user
    seats = parse_seats(plan, params)

    # Mirror the :org clause: never start a NEW Checkout Session when an
    # active/trialing :user subscription already exists. Doing so would create a
    # SECOND live Stripe subscription (the old code deleted only the LOCAL
    # Subscription row, leaving the Stripe sub live -> duplicate charge risk).
    # Interval/plan changes are routed in-place through SubscribeLive's
    # "switch_subscription" -> change_plan (Stripe Billing Portal update); the
    # subscribe UI only renders the "checkout" button when there is no active
    # billing, so reaching here with an active sub means a stale URL or a
    # double-submit — we refuse and send the user to billing (Task #239).
    case get_subscription(:user, user.id) do
      nil -> handle_checkout(conn, plan, :user, user.id, seats)
      _sub -> handle_subscription(conn, :user, user.id)
    end
  end

  # Seat count is only honored for per-seat plans (Family/Business); single-seat
  # plans always resolve to 1. Clamping guards against tampered query params.
  defp parse_seats(plan, params) do
    Plans.clamp_seats(plan, Map.get(params, "seats", Plans.included_seats(plan)))
  end

  defp handle_subscription(conn, source, source_id) do
    billing_url = billing_url(source, source_id)

    conn
    |> put_flash(:error, gettext("There is an existing active subscription."))
    |> redirect(to: billing_url)
  end

  defp handle_checkout(conn, plan, source, source_id, seats) do
    user = conn.assigns.current_user
    referral = Referrals.get_pending_referral_for_user(user.id)
    session_key = conn.private.plug_session["key"]

    case billing_provider().checkout(
           user,
           plan,
           source,
           source_id,
           session_key,
           referral,
           seats
         ) do
      {:ok, _customer, session} ->
        redirect(conn, external: billing_provider().checkout_url(session))

      {:error, reason} ->
        Logger.error(
          "Checkout failed for plan #{inspect(plan.id)} (#{source}): #{inspect(reason)}"
        )

        conn
        |> put_flash(:error, checkout_error_message(reason))
        |> redirect(to: checkout_failure_path(source, source_id))
    end
  end

  # Surface an honest, actionable message. A misconfigured Stripe price (common
  # in dev/test when STRIPE_PRICE_* env vars are unset) is distinct from a
  # transient failure (Task #215).
  defp checkout_error_message({:stripe_price_misconfigured, _}),
    do:
      gettext(
        "This plan isn't available for checkout yet. Please contact support or try a different plan."
      )

  defp checkout_error_message(:stripe_customer_creation_failed),
    do: gettext("We couldn't set up your billing account. Please try again in a moment.")

  defp checkout_error_message(_reason),
    do: gettext("Unable to start checkout. Please try again later.")

  defp checkout_failure_path(:org, source_id) do
    case Mosslet.Orgs.get_org_by_id(source_id) do
      %{slug: slug} -> ~p"/app/org/#{slug}/subscribe"
      _ -> ~p"/app/subscribe"
    end
  end

  defp checkout_failure_path(_source, _source_id), do: ~p"/app/subscribe"

  defp get_subscription(source, source_id) do
    source
    |> Customers.get_customer_by_source(source_id)
    |> get_subscription()
  end

  defp get_subscription(nil), do: nil

  defp get_subscription(customer) do
    Subscriptions.get_active_subscription_by_customer_id(customer.id)
  end

  defp billing_url(:user, _user_id), do: ~p"/app/billing"

  defp billing_url(:org, org_id) do
    org = Mosslet.Orgs.get_org_by_id(org_id)

    ~p"/app/org/#{org.slug}/billing"
  end
end
