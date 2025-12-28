defmodule MossletWeb.ReferralsLive do
  @moduledoc """
  LiveView for managing referral program - view stats, get referral link,
  set up Stripe Connect for payouts.
  """
  use MossletWeb, :live_view

  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.Providers.Stripe.Services.StripeConnect
  alias MossletWeb.DesignSystem

  @refresh_interval :timer.minutes(15)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key

    if Referrals.user_eligible_for_referrals?(user) do
      if connected?(socket) do
        Referrals.subscribe_referrals(user.id)
        schedule_refresh()
      end

      {:ok, load_referral_data(socket, user, session_key)}
    else
      in_free_trial = user_in_free_trial?(user)

      {:ok,
       socket
       |> assign(:page_title, gettext("Referrals"))
       |> assign(:eligible, false)
       |> assign(:in_free_trial, in_free_trial)
       |> assign(:stats, nil)
       |> assign(:referral_code, nil)}
    end
  end

  defp load_referral_data(socket, user, session_key) do
    {:ok, referral_code} = Referrals.get_or_create_code(user, session_key)
    stats = Referrals.get_stats(user.id)
    payouts = Referrals.list_payouts(referral_code.id)
    referrals = Referrals.list_referrals_with_commissions(referral_code.id)

    decrypted_code =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        referral_code.code,
        user,
        session_key
      )

    socket
    |> assign(:page_title, gettext("Referrals"))
    |> assign(:eligible, true)
    |> assign(:referral_code, referral_code)
    |> assign(:decrypted_code, decrypted_code)
    |> assign(:stats, stats)
    |> assign(:payouts, payouts)
    |> assign(:referrals, referrals)
    |> assign(:referral_link, build_referral_link(decrypted_code))
    |> assign(:connect_status, get_connect_status(referral_code))
    |> assign(:show_connect_modal, false)
  end

  defp build_referral_link(code) do
    "#{MossletWeb.Endpoint.url()}/auth/register?ref=#{code}"
  end

  defp get_connect_status(%{connect_payouts_enabled: true}), do: :enabled
  defp get_connect_status(%{connect_onboarding_complete: true}), do: :pending
  defp get_connect_status(%{stripe_connect_account_id: nil}), do: :not_started
  defp get_connect_status(_), do: :in_progress

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:referrals}
      sidebar_current_page={:referrals}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">
            {gettext("Referral Program")}
          </h1>
          <p class="text-slate-600 dark:text-slate-400">
            {gettext("Earn commission by inviting friends to MOSSLET")}
          </p>
        </div>

        <%= if @eligible do %>
          <.referral_dashboard
            stats={@stats}
            referral_link={@referral_link}
            decrypted_code={@decrypted_code}
            connect_status={@connect_status}
            payouts={@payouts}
            referrals={@referrals}
          />
        <% else %>
          <%= if @in_free_trial do %>
            <.free_trial_notice />
          <% else %>
            <.not_eligible_notice />
          <% end %>
        <% end %>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  attr :stats, :map, required: true
  attr :referral_link, :string, required: true
  attr :decrypted_code, :string, required: true
  attr :connect_status, :atom, required: true
  attr :payouts, :list, required: true
  attr :referrals, :list, required: true

  defp referral_dashboard(assigns) do
    ~H"""
    <div class="space-y-8">
      <.referral_link_card referral_link={@referral_link} decrypted_code={@decrypted_code} />
      <.stats_grid stats={@stats} />
      <.referrals_list referrals={@referrals} />
      <.payout_setup_card connect_status={@connect_status} stats={@stats} />
      <.payouts_history payouts={@payouts} />
      <.program_details />
    </div>
    """
  end

  attr :referral_link, :string, required: true
  attr :decrypted_code, :string, required: true

  defp referral_link_card(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border-emerald-200/60 dark:border-emerald-700/40">
      <div class="flex flex-col md:flex-row md:items-center gap-6">
        <div class="flex-shrink-0">
          <div class="flex h-14 w-14 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-500 to-teal-500 shadow-lg shadow-emerald-500/25">
            <.phx_icon name="hero-banknotes" class="h-7 w-7 text-white" />
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <h2 class="text-lg font-semibold text-emerald-800 dark:text-emerald-200 mb-1">
            {gettext("Your Referral Link")}
          </h2>
          <p class="text-sm text-emerald-700 dark:text-emerald-300 mb-4">
            {gettext("Share this link with friends. When they subscribe, you both benefit!")}
          </p>
          <div class="flex flex-col sm:flex-row gap-3">
            <div class="flex-1 bg-white dark:bg-slate-800 rounded-lg px-4 py-3 border border-emerald-200 dark:border-emerald-700">
              <code
                id="referral-link"
                class="text-sm text-slate-700 dark:text-slate-300 break-all select-all"
              >
                {@referral_link}
              </code>
            </div>
            <DesignSystem.liquid_button
              type="button"
              variant="primary"
              color="emerald"
              icon="hero-clipboard-document"
              data-copy-text={@referral_link}
              phx-click={
                JS.dispatch("phx:clipcopy")
                |> JS.push("copy_link")
              }
            >
              {gettext("Copy Link")}
            </DesignSystem.liquid_button>
          </div>
          <p class="mt-3 text-xs text-emerald-600 dark:text-emerald-400">
            {gettext("Your code: %{code}", code: @decrypted_code)}
          </p>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  attr :stats, :map, required: true

  defp stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <.stat_card
        label={gettext("Total Referrals")}
        value={@stats.total_referrals}
        icon="hero-users"
        color="blue"
      />
      <.stat_card
        label={gettext("Active Subscriptions")}
        value={@stats.active_referrals}
        subtitle={gettext("Recurring payouts")}
        icon="hero-arrow-path"
        color="emerald"
      />
      <.stat_card
        label={gettext("One-Time Purchases")}
        value={@stats.one_time_referrals}
        subtitle={gettext("Single payout")}
        icon="hero-shopping-bag"
        color="cyan"
      />
      <.stat_card
        label={gettext("Pending")}
        value={format_currency(@stats.pending_earnings)}
        subtitle={gettext("35-day hold")}
        icon="hero-clock"
        color="slate"
      />
      <.stat_card
        label={gettext("Available")}
        value={format_currency(@stats.available_for_payout)}
        icon="hero-banknotes"
        color="amber"
      />
      <.stat_card
        label={gettext("Total Earned")}
        value={format_currency(@stats.total_paid_out)}
        icon="hero-currency-dollar"
        color="purple"
      />
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :subtitle, :string, default: nil

  defp stat_card(assigns) do
    color_classes =
      case assigns.color do
        "blue" ->
          "from-blue-50 to-cyan-50 dark:from-blue-900/20 dark:to-cyan-900/20 border-blue-200/60 dark:border-blue-700/40"

        "emerald" ->
          "from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border-emerald-200/60 dark:border-emerald-700/40"

        "cyan" ->
          "from-cyan-50 to-sky-50 dark:from-cyan-900/20 dark:to-sky-900/20 border-cyan-200/60 dark:border-cyan-700/40"

        "amber" ->
          "from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 border-amber-200/60 dark:border-amber-700/40"

        "purple" ->
          "from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 border-purple-200/60 dark:border-purple-700/40"

        _ ->
          "from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700"
      end

    icon_color =
      case assigns.color do
        "blue" -> "text-blue-600 dark:text-blue-400"
        "emerald" -> "text-emerald-600 dark:text-emerald-400"
        "cyan" -> "text-cyan-600 dark:text-cyan-400"
        "amber" -> "text-amber-600 dark:text-amber-400"
        "purple" -> "text-purple-600 dark:text-purple-400"
        _ -> "text-slate-600 dark:text-slate-400"
      end

    assigns = assign(assigns, :color_classes, color_classes)
    assigns = assign(assigns, :icon_color, icon_color)

    ~H"""
    <DesignSystem.liquid_card class={"bg-gradient-to-br #{@color_classes}"}>
      <div class="flex items-start justify-between">
        <div>
          <p class="text-sm text-slate-600 dark:text-slate-400 mb-1">{@label}</p>
          <p class="text-2xl font-bold text-slate-900 dark:text-white">{@value}</p>
          <p :if={@subtitle} class="text-xs text-slate-500 dark:text-slate-400 mt-1">{@subtitle}</p>
        </div>
        <.phx_icon name={@icon} class={"h-6 w-6 #{@icon_color}"} />
      </div>
    </DesignSystem.liquid_card>
    """
  end

  attr :referrals, :list, required: true

  defp referrals_list(assigns) do
    ~H"""
    <div :if={@referrals != []}>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {gettext("Your Referrals")}
      </h3>
      <DesignSystem.liquid_card padding="none">
        <div class="divide-y divide-slate-200 dark:divide-slate-700">
          <div
            :for={referral <- @referrals}
            class="flex items-center justify-between px-6 py-4"
          >
            <div class="flex items-center gap-4">
              <div class={[
                "flex h-10 w-10 items-center justify-center rounded-full",
                referral_status_bg(referral_display_status(referral))
              ]}>
                <.phx_icon
                  name={referral_status_icon(referral_display_status(referral))}
                  class="h-5 w-5 text-white"
                />
              </div>
              <div>
                <p class="font-medium text-slate-900 dark:text-white">
                  {referral_display_name(referral)}
                </p>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  {gettext("Joined %{date}", date: format_date(referral.referred_at))}
                </p>
              </div>
            </div>
            <div class="text-right">
              <.referral_commission_display referral={referral} />
              <div class="flex items-center justify-end gap-2 mt-1">
                <.referral_type_badge :if={referral.status != "pending"} referral={referral} />
                <.referral_status_badge referral={referral} />
              </div>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>
      <p class="mt-3 text-xs text-slate-500 dark:text-slate-400">
        {gettext(
          "The first commission from each referral is held for 35 days to account for refunds. Subsequent payments are available immediately."
        )}
      </p>
    </div>
    """
  end

  defp referral_display_name(referral) do
    id_suffix = referral.id |> String.slice(-4, 4) |> String.upcase()
    gettext("Referral #%{id}", id: id_suffix)
  end

  attr :referral, :map, required: true

  defp referral_commission_display(assigns) do
    earned = earned_commissions(assigns.referral)
    pending = pending_commissions(assigns.referral)
    estimated = estimated_commission(assigns.referral)
    display_status = referral_display_status(assigns.referral)

    assigns =
      assigns
      |> assign(:earned, earned)
      |> assign(:pending, pending)
      |> assign(:estimated, estimated)
      |> assign(:display_status, display_status)

    ~H"""
    <div>
      <%= cond do %>
        <% @display_status == :awaiting_signup -> %>
          <p class="font-medium text-slate-500 dark:text-slate-400">
            {gettext("Awaiting signup")}
          </p>
        <% @display_status == :free_trial -> %>
          <p class="font-medium text-violet-600 dark:text-violet-400">
            {gettext("In free trial")}
          </p>
        <% @pending > 0 -> %>
          <p class="font-medium text-slate-900 dark:text-white">
            {format_currency(@earned)}
          </p>
          <p class="text-xs text-amber-600 dark:text-amber-400">
            {gettext("+%{amount} pending", amount: format_currency(@pending))}
          </p>
        <% @earned > 0 -> %>
          <p class="font-medium text-emerald-600 dark:text-emerald-400">
            {format_currency(@earned)}
          </p>
        <% true -> %>
          <p class="font-medium text-slate-500 dark:text-slate-400">
            {format_currency(0)}
          </p>
      <% end %>
    </div>
    """
  end

  defp earned_commissions(%{commissions: commissions}) when is_list(commissions) do
    Enum.reduce(commissions, 0, fn c, acc ->
      if c.status in ["available", "paid_out"], do: acc + c.commission_amount, else: acc
    end)
  end

  defp earned_commissions(_), do: 0

  defp pending_commissions(%{commissions: commissions}) when is_list(commissions) do
    Enum.reduce(commissions, 0, fn c, acc ->
      if c.status == "pending", do: acc + c.commission_amount, else: acc
    end)
  end

  defp pending_commissions(_), do: 0

  defp estimated_commission(%{commission_rate: rate}) when not is_nil(rate) do
    typical_monthly_amount = 1000

    rate
    |> Decimal.mult(typical_monthly_amount)
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  defp estimated_commission(_), do: 0

  defp referral_display_status(referral) do
    subscription = get_referral_subscription(referral)

    cond do
      referral.status in ["canceled", "expired"] ->
        String.to_existing_atom(referral.status)

      subscription && subscription.status == "trialing" ->
        :free_trial

      referral.status == "pending" ->
        :awaiting_signup

      has_commissions_past_hold?(referral) ->
        :active

      referral.status == "qualified" || has_pending_or_held_commissions?(referral) ->
        :pending_hold

      true ->
        :awaiting_signup
    end
  end

  defp get_referral_subscription(%{referred_user: %{customer: %{subscriptions: subscriptions}}})
       when is_list(subscriptions) and subscriptions != [] do
    active_statuses = ["active", "trialing", "past_due"]

    Enum.find(subscriptions, fn sub -> sub.status in active_statuses end) ||
      Enum.max_by(subscriptions, & &1.inserted_at, DateTime)
  end

  defp get_referral_subscription(_), do: nil

  defp has_commissions_past_hold?(%{commissions: commissions}) when is_list(commissions) do
    now = DateTime.utc_now()

    Enum.any?(commissions, fn c ->
      c.status in ["available", "paid_out"] and
        c.available_at != nil and
        DateTime.compare(c.available_at, now) == :lt
    end)
  end

  defp has_commissions_past_hold?(_), do: false

  defp has_pending_or_held_commissions?(%{commissions: commissions}) when is_list(commissions) do
    now = DateTime.utc_now()

    commissions != [] and
      Enum.all?(commissions, fn c ->
        c.status == "pending" or
          (c.available_at != nil and DateTime.compare(c.available_at, now) != :lt)
      end)
  end

  defp has_pending_or_held_commissions?(_), do: false

  defp referral_status_bg(:awaiting_signup), do: "bg-slate-400"
  defp referral_status_bg(:free_trial), do: "bg-violet-500"
  defp referral_status_bg(:pending_hold), do: "bg-amber-500"
  defp referral_status_bg(:active), do: "bg-emerald-500"
  defp referral_status_bg(:canceled), do: "bg-rose-500"
  defp referral_status_bg(:expired), do: "bg-slate-500"
  defp referral_status_bg(_), do: "bg-slate-500"

  defp referral_status_icon(:awaiting_signup), do: "hero-clock"
  defp referral_status_icon(:free_trial), do: "hero-sparkles"
  defp referral_status_icon(:pending_hold), do: "hero-clock"
  defp referral_status_icon(:active), do: "hero-check-badge"
  defp referral_status_icon(:canceled), do: "hero-x-mark"
  defp referral_status_icon(:expired), do: "hero-clock"
  defp referral_status_icon(_), do: "hero-question-mark-circle"

  attr :referral, :map, required: true

  defp referral_type_badge(assigns) do
    is_one_time = referral_is_one_time?(assigns.referral)
    billing_interval = get_billing_interval(assigns.referral)

    {bg, text, icon, label} =
      cond do
        is_one_time ->
          {"bg-cyan-100 dark:bg-cyan-900/30", "text-cyan-700 dark:text-cyan-300",
           "hero-shopping-bag-mini", gettext("Single payout")}

        billing_interval == :yearly ->
          {"bg-emerald-100 dark:bg-emerald-900/30", "text-emerald-700 dark:text-emerald-300",
           "hero-arrow-path-mini", gettext("Yearly")}

        true ->
          {"bg-emerald-100 dark:bg-emerald-900/30", "text-emerald-700 dark:text-emerald-300",
           "hero-arrow-path-mini", gettext("Monthly")}
      end

    assigns =
      assigns
      |> assign(:bg, bg)
      |> assign(:text, text)
      |> assign(:icon, icon)
      |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      <.phx_icon name={@icon} class="h-3 w-3" />
      {@label}
    </span>
    """
  end

  defp get_billing_interval(referral) do
    case get_referral_subscription(referral) do
      %{plan_id: plan_id} when is_binary(plan_id) ->
        if String.contains?(plan_id, "yearly"), do: :yearly, else: :monthly

      _ ->
        :monthly
    end
  end

  defp referral_is_one_time?(%{commissions: commissions}) when is_list(commissions) do
    commissions != [] and Enum.all?(commissions, &is_nil(&1.subscription_id))
  end

  defp referral_is_one_time?(_), do: false

  attr :referral, :map, required: true

  defp referral_status_badge(assigns) do
    display_status = referral_display_status(assigns.referral)

    {bg, text, label} =
      case display_status do
        :awaiting_signup ->
          {"bg-slate-100 dark:bg-slate-800", "text-slate-600 dark:text-slate-400",
           gettext("Awaiting signup")}

        :free_trial ->
          {"bg-violet-100 dark:bg-violet-900/30", "text-violet-700 dark:text-violet-300",
           gettext("Free trial")}

        :pending_hold ->
          {"bg-amber-100 dark:bg-amber-900/30", "text-amber-700 dark:text-amber-300",
           gettext("35-day hold")}

        :active ->
          {"bg-emerald-100 dark:bg-emerald-900/30", "text-emerald-700 dark:text-emerald-300",
           gettext("Active")}

        :canceled ->
          {"bg-rose-100 dark:bg-rose-900/30", "text-rose-700 dark:text-rose-300",
           gettext("Canceled")}

        :expired ->
          {"bg-slate-100 dark:bg-slate-800", "text-slate-600 dark:text-slate-400",
           gettext("Expired")}

        _ ->
          {"bg-slate-100 dark:bg-slate-800", "text-slate-600 dark:text-slate-400",
           to_string(display_status)}
      end

    assigns =
      assigns
      |> assign(:bg, bg)
      |> assign(:text, text)
      |> assign(:label, label)

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      {@label}
    </span>
    """
  end

  attr :connect_status, :atom, required: true
  attr :stats, :map, required: true

  defp payout_setup_card(assigns) do
    min_payout = Referrals.min_payout_cents()
    available = assigns.stats.available_for_payout
    next_payout_date = next_payout_date()
    eligible_for_payout = available >= min_payout

    assigns =
      assigns
      |> assign(:min_payout, min_payout)
      |> assign(:available, available)
      |> assign(:next_payout_date, next_payout_date)
      |> assign(:eligible_for_payout, eligible_for_payout)

    ~H"""
    <DesignSystem.liquid_card>
      <div class="flex flex-col md:flex-row md:items-center gap-6">
        <div class="flex-shrink-0">
          <div class={[
            "flex h-12 w-12 items-center justify-center rounded-xl",
            if(@connect_status == :enabled,
              do: "bg-emerald-100 dark:bg-emerald-900/30",
              else: "bg-slate-100 dark:bg-slate-800"
            )
          ]}>
            <.phx_icon
              name={if @connect_status == :enabled, do: "hero-check-badge", else: "hero-credit-card"}
              class={[
                "h-6 w-6",
                if(@connect_status == :enabled,
                  do: "text-emerald-600 dark:text-emerald-400",
                  else: "text-slate-600 dark:text-slate-400"
                )
              ]}
            />
          </div>
        </div>
        <div class="flex-1">
          <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-1">
            <%= case @connect_status do %>
              <% :enabled -> %>
                {gettext("Stripe Payouts Enabled")}
              <% :pending -> %>
                {gettext("Payout Setup Pending")}
              <% :in_progress -> %>
                {gettext("Complete Payout Setup")}
              <% :not_started -> %>
                {gettext("Set Up Automatic Payouts")}
            <% end %>
          </h3>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            <%= case @connect_status do %>
              <% :enabled -> %>
                {gettext(
                  "Your Stripe account is connected. Earnings are deposited monthly when you reach $15. Completed payouts will appear in your Stripe dashboard."
                )}
              <% :pending -> %>
                {gettext("Stripe is verifying your account. This usually takes 1-2 business days.")}
              <% _ -> %>
                {gettext("Connect your bank account to receive automatic monthly payouts via Stripe.")}
            <% end %>
          </p>
        </div>
        <div class="flex-shrink-0">
          <%= case @connect_status do %>
            <% :enabled -> %>
              <div class="flex flex-col items-end gap-2">
                <DesignSystem.liquid_button
                  type="button"
                  variant="secondary"
                  icon="hero-arrow-top-right-on-square"
                  phx-click="open_stripe_dashboard"
                >
                  {gettext("Stripe Dashboard")}
                </DesignSystem.liquid_button>
                <p class="text-xs text-slate-500 dark:text-slate-400 text-right">
                  {gettext("View payout history")}
                </p>
              </div>
            <% :not_started -> %>
              <DesignSystem.liquid_button
                type="button"
                variant="primary"
                icon="hero-arrow-right"
                phx-click="start_connect_onboarding"
              >
                {gettext("Set Up Payouts")}
              </DesignSystem.liquid_button>
            <% _ -> %>
              <DesignSystem.liquid_button
                type="button"
                variant="primary"
                icon="hero-arrow-right"
                phx-click="continue_connect_onboarding"
              >
                {gettext("Continue Setup")}
              </DesignSystem.liquid_button>
          <% end %>
        </div>
      </div>

      <div
        :if={@connect_status == :enabled && @available > 0}
        class="mt-6 pt-6 border-t border-slate-200 dark:border-slate-700"
      >
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-lg bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200 dark:border-emerald-700">
          <div class="flex items-center gap-3">
            <div class="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/40">
              <.phx_icon name="hero-calendar" class="h-5 w-5 text-emerald-600 dark:text-emerald-400" />
            </div>
            <div>
              <p class="text-sm font-medium text-emerald-800 dark:text-emerald-200">
                {gettext("Next Payout")}
              </p>
              <p class="text-xs text-emerald-600 dark:text-emerald-400">
                {@next_payout_date}
              </p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-2xl font-bold text-emerald-700 dark:text-emerald-300">
              {format_currency(@available)}
            </p>
            <%= if @eligible_for_payout do %>
              <p class="text-xs text-emerald-600 dark:text-emerald-400">
                {gettext("Ready for payout")}
              </p>
            <% else %>
              <p class="text-xs text-amber-600 dark:text-amber-400">
                {gettext("$%{remaining} more to reach minimum",
                  remaining: Float.round((@min_payout - @available) / 100, 2)
                )}
              </p>
            <% end %>
          </div>
        </div>
      </div>

      <details
        :if={@connect_status != :enabled}
        class="group mt-6 pt-6 border-t border-slate-200 dark:border-slate-700"
      >
        <summary class="flex items-center gap-2 cursor-pointer text-sm font-medium text-slate-700 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white select-none list-none [&::-webkit-details-marker]:hidden">
          <.phx_icon
            name="hero-chevron-right"
            class="h-4 w-4 transition-transform duration-200 group-open:rotate-90"
          />
          <.phx_icon name="hero-question-mark-circle" class="h-4 w-4" />
          {gettext("Tips for setting up your Stripe account")}
        </summary>
        <div class="mt-4 space-y-4 text-sm text-slate-600 dark:text-slate-400">
          <div class="p-4 rounded-lg bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800">
            <p class="font-medium text-blue-800 dark:text-blue-200 mb-2">
              <.phx_icon name="hero-user" class="h-4 w-4 inline mr-1" />
              {gettext("Choosing \"Individual\" account type")}
            </p>
            <p class="text-blue-700 dark:text-blue-300">
              {gettext(
                "If you're not a registered business, select \"Individual\" when prompted. This is the simplest option for personal referral earnings."
              )}
            </p>
          </div>

          <div class="p-4 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800">
            <p class="font-medium text-amber-800 dark:text-amber-200 mb-2">
              <.phx_icon name="hero-globe-alt" class="h-4 w-4 inline mr-1" />
              {gettext("Website or product description")}
            </p>
            <p class="text-amber-700 dark:text-amber-300 mb-2">
              {gettext("When asked for a website, you can enter:")}
            </p>
            <code class="block px-3 py-2 rounded bg-amber-100 dark:bg-amber-900/40 text-amber-900 dark:text-amber-100 font-mono text-xs">
              mosslet.com
            </code>
            <p class="text-amber-700 dark:text-amber-300 mt-2">
              {gettext(
                "For product description, you can write something like: \"Referral commissions from MOSSLET, a private social platform.\""
              )}
            </p>
          </div>

          <div class="p-4 rounded-lg bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-200 dark:border-emerald-800">
            <p class="font-medium text-emerald-800 dark:text-emerald-200 mb-2">
              <.phx_icon name="hero-banknotes" class="h-4 w-4 inline mr-1" />
              {gettext("Bank account details")}
            </p>
            <p class="text-emerald-700 dark:text-emerald-300">
              {gettext(
                "Have your bank account and routing numbers ready. Stripe will deposit your earnings directly to this account."
              )}
            </p>
          </div>
        </div>
      </details>
    </DesignSystem.liquid_card>
    """
  end

  attr :payouts, :list, required: true

  defp payouts_history(assigns) do
    ~H"""
    <div :if={@payouts != []}>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {gettext("Payout History")}
      </h3>
      <DesignSystem.liquid_card padding="none">
        <div class="divide-y divide-slate-200 dark:divide-slate-700">
          <div
            :for={payout <- @payouts}
            class="flex items-center justify-between px-6 py-4"
          >
            <div class="flex items-center gap-4">
              <div class={[
                "flex h-10 w-10 items-center justify-center rounded-full",
                payout_status_bg(payout.status)
              ]}>
                <.phx_icon name={payout_status_icon(payout.status)} class="h-5 w-5 text-white" />
              </div>
              <div>
                <p class="font-medium text-slate-900 dark:text-white">
                  {format_currency(payout.amount)}
                </p>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  {format_date(payout.period_start)} - {format_date(payout.period_end)}
                </p>
              </div>
            </div>
            <.payout_status_badge status={payout.status} />
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  attr :status, :string, required: true

  defp payout_status_badge(assigns) do
    {bg, text} =
      case assigns.status do
        "completed" ->
          {"bg-emerald-100 dark:bg-emerald-900/30", "text-emerald-700 dark:text-emerald-300"}

        "processing" ->
          {"bg-blue-100 dark:bg-blue-900/30", "text-blue-700 dark:text-blue-300"}

        "pending" ->
          {"bg-amber-100 dark:bg-amber-900/30", "text-amber-700 dark:text-amber-300"}

        "failed" ->
          {"bg-rose-100 dark:bg-rose-900/30", "text-rose-700 dark:text-rose-300"}

        _ ->
          {"bg-slate-100 dark:bg-slate-800", "text-slate-600 dark:text-slate-400"}
      end

    assigns = assign(assigns, :bg, bg)
    assigns = assign(assigns, :text, text)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@bg} #{@text}"}>
      {String.capitalize(@status)}
    </span>
    """
  end

  defp payout_status_bg("completed"), do: "bg-emerald-500"
  defp payout_status_bg("processing"), do: "bg-blue-500"
  defp payout_status_bg("pending"), do: "bg-amber-500"
  defp payout_status_bg("failed"), do: "bg-rose-500"
  defp payout_status_bg(_), do: "bg-slate-500"

  defp payout_status_icon("completed"), do: "hero-check"
  defp payout_status_icon("processing"), do: "hero-arrow-path"
  defp payout_status_icon("pending"), do: "hero-clock"
  defp payout_status_icon("failed"), do: "hero-x-mark"
  defp payout_status_icon(_), do: "hero-question-mark-circle"

  defp program_details(assigns) do
    commission = Decimal.mult(Referrals.commission_rate(), 100) |> Decimal.to_integer()

    one_time_commission =
      Decimal.mult(Referrals.one_time_commission_rate(), 100) |> Decimal.to_integer()

    discount = Referrals.referee_discount_percent()
    min_payout = Referrals.min_payout_cents() / 100

    assigns =
      assigns
      |> assign(:commission, commission)
      |> assign(:one_time_commission, one_time_commission)
      |> assign(:discount, discount)
      |> assign(:min_payout, min_payout)
      |> assign(:beta_mode, Referrals.beta_mode?())

    ~H"""
    <DesignSystem.liquid_card>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
        {gettext("How It Works")}
      </h3>
      <div class="space-y-4">
        <div
          :if={@beta_mode}
          class="p-3 rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700"
        >
          <div class="flex items-center gap-2">
            <.phx_icon name="hero-sparkles" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
            <span class="text-sm font-medium text-amber-800 dark:text-amber-200">
              {gettext("Beta Bonus: Enhanced rates for early supporters!")}
            </span>
          </div>
        </div>

        <div class="grid md:grid-cols-3 gap-6">
          <div class="flex gap-3">
            <div class="flex-shrink-0">
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 font-bold text-sm">
                1
              </div>
            </div>
            <div>
              <p class="font-medium text-slate-900 dark:text-white">{gettext("Share Your Link")}</p>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {gettext("Send your unique referral link to friends")}
              </p>
            </div>
          </div>

          <div class="flex gap-3">
            <div class="flex-shrink-0">
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 font-bold text-sm">
                2
              </div>
            </div>
            <div>
              <p class="font-medium text-slate-900 dark:text-white">
                {gettext("They Save %{discount}%", discount: @discount)}
              </p>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {gettext("Your friends get %{discount}% off their first payment",
                  discount: @discount
                )}
              </p>
            </div>
          </div>

          <div class="flex gap-3">
            <div class="flex-shrink-0">
              <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 font-bold text-sm">
                3
              </div>
            </div>
            <div>
              <p class="font-medium text-slate-900 dark:text-white">
                {gettext("You Earn %{commission}%", commission: @commission)}
              </p>
              <p class="text-sm text-slate-600 dark:text-slate-400">
                {gettext("Earn %{commission}% of subscriptions & %{one_time}% of one-time payments",
                  commission: @commission,
                  one_time: @one_time_commission
                )}
              </p>
            </div>
          </div>
        </div>

        <p class="text-xs text-slate-500 dark:text-slate-400 pt-4 border-t border-slate-200 dark:border-slate-700">
          {gettext(
            "First commission from each referral is held for 35 days to account for refunds. Subsequent payments are available immediately. Payouts are processed monthly when your balance reaches $%{min}.",
            min: trunc(@min_payout)
          )}
        </p>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  defp not_eligible_notice(assigns) do
    ~H"""
    <DesignSystem.liquid_card class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700">
      <div class="text-center py-8">
        <div class="flex h-16 w-16 items-center justify-center rounded-full bg-slate-200 dark:bg-slate-600 mx-auto mb-4">
          <.phx_icon name="hero-banknotes" class="h-8 w-8 text-slate-500 dark:text-slate-400" />
        </div>
        <h2 class="text-xl font-semibold text-slate-900 dark:text-white mb-2">
          {gettext("Referral Program")}
        </h2>
        <p class="text-slate-600 dark:text-slate-400 max-w-md mx-auto mb-6">
          {gettext(
            "The referral program is available to active subscribers. Subscribe to start earning by referring friends!"
          )}
        </p>
        <DesignSystem.liquid_button
          href={~p"/app/subscribe"}
          variant="primary"
          icon="hero-arrow-right"
        >
          {gettext("View Plans")}
        </DesignSystem.liquid_button>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  defp free_trial_notice(assigns) do
    commission = Decimal.mult(Referrals.commission_rate(), 100) |> Decimal.to_integer()

    one_time_commission =
      Decimal.mult(Referrals.one_time_commission_rate(), 100) |> Decimal.to_integer()

    discount = Referrals.referee_discount_percent()

    assigns =
      assigns
      |> assign(:commission, commission)
      |> assign(:one_time_commission, one_time_commission)
      |> assign(:discount, discount)

    ~H"""
    <div class="space-y-8">
      <DesignSystem.liquid_card class="bg-gradient-to-br from-violet-50/80 to-purple-50/60 dark:from-violet-900/30 dark:to-purple-900/20 border-violet-200/60 dark:border-violet-700/40">
        <div class="flex items-start gap-4">
          <div class="flex-shrink-0">
            <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-purple-500 shadow-lg shadow-violet-500/25">
              <.phx_icon name="hero-sparkles" class="h-6 w-6 text-white" />
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <h2 class="text-lg font-semibold text-violet-800 dark:text-violet-200">
              {gettext("Free Trial Active")}
            </h2>
            <p class="mt-1 text-sm text-violet-700 dark:text-violet-300">
              {gettext(
                "You're currently enjoying your free trial of MOSSLET. Once your trial ends and you become a paid member, you'll unlock the referral program!"
              )}
            </p>
            <div class="mt-4">
              <DesignSystem.liquid_button
                href={~p"/app/billing"}
                size="sm"
                variant="secondary"
                color="purple"
                icon="hero-cog-6-tooth"
              >
                {gettext("Manage Billing")}
              </DesignSystem.liquid_button>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>

      <DesignSystem.liquid_card>
        <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-4">
          {gettext("🎁 What You'll Unlock")}
        </h3>
        <div class="space-y-4">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {gettext("Once you become a paid member, you'll get access to our referral program:")}
          </p>

          <div class="grid md:grid-cols-3 gap-6">
            <div class="flex gap-3">
              <div class="flex-shrink-0">
                <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400">
                  <.phx_icon name="hero-link" class="h-4 w-4" />
                </div>
              </div>
              <div>
                <p class="font-medium text-slate-900 dark:text-white">
                  {gettext("Unique Referral Link")}
                </p>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  {gettext("Share with friends and family")}
                </p>
              </div>
            </div>

            <div class="flex gap-3">
              <div class="flex-shrink-0">
                <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400">
                  <.phx_icon name="hero-gift" class="h-4 w-4" />
                </div>
              </div>
              <div>
                <p class="font-medium text-slate-900 dark:text-white">
                  {gettext("They Save %{discount}%", discount: @discount)}
                </p>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  {gettext("Your friends get a discount")}
                </p>
              </div>
            </div>

            <div class="flex gap-3">
              <div class="flex-shrink-0">
                <div class="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400">
                  <.phx_icon name="hero-currency-dollar" class="h-4 w-4" />
                </div>
              </div>
              <div>
                <p class="font-medium text-slate-900 dark:text-white">
                  {gettext("You Earn %{commission}%", commission: @commission)}
                </p>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  {gettext("Lifetime revenue sharing")}
                </p>
              </div>
            </div>
          </div>

          <p class="text-xs text-slate-500 dark:text-slate-400 pt-4 border-t border-slate-200 dark:border-slate-700">
            {gettext(
              "Earn %{commission}% of every subscription payment and %{one_time}% of one-time purchases from your referrals—for life! Payouts are processed monthly via Stripe.",
              commission: @commission,
              one_time: @one_time_commission
            )}
          </p>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  @impl true
  def handle_event("copy_link", _params, socket) do
    {:noreply, put_flash(socket, :info, gettext("Referral link copied to clipboard!"))}
  end

  def handle_event("start_connect_onboarding", _params, socket) do
    user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key
    referral_code = socket.assigns.referral_code

    case StripeConnect.create_connect_account(referral_code, user, session_key) do
      {:ok, _account} ->
        case StripeConnect.create_account_link(referral_code, user, session_key) do
          {:ok, url} ->
            {:noreply, redirect(socket, external: url)}

          {:error, _} ->
            {:noreply,
             put_flash(socket, :error, gettext("Failed to create setup link. Please try again."))}
        end

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Failed to set up payouts. Please try again."))}
    end
  end

  def handle_event("continue_connect_onboarding", _params, socket) do
    user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key
    referral_code = socket.assigns.referral_code

    case StripeConnect.create_account_link(referral_code, user, session_key) do
      {:ok, url} ->
        {:noreply, redirect(socket, external: url)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, gettext("Failed to create setup link. Please try again."))}
    end
  end

  def handle_event("open_stripe_dashboard", _params, socket) do
    user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key
    referral_code = socket.assigns.referral_code

    case StripeConnect.create_login_link(referral_code, user, session_key) do
      {:ok, url} ->
        {:noreply, push_event(socket, "open_external_url", %{url: url})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to open Stripe dashboard."))}
    end
  end

  @impl true
  def handle_info({:referral_updated, _payload}, socket) do
    {:noreply, refresh_data(socket)}
  end

  def handle_info(:refresh_data, socket) do
    schedule_refresh()
    {:noreply, refresh_data(socket)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp refresh_data(socket) do
    user = socket.assigns.current_scope.user
    referral_code = socket.assigns.referral_code

    stats = Referrals.get_stats(user.id)
    referrals = Referrals.list_referrals_with_commissions(referral_code.id)
    payouts = Referrals.list_payouts(referral_code.id)

    socket
    |> assign(:stats, stats)
    |> assign(:referrals, referrals)
    |> assign(:payouts, payouts)
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_data, @refresh_interval)
  end

  defp format_currency(cents) when is_integer(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp format_currency(_), do: "$0.00"

  defp format_date(nil), do: "-"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y")
  end

  defp next_payout_date do
    today = Date.utc_today()
    first_of_next_month = Date.new!(today.year, today.month, 1) |> Date.add(32)
    first_of_next_month = Date.new!(first_of_next_month.year, first_of_next_month.month, 1)
    Calendar.strftime(first_of_next_month, "%B %d, %Y")
  end

  defp user_in_free_trial?(user) do
    case user do
      %{customer: %{id: customer_id}} when not is_nil(customer_id) ->
        case Subscriptions.get_active_subscription_by_customer_id(customer_id) do
          %{status: "trialing"} -> true
          _ -> false
        end

      _ ->
        false
    end
  end
end
