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

    case Customers.get_customer_by_source(:user, conn.assigns.current_user.id) do
      %Customer{} = customer ->
        check_customer_membership(conn, customer, user_subscribe_route)

      # check_customer_subscription(conn, customer, user_subscribe_route)

      _rest ->
        conn
        |> put_flash(:warning, gettext("You must have a paid account to access this page."))
        |> redirect(to: user_subscribe_route)
        |> halt()
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
        conn
        |> put_flash(:error, gettext("You must have a paid membership to access this page."))
        |> redirect(to: redirect_to)
        |> halt()
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
      |> assign_customer_subscription()

    {:cont, socket}
  end

  def on_mount(:subscribed_user, _params, _session, socket) do
    socket =
      socket
      |> assign_customer(:user)
      |> assign_customer_subscription()

    {:cont, socket}
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
end
