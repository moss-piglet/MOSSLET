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
      <div class="min-h-screen">
        <div class="relative overflow-hidden">
          <div class="absolute inset-0 pointer-events-none">
            <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
            </div>
            <div
              class="absolute top-1/2 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
              style="animation-delay: -2s;"
            >
            </div>
          </div>

          <div class="relative z-10 px-4 py-12 sm:px-6 lg:px-8 sm:py-16 lg:py-20">
            <div class="mx-auto max-w-3xl text-center mb-12 sm:mb-16">
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/30 dark:to-teal-900/30 border border-emerald-200/50 dark:border-emerald-700/30 mb-6">
                <.phx_icon
                  name="hero-sparkles"
                  class="w-4 h-4 text-emerald-600 dark:text-emerald-400"
                />
                <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                  {gettext("No subscriptions, ever")}
                </span>
              </div>

              <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight">
                <span class="bg-gradient-to-r from-slate-800 to-slate-700 dark:from-slate-100 dark:to-slate-200 bg-clip-text text-transparent">
                  {gettext("Pay once,")}
                </span>
                <br />
                <span class="bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 bg-clip-text text-transparent">
                  {gettext("own forever")}
                </span>
              </h1>

              <p class="mt-6 text-lg sm:text-xl text-slate-600 dark:text-slate-400 max-w-2xl mx-auto leading-relaxed">
                {gettext(
                  "Say goodbye to never-ending subscription fees. One simple payment gives you lifetime access—no hidden costs, no surprises."
                )}
              </p>
            </div>

            <div class="mx-auto max-w-lg">
              <%= for product <- @products do %>
                <.liquid_card padding="lg" class="overflow-hidden">
                  <div class="flex items-center justify-between gap-4 mb-6">
                    <div>
                      <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                        {product.name}
                      </h2>
                      <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        {gettext("Lifetime access")}
                      </p>
                    </div>
                    <div
                      id="app-beta-badge"
                      phx-hook="TippyHook"
                      data-tippy-content={gettext("Special launch pricing")}
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gradient-to-r from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30 border border-amber-200/50 dark:border-amber-700/30"
                    >
                      <.phx_icon name="hero-fire" class="w-4 h-4 text-amber-600 dark:text-amber-400" />
                      <span class="text-sm font-semibold text-amber-700 dark:text-amber-300">
                        {gettext("Save 40%")}
                      </span>
                    </div>
                  </div>

                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-8">
                    {product.description}
                  </p>

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

                  <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
                    <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-4 flex items-center gap-2">
                      <.phx_icon name="hero-check-badge" class="w-4 h-4 text-emerald-500" />
                      {gettext("Everything included")}
                    </h3>
                    <ul class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <%= for feature <- product.features do %>
                        <li class="flex items-start gap-2">
                          <.phx_icon
                            name="hero-check"
                            class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                          />
                          <span class="text-sm text-slate-600 dark:text-slate-400">
                            {feature}
                          </span>
                        </li>
                      <% end %>
                    </ul>
                  </div>

                  <div class="mt-6 p-4 rounded-xl bg-gradient-to-r from-blue-50/50 to-cyan-50/50 dark:from-blue-900/10 dark:to-cyan-900/10 border border-blue-200/30 dark:border-blue-700/20">
                    <div class="flex items-center gap-3">
                      <div class="flex items-center justify-center w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/40">
                        <.phx_icon
                          name="hero-credit-card"
                          class="w-5 h-5 text-blue-600 dark:text-blue-400"
                        />
                      </div>
                      <div
                        id="affirm-disclosure"
                        phx-hook="TippyHook"
                        data-tippy-content="Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders. CA residents: Loans by Affirm Loan Services, LLC are made or arranged pursuant to a California Finance Lenders Law license."
                        class="cursor-help flex-1"
                      >
                        <div class="text-sm font-medium text-blue-800 dark:text-blue-200">
                          {gettext("Flexible payments available")}
                        </div>
                        <div class="text-sm text-blue-700 dark:text-blue-300">
                          {gettext("Split into monthly payments with Affirm")}
                        </div>
                      </div>
                      <.phx_icon
                        name="hero-information-circle"
                        class="w-5 h-5 text-blue-400 dark:text-blue-500 flex-shrink-0"
                      />
                    </div>
                  </div>
                </.liquid_card>
              <% end %>
            </div>

            <div class="mt-12 text-center">
              <p class="text-sm text-slate-500 dark:text-slate-400 flex items-center justify-center gap-2">
                <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
                {gettext("Secure payment powered by Stripe")}
              </p>
            </div>
          </div>
        </div>
      </div>
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
