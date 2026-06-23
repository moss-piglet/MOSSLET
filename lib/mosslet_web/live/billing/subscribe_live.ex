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
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, session, socket) do
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

    families = build_families(subscription_products)

    socket =
      socket
      |> assign(:page_title, gettext("Pricing"))
      |> assign(:source, socket.assigns.live_action)
      |> assign(:current_membership, socket.assigns[:current_membership])
      |> assign(:products, products)
      |> assign(:one_time_products, one_time_products)
      |> assign(:subscription_products, subscription_products)
      |> assign(:referral_discount, referral_discount)
      |> assign(:families, families)
      |> assign(:plan_intent, session_plan_intent(session))
      |> assign(:selected_family, nil)
      |> assign(:selected_interval, session_plan_interval(session))
      |> assign(:org_onramp, nil)
      |> assign(:org_name_form, to_form(%{"name" => ""}, as: :org))

    socket = assign_billing_status(socket)

    {:ok, socket}
  end

  # Plan-aware signup intent persisted at sign-in (UserAuth.maybe_put_plan_intent),
  # used as a fallback when no explicit `?plan=` is present in the URL (Task #215).
  defp session_plan_intent(%{"plan_intent" => plan}) when plan in ~w(personal family business),
    do: plan

  defp session_plan_intent(_), do: nil

  # Billing interval (monthly/yearly) preserved from the pricing page through
  # sign-in, used as the default when no explicit `?billing=` is present (#215).
  defp session_plan_interval(%{"plan_interval" => b}) when b in ~w(month year), do: b
  defp session_plan_interval(_), do: "year"

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
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> maybe_assign_org(params)
      |> resolve_selection(params)

    {:noreply, socket}
  end

  # Same-session abandonment reclaim (Task #236, Trigger 1).
  #
  # The owner of a freshly-created INERT org sits in THIS LiveView (source: :org,
  # current_org = the inert org) for the entire pre-activation window. When this
  # process terminates — tab close, navigate away, socket drop — we enqueue a
  # short-delayed, targeted reclaim job for that org. The job re-validates state
  # at run time, so:
  #
  #   * leaving WITHOUT activating  -> the org is still inert -> name freed
  #   * navigating TO checkout      -> brief teardown, but the org activates
  #                                    within the grace window -> job no-ops
  #
  # We only enqueue for an org that is STILL inert (`:pending`) right now, so an
  # already-active/trialing org never schedules a needless job. ZK-safe: only the
  # org id (UUID) leaves this process.
  @impl true
  def terminate(_reason, %{assigns: %{source: :org, current_org: %Mosslet.Orgs.Org{} = org}}) do
    if Mosslet.Orgs.org_reclaim_state(org) == :pending do
      Mosslet.Orgs.Jobs.OrgNameReclaimJob.schedule_session_end_reclaim(org.id)
    end

    :ok
  end

  def terminate(_reason, _socket), do: :ok

  # Resolve which plan family + billing interval to show. Priority for family:
  # explicit `?plan=` > persisted signup intent > existing selection > default.
  # The interval comes from `?billing=monthly|yearly`, defaulting to yearly
  # (our best value). For the org-scoped source the family is fixed by the org's
  # type, so the switcher is hidden and we just resolve the interval.
  defp resolve_selection(socket, params) do
    interval =
      billing_param(params) ||
        current_billing_interval(socket) ||
        socket.assigns.selected_interval

    family =
      case socket.assigns.source do
        :org ->
          org_family(socket)

        _ ->
          plan_param(params) ||
            family_from_intent(socket.assigns.plan_intent) ||
            socket.assigns.selected_family ||
            default_family(socket.assigns.families)
      end

    socket
    |> assign(:selected_family, family)
    |> assign(:selected_interval, interval)
    |> assign_org_onramp(family)
  end

  # When the org already has an active/trialing subscription, default the
  # interval tab to MATCH that subscription's billing interval (so a yearly
  # trial opens on the yearly tab, a monthly on monthly). Only used when the URL
  # carries no explicit `?billing=`. Returns "month"/"year" or nil.
  defp current_billing_interval(%{assigns: %{current_subscription: %{plan_id: plan_id}}})
       when is_binary(plan_id) do
    case Plans.get_plan_by_id(plan_id) do
      %{interval: :month} -> "month"
      %{interval: :year} -> "year"
      _ -> nil
    end
  end

  defp current_billing_interval(_socket), do: nil

  # Filters subscription products to a single family (e.g. "Business") + billing
  # interval ("month"/"year"). Used to scope the pricing grid to one plan.
  defp filter_products_by_family_interval(products, family, interval) do
    Enum.filter(products, fn product ->
      item = List.first(product.line_items)

      short_name(product.name) == family &&
        item && to_string(item.interval) == interval
    end)
  end

  # On the `:user`-source subscribe page the Family/Business tabs are NOT
  # `:user` purchases — they are ORG on-ramps (Option B, Task #235). For those
  # tabs we resolve whether the user ALREADY owns an active org of that type (so
  # we can deep-link straight there) or needs to name + create an inert org
  # first. Personal stays a `:user` purchase, so it carries no on-ramp.
  defp assign_org_onramp(%{assigns: %{source: :user}} = socket, family)
       when family in ["Family", "Business"] do
    type = family_to_type(family)
    existing = Mosslet.Orgs.resumable_org_of_type(socket.assigns.current_user, type)
    existing_active? = existing != nil and Mosslet.Orgs.org_active?(existing)

    product =
      family_product(
        socket.assigns.subscription_products,
        family,
        socket.assigns.selected_interval
      )

    socket
    |> assign(:org_onramp, %{
      type: type,
      family: family,
      existing_org: existing,
      existing_active?: existing_active?,
      product: product
    })
    |> assign_new(:org_name_form, fn -> to_form(%{"name" => ""}, as: :org) end)
  end

  defp assign_org_onramp(socket, _family), do: assign(socket, :org_onramp, nil)

  defp family_to_type("Business"), do: :business
  defp family_to_type(_), do: :family

  # Pick a representative product for the family to surface an indicative
  # "from" price on the org on-ramp card. We honor the interval the user picked
  # on /pricing (`?billing=`, defaulting to yearly — our best value) so the card
  # reflects their choice; the binding monthly vs yearly selection is still
  # confirmed on the org's own subscribe page (Option B, Task #235). Falls back
  # to monthly, then any product, if the chosen interval has no line item.
  defp family_product(subscription_products, family, interval) do
    products =
      Enum.filter(subscription_products, fn product ->
        short_name(product.name) == family
      end)

    by_interval = fn wanted ->
      Enum.find(products, fn product ->
        item = List.first(product.line_items)
        item && to_string(item.interval) == wanted
      end)
    end

    by_interval.(interval) || by_interval.("month") || List.first(products)
  end

  defp billing_param(%{"billing" => b}) when b in ~w(month monthly), do: "month"
  defp billing_param(%{"billing" => b}) when b in ~w(year yearly annual), do: "year"
  defp billing_param(_), do: nil

  defp plan_param(%{"plan" => "family"}), do: "Family"
  defp plan_param(%{"plan" => "business"}), do: "Business"
  defp plan_param(%{"plan" => "personal"}), do: "Personal"
  defp plan_param(_), do: nil

  defp family_from_intent("family"), do: "Family"
  defp family_from_intent("business"), do: "Business"
  defp family_from_intent("personal"), do: "Personal"
  defp family_from_intent(_), do: nil

  defp org_family(socket) do
    case socket.assigns[:current_org] do
      %Mosslet.Orgs.Org{type: :business} -> "Business"
      %Mosslet.Orgs.Org{type: :family} -> "Family"
      _ -> nil
    end
  end

  # For the org-scoped subscribe route (/app/org/:org_slug/subscribe), load the
  # org from the slug so checkout + customer lookups tie to the real org (Task
  # #214). Membership is enforced by Orgs.get_org!/2 (scoped to the user).
  defp maybe_assign_org(%{assigns: %{source: :org}} = socket, %{"org_slug" => org_slug}) do
    current_user = socket.assigns.current_user

    case Mosslet.Orgs.get_org!(current_user, org_slug) do
      %Mosslet.Orgs.Org{} = org ->
        socket
        |> assign(:current_org, org)
        |> assign_billing_status()

      _ ->
        socket
    end
  rescue
    Ecto.NoResultsError ->
      socket
      |> put_flash(:error, gettext("Organization not found."))
      |> push_navigate(to: ~p"/app/business")
  end

  defp maybe_assign_org(socket, _params), do: socket

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
          <.confirm_email_banner :if={is_nil(@current_user.confirmed_at)} />

          <.referral_banner :if={@referral_discount} discount={@referral_discount} />

          <%= if @source == :user do %>
            <.plan_switcher
              families={@families}
              selected_family={@selected_family}
              selected_interval={@selected_interval}
              show_interval={@org_onramp == nil}
            />

            <%= if @org_onramp do %>
              <.org_onramp_card
                onramp={@org_onramp}
                org_name_form={@org_name_form}
                selected_interval={@selected_interval}
              />
            <% else %>
              <.active_billing_notice
                :if={@has_active_billing}
                current_payment_intent={@current_payment_intent}
                current_subscription={@current_subscription}
                source={@source}
                org_slug={assigns[:current_org] && @current_org.slug}
              />

              <.pricing_cards
                one_time_products={@one_time_products}
                subscription_products={@subscription_products}
                current_payment_intent={@current_payment_intent}
                current_subscription={@current_subscription}
                has_active_billing={@has_active_billing}
                source={@source}
                referral_discount={@referral_discount}
                selected_family={@selected_family}
                selected_interval={@selected_interval}
              />
            <% end %>
          <% else %>
            <.active_billing_notice
              :if={@has_active_billing}
              current_payment_intent={@current_payment_intent}
              current_subscription={@current_subscription}
              source={@source}
              org_slug={assigns[:current_org] && @current_org.slug}
            />

            <.interval_switcher
              selected_interval={@selected_interval}
              source={@source}
            />

            <.pricing_cards
              one_time_products={@one_time_products}
              subscription_products={@subscription_products}
              current_payment_intent={@current_payment_intent}
              current_subscription={@current_subscription}
              has_active_billing={@has_active_billing}
              source={@source}
              referral_discount={@referral_discount}
              selected_family={@selected_family}
              selected_interval={@selected_interval}
            />
          <% end %>
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

  # Friendly, non-blocking reminder shown to users who haven't confirmed their
  # email yet. They can still pick a plan; confirmation is required before
  # sensitive actions (Task #215).
  defp confirm_email_banner(assigns) do
    ~H"""
    <div class="mb-10 max-w-2xl mx-auto">
      <div class="p-4 rounded-xl bg-gradient-to-r from-sky-50 to-cyan-50 dark:from-sky-900/20 dark:to-cyan-900/20 border border-sky-200/60 dark:border-sky-700/40">
        <div class="flex items-start gap-3">
          <div class="flex-shrink-0 mt-0.5">
            <.phx_icon name="hero-envelope" class="w-5 h-5 text-sky-600 dark:text-sky-400" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-semibold text-sky-800 dark:text-sky-200">
              {gettext("Confirm your email to get started")}
            </p>
            <p class="mt-0.5 text-sm text-sky-700 dark:text-sky-300">
              {gettext(
                "You can explore plans now, but you'll need to confirm your email before starting a trial or creating your space. We've sent a confirmation link to your inbox—it only takes a moment."
              )}
            </p>
            <.link
              navigate={~p"/auth/confirm"}
              class="mt-2 inline-flex items-center gap-1.5 text-sm font-medium text-sky-700 hover:text-sky-900 dark:text-sky-300 dark:hover:text-sky-100 transition-colors"
            >
              <.phx_icon name="hero-paper-airplane" class="w-4 h-4" />
              {gettext("Resend confirmation email")}
            </.link>
          </div>
        </div>
      </div>
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

  attr :org_slug, :string,
    default: nil,
    doc: "the org slug, required when source is :org so the Manage Billing link resolves"

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
                href={manage_billing_href(@source, @org_slug)}
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

  # Manage-billing destination for the active-billing notice. Built directly from
  # the source + slug (rather than BillingLive.billing_path/2, which expects full
  # assigns) so the org case resolves to the org-scoped billing page. Falls back
  # to personal billing when the org slug is unavailable.
  defp manage_billing_href(:org, slug) when is_binary(slug), do: ~p"/app/org/#{slug}/billing"
  defp manage_billing_href(_source, _slug), do: ~p"/app/billing"

  attr :families, :list, required: true
  attr :selected_family, :string, default: nil
  attr :selected_interval, :string, default: "year"
  attr :show_interval, :boolean, default: true

  # Plan-family tab switcher (Personal / Family / Business) + billing interval
  # toggle, mirroring the marketing /pricing page so the in-app picker feels
  # like a continuation rather than a second round (Task #215). On the Family /
  # Business tabs the interval toggle is hidden because those tabs are org
  # on-ramps — the billing interval is chosen on the org's own subscribe page
  # once the org exists (Option B, Task #235).
  defp plan_switcher(assigns) do
    ~H"""
    <div :if={length(@families) > 1} class="mx-auto max-w-3xl mb-10">
      <div class="flex justify-center">
        <div
          role="tablist"
          aria-label={gettext("Plan types")}
          class="flex w-full max-w-md sm:w-auto sm:max-w-none items-center gap-1 rounded-2xl border border-slate-200/70 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/60 backdrop-blur-sm p-1.5 shadow-sm"
        >
          <button
            :for={family <- @families}
            type="button"
            role="tab"
            id={"family-tab-#{family.key}"}
            aria-selected={to_string(family.key == @selected_family)}
            phx-click="select_family"
            phx-value-family={family.key}
            class={[
              "group relative flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition-all duration-200 ease-out transform-gpu focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500/50",
              if(family.key == @selected_family,
                do:
                  "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg shadow-emerald-500/25",
                else:
                  "text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100/70 dark:hover:bg-slate-700/50"
              )
            ]}
          >
            <.phx_icon name={family.icon} class="h-4 w-4" />
            <span>{family.label}</span>
          </button>
        </div>
      </div>

      <.interval_toggle :if={@show_interval} selected_interval={@selected_interval} class="mt-6" />
    </div>
    """
  end

  attr :selected_interval, :string, default: "year"
  attr :source, :atom, required: true

  # Org-scoped subscribe shows just the billing-interval toggle (family is fixed
  # by the org's type).
  defp interval_switcher(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl mb-10">
      <.interval_toggle selected_interval={@selected_interval} class="" />
    </div>
    """
  end

  attr :onramp, :map, required: true
  attr :org_name_form, :any, required: true
  attr :selected_interval, :string, default: "year"

  # Org on-ramp card shown on the `:user`-source subscribe page when the
  # Family / Business tab is selected (Option B, Task #235). These tabs do NOT
  # sell a `:user` plan. Instead:
  #
  #   * If the user already has an ACTIVE org of that type, we deep-link them to
  #     that org's subscribe/manage surface instead of offering a duplicate.
  #   * Otherwise we capture an org name inline, create an INERT org, and route
  #     to /app/org/:slug/subscribe where the `:org` trial actually begins.
  defp org_onramp_card(assigns) do
    onramp = assigns.onramp
    item = onramp.product && List.first(onramp.product.line_items)

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:included_seats, (item && Plans.included_seats(item)) || nil)
      |> assign(:features, (onramp.product && onramp.product.features) || [])
      |> assign(:label, family_meta(onramp.family).label)
      |> assign(:icon, family_meta(onramp.family).icon)
      |> assign(:type_label, String.downcase(family_meta(onramp.family).label))

    ~H"""
    <div class="mx-auto max-w-md">
      <DesignSystem.liquid_card
        padding="lg"
        class="relative overflow-hidden ring-2 ring-emerald-500 dark:ring-emerald-400 shadow-2xl shadow-emerald-500/20"
      >
        <div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-emerald-200/30 via-teal-200/20 to-transparent dark:from-emerald-500/10 dark:via-teal-500/5 rounded-bl-full pointer-events-none">
        </div>

        <div class="relative">
          <div class="flex items-center gap-3 mb-4">
            <div class="flex items-center justify-center w-12 h-12 rounded-xl bg-gradient-to-br from-teal-500 to-emerald-500 shadow-lg shadow-emerald-500/30">
              <.phx_icon name={@icon} class="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                {gettext("%{label} plan", label: @label)}
              </h2>
              <p class="text-sm text-emerald-600 dark:text-emerald-400 font-medium">
                {gettext("Billed to your %{type}, not your personal account",
                  type: @type_label
                )}
              </p>
            </div>
          </div>

          <div :if={@item} class="mb-6">
            <p class="text-xs font-medium uppercase tracking-wide text-slate-400 dark:text-slate-500 mb-1">
              {gettext("Starting at")}
            </p>
            <div class="flex items-baseline gap-2">
              <span class="text-4xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
                {Util.format_money(@item.amount)}
              </span>
              <span class="text-base font-medium text-slate-600 dark:text-slate-400">
                <%= if @item.interval == :year do %>
                  {gettext("/year")}
                <% else %>
                  {gettext("/month")}
                <% end %>
              </span>
            </div>
            <p :if={@included_seats} class="mt-1 text-sm text-slate-500 dark:text-slate-400">
              {gettext("Includes %{count} members—add more anytime.", count: @included_seats)}
            </p>
            <p class="mt-2 inline-flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
              <.phx_icon name="hero-information-circle" class="size-3.5 text-emerald-500" />
              {gettext("Choose monthly or yearly billing on the next step.")}
            </p>
          </div>

          <ul :if={@features != []} class="space-y-3 mb-8">
            <%= for feature <- @features do %>
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

          <%= if @onramp.existing_org do %>
            <.org_onramp_existing
              onramp={@onramp}
              label={@label}
              type_label={@type_label}
              selected_interval={@selected_interval}
            />
          <% else %>
            <.org_onramp_create
              onramp={@onramp}
              org_name_form={@org_name_form}
              label={@label}
              type_label={@type_label}
            />
          <% end %>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  attr :onramp, :map, required: true
  attr :label, :string, required: true
  attr :type_label, :string, required: true
  attr :selected_interval, :string, default: "year"

  # Deep-link variant: the user already owns an org of this type, so we send them
  # to that org instead of creating a duplicate. Two states (#266):
  #   * active   — "Manage your <plan>"
  #   * inert    — they created it but never finished checkout (e.g. re-unlocked
  #                auth in a new tab); send them back to RESUME the trial setup
  #                rather than re-offering the create form (which would hit the
  #                one-family limit).
  # Carries the chosen billing interval so the org page opens on the right tab.
  defp org_onramp_existing(assigns) do
    ~H"""
    <div class="rounded-xl bg-emerald-50/70 dark:bg-emerald-900/20 border border-emerald-200/60 dark:border-emerald-700/40 p-4 mb-4">
      <p class="text-sm text-emerald-800 dark:text-emerald-200">
        <.phx_icon name="hero-check-badge" class="inline w-4 h-4 mr-1 -mt-0.5" />
        <%= if @onramp.existing_active? do %>
          {gettext("You already have an active %{type}.", type: @type_label)}
        <% else %>
          {gettext("You already started setting up your %{type}. Pick up where you left off.",
            type: @type_label
          )}
        <% end %>
      </p>
    </div>
    <DesignSystem.liquid_button
      navigate={~p"/app/org/#{@onramp.existing_org.slug}/subscribe?#{%{billing: @selected_interval}}"}
      variant="primary"
      color="emerald"
      size="lg"
      class="w-full"
      icon={if @onramp.existing_active?, do: "hero-cog-6-tooth", else: "hero-rocket-launch"}
      id={"org-onramp-manage-#{@onramp.type}"}
    >
      <%= if @onramp.existing_active? do %>
        {gettext("Manage your %{label}", label: @label)}
      <% else %>
        {gettext("Continue & start your trial")}
      <% end %>
    </DesignSystem.liquid_button>
    """
  end

  attr :onramp, :map, required: true
  attr :org_name_form, :any, required: true
  attr :label, :string, required: true
  attr :type_label, :string, required: true

  # Create variant: capture an org name inline and create an INERT org, then
  # route to the org's own subscribe page where the trial begins.
  defp org_onramp_create(assigns) do
    ~H"""
    <.form
      for={@org_name_form}
      id={"org-onramp-form-#{@onramp.type}"}
      phx-submit="create_org"
      class="space-y-4"
    >
      <input type="hidden" name="type" value={to_string(@onramp.type)} />
      <.phx_input
        field={@org_name_form[:name]}
        type="text"
        label={gettext("Name your %{type}", type: @type_label)}
        placeholder={gettext("e.g. The Smith %{label}", label: @label)}
        required
        autocomplete="off"
      />
      <DesignSystem.liquid_button
        type="submit"
        variant="primary"
        color="emerald"
        size="lg"
        class="w-full"
        icon="hero-rocket-launch"
        id={"org-onramp-start-#{@onramp.type}"}
      >
        {gettext("Name your %{type} & start trial", type: @type_label)}
      </DesignSystem.liquid_button>
      <p class="text-center text-xs text-slate-500 dark:text-slate-400">
        {gettext("Your 14-day free trial starts on the next step. Cancel anytime.")}
      </p>
    </.form>
    """
  end

  attr :selected_interval, :string, default: "year"
  attr :class, :string, default: ""

  defp interval_toggle(assigns) do
    ~H"""
    <div class={["flex justify-center", @class]}>
      <div class="inline-flex items-center gap-1 rounded-full border border-slate-200/70 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/60 backdrop-blur-sm p-1 shadow-sm">
        <button
          type="button"
          id="interval-toggle-month"
          aria-pressed={to_string(@selected_interval == "month")}
          phx-click="select_interval"
          phx-value-interval="month"
          class={[
            "rounded-full px-4 py-1.5 text-sm font-semibold transition-all duration-200",
            if(@selected_interval == "month",
              do: "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow",
              else:
                "text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            )
          ]}
        >
          {gettext("Monthly")}
        </button>
        <button
          type="button"
          id="interval-toggle-year"
          aria-pressed={to_string(@selected_interval == "year")}
          phx-click="select_interval"
          phx-value-interval="year"
          class={[
            "inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-sm font-semibold transition-all duration-200",
            if(@selected_interval == "year",
              do: "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow",
              else:
                "text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100"
            )
          ]}
        >
          {gettext("Yearly")}
          <span class="inline-flex items-center rounded-full bg-amber-100 dark:bg-amber-900/50 px-1.5 py-0.5 text-[10px] font-bold text-amber-700 dark:text-amber-300">
            {gettext("Save")}
          </span>
        </button>
      </div>
    </div>
    """
  end

  attr :one_time_products, :list, required: true
  attr :subscription_products, :list, required: true
  attr :current_payment_intent, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :has_active_billing, :boolean, default: false
  attr :source, :atom, required: true

  attr :referral_discount, :integer, default: nil
  attr :selected_family, :string, default: nil
  attr :selected_interval, :string, default: "year"

  defp pricing_cards(assigns) do
    # Product selection:
    #
    #   * :org source — ALWAYS scope to the org's own family + the selected
    #     billing interval (driven by the interval tab switcher), even when the
    #     org already has billing. An org buys exactly ONE plan family (its type),
    #     so a flat grid of every family/interval + the personal lifetime offer
    #     would be noise. This makes the active/trialing org view mirror the tab
    #     switcher and default to the tab matching the current subscription.
    #
    #   * :user with active billing — show everything (manage view).
    #
    #   * :user picking a plan — show only the selected family + interval so the
    #     page reflects the plan they picked on /pricing (Task #215).
    products =
      cond do
        assigns.source == :org ->
          filter_products_by_family_interval(
            assigns.subscription_products,
            assigns.selected_family,
            assigns.selected_interval
          )

        assigns.has_active_billing ->
          assigns.subscription_products

        assigns.selected_family ->
          filter_products_by_family_interval(
            assigns.subscription_products,
            assigns.selected_family,
            assigns.selected_interval
          )

        true ->
          assigns.subscription_products
      end

    # The one-time/lifetime offer is a PERSONAL (`:user`) product only — never
    # shown on the org-scoped page or on non-Personal family tabs.
    one_time =
      cond do
        assigns.source == :org -> []
        assigns.has_active_billing -> assigns.one_time_products
        assigns.selected_family in [nil, "Personal"] -> assigns.one_time_products
        true -> []
      end

    assigns =
      assigns
      |> assign(:products, products)
      |> assign(:one_time, one_time)

    ~H"""
    <div
      :if={@products != []}
      class={[
        "grid grid-cols-1 gap-6 lg:gap-8 mx-auto",
        if(length(@products) > 1, do: "md:grid-cols-2 max-w-3xl", else: "max-w-md")
      ]}
    >
      <%= for product <- @products do %>
        <.pricing_card
          product={product}
          current_payment_intent={@current_payment_intent}
          current_subscription={@current_subscription}
          has_active_billing={@has_active_billing}
          source={@source}
          referral_discount={@referral_discount}
        />
      <% end %>
    </div>

    <div :if={@one_time != []} class="mt-16 lg:mt-20">
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
        <%= for product <- @one_time do %>
          <.one_time_card
            product={product}
            current_payment_intent={@current_payment_intent}
            current_subscription={@current_subscription}
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
                  <div
                    :if={@discounted_amount}
                    class="flex flex-wrap items-center justify-center gap-2 mb-3"
                  >
                    <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 text-xs font-semibold">
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
      |> assign(:seat_based?, Plans.seat_based_plan?(item))
      |> assign(:included_seats, Plans.included_seats(item))
      |> assign(:max_seats, Plans.max_seats(item))

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
              seat_based?={@seat_based?}
              included_seats={@included_seats}
              max_seats={@max_seats}
            />
          </div>

          <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
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
    original_amount = assigns.item.amount

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
          :if={Map.get(@item, :save_percent) && @item.save_percent > 0}
          id={"save-pricing-#{@item.id}-#{@item.interval}"}
          phx-hook="TippyHook"
          data-tippy-content={gettext("Save %{percent}% off", percent: @item.save_percent)}
          class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold cursor-help"
        >
          <.phx_icon name="hero-tag" class="w-3.5 h-3.5" /> {gettext("Save %{percent}%",
            percent: @item.save_percent
          )}
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
  attr :seat_based?, :boolean, default: false
  attr :included_seats, :integer, default: 1
  attr :max_seats, :any, default: :infinity

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
      <% @seat_based? -> %>
        <.seat_checkout_form
          item={@item}
          is_most_popular={@is_most_popular}
          included_seats={@included_seats}
          max_seats={@max_seats}
        />
      <% true -> %>
        <DesignSystem.liquid_button
          variant={if @is_most_popular, do: "primary", else: "secondary"}
          size="lg"
          class="w-full"
          icon={button_icon(@item)}
          phx-click="checkout"
          phx-value-plan={@item.id}
        >
          {button_label(@item)}
        </DesignSystem.liquid_button>
    <% end %>
    """
  end

  attr :item, :map, required: true
  attr :is_most_popular, :boolean, required: true
  attr :included_seats, :integer, required: true
  attr :max_seats, :any, required: true

  # Seat selector + checkout submission for per-seat plans (Family/Business).
  # Submits the chosen member/seat count with the "checkout" event so the count
  # threads through to Stripe. The seat count is re-clamped server-side, so this
  # input is purely a convenience.
  defp seat_checkout_form(assigns) do
    max_attr =
      case assigns.max_seats do
        :infinity -> nil
        max when is_integer(max) -> max
      end

    assigns = assign(assigns, :max_attr, max_attr)

    ~H"""
    <.form
      for={%{}}
      as={:checkout}
      id={"seat-checkout-#{@item.id}"}
      phx-submit="checkout"
      class="space-y-3"
    >
      <input type="hidden" name="plan" value={@item.id} />
      <div>
        <label
          for={"seats-#{@item.id}"}
          class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
        >
          {gettext("Members")}
          <span class="text-slate-400 dark:text-slate-500 font-normal">
            ({gettext("%{count} included", count: @included_seats)})
          </span>
        </label>
        <div
          id={"seat-stepper-#{@item.id}"}
          phx-hook="SeatStepper"
          class={[
            "inline-flex items-stretch w-full overflow-hidden rounded-xl",
            "border border-slate-300 dark:border-slate-600",
            "bg-white dark:bg-slate-800 shadow-sm",
            "focus-within:border-emerald-500 focus-within:ring-1 focus-within:ring-emerald-500",
            "transition-colors duration-200"
          ]}
        >
          <button
            type="button"
            data-seat-step="-1"
            aria-label={gettext("Decrease members")}
            class={[
              "flex items-center justify-center w-11 shrink-0 text-slate-500 dark:text-slate-400",
              "hover:bg-slate-100 dark:hover:bg-slate-700 active:bg-slate-200 dark:active:bg-slate-600",
              "hover:text-emerald-600 dark:hover:text-emerald-400",
              "disabled:opacity-40 disabled:pointer-events-none",
              "transition-colors duration-150 focus:outline-none"
            ]}
          >
            <.phx_icon name="hero-minus" class="size-4" />
          </button>
          <input
            type="number"
            id={"seats-#{@item.id}"}
            name="seats"
            value={@included_seats}
            min={@included_seats}
            max={@max_attr}
            step="1"
            inputmode="numeric"
            class={[
              "min-w-0 flex-1 border-0 bg-transparent text-center font-semibold tabular-nums",
              "text-slate-900 dark:text-slate-100 focus:ring-0 sm:text-sm",
              "[appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
            ]}
          />
          <button
            type="button"
            data-seat-step="1"
            aria-label={gettext("Increase members")}
            class={[
              "flex items-center justify-center w-11 shrink-0 text-slate-500 dark:text-slate-400",
              "hover:bg-slate-100 dark:hover:bg-slate-700 active:bg-slate-200 dark:active:bg-slate-600",
              "hover:text-emerald-600 dark:hover:text-emerald-400",
              "disabled:opacity-40 disabled:pointer-events-none",
              "transition-colors duration-150 focus:outline-none"
            ]}
          >
            <.phx_icon name="hero-plus" class="size-4" />
          </button>
        </div>
      </div>
      <label
        :if={subdomain_addon_plan?(@item)}
        for={"subdomain-addon-#{@item.id}"}
        class={[
          "flex items-start gap-3 rounded-xl border p-3 cursor-pointer transition-colors",
          "border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800",
          "hover:border-emerald-400 dark:hover:border-emerald-500"
        ]}
      >
        <input
          type="checkbox"
          id={"subdomain-addon-#{@item.id}"}
          name="subdomain"
          value="1"
          class="mt-0.5 size-4 rounded border-slate-300 dark:border-slate-600 text-emerald-600 focus:ring-emerald-500/40"
        />
        <span class="min-w-0 flex-1 text-sm">
          <span class="block font-medium text-slate-800 dark:text-slate-100">
            {gettext("Add a custom subdomain")}
            <span class="font-normal text-slate-500 dark:text-slate-400">
              ({subdomain_addon_price_label(@item)})
            </span>
          </span>
          <span class="block text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            {gettext(
              "Your branded address (yourteam.mosslet.com) with an org-branded sign-in. Your logo is always free."
            )}
          </span>
        </span>
      </label>
      <DesignSystem.liquid_button
        type="submit"
        variant={if @is_most_popular, do: "primary", else: "secondary"}
        size="lg"
        class="w-full"
        icon={button_icon(@item)}
      >
        {button_label(@item)}
      </DesignSystem.liquid_button>
    </.form>
    """
  end

  defp subdomain_addon_plan?(item), do: Plans.subdomain_addon_plan?(item)

  defp subdomain_addon_price_label(%{interval: :year}), do: gettext("+$150/yr")
  defp subdomain_addon_price_label(_), do: gettext("+$15/mo")

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
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("checkout", %{"plan" => plan_id} = params, socket) do
    source = socket.assigns.source
    plan = Plans.get_plan_by_id!(plan_id)
    seats = Plans.clamp_seats(plan, Map.get(params, "seats", Plans.included_seats(plan)))
    addons = checkout_addons(plan, params)
    checkout_url = checkout_url(socket, source, plan_id, seats, addons)

    Logs.log("billing.click_subscribe_button", %{
      user: socket.assigns.current_user,
      metadata: %{
        plan_id: plan_id,
        seats: seats,
        subdomain_addon: :subdomain in addons,
        org_id: current_org_id(socket)
      }
    })

    {:noreply, redirect(socket, to: checkout_url)}
  end

  def handle_event(
        "switch_plan",
        %{"plan" => plan_id},
        %{
          assigns: %{
            current_customer: customer,
            current_payment_intent: payment_intent
          }
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

  def handle_event(
        "switch_subscription",
        %{"plan" => plan_id},
        %{
          assigns: %{
            current_customer: customer,
            current_subscription: subscription
          }
        } =
          socket
      ) do
    plan = Plans.get_plan_by_id!(plan_id)

    case billing_provider().change_plan(customer, subscription, plan) do
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

  def handle_event("select_family", %{"family" => key}, socket) do
    if Enum.any?(socket.assigns.families, &(&1.key == key)) do
      {:noreply,
       push_patch(socket,
         to: subscribe_patch_path(socket, key, socket.assigns.selected_interval)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_interval", %{"interval" => interval}, socket)
      when interval in ~w(month year) do
    {:noreply,
     push_patch(socket,
       to: subscribe_patch_path(socket, socket.assigns.selected_family, interval)
     )}
  end

  def handle_event("select_interval", _params, socket), do: {:noreply, socket}

  # Org on-ramp (Option B, Task #235): the Family/Business tab on the
  # `:user`-source subscribe page is NOT a `:user` purchase. Capture the org
  # name inline, create an INERT org, then route to the org's own subscribe page
  # where the `:org` trial begins. If the user already has an active org of that
  # type we deep-link there instead of creating a duplicate.
  def handle_event("create_org", %{"type" => type} = params, socket)
      when type in ~w(family business) do
    current_user = socket.assigns.current_user
    type_atom = family_to_type(String.capitalize(type))
    name = params |> Map.get("org", %{}) |> Map.get("name", "") |> String.trim()

    cond do
      # Unconfirmed users may BROWSE plans (we show a confirm-email banner), but
      # creating an org / starting a trial requires confirmation — Orgs.create_org/2
      # raises otherwise. Guard here so the on-ramp shows a friendly nudge instead
      # of crashing the LiveView.
      is_nil(current_user.confirmed_at) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "Please confirm your email before starting your %{type}. Check your inbox for the confirmation link.",
             type: type
           )
         )}

      existing = Mosslet.Orgs.resumable_org_of_type(current_user, type_atom) ->
        {:noreply, push_navigate(socket, to: org_subscribe_path(socket, existing.slug))}

      name == "" ->
        {:noreply,
         put_flash(socket, :error, gettext("Please enter a name for your %{type}.", type: type))}

      true ->
        create_and_route_org(socket, current_user, name, type)
    end
  end

  def handle_event("create_org", _params, socket), do: {:noreply, socket}

  defp create_and_route_org(socket, current_user, name, type) do
    case Mosslet.Orgs.create_org(current_user, %{"name" => name, "type" => type}) do
      {:ok, org} ->
        Logs.log("orgs.create_#{type}", %{
          user: current_user,
          org_id: org.id
        })

        {:noreply, push_navigate(socket, to: org_subscribe_path(socket, org.slug))}

      {:error, reason} when is_atom(reason) ->
        {:noreply, put_flash(socket, :error, org_create_error_message(reason, type))}

      {:error, _changeset} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Could not create your %{type}. Please try again.", type: type)
         )}
    end
  end

  defp org_create_error_message(:family_limit_reached, _type),
    do: gettext("You can only own one family. Manage your existing family instead.")

  defp org_create_error_message(reason, type)
       when reason in [:family_entitlement_required, :business_entitlement_required],
       do:
         gettext("Starting a separate %{type} is a paid plan. Continue to start your trial.",
           type: type
         )

  defp org_create_error_message(_reason, type),
    do: gettext("Could not create your %{type}. Please try again.", type: type)

  defp checkout_url(_socket, :user, plan_id, seats, addons),
    do: ~p"/app/checkout/#{plan_id}?#{checkout_query(seats, addons)}"

  defp checkout_url(socket, :org, plan_id, seats, addons) do
    org_slug = current_org_slug(socket)
    ~p"/app/org/#{org_slug}/checkout/#{plan_id}?#{checkout_query(seats, addons)}"
  end

  # The paid custom-subdomain branding add-on (Task #240, Phase B) is honored
  # only when checked AND the plan offers it (Business). The query param is
  # re-validated server-side in the checkout controller.
  defp checkout_addons(plan, params) do
    if params["subdomain"] in ["1", "true", "on"] and Plans.subdomain_addon_plan?(plan) do
      [:subdomain]
    else
      []
    end
  end

  defp checkout_query(seats, addons) do
    base = %{seats: seats}
    if :subdomain in addons, do: Map.put(base, :subdomain, "1"), else: base
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
    case socket.assigns[:current_org] do
      nil -> nil
      org -> Customers.get_customer_by_source(:org, org.id)
    end
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

  # --- Plan family switcher helpers (mirrors PublicLive.Pricing) ------------

  # Patch the URL so the selection survives reloads/back-button and matches the
  # `?plan=`/`?billing=` contract the funnel uses elsewhere.
  defp subscribe_patch_path(%{assigns: %{source: :org}} = socket, _family, interval) do
    org_slug = current_org_slug(socket)
    ~p"/app/org/#{org_slug}/subscribe?#{%{billing: interval}}"
  end

  defp subscribe_patch_path(_socket, family, interval) do
    ~p"/app/subscribe?#{%{plan: family_to_plan(family), billing: interval}}"
  end

  # Org on-ramp destination (Option B): route to the org's own subscribe page,
  # CARRYING the billing interval the user picked on /pricing (and on the
  # `:user` on-ramp page) so they land on their chosen monthly/yearly tab rather
  # than the org page's session/default fallback (#266).
  defp org_subscribe_path(socket, slug) do
    interval = socket.assigns[:selected_interval] || "year"
    ~p"/app/org/#{slug}/subscribe?#{%{billing: interval}}"
  end

  defp family_to_plan("Family"), do: "family"
  defp family_to_plan("Business"), do: "business"
  defp family_to_plan(_), do: "personal"

  defp build_families(subscription_products) do
    subscription_products
    |> Enum.map(&short_name(&1.name))
    |> Enum.uniq()
    |> Enum.map(fn key -> Map.put(family_meta(key), :key, key) end)
  end

  defp default_family(families) do
    keys = Enum.map(families, & &1.key)

    cond do
      "Personal" in keys -> "Personal"
      keys != [] -> List.first(keys)
      true -> nil
    end
  end

  # "MOSSLET (Family)" -> "Family"
  defp short_name(name) do
    case Regex.run(~r/\(([^)]+)\)/, name) do
      [_, inner] -> inner
      _ -> name
    end
  end

  defp family_meta("Personal"),
    do: %{label: gettext("Personal"), icon: "hero-user"}

  defp family_meta("Family"),
    do: %{label: gettext("Family"), icon: "hero-heart"}

  defp family_meta("Business"),
    do: %{label: gettext("Business"), icon: "hero-building-office-2"}

  defp family_meta(other),
    do: %{label: other, icon: "hero-sparkles"}
end
