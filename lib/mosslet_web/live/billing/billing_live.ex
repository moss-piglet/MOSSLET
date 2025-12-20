defmodule MossletWeb.BillingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Repo
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:source, socket.assigns.live_action)
      |> assign(:billing_provider, billing_provider())

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, maybe_load_provider_data(socket)}
  end

  defp maybe_load_provider_data(socket) do
    user = socket.assigns[:current_user] |> Repo.preload(:customer)
    payment_intent = socket.assigns[:payment_intent]
    session_key = socket.assigns.key

    assign_async(
      socket,
      [:provider_payment_intent_async, :provider_charge_async, :subscription_async],
      fn ->
        case payment_intent do
          nil ->
            if user.customer do
              payment_intent =
                PaymentIntents.get_active_payment_intent_by_customer_id(user.customer.id)

              subscription =
                Subscriptions.get_active_subscription_by_customer_id(user.customer.id)

              if payment_intent do
                provider_charge =
                  case Stripe.Charge.retrieve(payment_intent.provider_latest_charge_id) do
                    {:ok, provider_charge} -> provider_charge
                    _rest -> nil
                  end

                if provider_charge do
                  %{provider_payment_intent_id: provider_charge.payment_intent}
                  |> Mosslet.Billing.Providers.Stripe.Workers.PaymentIntentSyncWorker.new()
                  |> Oban.insert()
                end

                {:ok,
                 %{
                   provider_payment_intent_async: payment_intent,
                   provider_charge_async: provider_charge,
                   subscription_async: subscription
                 }}
              else
                {:ok,
                 %{
                   provider_payment_intent_async: nil,
                   provider_charge_async: nil,
                   subscription_async: subscription
                 }}
              end
            else
              {:ok,
               %{
                 provider_payment_intent_async: nil,
                 provider_charge_async: nil,
                 subscription_async: nil
               }}
            end

          payment_intent ->
            {:ok, provider_payment_intent} =
              billing_provider().retrieve_payment_intent(
                payment_intent.provider_payment_intent_id
              )

            subscription =
              if user.customer do
                Subscriptions.get_active_subscription_by_customer_id(user.customer.id)
              end

            case billing_provider().retrieve_charge(payment_intent.provider_latest_charge_id) do
              {:ok, provider_charge} ->
                {:ok,
                 %{
                   provider_payment_intent_async: provider_payment_intent,
                   provider_charge_async: provider_charge,
                   subscription_async: subscription
                 }}

              _rest ->
                {:ok,
                 %{
                   provider_payment_intent_async: provider_payment_intent,
                   provider_charge_async: nil,
                   subscription_async: subscription
                 }}
            end
        end
      end
    )
  end

  def billing_path(:user, _assigns), do: ~p"/app/billing"
  def billing_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/billing"

  defp subscribe_path(:user, _assigns), do: ~p"/app/subscribe"
  defp subscribe_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/subscribe"

  @impl true
  def handle_event("cancel_subscription", %{"subscription-id" => subscription_id}, socket) do
    subscription = Subscriptions.get_subscription!(subscription_id)

    if subscription.status == "trialing" do
      cancel_subscription_immediately(subscription, socket)
    else
      cancel_subscription_at_period_end(subscription, socket)
    end
  end

  defp cancel_subscription_immediately(subscription, socket) do
    case billing_provider().cancel_subscription_immediately(subscription.provider_subscription_id) do
      {:ok, _cancelled} ->
        Subscriptions.cancel_subscription_immediately(subscription)

        socket =
          socket
          |> put_flash(:info, gettext("Your free trial has been cancelled."))
          |> push_navigate(to: billing_path(socket.assigns.source, socket.assigns))

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> put_flash(
            :error,
            gettext("Failed to cancel subscription: %{error}", error: inspect(error))
          )

        {:noreply, socket}
    end
  end

  defp cancel_subscription_at_period_end(subscription, socket) do
    case billing_provider().cancel_subscription(subscription.provider_subscription_id) do
      {:ok, _updated} ->
        Subscriptions.cancel_subscription(subscription)

        socket =
          socket
          |> put_flash(
            :info,
            gettext(
              "Your subscription has been cancelled. You will retain access until the end of your billing period."
            )
          )
          |> push_navigate(to: billing_path(socket.assigns.source, socket.assigns))

        {:noreply, socket}

      {:error, error} ->
        socket =
          socket
          |> put_flash(
            :error,
            gettext("Failed to cancel subscription: %{error}", error: inspect(error))
          )

        {:noreply, socket}
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
          |> push_navigate(to: billing_path(socket.assigns.source, socket.assigns))

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

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout
          current_user={@current_user}
          current_page={:billing}
          sidebar_current_page={:billing}
          key={@key}
          type="sidebar"
        >
          <DesignSystem.liquid_container max_width="lg" class="py-16">
            <div class="mb-12">
              <div class="mb-8">
                <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Billing & Payments
                </h1>
                <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
                  Manage your membership and view payment history for your MOSSLET account.
                </p>
              </div>
              <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
              </div>
            </div>

            <div class="space-y-8 max-w-3xl">
              <.billing_info
                subscribe_path={subscribe_path(@source, assigns)}
                billing_provider={@billing_provider}
                provider_charge_async={@provider_charge_async}
                provider_payment_intent_async={@provider_payment_intent_async}
                subscription_async={@subscription_async}
                current_user={@current_user}
                key={@key}
              />
            </div>
          </DesignSystem.liquid_container>
        </.layout>
    <% end %>
    """
  end

  attr :billing_provider, :atom
  attr :provider_payment_intent_async, :map
  attr :provider_charge_async, :map
  attr :subscription_async, :map
  attr :subscribe_path, :string
  attr :current_user, Mosslet.Accounts.User, required: true
  attr :key, :string, required: true

  def billing_info(assigns) do
    ~H"""
    <div :if={@provider_payment_intent_async.loading}>
      <DesignSystem.liquid_card>
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
              <.phx_icon name="hero-credit-card" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <span>Loading Billing Information</span>
          </div>
        </:title>

        <div class="flex items-center justify-center py-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500"></div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <div :if={@provider_payment_intent_async.failed}>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-rose-50/50 to-pink-50/30 dark:from-rose-900/20 dark:to-pink-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="h-4 w-4 text-rose-600 dark:text-rose-400"
              />
            </div>
            <span class="text-rose-800 dark:text-rose-200">Provider Error</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-rose-700 dark:text-rose-300">
            {gettext("Something went wrong with our payment provider. Please contact support.")}
          </p>

          <div class="flex justify-start">
            <DesignSystem.liquid_button
              href="mailto:support@mosslet.com"
              color="rose"
              icon="hero-envelope"
            >
              Contact Support
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <div :if={
      @provider_payment_intent_async.ok? && !@provider_payment_intent_async.result &&
        @subscription_async.ok? && !@subscription_async.result
    }>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
              <.phx_icon name="hero-credit-card" class="h-4 w-4 text-amber-600 dark:text-amber-400" />
            </div>
            <span class="text-amber-800 dark:text-amber-200">No Active Membership</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-amber-700 dark:text-amber-300">
            {gettext(
              "You don't have an active membership yet. Browse our plans to get started with MOSSLET."
            )}
          </p>

          <div class="flex justify-start">
            <DesignSystem.liquid_button href={@subscribe_path} color="amber" icon="hero-eye">
              {gettext("View Plans")}
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <div
      :if={@subscription_async.ok? && @subscription_async.result}
      class="space-y-8"
    >
      <.subscription_info
        subscription={@subscription_async.result}
        subscribe_path={@subscribe_path}
        current_user={@current_user}
        key={@key}
      />
    </div>

    <div
      :if={
        @provider_payment_intent_async.ok? && @provider_payment_intent_async.result &&
          @provider_charge_async.ok?
      }
      class="space-y-8"
    >
      <.payment_intent_info
        provider_payment_intent={@provider_payment_intent_async.result}
        provider_charge={@provider_charge_async.result}
        subscribe_path={@subscribe_path}
        current_user={@current_user}
        key={@key}
      />
    </div>
    """
  end

  attr :subscription, :map, required: true
  attr :subscribe_path, :string, required: true
  attr :current_user, Mosslet.Accounts.User, required: true
  attr :key, :string, required: true

  defp subscription_info(assigns) do
    cancellation_pending = assigns.subscription.cancel_at != nil
    assigns = assign(assigns, :cancellation_pending, cancellation_pending)

    ~H"""
    <DesignSystem.liquid_card class={[
      "bg-gradient-to-br",
      if(@cancellation_pending,
        do: "from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10",
        else: "from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10"
      )
    ]}>
      <:title>
        <div class="flex items-center gap-3">
          <div class={[
            "relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br",
            if(@cancellation_pending,
              do:
                "from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30",
              else:
                "from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30"
            )
          ]}>
            <.phx_icon
              name={if(@cancellation_pending, do: "hero-clock", else: "hero-check-circle")}
              class={[
                "h-4 w-4",
                if(@cancellation_pending,
                  do: "text-amber-600 dark:text-amber-400",
                  else: "text-emerald-600 dark:text-emerald-400"
                )
              ]}
            />
          </div>
          <span class={
            if(@cancellation_pending,
              do: "text-amber-800 dark:text-amber-200",
              else: "text-emerald-800 dark:text-emerald-200"
            )
          }>
            <%= cond do %>
              <% @cancellation_pending -> %>
                {gettext("Subscription Ending")}
              <% @subscription.status == "trialing" -> %>
                {gettext("Free Trial Active")}
              <% true -> %>
                {gettext("Subscription Active")}
            <% end %>
          </span>
          <DesignSystem.liquid_badge
            variant="solid"
            color={if(@cancellation_pending, do: "amber", else: "emerald")}
            size="sm"
          >
            <%= if @cancellation_pending do %>
              {gettext("cancelling")}
            <% else %>
              {@subscription.status}
            <% end %>
          </DesignSystem.liquid_badge>
        </div>
      </:title>

      <div class="space-y-6">
        <p class={
          if(@cancellation_pending,
            do: "text-amber-700 dark:text-amber-300",
            else: "text-emerald-700 dark:text-emerald-300"
          )
        }>
          <%= cond do %>
            <% @cancellation_pending -> %>
              {gettext(
                "Your subscription has been cancelled. You will retain access until the end of your billing period."
              )}
            <% @subscription.status == "trialing" -> %>
              {gettext("You're currently on a free trial. Enjoy exploring all of MOSSLET's features!")}
            <% true -> %>
              {gettext("Your subscription is active. Thank you for being a MOSSLET member!")}
          <% end %>
        </p>

        <div class={[
          "rounded-lg p-6 border",
          if(@cancellation_pending,
            do: "bg-amber-100 dark:bg-amber-900/30 border-amber-200 dark:border-amber-700",
            else: "bg-emerald-100 dark:bg-emerald-900/30 border-emerald-200 dark:border-emerald-700"
          )
        ]}>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <p class={[
                "text-xs font-medium uppercase tracking-wide",
                if(@cancellation_pending,
                  do: "text-amber-600 dark:text-amber-400",
                  else: "text-emerald-600 dark:text-emerald-400"
                )
              ]}>
                {gettext("Status")}
              </p>
              <p class={[
                "mt-1 text-lg font-semibold capitalize",
                if(@cancellation_pending,
                  do: "text-amber-800 dark:text-amber-200",
                  else: "text-emerald-800 dark:text-emerald-200"
                )
              ]}>
                <%= if @cancellation_pending do %>
                  {gettext("Cancelling")}
                <% else %>
                  {@subscription.status}
                <% end %>
              </p>
            </div>
            <div :if={@subscription.current_period_end_at}>
              <p class={[
                "text-xs font-medium uppercase tracking-wide",
                if(@cancellation_pending,
                  do: "text-amber-600 dark:text-amber-400",
                  else: "text-emerald-600 dark:text-emerald-400"
                )
              ]}>
                <%= cond do %>
                  <% @cancellation_pending -> %>
                    {gettext("Access Ends")}
                  <% @subscription.status == "trialing" -> %>
                    {gettext("Trial Ends")}
                  <% true -> %>
                    {gettext("Next Billing Date")}
                <% end %>
              </p>
              <p class={[
                "mt-1 text-lg font-semibold",
                if(@cancellation_pending,
                  do: "text-amber-800 dark:text-amber-200",
                  else: "text-emerald-800 dark:text-emerald-200"
                )
              ]}>
                <.local_time_full
                  id={"subscription-#{@subscription.id}"}
                  at={@subscription.current_period_end_at}
                />
              </p>
            </div>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row gap-4">
          <DesignSystem.liquid_button
            href={@subscribe_path}
            color={if(@cancellation_pending, do: "amber", else: "emerald")}
            icon="hero-eye"
            variant="secondary"
          >
            {gettext("View Plans")}
          </DesignSystem.liquid_button>

          <DesignSystem.liquid_button
            :if={@subscription.status in ["trialing", "active"] && !@cancellation_pending}
            phx-click="cancel_subscription"
            phx-value-subscription-id={@subscription.id}
            color="rose"
            icon="hero-x-circle"
            variant="ghost"
            data-confirm={
              if @subscription.status == "trialing",
                do:
                  gettext(
                    "Are you sure you want to cancel your free trial? You will lose access immediately."
                  ),
                else:
                  gettext(
                    "Are you sure you want to cancel your subscription? You will retain access until the end of your billing period."
                  )
            }
          >
            {gettext("Cancel Subscription")}
          </DesignSystem.liquid_button>

          <DesignSystem.liquid_button
            :if={@cancellation_pending}
            phx-click="resume_subscription"
            phx-value-subscription-id={@subscription.id}
            color="emerald"
            icon="hero-arrow-path"
            variant="secondary"
            data-confirm={gettext("Are you sure you want to resume your subscription?")}
          >
            {gettext("Resume Plan")}
          </DesignSystem.liquid_button>
        </div>
      </div>
    </DesignSystem.liquid_card>

    <DesignSystem.liquid_card>
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
            <.phx_icon name="hero-document-text" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
          </div>
          <span>Subscription Details</span>
        </div>
      </:title>

      <div class="space-y-6">
        <div class="space-y-4">
          <h3 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-credit-card" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            Account Information
          </h3>

          <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
            <div class="space-y-4">
              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Subscription ID:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {@subscription.provider_subscription_id}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Customer ID:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {maybe_update_customer_provider_info_encryption(
                    @current_user.customer,
                    @current_user,
                    @key
                  )}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Payment Email:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {maybe_update_customer_email_encryption(
                    @current_user.customer.email,
                    @current_user,
                    @key
                  )}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Plan:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {@subscription.plan_id}
                </code>
              </div>
            </div>
          </div>
        </div>

        <div :if={@subscription.current_period_start} class="space-y-4">
          <h4 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-calendar-days" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            Billing Period
          </h4>

          <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="flex items-center justify-center w-10 h-10 rounded-lg bg-blue-100 dark:bg-blue-900/30">
                <.phx_icon name="hero-clock" class="h-5 w-5 text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  <.local_time_full
                    id={"subscription-start-#{@subscription.id}"}
                    at={@subscription.current_period_start}
                  />
                </p>
                <p class="text-xs text-slate-600 dark:text-slate-400 mt-0.5">
                  Current billing period started
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  attr :provider_payment_intent, :map, required: true
  attr :provider_charge, :map
  attr :subscribe_path, :string, required: true
  attr :current_user, Mosslet.Accounts.User, required: true
  attr :key, :string, required: true

  defp payment_intent_info(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
            <.phx_icon
              name="hero-check-circle"
              class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
            />
          </div>
          <span class="text-emerald-800 dark:text-emerald-200">Lifetime Member</span>
          <DesignSystem.liquid_badge
            :if={@provider_payment_intent.status == "succeeded"}
            variant="solid"
            color="emerald"
            size="sm"
          >
            {gettext("paid")}
          </DesignSystem.liquid_badge>
        </div>
      </:title>

      <div class="space-y-6">
        <p class="text-emerald-700 dark:text-emerald-300">
          Thank you for your payment! You have lifetime access to MOSSLET.
        </p>

        <div class="bg-emerald-100 dark:bg-emerald-900/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-700">
          <div class="text-center space-y-3">
            <div class="flex items-center justify-center gap-2 mb-2">
              <.phx_icon
                name="hero-check-badge"
                class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
              />
              <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
                One-Time Payment Complete
              </span>
            </div>

            <div
              :if={@provider_charge}
              class="text-3xl font-bold text-emerald-800 dark:text-emerald-200"
            >
              {@provider_charge.amount_captured |> Util.format_money()}
              <span class="text-lg uppercase ml-1">{@provider_charge.currency}</span>
            </div>

            <div class="space-y-1">
              <p class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                Lifetime access to MOSSLET
              </p>
              <p class="text-xs text-emerald-700 dark:text-emerald-300">
                No recurring charges • Pay once, use forever
              </p>
            </div>
          </div>
        </div>

        <div class="bg-emerald-50 dark:bg-emerald-900/20 rounded-lg p-4 border border-emerald-100 dark:border-emerald-800">
          <div class="flex items-start gap-3">
            <.phx_icon
              name="hero-information-circle"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400 mt-0.5 flex-shrink-0"
            />
            <div class="text-sm text-emerald-700 dark:text-emerald-300">
              <strong>This was a one-time payment.</strong>
              You will never be charged again for your MOSSLET account. Your lifetime access is now active and will never expire.
            </div>
          </div>
        </div>
      </div>
    </DesignSystem.liquid_card>

    <DesignSystem.liquid_card :if={@provider_charge}>
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
            <.phx_icon name="hero-document-text" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
          </div>
          <span>Payment Details</span>
        </div>
      </:title>

      <div class="space-y-6">
        <div class="space-y-4">
          <h3 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-credit-card" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            Charge Information
          </h3>

          <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
            <div class="space-y-4">
              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Charge ID:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {@provider_charge.id}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Customer ID:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {maybe_update_customer_provider_info_encryption(
                    @current_user.customer,
                    @current_user,
                    @key
                  )}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Payment Email:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {maybe_update_customer_email_encryption(
                    @current_user.customer.email,
                    @current_user,
                    @key
                  )}
                </code>
              </div>
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <h4 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
            <.phx_icon name="hero-calendar-days" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            Billing Date
          </h4>

          <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
            <div class="flex items-center gap-3">
              <div class="flex items-center justify-center w-10 h-10 rounded-lg bg-blue-100 dark:bg-blue-900/30">
                <.phx_icon name="hero-clock" class="h-5 w-5 text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <time
                  datetime={@provider_payment_intent.provider_created_at}
                  class="text-sm font-medium text-slate-900 dark:text-slate-100"
                >
                  <.local_time_full
                    id={@current_user.id}
                    at={@provider_payment_intent.provider_created_at}
                  />
                </time>
                <p class="text-xs text-slate-600 dark:text-slate-400 mt-0.5">
                  Payment processed successfully
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </DesignSystem.liquid_card>

    <DesignSystem.liquid_card
      :if={@provider_charge}
      class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
            <.phx_icon name="hero-cog-6-tooth" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
          </div>
          <span class="text-blue-800 dark:text-blue-200">Account Actions</span>
        </div>
      </:title>

      <div class="space-y-4">
        <p class="text-blue-700 dark:text-blue-300">
          Manage your account and access additional resources.
        </p>

        <div class="flex flex-col sm:flex-row gap-4">
          <DesignSystem.liquid_button
            href={@subscribe_path}
            color="blue"
            icon="hero-eye"
            variant="secondary"
          >
            {gettext("View Plans")}
          </DesignSystem.liquid_button>

          <DesignSystem.liquid_button
            href={@provider_charge.receipt_url}
            target="_blank"
            rel="noopener noreferrer"
            color="blue"
            icon="hero-document-arrow-down"
          >
            {gettext("View Receipt")}
          </DesignSystem.liquid_button>
        </div>
      </div>
    </DesignSystem.liquid_card>

    <DesignSystem.liquid_card class="bg-gradient-to-br from-purple-50/50 to-violet-50/30 dark:from-purple-900/20 dark:to-violet-900/10">
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
            <.phx_icon
              name="hero-question-mark-circle"
              class="h-4 w-4 text-purple-600 dark:text-purple-400"
            />
          </div>
          <span class="text-purple-800 dark:text-purple-200">Need Help?</span>
        </div>
      </:title>

      <div class="space-y-4">
        <p class="text-purple-700 dark:text-purple-300">
          If you have any questions about your payment or need assistance with your account, our support team is here to help.
        </p>

        <div class="flex flex-col sm:flex-row gap-4">
          <DesignSystem.liquid_button
            href="mailto:support@mosslet.com"
            color="purple"
            icon="hero-envelope"
          >
            Contact Support
          </DesignSystem.liquid_button>

          <DesignSystem.liquid_button
            href="/faq"
            color="purple"
            icon="hero-question-mark-circle"
            variant="ghost"
          >
            View FAQ
          </DesignSystem.liquid_button>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  defp maybe_update_customer_email_encryption(email, current_user, key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_data(email, current_user, key) do
      :failed_verification ->
        {:ok, customer} = update_customer_for_source(email, current_user, key)

        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          customer.email,
          current_user,
          key
        )

      d_email ->
        d_email
    end
  end

  defp maybe_update_customer_provider_info_encryption(customer, current_user, key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
           customer.provider_customer_id,
           current_user,
           key
         ) do
      :failed_verification ->
        {:ok, customer} =
          update_customer_provider_info_for_source(
            customer.provider_customer_id,
            current_user,
            key
          )

        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          customer.provider_customer_id,
          current_user,
          key
        )

      d_provider_customer_id ->
        d_provider_customer_id
    end
  end

  defp update_customer_for_source(email, current_user, key) do
    Mosslet.Billing.Customers.update_customer_for_source(
      :user,
      current_user.id,
      %{
        email: maybe_decrypt_user_data(email, current_user, key),
        provider: "stripe",
        provider_customer_id:
          maybe_decrypt_user_data(current_user.customer.provider_customer_id, current_user, key)
      },
      current_user,
      key
    )
  end

  defp update_customer_provider_info_for_source(provider_customer_id, current_user, key) do
    Mosslet.Billing.Customers.update_customer_for_source(
      :user,
      current_user.id,
      %{
        provider: "stripe",
        provider_customer_id: maybe_decrypt_user_data(provider_customer_id, current_user, key)
      },
      current_user,
      key
    )
  end
end
