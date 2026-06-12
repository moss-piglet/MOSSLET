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
    {:ok, assign_businesses(socket)}
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

          <.phx_button
            :if={@live_action != :new && @businesses != [] && @can_create_business?}
            phx-click="show_new"
            id="new-business-button"
            class="w-full sm:w-auto"
          >
            <.phx_icon name="hero-plus" class="size-4 mr-1.5" /> New business
          </.phx_button>
        </header>

        <%!-- Multi-business upsell: the first business is free; creating another
              requires every business you already own to be on an active paid plan
              (Task #214, Q1-B). --%>
        <div
          :if={@live_action != :new && @businesses != [] && !@can_create_business?}
          id="business-upsell"
          class="mb-8 rounded-2xl border border-amber-200/70 dark:border-amber-700/40 bg-gradient-to-br from-amber-50/80 to-orange-50/50 dark:from-amber-900/15 dark:to-orange-900/10 p-5"
        >
          <div class="flex items-start gap-3">
            <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-500 to-orange-500 shadow-sm">
              <.phx_icon name="hero-sparkles" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <h2 class="text-sm font-semibold text-amber-900 dark:text-amber-200">
                Want another business workspace?
              </h2>
              <p class="mt-1 text-sm text-amber-800/80 dark:text-amber-300/80">
                Your first business is free. To open an additional business, your current
                business needs an active paid plan. Subscribe your existing business, then come
                back to create another.
              </p>
              <div class="mt-3 flex flex-wrap gap-2">
                <.link
                  :for={business <- @businesses}
                  navigate={~p"/app/org/#{business.org.slug}/subscribe"}
                  class="inline-flex items-center gap-1.5 rounded-full bg-amber-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-amber-700 transition-colors duration-200"
                >
                  <.phx_icon name="hero-credit-card" class="size-3.5" /> Subscribe {business.org.name}
                </.link>
              </div>
            </div>
          </div>
        </div>

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
              <.phx_button type="submit" id="create-business-submit" class="w-full sm:w-auto">
                <.phx_icon name="hero-sparkles" class="size-4 mr-1.5" /> Create business
              </.phx_button>
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
          <.phx_button phx-click="show_new" id="new-business-empty-button" class="mt-6">
            <.phx_icon name="hero-plus" class="size-4 mr-1.5" /> Create a business
          </.phx_button>
        </div>

        <ul role="list" class="space-y-3">
          <li
            :for={business <- @businesses}
            id={"business-#{business.org.id}"}
            class="group relative overflow-hidden rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm transition-all duration-200 ease-out hover:shadow-lg hover:shadow-emerald-500/10 hover:border-emerald-300/60 dark:hover:border-emerald-700/50"
          >
            <.link
              navigate={~p"/app/business/#{business.org.slug}"}
              class="flex items-center gap-4 p-4"
            >
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-600 dark:text-slate-300 transition-colors duration-200 group-hover:from-teal-100 group-hover:to-emerald-100 dark:group-hover:from-teal-900/40 dark:group-hover:to-emerald-900/40 group-hover:text-teal-700 dark:group-hover:text-teal-300">
                <.phx_icon name="hero-building-office" class="h-5 w-5" />
              </div>
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
          </li>
        </ul>
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
         "Subscribe your current business to a paid plan before creating another."
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
         |> put_flash(
           :error,
           "Subscribe your current business to a paid plan before creating another."
         )
         |> push_patch(to: ~p"/app/business")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create business. Please try again.")}
    end
  end

  # After creating a business from the guided onboarding step, take the user
  # straight to org-scoped checkout so billing ties to the real org. Otherwise
  # land on the new business's dashboard.
  defp next_path_after_create(socket, org) do
    if socket.assigns[:onboarding?] do
      ~p"/app/org/#{org.slug}/subscribe"
    else
      ~p"/app/business/#{org.slug}"
    end
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

        %{org: org, membership: membership, member_count: length(members)}
      end)

    socket
    |> assign(:businesses, businesses)
    |> assign(:can_create_business?, Orgs.can_create_org?(current_user, :business))
    |> assign(:form, to_form(%{"name" => ""}, as: :business))
  end

  defp page_title(:new), do: "New business"
  defp page_title(_), do: "Business"
end
