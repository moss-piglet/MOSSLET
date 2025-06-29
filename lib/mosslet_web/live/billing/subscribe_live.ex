defmodule MossletWeb.SubscribeLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.PaymentIntents.PaymentIntent
  alias Mosslet.Logs
  alias MossletWeb.BillingComponents
  alias MossletWeb.BillingLive

  @billing_provider Application.compile_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Pay Once"))
      |> assign(:source, socket.assigns.live_action)
      |> assign(:current_membership, socket.assigns[:current_membership])
      |> assign(:products, Plans.products())

    socket =
      with %Customer{id: customer_id} = customer <- get_customer(socket.assigns.source, socket),
           %PaymentIntent{} = payment_intent <-
             PaymentIntents.get_active_payment_intent_by_customer_id(customer_id) do
        socket
        |> assign(:current_customer, customer)
        |> assign(:current_payment_intent, payment_intent)
      else
        nil -> assign(socket, :current_payment_intent, nil)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.source_layout
      source={@source}
      current_user={@current_user}
      current_membership={@current_membership}
      socket={@socket}
      key={@key}
    >
      <.container class="my-12">
        <div class="mx-auto max-w-4xl sm:text-center pb-4">
          <div class="mx-auto max-w-2xl text-center lg:max-w-4xl">
            <h1 class="mt-2 text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Simple,
              <span class="italic underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                pay once
              </span>
              pricing
            </h1>
          </div>
          <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
            Say goodbye to never-ending subscription fees.
          </h2>
          <p class="mx-auto mt-6 max-w-2xl text-center text-lg leading-8 text-gray-600 dark:text-gray-400">
            Pay once and forget about it. With one, simple payment you get access to our service forever. No hidden fees, no subscriptions, no surprises. We also support lowering your upfront payment with Affirm.
          </p>
        </div>

        <BillingComponents.pricing_panels_container panels={length(@products)} interval_selector>
          <%= for product <- @products do %>
            <BillingComponents.pricing_panel
              id={"pricing-product-#{product.id}"}
              label={product.name}
              description={product.description}
              features={product.features}
              most_popular={Map.get(product, :most_popular)}
              disabled={product.id == "business"}
            >
              <%= for item <- product.line_items do %>
                <BillingComponents.item_price
                  id={"pricing-plan-#{item.id}"}
                  interval={item.interval}
                  amount={item.amount}
                  button_props={button_props(item, @current_payment_intent, @key)}
                  button_label={subscribe_text(item, @current_payment_intent)}
                  is_already_paid={already_paid?(@current_payment_intent)}
                  most_popular={Map.get(product, :most_popular)}
                  disabled={already_paid?(@current_payment_intent)}
                  billing_path={BillingLive.billing_path(@source, assigns)}
                />
              <% end %>
            </BillingComponents.pricing_panel>
          <% end %>
        </BillingComponents.pricing_panels_container>
      </.container>
    </.source_layout>
    """
  end

  defp already_paid?(%PaymentIntent{} = payment_intent) do
    payment_intent.provider_created_at && payment_intent.amount_received &&
      payment_intent.status == "succeeded"
  end

  defp already_paid?(_payment_intent), do: false

  defp subscribe_text(plan, payment_intent)
  defp subscribe_text(_plan, nil), do: gettext("Pay Once")

  defp subscribe_text(plan, payment_intent) when plan.id == payment_intent.plan_id,
    do: gettext("Current")

  defp subscribe_text(_plan, _payment_intent), do: gettext("Current member")

  defp button_props(plan, payment_intent, key)

  defp button_props(plan, nil, key) do
    %{"phx-click" => "checkout", "phx-value-plan" => plan.id, "phx-value-key" => key}
  end

  defp button_props(plan, payment_intent, _key) when plan.id == payment_intent.plan_id do
    %{"disabled" => true}
  end

  defp button_props(plan, _payment_intent, key) do
    %{"phx-click" => "switch_plan", "phx-value-plan" => plan.id, "phx-value-key" => key}
  end

  attr :source, :atom, default: :user
  attr :current_user, :map, default: nil
  attr :current_membership, :map, default: nil
  attr :socket, :map, default: nil
  attr :key, :string, default: nil, doc: "the user session key"
  slot :inner_block

  defp source_layout(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout current_page={:subscribe} current_user={@current_user} key={@key}>
          {render_slot(@inner_block)}
        </.layout>
    <% end %>
    """
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

  @impl true
  def handle_event("checkout", %{"plan" => plan_id, "key" => _key}, socket) do
    source = socket.assigns.source
    checkout_url = checkout_url(socket, source, plan_id)

    Logs.log("billing.click_subscribe_button", %{
      user: socket.assigns.current_user,
      metadata: %{
        plan_id: plan_id,
        org_id: current_org_id(socket)
      }
    })

    {:noreply, redirect(socket, to: checkout_url)}
  end

  def handle_event(
        "switch_plan",
        %{"plan" => plan_id, "key" => key},
        %{
          assigns: %{current_customer: customer, current_payment_intent: payment_intent, key: key}
        } =
          socket
      ) do
    plan = Plans.get_plan_by_id!(plan_id)

    case @billing_provider.change_plan(customer, payment_intent, plan) do
      {:ok, session} ->
        url = @billing_provider.checkout_url(session)
        {:noreply, redirect(socket, external: url)}

      {:error, reason} ->
        {
          :noreply,
          put_flash(
            socket,
            :error,
            gettext("Something went wrong with our payment portal. ") <> inspect(reason)
          )
        }
    end
  end

  defp checkout_url(_socket, :user, plan_id), do: ~p"/app/checkout/#{plan_id}"

  defp checkout_url(socket, :org, plan_id) do
    org_slug = current_org_slug(socket)

    ~p"/app/org/#{org_slug}/checkout/#{plan_id}"
  end

  defp current_org_id(socket) do
    case socket.assigns[:current_org] do
      nil -> nil
      org -> org.id
    end
  end

  defp current_org_slug(socket) do
    case socket.assigns[:current_org] do
      nil -> nil
      org -> org.slug
    end
  end

  defp get_customer(:org, socket) do
    Customers.get_customer_by_source(:org, socket.assigns[:current_org].id)
  end

  defp get_customer(:user, socket) do
    Customers.get_customer_by_source(:user, socket.assigns[:current_user].id)
  end
end
