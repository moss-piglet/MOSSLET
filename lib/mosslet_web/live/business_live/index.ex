defmodule MossletWeb.BusinessLive.Index do
  @moduledoc """
  Lists the current user's Business orgs and lets them create a new one.

  Business orgs (`type: :business`) power private, org-scoped circles. See
  `docs/BUSINESS_CIRCLES_DESIGN.md`. Business orgs do NOT use guardianship.
  """
  use MossletWeb, :live_view

  alias Mosslet.Orgs

  @impl true
  def mount(_params, _session, socket) do
    socket = assign_businesses(socket)
    if connected?(socket), do: subscribe_to_businesses(socket)
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:onboarding?, params["onboarding"] == "1")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_page={:business}
      sidebar_current_page={:business}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10">
        <header class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-building-office" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                Business
              </h1>
              <p class="mt-0.5 text-sm text-slate-500 dark:text-slate-400">
                Private, org-scoped circles for your team — end-to-end encrypted; Mosslet can't read them.
              </p>
            </div>
          </div>

          <.liquid_button
            :if={@live_action != :new && @businesses != [] && @can_create_business?}
            phx-click="show_new"
            id="new-business-button"
            color="emerald"
            icon="hero-plus"
            class="w-full sm:w-auto"
          >
            New business
          </.liquid_button>
        </header>

        <div
          :if={@live_action == :new}
          id="new-business-form-wrapper"
          class="mb-8 overflow-hidden rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-xl shadow-slate-900/5 dark:shadow-slate-900/30"
        >
          <div class="border-b border-slate-100 dark:border-slate-700/60 bg-gradient-to-r from-teal-50/60 to-emerald-50/40 dark:from-teal-900/10 dark:to-emerald-900/10 px-5 py-4">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Create a business
            </h2>
            <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
              Pick a name your team will recognize. You can invite teammates and create circles next.
            </p>
          </div>
          <.form for={@form} id="new-business-form" phx-submit="create_business" class="p-5">
            <.phx_input
              field={@form[:name]}
              type="text"
              label="Business name"
              placeholder="e.g. Acme Inc."
              required
            />
            <div class="mt-5 flex flex-col-reverse gap-2 sm:flex-row sm:items-center">
              <.link
                patch={~p"/app/business"}
                class="inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/60 transition-colors duration-200"
              >
                Cancel
              </.link>
              <.liquid_button
                type="submit"
                id="create-business-submit"
                color="emerald"
                icon="hero-sparkles"
                class="w-full sm:w-auto"
              >
                Create business
              </.liquid_button>
            </div>
          </.form>
        </div>

        <div
          :if={@businesses == [] && @live_action != :new}
          class="rounded-3xl border border-dashed border-slate-300/70 dark:border-slate-700/60 bg-white/50 dark:bg-slate-800/30 px-6 py-14 text-center"
        >
          <div class="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500/10 to-emerald-500/10 dark:from-teal-400/10 dark:to-emerald-400/10 ring-1 ring-inset ring-teal-500/20">
            <.phx_icon name="hero-building-office" class="h-8 w-8 text-teal-600 dark:text-teal-400" />
          </div>
          <h2 class="mt-5 text-lg font-semibold text-slate-900 dark:text-slate-100">
            Start your business workspace
          </h2>
          <p class="mx-auto mt-2 max-w-md text-sm text-slate-500 dark:text-slate-400">
            Create a business to invite teammates and set up private, org-scoped circles. Content
            stays end-to-end encrypted; Mosslet can't read it.
          </p>
          <.liquid_button
            phx-click="show_new"
            id="new-business-empty-button"
            color="emerald"
            icon="hero-plus"
            class="mt-6"
          >
            Create a business
          </.liquid_button>
        </div>

        <ul role="list" class="space-y-3">
          <li
            :for={business <- @businesses}
            id={"business-#{business.org.id}"}
            class={[
              "group relative overflow-hidden rounded-2xl border backdrop-blur-sm shadow-sm transition-all duration-200 ease-out",
              if(business.active?,
                do:
                  "border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 hover:shadow-lg hover:shadow-emerald-500/10 hover:border-emerald-300/60 dark:hover:border-emerald-700/50",
                else:
                  "border-amber-300/60 dark:border-amber-700/50 bg-amber-50/60 dark:bg-amber-900/10"
              )
            ]}
          >
            <.link
              :if={business.active?}
              navigate={~p"/app/business/#{business.org.slug}"}
              class="flex items-center gap-4 p-4"
            >
              <.org_logo
                id={"business-logo-#{business.org.id}"}
                encrypted_blob={business.logo_blob}
                sealed_org_key={business.sealed_org_key}
                frame_class="h-11 w-11 rounded-xl"
                alt={business.org.name <> " logo"}
              >
                <:fallback>
                  <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-600 dark:text-slate-300 transition-colors duration-200 group-hover:from-teal-100 group-hover:to-emerald-100 dark:group-hover:from-teal-900/40 dark:group-hover:to-emerald-900/40 group-hover:text-teal-700 dark:group-hover:text-teal-300">
                    <.phx_icon name="hero-building-office" class="h-5 w-5" />
                  </div>
                </:fallback>
              </.org_logo>
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                    {business.org.name}
                  </p>
                  <.business_role_badge role={business.membership.role} />
                </div>
                <p class="mt-0.5 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
                  <.phx_icon name="hero-user-group" class="size-3.5" />
                  {business.member_count} member{if business.member_count != 1, do: "s"}
                </p>
              </div>
              <.phx_icon
                name="hero-chevron-right"
                class="size-5 shrink-0 text-slate-300 dark:text-slate-600 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-teal-500 dark:group-hover:text-teal-400"
              />
            </.link>

            <%!-- Inert (unpaid) business: created but its `:org` plan isn't active
                  yet, so its content routes are gated (Option B, #235). Surface a
                  clear "Activate" card + name-reservation reminder instead of a
                  dead link that would just bounce to subscribe. --%>
            <div :if={!business.active?} id={"business-inert-#{business.org.id}"} class="p-4">
              <div class="flex items-start gap-4">
                <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/40 dark:to-orange-900/40 text-amber-700 dark:text-amber-300">
                  <.phx_icon name="hero-clock" class="h-5 w-5" />
                </div>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                      {business.org.name}
                    </p>
                    <span class="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/50 px-2 py-0.5 text-[11px] font-semibold text-amber-700 dark:text-amber-300">
                      <.phx_icon name="hero-pause-circle" class="size-3" /> Not active yet
                    </span>
                  </div>
                  <p class="mt-1 text-xs text-amber-700/90 dark:text-amber-300/90">
                    <%= if business.owner? do %>
                      We're holding the name <span class="font-semibold">{business.org.name}</span>
                      for you. Start your free trial to activate it, invite teammates, and create circles.
                    <% else %>
                      This business isn't active yet. Its owner needs to start the plan
                      before you can join.
                    <% end %>
                  </p>
                  <.liquid_button
                    :if={business.owner?}
                    navigate={~p"/app/org/#{business.org.slug}/subscribe"}
                    id={"business-activate-#{business.org.id}"}
                    color="amber"
                    size="sm"
                    class="mt-3 w-full sm:w-auto"
                    icon="hero-rocket-launch"
                  >
                    Activate &amp; start trial
                  </.liquid_button>
                </div>
              </div>
            </div>
          </li>
        </ul>

        <%!-- Quiet, secondary note about adding MORE businesses. Most people only
              want one, so this is intentionally low-key (no alarm box). When the
              first business is on a trial, the requirement is just that the plan
              becomes paid — by waiting for the trial to convert, or starting the
              paid plan early. (Task #214, Q1-B / #218.)

              A member-seat (invited into someone else's business, owns none) sees
              a different note: they can't spin up a free business off a seat the
              org pays for — starting their own is a separate, paid plan. (#224) --%>
        <p
          :if={
            @live_action != :new && @businesses != [] && !@can_create_business? && !@owns_business?
          }
          id="business-member-seat-note"
          class="mt-4 text-xs text-slate-400 dark:text-slate-500"
        >
          Want a business of your own? Starting one (separate from the organization
          you were invited to) is its own paid plan.
          <.link
            navigate={~p"/app/subscribe?#{%{plan: "business"}}"}
            class="font-medium text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 hover:underline"
          >
            Start a business plan
          </.link>
        </p>

        <p
          :if={@live_action != :new && @businesses != [] && !@can_create_business? && @owns_business?}
          id="business-upsell-note"
          class="mt-4 text-xs text-slate-400 dark:text-slate-500"
        >
          {add_business_note(@personal_billing)}
          <.link
            :if={@owned_business_slug}
            navigate={~p"/app/org/#{@owned_business_slug}/subscribe"}
            class="font-medium text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 hover:underline"
          >
            {add_business_link_text(@personal_billing)}
          </.link>
        </p>
      </div>
    </.layout>
    """
  end

  @impl true
  def handle_event("show_new", _params, socket) do
    if socket.assigns.can_create_business? do
      {:noreply, push_patch(socket, to: ~p"/app/business/new")}
    else
      {:noreply,
       put_flash(
         socket,
         :info,
         business_entitlement_message(socket.assigns.current_scope.user)
       )}
    end
  end

  @impl true
  def handle_event("create_business", %{"business" => %{"name" => name}}, socket) do
    current_user = socket.assigns.current_scope.user

    case Orgs.create_org(current_user, %{"name" => name, "type" => "business"}) do
      {:ok, org} ->
        Mosslet.Logs.log("orgs.create_business", %{
          user: current_user,
          org_id: org.id
        })

        {:noreply,
         socket
         |> put_flash(:success, "Business created")
         |> push_navigate(to: next_path_after_create(socket, org))}

      {:error, :business_entitlement_required} ->
        {:noreply,
         socket
         |> put_flash(:error, business_entitlement_message(current_user))
         |> push_patch(to: ~p"/app/business")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create business. Please try again.")}
    end
  end

  # Realtime org changes (Orgs pubsub): a teammate joining/leaving, role changes,
  # or coverage shifts should refresh the list (member counts) and the create
  # gating (button/upsell) without a reload. Re-subscribe in case the set of
  # orgs the user belongs to changed.
  @impl true
  def handle_info({:org_updated, _org_id}, socket) do
    socket = assign_businesses(socket)
    subscribe_to_businesses(socket)
    {:noreply, socket}
  end

  # Ignore unrelated process messages (e.g. Swoosh test email delivery).
  def handle_info(_message, socket), do: {:noreply, socket}

  # A newly created business org is INERT until its `:org` plan is purchased
  # (Option B, Task #235), so always route the owner to org-scoped checkout to
  # activate it — whether they arrived via guided onboarding or created it
  # directly. The org's content stays gated until the subscription is active.
  defp next_path_after_create(_socket, org) do
    ~p"/app/org/#{org.slug}/subscribe"
  end

  defp assign_businesses(socket) do
    current_user = socket.assigns.current_scope.user

    businesses =
      current_user
      |> Orgs.list_orgs()
      |> Enum.filter(&(&1.type == :business))
      |> Enum.map(fn org ->
        membership = Orgs.get_membership!(current_user, org.slug)
        members = Orgs.list_members_by_org(org)

        %{
          org: org,
          membership: membership,
          member_count: length(members),
          active?: Orgs.org_active?(org),
          owner?: Orgs.owner?(org, current_user.id),
          # Brand logo (Task #228, #349): the viewer decrypts it browser-side with
          # the org_key sealed for them in their membership row. The encrypted blob
          # is delivered inline (no cross-origin fetch) to the OrgLogoDisplay hook.
          logo_blob: Orgs.org_logo_blob_b64(org),
          sealed_org_key: membership.key
        }
      end)

    owned_business_slug =
      Enum.find_value(businesses, fn %{org: org} ->
        org.created_by_id == current_user.id && org.slug
      end)

    socket
    |> assign(:businesses, businesses)
    |> assign(:can_create_business?, Orgs.can_create_org?(current_user, :business))
    |> assign(:owns_business?, owned_business_slug != nil)
    |> assign(:owned_business_slug, owned_business_slug)
    |> assign(:personal_billing, personal_billing_context(current_user))
    |> assign(:form, to_form(%{"name" => ""}, as: :business))
  end

  # Subscribe to each business org's pubsub topic so member joins/leaves, role
  # changes, and coverage shifts update this list in realtime. Re-subscribing to
  # an already-subscribed topic is a no-op for the LiveView process.
  defp subscribe_to_businesses(socket) do
    Enum.each(socket.assigns.businesses, fn %{org: org} -> Orgs.subscribe_org(org) end)
  end

  # Summarizes the user's PERSONAL (`:user`-source) subscription so the upsell
  # can speak to it accurately. Returns one of:
  #
  #   * `{:trialing, plan_label}` — e.g. `{:trialing, "Business"}`
  #   * `{:active, plan_label}`
  #   * `nil`                     — no active/trialing personal subscription
  defp personal_billing_context(user) do
    with %{} = customer <- Mosslet.Billing.Customers.get_customer_by_source(:user, user.id),
         %{} = sub <-
           Mosslet.Billing.Subscriptions.get_active_subscription_by_customer_id(customer.id) do
      status = if sub.status == "trialing", do: :trialing, else: :active
      {status, personal_plan_label(sub.plan_id)}
    else
      _ -> nil
    end
  end

  defp personal_plan_label(plan_id) when is_binary(plan_id) do
    cond do
      String.starts_with?(plan_id, "business-") -> "Business"
      String.starts_with?(plan_id, "family-") -> "Family"
      true -> "Personal"
    end
  end

  defp personal_plan_label(_), do: "Personal"

  defp page_title(:new), do: "New business"
  defp page_title(_), do: "Business"

  # Tailors the "can't create" message: a member-seat (owns no business) is told
  # starting their own is a separate paid plan; an owner is told to put their
  # existing business on a paid plan first.
  defp business_entitlement_message(user) do
    if Mosslet.Orgs.count_owned_orgs(user, :business) > 0 do
      "Subscribe your current business to a paid plan before creating another."
    else
      "Starting your own business is a separate paid plan. Choose a business plan to begin."
    end
  end

  # Quiet note about adding ADDITIONAL businesses (most users only want one).
  # When the existing business is on a trial, it already has a plan — the only
  # requirement is that the plan be paid, so we frame it as "wait for the trial
  # to convert, or start it now" rather than "subscribe".
  defp add_business_note({:trialing, _plan}),
    do:
      "Want more than one business? Each additional business is billed separately, and your " <>
        "current one needs to be on a paid plan first — that happens automatically when your " <>
        "trial ends, or you can"

  defp add_business_note({:active, _plan}),
    do:
      "Want more than one business? Each additional business is billed separately. Subscribe " <>
        "your current business to unlock another —"

  defp add_business_note(_),
    do:
      "Want more than one business? Each additional business is billed separately. Subscribe " <>
        "your current business to unlock another —"

  defp add_business_link_text({:trialing, _plan}), do: "start your paid plan early"
  defp add_business_link_text(_), do: "manage billing"
end
