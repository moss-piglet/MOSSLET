defmodule MossletWeb.SubscribeSuccessLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Repo

  @impl true
  def mount(%{"customer_id" => customer_id}, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Payment Success"))
      |> assign(:payment_intent_status, :loading)
      |> assign(:payment_intent, nil)
      |> assign(:customer_id, customer_id)
      |> assign(:source, socket.assigns.live_action)
      |> assign(:pings, 0)
      |> assign_payment_intent()

    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user] |> Repo.preload(:customer)

    if user && user.customer do
      socket =
        socket
        |> assign(:page_title, gettext("Payment Success"))
        |> assign(:payment_intent_status, :loading)
        |> assign(:payment_intent, nil)
        |> assign(:customer_id, user.customer.id)
        |> assign(:source, socket.assigns.live_action)
        |> assign(:pings, 0)
        |> assign_payment_intent()

      {:ok, socket}
    else
      socket =
        socket
        |> put_flash(:warning, gettext("You must pay first before you can access this page."))

      {:ok, socket |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_info(:check_payment_intent, socket) do
    {:noreply, assign_payment_intent(socket)}
  end

  @impl true
  def handle_info(:redirect, socket) do
    {:noreply, push_navigate(socket, to: "/")}
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

  defp assign_payment_intent(%{assigns: %{pings: 10}} = socket) do
    assign(socket, :payment_intent_status, :failed)
  end

  defp assign_payment_intent(socket) do
    payment_intent =
      PaymentIntents.get_all_payment_intents_by(%{
        status: "succeeded",
        billing_customer_id: socket.assigns.customer_id
      })
      |> List.first()

    case payment_intent do
      nil ->
        schedule_membership_check()
        assign(socket, :pings, socket.assigns.pings + 1)

      payment_intent ->
        schedule_redirect()

        socket
        |> assign(:payment_intent, payment_intent)
        |> assign(:payment_intent_status, :success)
    end
  end

  defp schedule_membership_check do
    Process.send_after(self(), :check_payment_intent, 1500)
  end

  defp schedule_redirect do
    Process.send_after(self(), :redirect, 3000)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout current_page={:subscribe} current_user={@current_user} key={@key}>
          <.payment_intent_status
            payment_intent_status={@payment_intent_status}
            payment_intent={@payment_intent}
          />
        </.layout>
    <% end %>
    """
  end

  def payment_intent_status(assigns) do
    ~H"""
    <.container class="my-12" id="payment_intent-status">
      <.spinner show={@payment_intent_status == :loading} size="lg" />
      <.h2 :if={@payment_intent_status == :failed}>
        {gettext(
          "There was a failure to communicate with our payment provider (this could be an internet speed/connection issue). Please refresh your browser. If this error continues, then please contact support@mosslet.com."
        )}
      </.h2>
      <.h2 :if={@payment_intent} class="text-center">
        {gettext("Woohoo! Thank you for joining us, you will be redirected shortly.")}
      </.h2>
    </.container>
    """
  end
end
