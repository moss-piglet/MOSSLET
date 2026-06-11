defmodule MossletWeb.SubscribeController do
  use MossletWeb, :controller

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

    case get_subscription(:user, user.id) do
      nil ->
        handle_checkout(conn, plan, :user, user.id, seats)

      sub ->
        case Mosslet.Repo.delete(sub) do
          {:ok, _sub_deleted} ->
            handle_checkout(conn, plan, :user, user.id, seats)

          _error ->
            handle_subscription(conn, :user, user.id)
        end
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

      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Unable to start checkout. Please try again later."))
        |> redirect(to: ~p"/app/subscribe")
    end
  end

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
