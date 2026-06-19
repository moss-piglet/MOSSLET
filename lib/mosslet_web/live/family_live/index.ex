defmodule MossletWeb.FamilyLive.Index do
  @moduledoc """
  Lists the current user's Family orgs and lets them create a new one.

  Family orgs (`type: :family`) power consent-based guardianship. See
  `docs/GUARDIANSHIP_DESIGN.md`.
  """
  use MossletWeb, :live_view

  alias Mosslet.Orgs

  @impl true
  def mount(_params, _session, socket) do
    socket = assign_families(socket)
    if connected?(socket), do: subscribe_to_families(socket)
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
      current_page={:family}
      sidebar_current_page={:family}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10">
        <header class="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-heart" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                Family
              </h1>
              <p class="mt-0.5 text-sm text-slate-500 dark:text-slate-400">
                Consent-based guardianship — read your family's posts &amp; messages with your own key.
              </p>
            </div>
          </div>

          <.phx_button
            :if={@live_action != :new && @families != [] && @can_create_family?}
            phx-click="show_new"
            id="new-family-button"
            class="w-full sm:w-auto"
          >
            <.phx_icon name="hero-plus" class="size-4 mr-1.5" /> New family
          </.phx_button>
        </header>

        <div
          :if={@live_action == :new}
          id="new-family-form-wrapper"
          class="mb-8 overflow-hidden rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-xl shadow-slate-900/5 dark:shadow-slate-900/30"
        >
          <div class="border-b border-slate-100 dark:border-slate-700/60 bg-gradient-to-r from-teal-50/60 to-emerald-50/40 dark:from-teal-900/10 dark:to-emerald-900/10 px-5 py-4">
            <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
              Create a family
            </h2>
            <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
              Pick a name only you and your members will see. You can invite members next.
            </p>
          </div>
          <.form for={@form} id="new-family-form" phx-submit="create_family" class="p-5">
            <.phx_input
              field={@form[:name]}
              type="text"
              label="Family name"
              placeholder="e.g. The Smiths"
              required
            />
            <div class="mt-5 flex flex-col-reverse gap-2 sm:flex-row sm:items-center">
              <.link
                patch={~p"/app/family"}
                class="inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700/60 transition-colors duration-200"
              >
                Cancel
              </.link>
              <.phx_button type="submit" id="create-family-submit" class="w-full sm:w-auto">
                <.phx_icon name="hero-sparkles" class="size-4 mr-1.5" /> Create family
              </.phx_button>
            </div>
          </.form>
        </div>

        <div
          :if={@families == [] && @live_action != :new}
          class="rounded-3xl border border-dashed border-slate-300/70 dark:border-slate-700/60 bg-white/50 dark:bg-slate-800/30 px-6 py-14 text-center"
        >
          <div class="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500/10 to-emerald-500/10 dark:from-teal-400/10 dark:to-emerald-400/10 ring-1 ring-inset ring-teal-500/20">
            <.phx_icon name="hero-heart" class="h-8 w-8 text-teal-600 dark:text-teal-400" />
          </div>
          <h2 class="mt-5 text-lg font-semibold text-slate-900 dark:text-slate-100">
            Start your family space
          </h2>
          <p class="mx-auto mt-2 max-w-md text-sm text-slate-500 dark:text-slate-400">
            Create a family to invite members and set up consent-based guardianship — stay in the
            loop without surveillance. Content stays end-to-end encrypted; Mosslet can't read it.
          </p>
          <.phx_button phx-click="show_new" id="new-family-empty-button" class="mt-6">
            <.phx_icon name="hero-plus" class="size-4 mr-1.5" /> Create a family
          </.phx_button>
        </div>

        <ul role="list" class="space-y-3">
          <li
            :for={family <- @families}
            id={"family-#{family.org.id}"}
            class={[
              "group relative overflow-hidden rounded-2xl border backdrop-blur-sm shadow-sm transition-all duration-200 ease-out",
              if(family.active?,
                do:
                  "border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 hover:shadow-lg hover:shadow-emerald-500/10 hover:border-emerald-300/60 dark:hover:border-emerald-700/50",
                else:
                  "border-amber-300/60 dark:border-amber-700/50 bg-amber-50/60 dark:bg-amber-900/10"
              )
            ]}
          >
            <.link
              :if={family.active?}
              navigate={~p"/app/family/#{family.org.slug}"}
              class="flex items-center gap-4 p-4"
            >
              <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-600 dark:text-slate-300 transition-colors duration-200 group-hover:from-teal-100 group-hover:to-emerald-100 dark:group-hover:from-teal-900/40 dark:group-hover:to-emerald-900/40 group-hover:text-teal-700 dark:group-hover:text-teal-300">
                <.phx_icon name="hero-heart" class="h-5 w-5" />
              </div>
              <div class="min-w-0 flex-1">
                <div class="flex flex-wrap items-center gap-2">
                  <p class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                    {family.org.name}
                  </p>
                  <.family_role_badge role={family.membership.role} />
                </div>
                <p class="mt-0.5 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
                  <.phx_icon name="hero-user-group" class="size-3.5" />
                  {family.member_count} member{if family.member_count != 1, do: "s"}
                </p>
              </div>
              <.phx_icon
                name="hero-chevron-right"
                class="size-5 shrink-0 text-slate-300 dark:text-slate-600 transition-all duration-200 group-hover:translate-x-0.5 group-hover:text-teal-500 dark:group-hover:text-teal-400"
              />
            </.link>

            <%!-- Inert (unpaid) family: created but its `:org` plan isn't active
                  yet, so its content routes are gated (Option B, #235). Surface a
                  clear "Activate" card + name-reservation reminder instead of a
                  dead link that would just bounce to subscribe. --%>
            <div :if={!family.active?} id={"family-inert-#{family.org.id}"} class="p-4">
              <div class="flex items-start gap-4">
                <div class="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/40 dark:to-orange-900/40 text-amber-700 dark:text-amber-300">
                  <.phx_icon name="hero-clock" class="h-5 w-5" />
                </div>
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="font-semibold text-slate-900 dark:text-slate-100 truncate">
                      {family.org.name}
                    </p>
                    <span class="inline-flex items-center gap-1 rounded-full bg-amber-100 dark:bg-amber-900/50 px-2 py-0.5 text-[11px] font-semibold text-amber-700 dark:text-amber-300">
                      <.phx_icon name="hero-pause-circle" class="size-3" /> Not active yet
                    </span>
                  </div>
                  <p class="mt-1 text-xs text-amber-700/90 dark:text-amber-300/90">
                    <%= if family.owner? do %>
                      We're holding the name <span class="font-semibold">{family.org.name}</span>
                      for you. Start your free trial to activate it and invite members.
                    <% else %>
                      This family isn't active yet. Its owner needs to start the plan
                      before you can join.
                    <% end %>
                  </p>
                  <.liquid_button
                    :if={family.owner?}
                    navigate={~p"/app/org/#{family.org.slug}/subscribe"}
                    id={"family-activate-#{family.org.id}"}
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

        <%!-- A family member-seat (invited into someone else's family, owns
              none) can't create a free family off a seat the org pays for —
              starting their own is a separate, paid plan. (#224) --%>
        <p
          :if={@live_action != :new && @families != [] && !@can_create_family? && !@owns_family?}
          id="family-member-seat-note"
          class="mt-4 text-xs text-slate-400 dark:text-slate-500"
        >
          Want a family space of your own? Starting one (separate from the family
          you were invited to) is its own paid plan.
          <.link
            navigate={~p"/app/subscribe?#{%{plan: "family"}}"}
            class="font-medium text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 hover:underline"
          >
            Start a family plan
          </.link>
        </p>
      </div>
    </.layout>
    """
  end

  @impl true
  def handle_event("show_new", _params, socket) do
    if socket.assigns.can_create_family? do
      {:noreply, push_patch(socket, to: ~p"/app/family/new")}
    else
      {:noreply,
       put_flash(socket, :info, family_blocked_message(socket.assigns.current_scope.user))}
    end
  end

  @impl true
  def handle_event("create_family", %{"family" => %{"name" => name}}, socket) do
    current_user = socket.assigns.current_scope.user

    case Orgs.create_org(current_user, %{"name" => name, "type" => "family"}) do
      {:ok, org} ->
        Mosslet.Logs.log("orgs.create_family", %{
          user: current_user,
          org_id: org.id
        })

        {:noreply,
         socket
         |> put_flash(:success, "Family created")
         |> push_navigate(to: next_path_after_create(socket, org))}

      {:error, :family_limit_reached} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You can only own one family. Manage your existing family instead."
         )
         |> push_patch(to: ~p"/app/family")}

      {:error, :family_entitlement_required} ->
        {:noreply,
         socket
         |> put_flash(
           :warning,
           "Starting your own family is a separate paid plan. Choose a family plan to begin."
         )
         |> push_navigate(to: ~p"/app/subscribe?#{%{plan: "family"}}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not create family. Please try again.")}
    end
  end

  # Realtime org changes (Orgs pubsub): a member joining/leaving, role changes,
  # or coverage shifts refresh the list (member counts) and create gating
  # without a reload. Re-subscribe in case the user's set of orgs changed.
  @impl true
  def handle_info({:org_updated, _org_id}, socket) do
    socket = assign_families(socket)
    subscribe_to_families(socket)
    {:noreply, socket}
  end

  # Ignore unrelated process messages (e.g. Swoosh test email delivery).
  def handle_info(_message, socket), do: {:noreply, socket}

  # A newly created family org is INERT until its `:org` plan is purchased
  # (Option B, Task #235), so always route the owner to org-scoped checkout to
  # activate it — whether they arrived via guided onboarding or created it
  # directly. The org's content stays gated until the subscription is active.
  defp next_path_after_create(_socket, org) do
    ~p"/app/org/#{org.slug}/subscribe"
  end

  defp assign_families(socket) do
    current_user = socket.assigns.current_scope.user

    families =
      current_user
      |> Orgs.list_orgs()
      |> Enum.filter(&(&1.type == :family))
      |> Enum.map(fn org ->
        membership = Orgs.get_membership!(current_user, org.slug)
        members = Orgs.list_members_by_org(org)

        %{
          org: org,
          membership: membership,
          member_count: length(members),
          active?: Orgs.org_active?(org),
          owner?: Orgs.owner?(org, current_user.id)
        }
      end)

    socket
    |> assign(:families, families)
    |> assign(:can_create_family?, Orgs.can_create_org?(current_user, :family))
    |> assign(:owns_family?, Orgs.count_owned_orgs(current_user, :family) > 0)
    |> assign(:form, to_form(%{"name" => ""}, as: :family))
  end

  # Subscribe to each family org's pubsub topic so member joins/leaves and role
  # changes update this list in realtime. Re-subscribing is a no-op.
  defp subscribe_to_families(socket) do
    Enum.each(socket.assigns.families, fn %{org: org} -> Orgs.subscribe_org(org) end)
  end

  # A member-seat (invited into a family, owns none) can't spin up a free family
  # off a seat the org pays for; an owner is already capped at one family.
  defp family_blocked_message(user) do
    if Orgs.count_owned_orgs(user, :family) > 0 do
      "You already own a family. Each account can own one family."
    else
      "Starting your own family is a separate paid plan. Choose a family plan to begin."
    end
  end

  defp page_title(:new), do: "New family"
  defp page_title(_), do: "Family"
end
