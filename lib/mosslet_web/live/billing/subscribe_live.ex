defmodule MossletWeb.SubscribeLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.PaymentIntents.PaymentIntent
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Subscriptions.Subscription
  alias Mosslet.Logs
  alias MossletWeb.BillingLive
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    products = Plans.products()

    one_time_products =
      Enum.filter(products, fn product ->
        item = List.first(product.line_items)
        item && item.interval == :one_time
      end)

    subscription_products =
      Enum.filter(products, fn product ->
        item = List.first(product.line_items)
        item && item.interval in [:month, :year]
      end)

    socket =
      socket
      |> assign(:page_title, gettext("Pricing"))
      |> assign(:source, socket.assigns.live_action)
      |> assign(:current_membership, socket.assigns[:current_membership])
      |> assign(:products, products)
      |> assign(:one_time_products, one_time_products)
      |> assign(:subscription_products, subscription_products)

    socket = assign_billing_status(socket)

    {:ok, socket}
  end

  defp assign_billing_status(socket) do
    source = socket.assigns.source

    case get_customer(source, socket) do
      %Customer{id: customer_id} = customer ->
        payment_intent = PaymentIntents.get_active_payment_intent_by_customer_id(customer_id)
        subscription = Subscriptions.get_active_subscription_by_customer_id(customer_id)

        socket
        |> assign(:current_customer, customer)
        |> assign(:current_payment_intent, payment_intent)
        |> assign(:current_subscription, subscription)
        |> assign(:has_active_billing, payment_intent != nil || subscription != nil)

      _ ->
        socket
        |> assign(:current_customer, nil)
        |> assign(:current_payment_intent, nil)
        |> assign(:current_subscription, nil)
        |> assign(:has_active_billing, false)
    end
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
              class="absolute top-1/3 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
              style="animation-delay: -2s;"
            >
            </div>
            <div
              class="absolute bottom-0 right-1/4 h-64 w-64 rounded-full bg-gradient-to-tl from-cyan-400/10 via-teal-500/10 to-emerald-400/15 blur-3xl animate-pulse"
              style="animation-delay: -4s;"
            >
            </div>
          </div>

          <div class="relative z-10 px-4 py-12 sm:px-6 lg:px-8 sm:py-16 lg:py-20">
            <.pricing_header has_active_billing={@has_active_billing} />

            <div class="mx-auto max-w-6xl">
              <.active_billing_notice
                :if={@has_active_billing}
                current_payment_intent={@current_payment_intent}
                current_subscription={@current_subscription}
                source={@source}
              />

              <.pricing_cards
                one_time_products={@one_time_products}
                subscription_products={@subscription_products}
                current_payment_intent={@current_payment_intent}
                current_subscription={@current_subscription}
                has_active_billing={@has_active_billing}
                source={@source}
                key={@key}
              />
            </div>

            <.pricing_footer />
          </div>
        </div>
      </div>
    </.source_layout>
    """
  end

  attr :has_active_billing, :boolean, default: false

  defp pricing_header(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl text-center mb-12 sm:mb-16">
      <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/30 dark:to-teal-900/30 border border-emerald-200/50 dark:border-emerald-700/30 mb-6">
        <.phx_icon name="hero-sparkles" class="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
        <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
          {gettext("Privacy-first social")}
        </span>
      </div>

      <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight">
        <span class="bg-gradient-to-r from-slate-800 to-slate-700 dark:from-slate-100 dark:to-slate-200 bg-clip-text text-transparent">
          {gettext("Simple,")}
        </span>
        <br class="sm:hidden" />
        <span class="bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 bg-clip-text text-transparent">
          {gettext("transparent pricing")}
        </span>
      </h1>

      <p class="mt-6 text-lg sm:text-xl text-slate-600 dark:text-slate-400 max-w-2xl mx-auto leading-relaxed">
        <%= if @has_active_billing do %>
          {gettext("You're already a member! Here's an overview of our plans.")}
        <% else %>
          {gettext(
            "Choose the plan that works best for you. Start with a free trial or pay once for lifetime access."
          )}
        <% end %>
      </p>
    </div>
    """
  end

  attr :current_payment_intent, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :source, :atom, required: true

  defp active_billing_notice(assigns) do
    ~H"""
    <div class="mb-10 max-w-2xl mx-auto">
      <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/80 to-teal-50/60 dark:from-emerald-900/30 dark:to-teal-900/20 border-emerald-200/60 dark:border-emerald-700/40">
        <div class="flex items-start gap-4">
          <div class="flex-shrink-0">
            <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-500 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-check-badge" class="h-5 w-5 text-white" />
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <h3 class="text-lg font-semibold text-emerald-800 dark:text-emerald-200">
              <%= cond do %>
                <% @current_payment_intent -> %>
                  {gettext("Lifetime Member")}
                <% @current_subscription && @current_subscription.status == "trialing" -> %>
                  {gettext("Free Trial Active")}
                <% @current_subscription -> %>
                  {gettext("Active Subscription")}
                <% true -> %>
                  {gettext("Active Member")}
              <% end %>
            </h3>
            <p class="mt-1 text-sm text-emerald-700 dark:text-emerald-300">
              <%= cond do %>
                <% @current_payment_intent -> %>
                  {gettext("You have lifetime access to MOSSLET. No recurring charges.")}
                <% @current_subscription && @current_subscription.status == "trialing" -> %>
                  {gettext("Your free trial is active. Enjoy exploring MOSSLET!")}
                <% @current_subscription -> %>
                  {gettext("Your subscription is active. Thank you for being a member!")}
                <% true -> %>
                  {gettext("You have access to all MOSSLET features.")}
              <% end %>
            </p>
            <div class="mt-4">
              <DesignSystem.liquid_button
                href={BillingLive.billing_path(@source, %{})}
                size="sm"
                variant="secondary"
                color="emerald"
                icon="hero-cog-6-tooth"
              >
                {gettext("Manage Billing")}
              </DesignSystem.liquid_button>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  attr :one_time_products, :list, required: true
  attr :subscription_products, :list, required: true
  attr :current_payment_intent, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :has_active_billing, :boolean, default: false
  attr :source, :atom, required: true
  attr :key, :string, required: true

  defp pricing_cards(assigns) do
    ~H"""
    <div :if={@subscription_products != []} class="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
      <%= for product <- @subscription_products do %>
        <.pricing_card
          product={product}
          current_payment_intent={@current_payment_intent}
          current_subscription={@current_subscription}
          has_active_billing={@has_active_billing}
          source={@source}
          key={@key}
        />
      <% end %>
    </div>

    <div :if={@one_time_products != []} class="mt-16 lg:mt-20">
      <div class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-slate-200 dark:border-slate-700/50"></div>
        </div>
        <div class="relative flex justify-center">
          <div class="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-gradient-to-r from-amber-100 via-orange-100 to-amber-100 dark:from-amber-900/40 dark:via-orange-900/30 dark:to-amber-900/40 border border-amber-300/60 dark:border-amber-600/40 shadow-sm">
            <.phx_icon name="hero-fire" class="w-5 h-5 text-amber-600 dark:text-amber-400" />
            <span class="text-sm font-semibold text-amber-800 dark:text-amber-200">
              {gettext("Or pay once, own forever")}
            </span>
          </div>
        </div>
      </div>

      <div class="mt-10 mx-auto max-w-4xl">
        <%= for product <- @one_time_products do %>
          <.one_time_card
            product={product}
            current_payment_intent={@current_payment_intent}
            has_active_billing={@has_active_billing}
            key={@key}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :product, :map, required: true
  attr :current_payment_intent, :any, default: nil
  attr :has_active_billing, :boolean, default: false
  attr :key, :string, required: true

  defp one_time_card(assigns) do
    item = List.first(assigns.product.line_items)
    is_current = assigns.current_payment_intent != nil

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:is_current, is_current)

    ~H"""
    <div class="relative group">
      <div class="absolute -inset-1 bg-gradient-to-r from-amber-400/20 via-orange-400/20 to-yellow-400/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
      </div>

      <DesignSystem.liquid_card
        padding="lg"
        class="relative overflow-hidden bg-gradient-to-br from-white via-amber-50/30 to-orange-50/40 dark:from-slate-800/90 dark:via-amber-900/10 dark:to-orange-900/10 border-amber-200/70 dark:border-amber-700/40 shadow-xl shadow-amber-500/5"
      >
        <div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-amber-200/30 via-orange-200/20 to-transparent dark:from-amber-500/10 dark:via-orange-500/5 rounded-bl-full pointer-events-none">
        </div>

        <div class="relative">
          <div class="flex flex-col lg:flex-row lg:items-start gap-8 lg:gap-12">
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-3 mb-4">
                <div class="flex items-center justify-center w-12 h-12 rounded-xl bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg shadow-amber-500/30">
                  <.phx_icon name="hero-bolt" class="w-6 h-6 text-white" />
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
                    {@product.name}
                  </h2>
                  <p class="text-sm text-amber-600 dark:text-amber-400 font-medium">
                    {gettext("Lifetime Access • No Subscriptions")}
                  </p>
                </div>
              </div>

              <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-6">
                {@product.description}
              </p>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <%= for feature <- @product.features do %>
                  <div class="flex items-start gap-2.5">
                    <div class="flex-shrink-0 mt-0.5">
                      <div class="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50">
                        <.phx_icon
                          name="hero-check"
                          class="w-3 h-3 text-emerald-600 dark:text-emerald-400"
                        />
                      </div>
                    </div>
                    <span class="text-sm text-slate-600 dark:text-slate-400">{feature}</span>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="lg:w-72 flex-shrink-0">
              <div class="bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm rounded-2xl p-6 border border-amber-200/50 dark:border-amber-700/30 shadow-lg">
                <div class="text-center mb-6">
                  <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold mb-3">
                    <.phx_icon name="hero-tag" class="w-3.5 h-3.5" />
                    {gettext("Beta Pricing")}
                  </div>
                  <div class="flex items-baseline justify-center gap-1">
                    <span class="text-5xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 dark:from-amber-400 dark:to-orange-400 bg-clip-text text-transparent">
                      {Util.format_money(@item.amount)}
                    </span>
                  </div>
                  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                    {gettext("one-time payment")}
                  </p>
                </div>

                <%= if @is_current do %>
                  <DesignSystem.liquid_button
                    variant="secondary"
                    size="lg"
                    class="w-full mb-4"
                    icon="hero-check-circle"
                    disabled
                  >
                    {gettext("Current Plan")}
                  </DesignSystem.liquid_button>
                <% else %>
                  <%= if @has_active_billing do %>
                    <DesignSystem.liquid_button
                      variant="secondary"
                      size="lg"
                      class="w-full mb-4"
                      disabled
                    >
                      {gettext("Already a Member")}
                    </DesignSystem.liquid_button>
                  <% else %>
                    <DesignSystem.liquid_button
                      variant="primary"
                      color="amber"
                      size="lg"
                      icon="hero-credit-card"
                      class="w-full mb-4"
                      phx-click="checkout"
                      phx-value-plan={@item.id}
                      phx-value-key={@key}
                    >
                      {gettext("Get Lifetime Access")}
                    </DesignSystem.liquid_button>
                  <% end %>
                <% end %>

                <div
                  id="affirm-disclosure-one-time"
                  phx-hook="TippyHook"
                  data-tippy-content={
                    gettext(
                      "Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders."
                    )
                  }
                  class="flex items-center justify-center gap-2 text-xs text-blue-600 dark:text-blue-400 cursor-help hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
                >
                  <.phx_icon name="hero-credit-card" class="w-3.5 h-3.5" />
                  <span>{gettext("Split payments with Affirm")}</span>
                  <.phx_icon name="hero-information-circle" class="w-3.5 h-3.5" />
                </div>
              </div>

              <div class="mt-4 flex items-center justify-center gap-4 text-xs text-slate-500 dark:text-slate-400">
                <div class="flex items-center gap-1.5">
                  <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
                  <span>{gettext("30-day guarantee")}</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <.phx_icon name="hero-lock-closed" class="w-4 h-4 text-emerald-500" />
                  <span>{gettext("Secure checkout")}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  attr :product, :map, required: true
  attr :current_payment_intent, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :has_active_billing, :boolean, default: false
  attr :source, :atom, required: true
  attr :key, :string, required: true

  defp pricing_card(assigns) do
    item = List.first(assigns.product.line_items)
    is_most_popular = assigns.product.most_popular
    is_one_time = item.interval == :one_time

    is_current =
      cond do
        assigns.current_payment_intent && is_one_time -> true
        assigns.current_subscription && !is_one_time -> true
        true -> false
      end

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:is_most_popular, is_most_popular)
      |> assign(:is_one_time, is_one_time)
      |> assign(:is_current, is_current)

    ~H"""
    <div class={[
      "relative group",
      @is_most_popular && "lg:-mt-4 lg:mb-4"
    ]}>
      <div
        :if={@is_most_popular}
        class="absolute -top-4 left-1/2 -translate-x-1/2 z-10"
      >
        <DesignSystem.liquid_badge variant="solid" color="emerald" size="md">
          <.phx_icon name="hero-star" class="w-3.5 h-3.5 mr-1" />
          {gettext("Most Popular")}
        </DesignSystem.liquid_badge>
      </div>

      <DesignSystem.liquid_card
        padding="lg"
        class={[
          "h-full flex flex-col transition-all duration-300 ease-out",
          @is_most_popular &&
            "ring-2 ring-emerald-500 dark:ring-emerald-400 shadow-2xl shadow-emerald-500/20",
          !@is_most_popular &&
            "hover:ring-1 hover:ring-emerald-200 dark:hover:ring-emerald-800 hover:shadow-xl"
        ]}
      >
        <div class="flex-1">
          <div class="flex items-start justify-between gap-4 mb-4">
            <div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                {@product.name}
              </h3>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                {@product.description}
              </p>
            </div>
          </div>

          <.price_display item={@item} is_one_time={@is_one_time} />

          <.trial_badge :if={Map.get(@item, :trial_days)} trial_days={@item.trial_days} />

          <div class="mt-6">
            <.action_button
              item={@item}
              is_current={@is_current}
              has_active_billing={@has_active_billing}
              is_most_popular={@is_most_popular}
              key={@key}
            />
          </div>

          <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
            <h4 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-4 flex items-center gap-2">
              <.phx_icon name="hero-check-badge" class="w-4 h-4 text-emerald-500" />
              {gettext("What's included")}
            </h4>
            <ul class="space-y-3">
              <%= for feature <- @product.features do %>
                <li class="flex items-start gap-3">
                  <div class="flex-shrink-0 mt-0.5">
                    <div class="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/40 dark:to-teal-900/40">
                      <.phx_icon
                        name="hero-check"
                        class="w-3 h-3 text-emerald-600 dark:text-emerald-400"
                      />
                    </div>
                  </div>
                  <span class="text-sm text-slate-600 dark:text-slate-400">{feature}</span>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :is_one_time, :boolean, required: true

  defp price_display(assigns) do
    ~H"""
    <div class="mt-6 mb-2">
      <div class="flex items-baseline gap-2">
        <span class="text-4xl sm:text-5xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
          <%= if @is_one_time do %>
            {Util.format_money(@item.amount)}
          <% else %>
            <%= if Map.get(@item, :monthly_equivalent) do %>
              {Util.format_money(@item.monthly_equivalent)}
            <% else %>
              {Util.format_money(@item.amount)}
            <% end %>
          <% end %>
        </span>
        <div class="flex flex-col">
          <span class="text-base font-medium text-slate-600 dark:text-slate-400">
            <%= cond do %>
              <% @is_one_time -> %>
                {gettext("once")}
              <% @item.interval == :year -> %>
                {gettext("/mo")}
              <% true -> %>
                {gettext("/month")}
            <% end %>
          </span>
          <span
            :if={@item.interval == :year}
            class="text-xs text-slate-500 dark:text-slate-500"
          >
            {gettext("billed annually")} ({Util.format_money(@item.amount)})
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :trial_days, :integer, required: true

  defp trial_badge(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-900/30 dark:to-cyan-900/30 border border-blue-200/50 dark:border-blue-700/30">
      <.phx_icon name="hero-clock" class="w-3.5 h-3.5 text-blue-600 dark:text-blue-400" />
      <span class="text-xs font-semibold text-blue-700 dark:text-blue-300">
        {ngettext("%{count}-day free trial", "%{count}-day free trial", @trial_days,
          count: @trial_days
        )}
      </span>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :is_current, :boolean, required: true
  attr :has_active_billing, :boolean, required: true
  attr :is_most_popular, :boolean, required: true
  attr :key, :string, required: true

  defp action_button(assigns) do
    ~H"""
    <%= if @is_current do %>
      <DesignSystem.liquid_button
        variant="secondary"
        size="lg"
        class="w-full"
        icon="hero-check-circle"
        disabled
      >
        {gettext("Current Plan")}
      </DesignSystem.liquid_button>
    <% else %>
      <%= if @has_active_billing do %>
        <DesignSystem.liquid_button
          variant="secondary"
          size="lg"
          class="w-full"
          disabled
        >
          {gettext("Already a Member")}
        </DesignSystem.liquid_button>
      <% else %>
        <DesignSystem.liquid_button
          variant={if @is_most_popular, do: "primary", else: "secondary"}
          size="lg"
          class="w-full"
          icon={button_icon(@item)}
          phx-click="checkout"
          phx-value-plan={@item.id}
          phx-value-key={@key}
        >
          {button_label(@item)}
        </DesignSystem.liquid_button>
      <% end %>
    <% end %>
    """
  end

  defp button_icon(%{interval: :one_time}), do: "hero-credit-card"
  defp button_icon(%{trial_days: days}) when is_integer(days) and days > 0, do: "hero-play"
  defp button_icon(_), do: "hero-arrow-right"

  defp button_label(%{interval: :one_time}), do: gettext("Pay Once")

  defp button_label(%{trial_days: days}) when is_integer(days) and days > 0,
    do: gettext("Start Free Trial")

  defp button_label(_), do: gettext("Subscribe")

  defp pricing_footer(assigns) do
    ~H"""
    <div class="mt-16 text-center space-y-4">
      <div class="flex flex-wrap items-center justify-center gap-6 text-sm text-slate-500 dark:text-slate-400">
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
          <span>{gettext("Secure payment")}</span>
        </div>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-lock-closed" class="w-4 h-4 text-emerald-500" />
          <span>{gettext("End-to-end encrypted")}</span>
        </div>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-heart" class="w-4 h-4 text-emerald-500" />
          <span>{gettext("Cancel anytime")}</span>
        </div>
      </div>

      <p class="text-xs text-slate-400 dark:text-slate-500">
        {gettext("Powered by Stripe. Your payment information is never stored on our servers.")}
      </p>
    </div>
    """
  end

  attr :source, :atom, default: :user
  attr :current_user, :map, default: nil
  attr :current_membership, :map, default: nil
  attr :socket, :map, default: nil
  attr :key, :string, default: nil
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

    case billing_provider().change_plan(customer, payment_intent, plan) do
      {:ok, session} ->
        url = billing_provider().checkout_url(session)
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
