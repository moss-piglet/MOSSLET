defmodule MossletWeb.SubscribeSuccessLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Repo

  @impl true
  def mount(%{"customer_id" => customer_id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Payment Success"))
      |> assign(:billing_status, :loading)
      |> assign(:payment_intent, nil)
      |> assign(:subscription, nil)
      |> assign(:customer_id, customer_id)
      |> assign(:source, socket.assigns.live_action)
      |> assign(:pings, 0)
      |> assign_billing_status()

    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] |> Repo.preload(:customer)

    if user && user.customer do
      socket =
        socket
        |> assign(:page_title, gettext("Payment Success"))
        |> assign(:billing_status, :loading)
        |> assign(:payment_intent, nil)
        |> assign(:subscription, nil)
        |> assign(:customer_id, user.customer.id)
        |> assign(:source, socket.assigns.live_action)
        |> assign(:pings, 0)
        |> assign_billing_status()

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:warning, gettext("You must pay first before you can access this page."))

      {:ok, socket |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info(:check_billing_status, socket) do
    {:noreply, assign_billing_status(socket)}
  end

  @impl true
  def handle_info(:redirect, socket) do
    {:noreply, push_navigate(socket, to: "/app")}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp assign_billing_status(%{assigns: %{pings: 10}} = socket) do
    assign(socket, :billing_status, :failed)
  end

  defp assign_billing_status(socket) do
    customer_id = socket.assigns.customer_id

    payment_intent =
      PaymentIntents.get_all_payment_intents_by(%{
        status: "succeeded",
        billing_customer_id: customer_id
      })
      |> List.first()

    subscription = Subscriptions.get_active_subscription_by_customer_id(customer_id)

    cond do
      payment_intent != nil ->
        schedule_redirect()
        maybe_broadcast_referral_update(socket.assigns[:current_user])

        socket
        |> assign(:payment_intent, payment_intent)
        |> assign(:billing_status, :success)

      subscription != nil ->
        schedule_redirect()
        maybe_broadcast_referral_update(socket.assigns[:current_user])

        socket
        |> assign(:subscription, subscription)
        |> assign(:billing_status, :success)

      true ->
        schedule_billing_check()
        assign(socket, :pings, socket.assigns.pings + 1)
    end
  end

  defp maybe_broadcast_referral_update(%{id: user_id}) when is_binary(user_id) do
    case Referrals.get_referral_by_user(user_id) do
      nil ->
        :ok

      referral ->
        referral = Repo.preload(referral, :referral_code)

        if referral.referral_code do
          Referrals.broadcast_referral_update(
            referral.referral_code.user_id,
            :referral_updated
          )
        end
    end
  end

  defp maybe_broadcast_referral_update(_), do: :ok

  defp schedule_billing_check do
    Process.send_after(self(), :check_billing_status, 1500)
  end

  defp schedule_redirect do
    Process.send_after(self(), :redirect, 3000)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout current_page={:subscribe} current_scope={@current_scope}>
          <.billing_status
            billing_status={@billing_status}
            payment_intent={@payment_intent}
            subscription={@subscription}
          />
        </.layout>
    <% end %>
    """
  end

  attr :billing_status, :atom, required: true
  attr :payment_intent, :any, default: nil
  attr :subscription, :any, default: nil

  def billing_status(assigns) do
    ~H"""
    <.container class="my-12" id="billing-status">
      <.spinner show={@billing_status == :loading} size="lg" />
      <.h2 :if={@billing_status == :failed}>
        {gettext(
          "There was a failure to communicate with our payment provider (this could be an internet speed/connection issue). Please refresh your browser. If this error continues, then please contact support@mosslet.com."
        )}
      </.h2>
      <.h2 :if={@billing_status == :success} class="text-center">
        {gettext("Success! You will be redirected shortly.")}
      </.h2>
    </.container>
    """
  end
end
