defmodule MossletWeb.SubscribeLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Plans
  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions
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

    referral_discount = get_referral_discount(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, gettext("Pricing"))
      |> assign(:source, socket.assigns.live_action)
      |> assign(:current_membership, socket.assigns[:current_membership])
      |> assign(:products, products)
      |> assign(:one_time_products, one_time_products)
      |> assign(:subscription_products, subscription_products)
      |> assign(:referral_discount, referral_discount)

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
    <main
      role="main"
      class="fixed inset-0 z-10 overflow-y-auto bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900"
    >
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
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
          <.referral_banner :if={@referral_discount} discount={@referral_discount} />

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
            referral_discount={@referral_discount}
          />
        </div>

        <.pricing_footer />
      </div>
    </main>
    """
  end

  attr :has_active_billing, :boolean, default: false

  defp pricing_header(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl text-center mb-10 sm:mb-12">
      <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/30 dark:to-emerald-900/30 border border-teal-200/50 dark:border-teal-700/30 mb-6">
        <span class="text-xl">🎉</span>
        <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
          {gettext("Final step")}
        </span>
      </div>

      <h1 class={[
        "text-2xl sm:text-3xl font-bold tracking-tight leading-tight mb-3",
        "bg-gradient-to-r from-teal-600 via-emerald-500 to-teal-500",
        "dark:from-teal-400 dark:via-emerald-400 dark:to-teal-300",
        "bg-clip-text text-transparent"
      ]}>
        {gettext("Choose your plan")}
      </h1>

      <p class="text-base text-slate-600 dark:text-slate-400 max-w-xl mx-auto">
        <%= if @has_active_billing do %>
          {gettext("You're already a member! Manage your subscription below.")}
        <% else %>
          {gettext("Start your free trial today—cancel anytime before it ends.")}
        <% end %>
      </p>
    </div>
    """
  end

  attr :discount, :integer, required: true

  defp referral_banner(assigns) do
    ~H"""
    <div class="mb-10 max-w-2xl mx-auto">
      <div class="p-4 rounded-xl bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 border border-amber-200/50 dark:border-amber-700/30">
        <div class="flex items-center gap-3">
          <div class="flex-shrink-0">
            <.phx_icon name="hero-gift" class="w-6 h-6 text-amber-600 dark:text-amber-400" />
          </div>
          <div>
            <p class="text-sm font-semibold text-amber-800 dark:text-amber-200">
              🎉 {gettext("You've been referred!")}
            </p>
            <p class="text-sm text-amber-700 dark:text-amber-300">
              {gettext("You'll get %{discount}% off your first payment—subscription or one-time.",
                discount: @discount
              )}
            </p>
          </div>
        </div>
      </div>
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
            <h2 class="text-lg font-semibold text-emerald-800 dark:text-emerald-200">
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
            </h2>
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
  attr :referral_discount, :integer, default: nil

  defp pricing_cards(assigns) do
    ~H"""
    <div
      :if={@subscription_products != []}
      class="grid grid-cols-1 md:grid-cols-2 gap-6 lg:gap-8 max-w-3xl mx-auto"
    >
      <%= for product <- @subscription_products do %>
        <.pricing_card
          product={product}
          current_payment_intent={@current_payment_intent}
          current_subscription={@current_subscription}
          has_active_billing={@has_active_billing}
          source={@source}
          key={@key}
          referral_discount={@referral_discount}
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
            current_subscription={@current_subscription}
            key={@key}
            referral_discount={@referral_discount}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :product, :map, required: true
  attr :current_payment_intent, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :key, :string, required: true
  attr :referral_discount, :integer, default: nil

  defp one_time_card(assigns) do
    item = List.first(assigns.product.line_items)
    is_current = assigns.current_payment_intent != nil
    has_subscription = assigns.current_subscription != nil

    discounted_amount =
      if assigns.referral_discount do
        trunc(item.amount * (100 - assigns.referral_discount) / 100)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:is_current, is_current)
      |> assign(:has_subscription, has_subscription)
      |> assign(:discounted_amount, discounted_amount)

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
                  <div class="flex flex-wrap items-center justify-center gap-2 mb-3">
                    <div
                      :if={Map.get(@item, :save_percent)}
                      id={"beta-pricing-#{@item.id}-#{@item.interval}"}
                      phx-hook="TippyHook"
                      data-tippy-content={
                        gettext("Save %{percent}% off", percent: @item.save_percent)
                      }
                      class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold cursor-help"
                    >
                      <.phx_icon name="hero-tag" class="w-3.5 h-3.5" />
                      {gettext("Beta Pricing")}
                    </div>
                    <div
                      :if={@discounted_amount}
                      class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 text-xs font-semibold"
                    >
                      <.phx_icon name="hero-gift" class="w-3.5 h-3.5" />
                      {gettext("%{percent}% off", percent: @referral_discount)}
                    </div>
                  </div>
                  <div class="flex items-baseline justify-center gap-2">
                    <%= if @discounted_amount do %>
                      <span class="text-5xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 dark:from-amber-400 dark:to-orange-400 bg-clip-text text-transparent">
                        {Util.format_money(@discounted_amount)}
                      </span>
                      <span class="text-xl line-through text-slate-400 dark:text-slate-500">
                        {Util.format_money(@item.amount)}
                      </span>
                    <% else %>
                      <span class="text-5xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 dark:from-amber-400 dark:to-orange-400 bg-clip-text text-transparent">
                        {Util.format_money(@item.amount)}
                      </span>
                    <% end %>
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
                  <%= if @has_subscription do %>
                    <DesignSystem.liquid_button
                      variant="primary"
                      color="amber"
                      size="lg"
                      icon="hero-arrow-up-circle"
                      class="w-full mb-4"
                      phx-click="checkout"
                      phx-value-plan={@item.id}
                      phx-value-key={@key}
                    >
                      {gettext("Upgrade to Lifetime")}
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
  attr :referral_discount, :integer, default: nil

  defp pricing_card(assigns) do
    item = List.first(assigns.product.line_items)
    is_most_popular = assigns.product.most_popular
    is_one_time = item.interval == :one_time

    current_subscription = assigns.current_subscription

    cancellation_pending =
      current_subscription != nil && current_subscription.cancel_at != nil

    is_current =
      cond do
        assigns.current_payment_intent && is_one_time -> true
        current_subscription && !is_one_time && current_subscription.plan_id == item.id -> true
        true -> false
      end

    can_upgrade =
      cond do
        is_current -> false
        current_subscription && !is_one_time && current_subscription.plan_id != item.id -> true
        true -> false
      end

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:is_most_popular, is_most_popular)
      |> assign(:is_one_time, is_one_time)
      |> assign(:is_current, is_current)
      |> assign(:can_upgrade, can_upgrade)
      |> assign(:cancellation_pending, cancellation_pending)

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
              <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                {@product.name}
              </h2>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                {@product.description}
              </p>
            </div>
          </div>

          <.price_display
            item={@item}
            is_one_time={@is_one_time}
            referral_discount={@referral_discount}
          />

          <.trial_badge :if={Map.get(@item, :trial_days)} trial_days={@item.trial_days} />

          <div class="mt-6">
            <.action_button
              item={@item}
              is_current={@is_current}
              has_active_billing={@has_active_billing}
              can_upgrade={@can_upgrade}
              is_most_popular={@is_most_popular}
              cancellation_pending={@cancellation_pending}
              current_subscription={@current_subscription}
              key={@key}
            />

            <div
              :if={@item.interval == :year}
              id={"affirm-disclosure-#{@item.id}"}
              phx-hook="TippyHook"
              data-tippy-content={
                gettext(
                  "Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders."
                )
              }
              class="mt-4 flex items-center justify-center gap-2 text-xs text-blue-600 dark:text-blue-400 cursor-help hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
            >
              <.phx_icon name="hero-credit-card" class="w-3.5 h-3.5" />
              <span>{gettext("Split payments with Affirm")}</span>
              <.phx_icon name="hero-information-circle" class="w-3.5 h-3.5" />
            </div>
          </div>

          <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
            <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-4 flex items-center gap-2">
              <.phx_icon name="hero-check-badge" class="w-4 h-4 text-emerald-500" />
              {gettext("What's included")}
            </h3>
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
  attr :referral_discount, :integer, default: nil

  defp price_display(assigns) do
    original_amount =
      if assigns.is_one_time do
        assigns.item.amount
      else
        Map.get(assigns.item, :monthly_equivalent) || assigns.item.amount
      end

    discounted_amount =
      if assigns.referral_discount && !assigns.is_one_time do
        trunc(original_amount * (100 - assigns.referral_discount) / 100)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:original_amount, original_amount)
      |> assign(:discounted_amount, discounted_amount)

    ~H"""
    <div class="mt-6 mb-2">
      <div class="flex items-center gap-3 mb-2">
        <div
          :if={Map.get(@item, :save_percent)}
          id={"beta-pricing-#{@item.id}-#{@item.interval}"}
          phx-hook="TippyHook"
          data-tippy-content={gettext("Save %{percent}% off", percent: @item.save_percent)}
          class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold cursor-help"
        >
          <.phx_icon name="hero-tag" class="w-3.5 h-3.5" /> {gettext("Beta Pricing")}
        </div>
        <div
          :if={@discounted_amount}
          class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 text-xs font-semibold"
        >
          <.phx_icon name="hero-gift" class="w-3.5 h-3.5" /> {gettext("%{percent}% off first payment",
            percent: @referral_discount
          )}
        </div>
      </div>
      <div class="flex items-baseline gap-2">
        <%= if @discounted_amount do %>
          <span class="text-4xl sm:text-5xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
            {Util.format_money(@discounted_amount)}
          </span>
          <span class="text-xl line-through text-slate-400 dark:text-slate-500">
            {Util.format_money(@original_amount)}
          </span>
        <% else %>
          <span class="text-4xl sm:text-5xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
            {Util.format_money(@original_amount)}
          </span>
        <% end %>
        <div class="flex flex-col">
          <span class="text-base font-medium text-slate-600 dark:text-slate-400">
            <%= cond do %>
              <% @is_one_time -> %>
                {gettext("once")}
              <% @item.interval == :year -> %>
                {gettext("/year")}
              <% true -> %>
                {gettext("/month")}
            <% end %>
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
  attr :can_upgrade, :boolean, required: true
  attr :is_most_popular, :boolean, required: true
  attr :cancellation_pending, :boolean, required: true
  attr :current_subscription, :any, default: nil
  attr :key, :string, required: true

  defp action_button(assigns) do
    ~H"""
    <%= cond do %>
      <% @is_current && @cancellation_pending -> %>
        <DesignSystem.liquid_button
          variant="primary"
          size="lg"
          class="w-full"
          icon="hero-arrow-path"
          phx-click="resume_subscription"
          phx-value-subscription-id={@current_subscription.id}
          data-confirm={gettext("Are you sure you want to resume your subscription?")}
        >
          {gettext("Resume Plan")}
        </DesignSystem.liquid_button>
      <% @is_current -> %>
        <DesignSystem.liquid_button
          variant="secondary"
          size="lg"
          class="w-full"
          icon="hero-check-circle"
          disabled
        >
          {gettext("Current Plan")}
        </DesignSystem.liquid_button>
      <% @can_upgrade -> %>
        <DesignSystem.liquid_button
          variant={if @is_most_popular, do: "primary", else: "secondary"}
          size="lg"
          class="w-full"
          icon="hero-arrow-up-circle"
          phx-click="switch_subscription"
          phx-value-plan={@item.id}
          phx-value-key={@key}
        >
          {gettext("Switch Plan")}
        </DesignSystem.liquid_button>
      <% @has_active_billing -> %>
        <DesignSystem.liquid_button
          variant="secondary"
          size="lg"
          class="w-full"
          disabled
        >
          {gettext("Already a Member")}
        </DesignSystem.liquid_button>
      <% true -> %>
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
    <div class="mt-12 text-center space-y-6">
      <div class="flex flex-wrap items-center justify-center gap-4 text-xs text-slate-500 dark:text-slate-400">
        <div class="flex items-center gap-1.5">
          <.phx_icon name="hero-shield-check" class="w-3.5 h-3.5 text-emerald-500" />
          <span>{gettext("Secure payment")}</span>
        </div>
        <div class="flex items-center gap-1.5">
          <.phx_icon name="hero-heart" class="w-3.5 h-3.5 text-emerald-500" />
          <span>{gettext("Cancel anytime")}</span>
        </div>
      </div>

      <div class="pt-4 border-t border-slate-200/60 dark:border-slate-700/50">
        <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
          {gettext("Not ready to start? You can always come back later.")}
        </p>
        <div class="flex flex-wrap items-center justify-center gap-4">
          <.link
            navigate={~p"/app/users/edit-details"}
            class="inline-flex items-center gap-1.5 text-sm text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 transition-colors duration-200"
          >
            <.phx_icon name="hero-cog-6-tooth" class="w-4 h-4" />
            {gettext("Account settings")}
          </.link>
          <span class="text-slate-300 dark:text-slate-600">•</span>
          <.link
            class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-rose-500 dark:text-slate-400 dark:hover:text-rose-400 transition-colors duration-200"
            href={~p"/auth/sign_out"}
            method="delete"
          >
            <.phx_icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" />
            {gettext("Sign out")}
          </.link>
        </div>
      </div>
    </div>
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
          assigns: %{
            current_customer: customer,
            current_payment_intent: payment_intent,
            current_user: user,
            key: key
          }
        } =
          socket
      ) do
    plan = Plans.get_plan_by_id!(plan_id)

    case billing_provider().change_plan(customer, payment_intent, plan, user, key) do
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

  def handle_event(
        "switch_subscription",
        %{"plan" => plan_id, "key" => key},
        %{
          assigns: %{
            current_customer: customer,
            current_subscription: subscription,
            current_user: user,
            key: key
          }
        } =
          socket
      ) do
    plan = Plans.get_plan_by_id!(plan_id)

    case billing_provider().change_plan(customer, subscription, plan, user, key) do
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

  def handle_event("resume_subscription", %{"subscription-id" => subscription_id}, socket) do
    subscription = Subscriptions.get_subscription!(subscription_id)

    case billing_provider().resume_subscription(subscription.provider_subscription_id) do
      {:ok, _updated} ->
        Subscriptions.resume_subscription(subscription)

        socket =
          socket
          |> put_flash(:info, gettext("Your subscription has been resumed."))
          |> assign_billing_status()

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> put_flash(
            :error,
            gettext("Failed to resume subscription: %{error}", error: inspect(error))
          )

        {:noreply, socket}
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

  defp get_referral_discount(user) do
    case Referrals.get_pending_referral_for_user(user.id) do
      %{discount_percent: discount} -> discount
      _ -> nil
    end
  end
end
