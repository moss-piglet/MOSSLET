defmodule MossletWeb.SubscriptionPlugs do
  @moduledoc false
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext
  import Phoenix.Controller
  import Plug.Conn

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.PaymentIntents.PaymentIntent
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Subscriptions.Subscription
  alias Mosslet.Orgs

  def subscribed_entity_only(conn, opts) do
    case Customers.entity() do
      :org -> subscribed_org_only(conn, opts)
      :user -> subscribed_user_only(conn, opts)
    end
  end

  def subscribed_org_only(conn, _opts) do
    org_subscribe_route = ~p"/app/org/#{conn.assigns.current_org.slug}/subscribe"

    case Customers.get_customer_by_source(:org, conn.assigns.current_membership.org_id) do
      %Customer{} = customer ->
        check_customer_subscription(conn, customer, org_subscribe_route)

      _ ->
        conn
        |> put_flash(:error, gettext("You must have a subscription to access this page."))
        |> redirect(to: org_subscribe_route)
        |> halt()
    end
  end

  def subscribed_user_only(conn, _opts) do
    user_subscribe_route = ~p"/app/subscribe"

    cond do
      # Org-covered members (Family/Business) occupy a seat the ORG already pays
      # for — they must NOT be funneled to the personal paywall (Task #223). This
      # is server-authoritative: derived from confirmed membership rows + the
      # org's `:org`-source subscription status, never client-trusted. Covers
      # active/trialing orgs and the `past_due` grace window.
      Orgs.covered_by_org_seat?(conn.assigns.current_user) ->
        conn

      true ->
        case Customers.get_customer_by_source(:user, conn.assigns.current_user.id) do
          %Customer{} = customer ->
            check_customer_membership(conn, customer, user_subscribe_route)

          _rest ->
            {level, message} = coverage_paywall_flash(conn.assigns.current_user)

            conn
            |> put_flash(level, message)
            |> redirect(to: user_subscribe_route)
            |> halt()
        end
    end
  end

  # Tailors the loss-of-coverage message for a user who is NOT covered and has no
  # personal subscription (Task #223). Distinguishes a member whose org plan has
  # fully lapsed (state B — don't blame the member, point at their admin) from a
  # plain unsubscribed user / removed member (state A — offer next steps). We
  # never show a scary error; the copy is friendly and routes to /app/subscribe
  # where the user can start a Personal/Family plan.
  defp coverage_paywall_flash(user) do
    case Orgs.org_coverage_status(user) do
      {:lapsed, %{name: name}} when is_binary(name) and name != "" ->
        {:warning,
         gettext(
           "Your organization (%{name}) doesn't have an active plan right now, so this page is paused. Reach out to your organization's admin, or start your own plan below.",
           name: name
         )}

      {:lapsed, _org} ->
        {:warning,
         gettext(
           "Your organization doesn't have an active plan right now, so this page is paused. Reach out to your organization's admin, or start your own plan below."
         )}

      _ ->
        {:warning,
         gettext(
           "You need an active plan to access this page. Pick a plan below to get started, or join an organization."
         )}
    end
  end

  defp check_customer_membership(conn, customer, redirect_to) do
    case PaymentIntents.get_active_payment_intent_by_customer_id(customer.id) do
      %PaymentIntent{} = payment_intent ->
        assign(conn, :payment_intent, payment_intent)

      _rest ->
        # add this check of legacy subscription customers
        check_customer_subscription(conn, customer, redirect_to)
    end
  end

  defp check_customer_subscription(conn, customer, redirect_to) do
    case Subscriptions.get_active_subscription_by_customer_id(customer.id) do
      %Subscription{} = subscription ->
        assign(conn, :subscription, subscription)

      _ ->
        case Subscriptions.get_payment_required_subscription_by_customer_id(customer.id) do
          %Subscription{} ->
            conn
            |> redirect(to: ~p"/app/trial-expired")
            |> halt()

          _ ->
            conn
            |> put_flash(:error, gettext("You must have a paid membership to access this page."))
            |> redirect(to: redirect_to)
            |> halt()
        end
    end
  end

  def on_mount(:subscribed_entity, params, session, socket) do
    case Customers.entity() do
      :org -> on_mount(:subscribed_org, params, session, socket)
      :user -> on_mount(:subscribed_user, params, session, socket)
    end
  end

  def on_mount(:subscribed_org, _params, _session, socket) do
    socket =
      socket
      |> assign_customer(:org)
      |> assign_customer_payment_intent()
      |> assign_customer_subscription()

    {:cont, socket}
  end

  def on_mount(:subscribed_user, _params, _session, socket) do
    socket =
      socket
      |> assign_customer(:user)
      |> assign_customer_payment_intent()
      |> assign_customer_subscription()

    {:cont, socket}
  end

  # Halting variant: redirects to /app/subscribe unless the user has finalized
  # their own subscription signup (active/trialing subscription or active lifetime
  # payment intent). Used to gate org-creation surfaces on live navigation, where
  # the `subscribed_user_only` plug does not run (Task #215 follow-up).
  def on_mount(:require_subscribed_user, params, session, socket) do
    {:cont, socket} = on_mount(:subscribed_user, params, session, socket)

    cond do
      socket.assigns[:subscription] || socket.assigns[:payment_intent] ->
        {:cont, socket}

      # Org-covered members are exempt from the personal paywall (Task #223).
      # Server-authoritative; re-evaluated on every live mount so loss of
      # coverage (seat revoked → membership row deleted, or org sub lapses past
      # the `past_due` grace window) takes effect immediately on next navigation.
      Orgs.covered_by_org_seat?(socket.assigns.current_user) ->
        {:cont, socket}

      true ->
        {level, message} = coverage_paywall_flash(socket.assigns.current_user)

        socket =
          socket
          |> Phoenix.LiveView.put_flash(level, message)
          |> Phoenix.LiveView.redirect(to: ~p"/app/subscribe")

        {:halt, socket}
    end
  end

  defp assign_customer(socket, :org) do
    Phoenix.Component.assign_new(socket, :customer, fn ->
      current_org = socket.assigns.current_org

      if current_org do
        Customers.get_customer_by_source(:org, current_org.id)
      end
    end)
  end

  defp assign_customer(socket, :user) do
    Phoenix.Component.assign_new(socket, :customer, fn ->
      Customers.get_customer_by_source(:user, socket.assigns.current_user.id)
    end)
  end

  defp assign_customer_subscription(socket) do
    Phoenix.Component.assign_new(socket, :subscription, fn ->
      if socket.assigns.customer do
        Subscriptions.get_active_subscription_by_customer_id(socket.assigns.customer.id)
      end
    end)
  end

  defp assign_customer_payment_intent(socket) do
    Phoenix.Component.assign_new(socket, :payment_intent, fn ->
      if socket.assigns.customer do
        PaymentIntents.get_active_payment_intent_by_customer_id(socket.assigns.customer.id)
      end
    end)
  end
end
