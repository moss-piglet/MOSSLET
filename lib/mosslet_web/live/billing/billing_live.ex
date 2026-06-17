defmodule MossletWeb.BillingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Repo
  alias MossletWeb.DesignSystem
  alias Phoenix.LiveView.AsyncResult

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:source, socket.assigns.live_action)
      |> assign(:billing_provider, billing_provider())
      |> assign(:invoice_year_filter, nil)
      |> assign(:orphan_guard_open, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> maybe_assign_org(params)

    socket =
      socket
      |> assign(:billing_customer, billing_customer(socket))
      |> assign_org_memberships()
      |> maybe_load_provider_data()

    {:noreply, socket}
  end

  # For the org-scoped billing route (/app/org/:org_slug/billing) load the org
  # from the slug (membership-enforced by Orgs.get_org!/2) so billing resolves
  # against the org's OWN `:org`-source customer — not the owner's personal
  # `:user` customer (Option B billing, Task #235).
  defp maybe_assign_org(%{assigns: %{source: :org}} = socket, %{"org_slug" => org_slug}) do
    current_user = socket.assigns.current_scope.user

    case Mosslet.Orgs.get_org!(current_user, org_slug) do
      %Mosslet.Orgs.Org{} = org -> assign(socket, :current_org, org)
      _ -> socket
    end
  rescue
    Ecto.NoResultsError ->
      socket
      |> put_flash(:error, gettext("Organization not found."))
      |> push_navigate(to: ~p"/app/business")
  end

  defp maybe_assign_org(socket, _params), do: socket

  # The PERSONAL billing page (source == :user) also surfaces the user's
  # family/business seats + ownership, so a member with no personal plan still
  # sees that they're covered by an org, and an owner sees their org plan (even
  # trialing). Org-scoped pages already show that org's own plan, so we skip it.
  defp assign_org_memberships(%{assigns: %{source: :user, current_scope: %{user: user}}} = socket) do
    assign(socket, :org_memberships, Mosslet.Orgs.list_org_billing_summaries(user))
  end

  defp assign_org_memberships(socket), do: assign(socket, :org_memberships, [])

  # Resolves the billing customer for the current source: the org's OWN
  # `:org`-source customer for the org-scoped page, else the user's personal
  # `:user`-source customer.
  defp billing_customer(%{assigns: %{source: :org, current_org: %Mosslet.Orgs.Org{} = org}}) do
    Mosslet.Billing.Customers.get_customer_by_source(:org, org.id)
  end

  defp billing_customer(%{assigns: %{current_scope: %{user: user}}}) do
    Repo.preload(user, :customer).customer
  end

  defp maybe_load_provider_data(socket) do
    customer = socket.assigns[:billing_customer] || billing_customer(socket)
    payment_intent = socket.assigns[:payment_intent]

    assign_async(
      socket,
      [
        :provider_payment_intent_async,
        :provider_charge_async,
        :subscription_async,
        :upcoming_invoice_async,
        :invoices_async,
        :invoices_has_more_async
      ],
      fn ->
        case payment_intent do
          nil ->
            if customer do
              payment_intent =
                PaymentIntents.get_active_payment_intent_by_customer_id(customer.id)

              subscription =
                Subscriptions.get_active_subscription_by_customer_id(customer.id)

              upcoming_invoice = fetch_upcoming_invoice(subscription)
              %{invoices: invoices, has_more: invoices_has_more} = fetch_invoices(subscription)

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
                   subscription_async: subscription,
                   upcoming_invoice_async: upcoming_invoice,
                   invoices_async: invoices,
                   invoices_has_more_async: invoices_has_more
                 }}
              else
                {:ok,
                 %{
                   provider_payment_intent_async: nil,
                   provider_charge_async: nil,
                   subscription_async: subscription,
                   upcoming_invoice_async: upcoming_invoice,
                   invoices_async: invoices,
                   invoices_has_more_async: invoices_has_more
                 }}
              end
            else
              {:ok,
               %{
                 provider_payment_intent_async: nil,
                 provider_charge_async: nil,
                 subscription_async: nil,
                 upcoming_invoice_async: nil,
                 invoices_async: [],
                 invoices_has_more_async: false
               }}
            end

          payment_intent ->
            {:ok, provider_payment_intent} =
              billing_provider().retrieve_payment_intent(
                payment_intent.provider_payment_intent_id
              )

            subscription =
              if customer do
                Subscriptions.get_active_subscription_by_customer_id(customer.id)
              end

            upcoming_invoice = fetch_upcoming_invoice(subscription)
            %{invoices: invoices, has_more: invoices_has_more} = fetch_invoices(subscription)

            case billing_provider().retrieve_charge(payment_intent.provider_latest_charge_id) do
              {:ok, provider_charge} ->
                {:ok,
                 %{
                   provider_payment_intent_async: provider_payment_intent,
                   provider_charge_async: provider_charge,
                   subscription_async: subscription,
                   upcoming_invoice_async: upcoming_invoice,
                   invoices_async: invoices,
                   invoices_has_more_async: invoices_has_more
                 }}

              _rest ->
                {:ok,
                 %{
                   provider_payment_intent_async: provider_payment_intent,
                   provider_charge_async: nil,
                   subscription_async: subscription,
                   upcoming_invoice_async: upcoming_invoice,
                   invoices_async: invoices,
                   invoices_has_more_async: invoices_has_more
                 }}
            end
        end
      end
    )
  end

  defp fetch_upcoming_invoice(nil), do: nil

  defp fetch_upcoming_invoice(subscription) do
    case billing_provider().upcoming_invoice(%{
           subscription: subscription.provider_subscription_id
         }) do
      {:ok, invoice} -> invoice
      _error -> nil
    end
  end

  defp fetch_invoices(nil), do: %{invoices: [], has_more: false}

  defp fetch_invoices(subscription, starting_after \\ nil) do
    params = %{
      subscription: subscription.provider_subscription_id,
      limit: 24
    }

    params = if starting_after, do: Map.put(params, :starting_after, starting_after), else: params

    case billing_provider().list_invoices(params) do
      {:ok, %{data: invoices, has_more: has_more}} ->
        %{invoices: invoices, has_more: has_more}

      _error ->
        %{invoices: [], has_more: false}
    end
  end

  def billing_path(:user, _assigns), do: ~p"/app/billing"
  def billing_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/billing"

  defp subscribe_path(:user, _assigns), do: ~p"/app/subscribe"
  defp subscribe_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/subscribe"

  defp do_cancel_subscription(subscription_id, socket) do
    subscription = Subscriptions.get_subscription!(subscription_id)

    if subscription.status == "trialing" do
      cancel_subscription_immediately(subscription, socket)
    else
      cancel_subscription_at_period_end(subscription, socket)
    end
  end

  # True only when this is the org-scoped billing page, the current user OWNS the
  # org, and the org has at least 2 members (the owner + at least one other who
  # would be stranded). Everything else (personal billing, non-owner admin,
  # single-member org) returns false and cancellation proceeds normally.
  defp org_owner_cancel_would_orphan?(%{
         assigns: %{
           source: :org,
           current_org: %Mosslet.Orgs.Org{} = org,
           current_scope: %{user: user}
         }
       }) do
    Mosslet.Orgs.owner?(org, user.id) and
      length(Mosslet.Orgs.list_members_by_org(org)) >= 2
  end

  defp org_owner_cancel_would_orphan?(_socket), do: false

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

  @impl true
  def handle_event("cancel_subscription", %{"subscription-id" => subscription_id}, socket) do
    # Orphan guard (Task #237): canceling an ORG's `:org`-source subscription is
    # the ONLY path that can strand fellow members (it removes the org's
    # coverage). When the canceller is the OWNER of an org with at least one OTHER
    # member, we intercept BEFORE any Stripe call and surface a friendly blocking
    # notice: transfer ownership first, or delete the org (deletion is #227, shown
    # as "coming soon"). A single-member org (owner only) can cancel freely —
    # nobody is stranded. Personal `:user` cancellation is never gated here: a
    # personal plan can't orphan an org.
    if org_owner_cancel_would_orphan?(socket) do
      {:noreply, assign(socket, :orphan_guard_open, true)}
    else
      do_cancel_subscription(subscription_id, socket)
    end
  end

  @impl true
  def handle_event("dismiss_orphan_guard", _params, socket) do
    {:noreply, assign(socket, :orphan_guard_open, false)}
  end

  @impl true
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
  def handle_event("update_payment_method", _params, socket) do
    user = socket.assigns.current_scope.user
    customer = Repo.preload(user, :customer).customer

    # provider_customer_id is now Cloak-only — read directly
    provider_customer_id = customer.provider_customer_id

    return_path = billing_path(socket.assigns.source, socket.assigns)
    return_url = MossletWeb.Endpoint.url() <> return_path

    case billing_provider().create_portal_session(%{
           customer: provider_customer_id,
           return_url: return_url,
           flow_data: %{
             type: "payment_method_update"
           }
         }) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, _reason} ->
        socket =
          socket
          |> put_flash(
            :error,
            gettext("Something went wrong. Please try again or contact support.")
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("load_more_invoices", _params, socket) do
    subscription = socket.assigns.subscription_async.result
    current_invoices = socket.assigns.invoices_async.result

    last_invoice_id =
      case List.last(current_invoices) do
        nil -> nil
        invoice -> invoice.id
      end

    %{invoices: new_invoices, has_more: has_more} =
      fetch_invoices(subscription, last_invoice_id)

    updated_invoices = current_invoices ++ new_invoices

    socket =
      socket
      |> assign(
        :invoices_async,
        AsyncResult.ok(socket.assigns.invoices_async, updated_invoices)
      )
      |> assign(
        :invoices_has_more_async,
        AsyncResult.ok(socket.assigns.invoices_has_more_async, has_more)
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_invoices_by_year", %{"filter" => %{"year" => year}}, socket) do
    year_filter =
      case year do
        "" -> nil
        year_str -> String.to_integer(year_str)
      end

    {:noreply, assign(socket, :invoice_year_filter, year_filter)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout
          current_scope={@current_scope}
          current_page={:billing}
          sidebar_current_page={:billing}
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
              <.org_memberships_info org_memberships={@org_memberships} />

              <.billing_info
                subscribe_path={subscribe_path(@source, assigns)}
                billing_provider={@billing_provider}
                provider_charge_async={@provider_charge_async}
                provider_payment_intent_async={@provider_payment_intent_async}
                subscription_async={@subscription_async}
                upcoming_invoice_async={@upcoming_invoice_async}
                invoices_async={@invoices_async}
                invoices_has_more_async={@invoices_has_more_async}
                current_scope={@current_scope}
                customer={@billing_customer}
                org_memberships={@org_memberships}
                invoice_year_filter={@invoice_year_filter}
              />
            </div>
          </DesignSystem.liquid_container>
        </.layout>
      <% :org -> %>
        <.layout
          current_scope={@current_scope}
          current_page={org_sidebar_page(@current_org)}
          sidebar_current_page={org_sidebar_page(@current_org)}
          type="sidebar"
        >
          <DesignSystem.liquid_container max_width="lg" class="py-16">
            <div class="mb-12">
              <header class="flex items-center gap-3 mb-6">
                <.link
                  navigate={org_home_path(@current_org)}
                  class="p-2 -ml-2 rounded-xl text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 transition-all duration-200"
                  aria-label={gettext("Back to organization")}
                >
                  <.phx_icon name="hero-arrow-left" class="size-5" />
                </.link>
                <div class="flex items-center gap-3 min-w-0">
                  <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
                    <.phx_icon name="hero-credit-card" class="h-6 w-6 text-white" />
                  </div>
                  <div class="min-w-0">
                    <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate">
                      {gettext("Billing & Payments")}
                    </h1>
                    <p class="mt-0.5 text-sm text-slate-500 dark:text-slate-400 truncate">
                      {gettext("Manage the plan and payment history for %{name}.",
                        name: @current_org.name
                      )}
                    </p>
                  </div>
                </div>
              </header>
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
                upcoming_invoice_async={@upcoming_invoice_async}
                invoices_async={@invoices_async}
                invoices_has_more_async={@invoices_has_more_async}
                current_scope={@current_scope}
                customer={@billing_customer}
                invoice_year_filter={@invoice_year_filter}
              />
            </div>
          </DesignSystem.liquid_container>

          <%!-- Orphan guard (Task #237): block an owner from canceling the org's
                plan while other members still depend on its coverage. --%>
          <DesignSystem.liquid_modal
            :if={@orphan_guard_open}
            id="orphan-guard-modal"
            show={@orphan_guard_open}
            modal_portal={false}
            on_cancel={JS.push("dismiss_orphan_guard")}
          >
            <:title>{gettext("This organization has other members")}</:title>

            <div id="orphan-guard-body" class="space-y-5">
              <p class="text-sm text-slate-600 dark:text-slate-300">
                {gettext(
                  "Canceling this plan would remove coverage for everyone in %{name}. Before you can cancel, transfer ownership to another member, or delete the organization.",
                  name: @current_org.name
                )}
              </p>

              <div class="flex flex-col sm:flex-row gap-3">
                <DesignSystem.liquid_button
                  id="orphan-guard-transfer"
                  navigate={"#{org_home_path(@current_org)}#ownership"}
                  color="emerald"
                  icon="hero-arrow-right-circle"
                >
                  {gettext("Transfer ownership")}
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  id="orphan-guard-delete"
                  navigate={"#{org_home_path(@current_org)}#org-danger-zone"}
                  color="rose"
                  icon="hero-trash"
                  variant="ghost"
                >
                  {gettext("Delete organization")}
                </DesignSystem.liquid_button>
              </div>

              <div class="flex justify-end">
                <button
                  id="orphan-guard-dismiss"
                  type="button"
                  phx-click="dismiss_orphan_guard"
                  class="text-sm font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition-colors"
                >
                  {gettext("Never mind")}
                </button>
              </div>
            </div>
          </DesignSystem.liquid_modal>
        </.layout>
    <% end %>
    """
  end

  # Org-scoped sidebar nav + back-link helpers (family vs business).
  defp org_sidebar_page(%Mosslet.Orgs.Org{type: :business}), do: :business
  defp org_sidebar_page(%Mosslet.Orgs.Org{type: :family}), do: :family
  defp org_sidebar_page(_), do: :business

  defp org_home_path(%Mosslet.Orgs.Org{type: :business, slug: slug}),
    do: ~p"/app/business/#{slug}"

  defp org_home_path(%Mosslet.Orgs.Org{type: :family, slug: slug}), do: ~p"/app/family/#{slug}"
  defp org_home_path(_), do: ~p"/app/business"

  @doc """
  Personal-billing summary of the user's family/business memberships (Task #239
  follow-up). Renders nothing when the user belongs to no org. Each org shows the
  user's relationship (Owner / Admin / Member) and the org plan's coverage state
  — so a member with no personal plan still sees they're covered by an org seat,
  and an owner sees their org plan even while trialing. Billing for an org is
  managed on that org's own billing page, linked from each row.
  """
  attr :org_memberships, :list, default: []

  def org_memberships_info(assigns) do
    ~H"""
    <div :if={@org_memberships != []} id="org-memberships-card">
      <DesignSystem.liquid_card>
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
              <.phx_icon name="hero-users" class="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
            </div>
            <span>{gettext("Your memberships")}</span>
          </div>
        </:title>

        <p class="mb-4 text-sm text-slate-600 dark:text-slate-400">
          {gettext(
            "Seats you hold in a family or business. These are billed on the organization's own plan, separate from your personal membership below."
          )}
        </p>

        <ul role="list" class="divide-y divide-slate-200/60 dark:divide-slate-700/60">
          <li
            :for={summary <- @org_memberships}
            id={"org-membership-#{summary.org.id}"}
            class="flex items-center gap-4 py-4 first:pt-0 last:pb-0"
          >
            <div class={[
              "flex h-10 w-10 shrink-0 items-center justify-center rounded-xl shadow-sm",
              org_kind_icon_bg(summary.org.type)
            ]}>
              <.phx_icon name={org_kind_icon(summary.org.type)} class="h-5 w-5 text-white" />
            </div>

            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-2">
                <span class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                  {summary.org.name}
                </span>
                <DesignSystem.liquid_badge
                  :if={summary.owner?}
                  variant="soft"
                  color="amber"
                  size="xs"
                >
                  <.phx_icon name="hero-key" class="h-3 w-3 mr-1" />{gettext("Owner")}
                </DesignSystem.liquid_badge>
                <DesignSystem.liquid_badge
                  :if={!summary.owner? && summary.role == :admin}
                  variant="soft"
                  color="blue"
                  size="xs"
                >
                  {gettext("Admin")}
                </DesignSystem.liquid_badge>
                <DesignSystem.liquid_badge
                  :if={!summary.owner? && summary.role == :member}
                  variant="soft"
                  color="slate"
                  size="xs"
                >
                  {gettext("Member")}
                </DesignSystem.liquid_badge>
              </div>

              <div class="mt-1 flex flex-wrap items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                <span>{org_kind_label(summary.org.type)}</span>
                <span aria-hidden="true">&middot;</span>
                <DesignSystem.liquid_badge
                  variant="soft"
                  color={org_status_color(summary.status)}
                  size="xs"
                >
                  {org_status_label(summary.status)}
                </DesignSystem.liquid_badge>
                <span :if={summary.plan} aria-hidden="true">&middot;</span>
                <span :if={summary.plan}>{plan_interval_label(summary.plan)}</span>
              </div>
            </div>

            <.link
              navigate={org_billing_path(summary.org)}
              class="shrink-0 text-sm font-medium text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 transition-colors"
            >
              {if summary.owner? || summary.role == :admin,
                do: gettext("Manage"),
                else: gettext("View")}
            </.link>
          </li>
        </ul>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  defp org_kind_icon(:family), do: "hero-home-modern"
  defp org_kind_icon(:business), do: "hero-building-office-2"
  defp org_kind_icon(_), do: "hero-user-group"

  defp org_kind_icon_bg(:family),
    do: "bg-gradient-to-br from-purple-500 to-violet-600 shadow-violet-500/25"

  defp org_kind_icon_bg(_),
    do: "bg-gradient-to-br from-teal-500 to-emerald-600 shadow-emerald-500/25"

  defp org_kind_label(:family), do: gettext("Family")
  defp org_kind_label(:business), do: gettext("Business")
  defp org_kind_label(_), do: gettext("Organization")

  defp org_status_label(:active), do: gettext("Active")
  defp org_status_label(:trialing), do: gettext("Trial")
  defp org_status_label(:past_due), do: gettext("Payment overdue")
  defp org_status_label(:lapsed), do: gettext("Inactive")
  defp org_status_label(_), do: gettext("Not set up")

  defp org_status_color(:active), do: "emerald"
  defp org_status_color(:trialing), do: "teal"
  defp org_status_color(:past_due), do: "amber"
  defp org_status_color(:lapsed), do: "rose"
  defp org_status_color(_), do: "slate"

  defp plan_interval_label(%{interval: :month}), do: gettext("Monthly")
  defp plan_interval_label(%{interval: :year}), do: gettext("Yearly")
  defp plan_interval_label(_), do: ""

  defp org_billing_path(%Mosslet.Orgs.Org{slug: slug}), do: ~p"/app/org/#{slug}/billing"

  attr :billing_provider, :atom
  attr :provider_payment_intent_async, :map
  attr :provider_charge_async, :map
  attr :subscription_async, :map
  attr :upcoming_invoice_async, :map
  attr :invoices_async, :map
  attr :invoices_has_more_async, :map
  attr :subscribe_path, :string
  attr :current_scope, Mosslet.Accounts.Scope, required: true
  attr :invoice_year_filter, :integer, default: nil

  attr :customer, :any,
    default: nil,
    doc: "the billing customer (org's `:org` customer, or the user's `:user` customer)"

  attr :org_memberships, :list,
    default: [],
    doc: "the user's org seats (personal page only) — softens the no-plan notice"

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
            <span class="text-amber-800 dark:text-amber-200">
              {if @org_memberships == [],
                do: gettext("No Active Membership"),
                else: gettext("No Personal Plan")}
            </span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-amber-700 dark:text-amber-300">
            {if @org_memberships == [],
              do:
                gettext(
                  "You don't have an active membership yet. Browse our plans to get started with MOSSLET."
                ),
              else:
                gettext(
                  "You don't have a personal plan, but you're covered through your organization seat(s) above. Add a personal plan to use MOSSLET outside of your family or business."
                )}
          </p>

          <div class="flex justify-start">
            <DesignSystem.liquid_button href={@subscribe_path} color="amber" icon="hero-eye">
              {if @org_memberships == [],
                do: gettext("View Plans"),
                else: gettext("View Personal Plans")}
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
        upcoming_invoice={@upcoming_invoice_async.result}
        invoices={@invoices_async.result}
        invoices_has_more={@invoices_has_more_async.result}
        subscribe_path={@subscribe_path}
        current_scope={@current_scope}
        customer={@customer}
        invoice_year_filter={@invoice_year_filter}
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
        current_scope={@current_scope}
        customer={@customer}
      />
    </div>
    """
  end

  attr :subscription, :map, required: true
  attr :upcoming_invoice, :map, default: nil
  attr :invoices, :list, default: []
  attr :invoices_has_more, :boolean, default: false
  attr :subscribe_path, :string, required: true
  attr :current_scope, Mosslet.Accounts.Scope, required: true
  attr :invoice_year_filter, :integer, default: nil

  attr :customer, :any,
    default: nil,
    doc: "the billing customer that owns this subscription (org or user)"

  defp subscription_info(assigns) do
    cancellation_pending = assigns.subscription.cancel_at != nil
    plan = Mosslet.Billing.Plans.get_plan_by_id(assigns.subscription.plan_id)

    billing_cycle =
      case plan do
        %{interval: :month} -> "Monthly"
        %{interval: :year} -> "Yearly"
        _ -> infer_billing_cycle_from_plan_id(assigns.subscription.plan_id)
      end

    available_years =
      assigns.invoices
      |> Enum.map(fn invoice ->
        invoice.created
        |> Util.unix_to_naive_datetime()
        |> Map.get(:year)
      end)
      |> Enum.uniq()
      |> Enum.sort(:desc)

    filtered_invoices =
      case assigns.invoice_year_filter do
        nil ->
          assigns.invoices

        year ->
          Enum.filter(assigns.invoices, fn invoice ->
            invoice.created
            |> Util.unix_to_naive_datetime()
            |> Map.get(:year) == year
          end)
      end

    year_total =
      if assigns.invoice_year_filter do
        Enum.reduce(filtered_invoices, 0, fn invoice, acc ->
          acc + invoice.amount_paid
        end)
      end

    year_currency =
      case filtered_invoices do
        [first | _] -> first.currency
        [] -> nil
      end

    assigns =
      assigns
      |> assign(:cancellation_pending, cancellation_pending)
      |> assign(:billing_cycle, billing_cycle)
      |> assign(:available_years, available_years)
      |> assign(:filtered_invoices, filtered_invoices)
      |> assign(:year_total, year_total)
      |> assign(:year_currency, year_currency)

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
                  do: "text-amber-700 dark:text-amber-300",
                  else: "text-emerald-700 dark:text-emerald-300"
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
                  do: "text-amber-700 dark:text-amber-300",
                  else: "text-emerald-700 dark:text-emerald-300"
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
            <div :if={@upcoming_invoice && !@cancellation_pending}>
              <p class="text-xs font-medium uppercase tracking-wide text-emerald-700 dark:text-emerald-300">
                {gettext("Next Charge")}
              </p>
              <p class="mt-1 text-lg font-semibold text-emerald-800 dark:text-emerald-200">
                {Util.format_money(@upcoming_invoice.amount_due, @upcoming_invoice.currency)}
                <span class="text-sm uppercase ml-1">{@upcoming_invoice.currency}</span>
                <span
                  :if={@billing_cycle}
                  class="text-sm font-normal text-emerald-700 dark:text-emerald-300 ml-1"
                >
                  ({@billing_cycle})
                </span>
              </p>
            </div>
          </div>
        </div>

        <div
          :if={@upcoming_invoice && @upcoming_invoice.hosted_invoice_url && !@cancellation_pending}
          class="bg-emerald-50 dark:bg-emerald-900/20 rounded-lg p-4 border border-emerald-100 dark:border-emerald-800"
        >
          <div class="flex items-start gap-3">
            <.phx_icon
              name="hero-document-text"
              class="h-5 w-5 text-emerald-600 dark:text-emerald-400 mt-0.5 flex-shrink-0"
            />
            <div class="flex-1">
              <p class="text-sm font-medium text-emerald-800 dark:text-emerald-200">
                {gettext("View Invoice")}
              </p>
              <p class="text-xs text-emerald-700 dark:text-emerald-300 mt-0.5">
                {gettext("Preview your upcoming invoice or view past receipts.")}
              </p>
              <a
                href={@upcoming_invoice.hosted_invoice_url}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 mt-2 text-sm font-medium text-emerald-700 dark:text-emerald-300 hover:text-emerald-800 dark:hover:text-emerald-200 transition-colors"
              >
                <.phx_icon name="hero-arrow-top-right-on-square" class="h-4 w-4" />
                {gettext("View Invoice")}
              </a>
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
            :if={@subscription.status in ["active"] && !@cancellation_pending}
            phx-click="update_payment_method"
            color="blue"
            icon="hero-credit-card"
            variant="secondary"
          >
            {gettext("Update Payment Method")}
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
                    "Are you sure you want to cancel your free trial? You will lose access immediately and won't be able to start another trial. Consider waiting until closer to the end of your 14-day trial to get the most out of it."
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
                  {@customer && @customer.provider_customer_id}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Payment Email:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {@customer && @customer.email}
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

    <DesignSystem.liquid_card :if={@invoices != []}>
      <:title>
        <div class="flex items-center gap-3">
          <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
            <.phx_icon name="hero-clock" class="h-4 w-4 text-purple-600 dark:text-purple-400" />
          </div>
          <span>Payment History</span>
          <span
            :if={@invoices_has_more && @invoice_year_filter == nil}
            class="text-sm font-normal text-slate-500 dark:text-slate-400"
          >
            ({gettext("showing %{count} most recent", count: length(@invoices))})
          </span>
          <span
            :if={@invoice_year_filter != nil}
            class="text-sm font-normal text-slate-500 dark:text-slate-400"
          >
            ({gettext("%{count} in %{year}",
              count: length(@filtered_invoices),
              year: @invoice_year_filter
            )})
          </span>
        </div>
      </:title>

      <div class="space-y-4">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {gettext("View your past payments and download receipts.")}
          </p>
          <.form
            :if={length(@available_years) > 1}
            for={%{}}
            as={:filter}
            id="invoice-year-filter-form"
            phx-change="filter_invoices_by_year"
            class="flex items-center gap-2"
            aria-label={gettext("Filter payment history by year")}
          >
            <label
              for="invoice-year-filter"
              class="text-sm font-medium text-slate-600 dark:text-slate-400"
            >
              {gettext("Year:")}
            </label>
            <select
              id="invoice-year-filter"
              name="filter[year]"
              aria-describedby="invoice-filter-description"
              class="text-sm rounded-lg border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 focus:ring-purple-500 focus:border-purple-500"
            >
              <option value="">{gettext("All")}</option>
              <option
                :for={year <- @available_years}
                value={year}
                selected={@invoice_year_filter == year}
              >
                {year}
              </option>
            </select>
            <span id="invoice-filter-description" class="sr-only">
              {gettext("Select a year to filter payment history")}
            </span>
          </.form>
        </div>

        <div
          :if={@invoice_year_filter && @year_total && @filtered_invoices != []}
          class="bg-purple-50 dark:bg-purple-900/20 rounded-lg p-4 border border-purple-100 dark:border-purple-800"
        >
          <div class="flex items-center justify-between">
            <span class="text-sm font-medium text-purple-700 dark:text-purple-300">
              {gettext("Total for %{year}", year: @invoice_year_filter)}
            </span>
            <span class="text-lg font-semibold text-purple-800 dark:text-purple-200">
              {Util.format_money(@year_total, @year_currency)}
              <span class="text-sm uppercase ml-1">{@year_currency}</span>
            </span>
          </div>
        </div>

        <div
          :if={@filtered_invoices == []}
          class="text-center py-8 text-slate-500 dark:text-slate-400"
        >
          <.phx_icon name="hero-document-magnifying-glass" class="h-8 w-8 mx-auto mb-2 opacity-50" />
          <p class="text-sm">
            {gettext("No payments found for %{year}", year: @invoice_year_filter)}
          </p>
        </div>

        <div
          :if={@filtered_invoices != []}
          class="divide-y divide-slate-200 dark:divide-slate-700 border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden max-h-[32rem] overflow-y-auto"
        >
          <div
            :for={invoice <- @filtered_invoices}
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 p-4 bg-slate-50 dark:bg-slate-800/50 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <div class="flex items-center gap-3">
              <div class={[
                "flex items-center justify-center w-8 h-8 rounded-full",
                if(invoice.status == "paid",
                  do: "bg-emerald-100 dark:bg-emerald-900/30",
                  else: "bg-amber-100 dark:bg-amber-900/30"
                )
              ]}>
                <.phx_icon
                  name={if(invoice.status == "paid", do: "hero-check", else: "hero-clock")}
                  class={[
                    "h-4 w-4",
                    if(invoice.status == "paid",
                      do: "text-emerald-600 dark:text-emerald-400",
                      else: "text-amber-600 dark:text-amber-400"
                    )
                  ]}
                />
              </div>
              <div>
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {Util.format_money(invoice.amount_paid, invoice.currency)}
                  <span class="text-xs uppercase ml-1 text-slate-500 dark:text-slate-400">
                    {invoice.currency}
                  </span>
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  <.local_time_med
                    id={"invoice-#{invoice.id}"}
                    at={Util.unix_to_naive_datetime(invoice.created)}
                  />
                  <span class="mx-1">•</span>
                  <span class="capitalize">{invoice.status}</span>
                </p>
              </div>
            </div>
            <div class="flex items-center gap-2 sm:ml-auto">
              <a
                :if={invoice.hosted_invoice_url}
                href={invoice.hosted_invoice_url}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-purple-700 dark:text-purple-300 bg-purple-100 dark:bg-purple-900/30 rounded-lg hover:bg-purple-200 dark:hover:bg-purple-900/50 transition-colors"
              >
                <.phx_icon name="hero-document-text" class="h-3.5 w-3.5" />
                {gettext("View Receipt")}
              </a>
            </div>
          </div>
        </div>

        <div :if={@invoices_has_more} class="pt-2">
          <button
            type="button"
            phx-click="load_more_invoices"
            class="w-full flex items-center justify-center gap-2 px-4 py-3 text-sm font-medium text-purple-700 dark:text-purple-300 bg-purple-50 dark:bg-purple-900/20 hover:bg-purple-100 dark:hover:bg-purple-900/30 rounded-lg border border-purple-200 dark:border-purple-800 transition-colors"
          >
            <.phx_icon name="hero-arrow-down" class="h-4 w-4" />
            {gettext("Load More Payments")}
          </button>
        </div>
      </div>
    </DesignSystem.liquid_card>
    """
  end

  attr :provider_payment_intent, :map, required: true
  attr :provider_charge, :map
  attr :subscribe_path, :string, required: true
  attr :current_scope, Mosslet.Accounts.Scope, required: true

  attr :customer, :any,
    default: nil,
    doc: "the billing customer that owns this payment intent (org or user)"

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
                  {@customer && @customer.provider_customer_id}
                </code>
              </div>

              <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

              <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                  Payment Email:
                </span>
                <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                  {@customer && @customer.email}
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
                    id={@current_scope.user.id}
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

  # Billing data is now Cloak-only (no user-key layer), so these legacy
  # migration helpers that re-encrypted from plaintext to user-key format
  # are no longer needed. Customer email/provider_customer_id are read directly.

  defp infer_billing_cycle_from_plan_id(nil), do: nil

  defp infer_billing_cycle_from_plan_id(plan_id) do
    plan_id_lower = String.downcase(plan_id)

    cond do
      String.contains?(plan_id_lower, "year") -> "Yearly"
      String.contains?(plan_id_lower, "month") -> "Monthly"
      true -> nil
    end
  end
end
