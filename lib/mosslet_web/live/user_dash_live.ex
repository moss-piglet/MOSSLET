defmodule MossletWeb.UserDashLive do
  @moduledoc """
  The personal dashboard — the signed-in "Home" at `/app`.

  For users who have created a profile, this renders a profile summary (reusing
  `MossletWeb.ProfileComponents.profile_hero/1` + `profile_header/1` in the
  owner's `:own` zero-knowledge variant), a "what's new" timeline teaser, quick
  actions, an at-a-glance pulse of live counts, and shortcuts to any Family /
  Business spaces they belong to. Users without a profile yet get a focused
  "create your profile" prompt (or an "unconfirmed account" notice).

  ## Zero-knowledge invariants

  All displayed identity (name/username/avatar) flows through the existing ZK
  paths: the `:own` server fast-path (`ProfileViewModel`) plus the
  `DecryptAvatar` hook for the banner. The dashboard's counts and org names are
  server-side metadata (counts are plaintext; org names use Cloak at-rest
  encryption, not per-user ZK) — no plaintext user content is read server-side
  and no sealed → server decryption is introduced.
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Conversations
  alias Mosslet.GroupMessages
  alias Mosslet.Groups
  alias Mosslet.Journal
  alias Mosslet.Orgs
  alias Mosslet.Timeline
  alias MossletWeb.UserHomeLive.ProfileViewModel

  import MossletWeb.DesignSystem

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    profile = current_user.connection.profile
    has_profile? = !!(profile && profile.slug)

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Groups.private_subscribe(current_user)
      Timeline.private_subscribe(current_user)
      Timeline.connections_subscribe(current_user)

      # Surface unread DMs + circle @mentions on the dashboard pulse. Subscribe to
      # the viewer's conversation topic (new/read DMs) and to each confirmed
      # circle's `group:` topic (new mentions or reads elsewhere), mirroring the
      # mention indicator (Task #281). Any of these refreshes the cheap COUNT
      # stats via `handle_info/2`. ZK-safe: payloads carry only UUIDs.
      Conversations.subscribe_to_user(current_user.id)

      Enum.each(confirmed_user_group_ids(current_user), fn {_ug_id, group_id} ->
        Phoenix.PubSub.subscribe(Mosslet.PubSub, "group:#{group_id}")
      end)
    end

    socket =
      socket
      |> assign(:page_title, "Home")
      |> assign(:has_profile?, has_profile?)
      |> maybe_assign_dashboard(has_profile?)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("onboard", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    key = socket.assigns.key

    case user.is_onboarded? do
      true ->
        {:noreply, socket}

      false ->
        case Accounts.update_user_onboarding(user, %{is_onboarded?: true},
               change_name: false,
               key: key,
               user: user
             ) do
          {:ok, _user} ->
            info = "Welcome! You've been onboarded successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> redirect(to: ~p"/app")}
        end
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    # Our mount subscriptions are scoped to this user's connections, circles, and
    # timeline. Any of those events can change the at-a-glance counts, so refresh
    # them (cheap COUNT queries) to keep the dashboard pulse live.
    socket =
      if socket.assigns.has_profile? do
        assign_dashboard_stats(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # ── Assigns ────────────────────────────────────────────────────────────────

  defp maybe_assign_dashboard(socket, false), do: socket

  defp maybe_assign_dashboard(socket, true) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    # Owner viewing their own profile: identity via the server fast-path, profile
    # detail fields sealed for the browser — exactly as the profile page builds.
    profile = ProfileViewModel.build(current_user, current_user, key, nil)

    socket
    |> assign(:profile, profile)
    |> assign(:profile_user, current_user)
    |> assign(:profile_slug, current_user.connection.profile.slug)
    |> maybe_load_custom_banner(current_user)
    |> assign_dashboard_stats()
    |> assign_org_spaces()
  end

  defp assign_dashboard_stats(socket) do
    user = socket.assigns.current_scope.user
    user_group_ids = confirmed_user_group_ids(user) |> Enum.map(&elem(&1, 0))

    stats = %{
      connections: length(Accounts.get_all_confirmed_user_connections(user.id)),
      pending_connections: Accounts.arrivals_count(user),
      circles: Groups.group_count_confirmed(user),
      pending_circles: length(Groups.list_unconfirmed_groups(user)),
      timeline_total: Timeline.count_home_timeline(user),
      timeline_unread: Timeline.count_unread_home_timeline(user),
      journal_entries: Journal.count_entries(user),
      unread_dms: Conversations.count_unread_messages(user.id),
      unread_mentions: GroupMessages.count_unread_mentions(user_group_ids)
    }

    assign(socket, :stats, stats)
  end

  # The viewer's CONFIRMED circle memberships as `{user_group_id, group_id}`
  # tuples — used both to subscribe to each circle's realtime topic and to count
  # unread @mentions. Server-authoritative; carries no ciphertext.
  defp confirmed_user_group_ids(user) do
    user
    |> Groups.list_user_groups_for_user()
    |> Enum.filter(& &1.confirmed_at)
    |> Enum.map(&{&1.id, &1.group_id})
  end

  defp assign_org_spaces(socket) do
    user = socket.assigns.current_scope.user

    spaces =
      user
      |> Orgs.list_orgs()
      |> Enum.map(fn org ->
        %{
          org: org,
          type: org.type,
          owner?: Orgs.owner?(org, user.id),
          active?: Orgs.org_active?(org)
        }
      end)

    socket
    |> assign(:families, Enum.filter(spaces, &(&1.type == :family)))
    |> assign(:businesses, Enum.filter(spaces, &(&1.type == :business)))
  end

  # Mirrors the profile page's banner loading (owner path only): a custom banner
  # is decrypted browser-side via the `DecryptAvatar` hook fed by this async
  # result; otherwise the static configured banner is used.
  defp maybe_load_custom_banner(socket, user) do
    profile = user.connection.profile

    if profile && profile.banner_image == :custom && Map.get(profile, :custom_banner_url) do
      key = socket.assigns.current_scope.key
      connection_id = user.connection.id

      case Mosslet.Extensions.BannerProcessor.get_banner(connection_id) do
        nil ->
          assign_async(socket, :custom_banner_src, fn ->
            {:ok, %{custom_banner_src: MossletWeb.Helpers.load_custom_banner(user, profile, key)}}
          end)

        cached_encrypted_binary ->
          assign_async(socket, :custom_banner_src, fn ->
            {:ok,
             %{
               custom_banner_src:
                 MossletWeb.Helpers.encrypted_banner_data(cached_encrypted_binary, user.conn_key)
             }}
          end)
      end
    else
      assign(socket, :custom_banner_src, %Phoenix.LiveView.AsyncResult{ok?: true, result: nil})
    end
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <%= if @has_profile? do %>
        <.dashboard_home
          profile={@profile}
          profile_user={@profile_user}
          profile_slug={@profile_slug}
          current_scope={@current_scope}
          custom_banner_src={@custom_banner_src}
          stats={@stats}
          families={@families}
          businesses={@businesses}
        />
      <% else %>
        <.dashboard_onboarding current_scope={@current_scope} />
      <% end %>
    </.layout>
    """
  end

  # ── Full dashboard (profile exists) ──────────────────────────────────────────

  attr :profile, :map, required: true
  attr :profile_user, :map, required: true
  attr :profile_slug, :string, required: true
  attr :current_scope, :map, required: true
  attr :custom_banner_src, :any, required: true
  attr :stats, :map, required: true
  attr :families, :list, required: true
  attr :businesses, :list, required: true

  defp dashboard_home(assigns) do
    ~H"""
    <div id="dashboard-home">
      <h1 class="sr-only">Home</h1>

      <%!-- Profile summary: reuses the profile hero + header in the owner ZK variant --%>
      <div class="relative overflow-hidden">
        <MossletWeb.ProfileComponents.profile_hero
          access={@profile.access}
          connection={@profile_user.connection}
          custom_banner_src={@custom_banner_src}
        />
        <MossletWeb.ProfileComponents.profile_header
          profile={@profile}
          profile_user={@profile_user}
          current_scope={@current_scope}
        />
      </div>

      <.liquid_container class="py-10 space-y-10">
        <%!-- Smart nudges --%>
        <div
          :if={
            @stats.pending_connections > 0 || @stats.pending_circles > 0 ||
              @stats.unread_dms > 0 || @stats.unread_mentions > 0
          }
          class="grid gap-4 sm:grid-cols-2"
        >
          <.link
            :if={@stats.pending_connections > 0}
            navigate={~p"/app/users/connections/greet"}
            id="nudge-connection-requests"
            class="group flex items-center gap-4 rounded-2xl border border-amber-200/70 dark:border-amber-800/50 bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-950/40 dark:to-orange-950/30 p-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-amber-500/10"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-400 to-orange-500 shadow-md shadow-amber-500/30">
              <.phx_icon name="hero-user-plus" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-amber-900 dark:text-amber-100">
                {pluralize(
                  @stats.pending_connections,
                  "new connection request",
                  "new connection requests"
                )}
              </p>
              <p class="text-xs text-amber-700/80 dark:text-amber-300/70">Tap to review and greet</p>
            </div>
            <.phx_icon
              name="hero-chevron-right"
              class="size-5 text-amber-500 transition-transform duration-300 group-hover:translate-x-0.5"
            />
          </.link>

          <.link
            :if={@stats.pending_circles > 0}
            navigate={~p"/app/circles"}
            id="nudge-circle-invites"
            class="group flex items-center gap-4 rounded-2xl border border-violet-200/70 dark:border-violet-800/50 bg-gradient-to-br from-violet-50 to-fuchsia-50 dark:from-violet-950/40 dark:to-fuchsia-950/30 p-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-violet-500/10"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-400 to-fuchsia-500 shadow-md shadow-violet-500/30">
              <.phx_icon name="hero-user-group" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-violet-900 dark:text-violet-100">
                {pluralize(@stats.pending_circles, "circle invitation", "circle invitations")}
              </p>
              <p class="text-xs text-violet-700/80 dark:text-violet-300/70">
                Tap to view your circles
              </p>
            </div>
            <.phx_icon
              name="hero-chevron-right"
              class="size-5 text-violet-500 transition-transform duration-300 group-hover:translate-x-0.5"
            />
          </.link>

          <%!-- Unread DMs --%>
          <.link
            :if={@stats.unread_dms > 0}
            navigate={~p"/app/conversations"}
            id="nudge-unread-dms"
            class="group flex items-center gap-4 rounded-2xl border border-teal-200/70 dark:border-teal-800/50 bg-gradient-to-br from-teal-50 to-emerald-50 dark:from-teal-950/40 dark:to-emerald-950/30 p-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-teal-500/10"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-400 to-emerald-500 shadow-md shadow-teal-500/30">
              <.phx_icon name="hero-chat-bubble-left-right" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-teal-900 dark:text-teal-100">
                {pluralize(@stats.unread_dms, "unread message", "unread messages")}
              </p>
              <p class="text-xs text-teal-700/80 dark:text-teal-300/70">
                Tap to open your conversations
              </p>
            </div>
            <.phx_icon
              name="hero-chevron-right"
              class="size-5 text-teal-500 transition-transform duration-300 group-hover:translate-x-0.5"
            />
          </.link>

          <%!-- Unread @mentions across circles --%>
          <.link
            :if={@stats.unread_mentions > 0}
            navigate={~p"/app/circles"}
            id="nudge-unread-mentions"
            class="group flex items-center gap-4 rounded-2xl border border-indigo-200/70 dark:border-indigo-800/50 bg-gradient-to-br from-indigo-50 to-violet-50 dark:from-indigo-950/40 dark:to-violet-950/30 p-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-indigo-500/10"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-400 to-violet-500 shadow-md shadow-indigo-500/30">
              <.phx_icon name="hero-at-symbol" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-indigo-900 dark:text-indigo-100">
                {pluralize(@stats.unread_mentions, "new mention", "new mentions")}
              </p>
              <p class="text-xs text-indigo-700/80 dark:text-indigo-300/70">
                Someone tagged you in a circle
              </p>
            </div>
            <.phx_icon
              name="hero-chevron-right"
              class="size-5 text-indigo-500 transition-transform duration-300 group-hover:translate-x-0.5"
            />
          </.link>
        </div>

        <%!-- What's new in your timeline --%>
        <.link navigate={~p"/app/timeline"} id="dash-whats-new" class="group block">
          <div class="relative overflow-hidden rounded-3xl bg-gradient-to-br from-teal-500 via-emerald-500 to-cyan-500 p-6 sm:p-8 shadow-xl shadow-emerald-500/20 transition-all duration-300 group-hover:shadow-2xl group-hover:shadow-emerald-500/30">
            <div class="absolute inset-0 opacity-20">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent -skew-x-12 transform-gpu transition-transform duration-700 group-hover:translate-x-full -translate-x-full">
              </div>
            </div>
            <div class="relative flex items-center justify-between gap-4">
              <div class="min-w-0">
                <p class="text-sm font-medium text-white/80">Your timeline</p>
                <p class="mt-1 text-2xl sm:text-3xl font-bold text-white">
                  <%= if @stats.timeline_unread > 0 do %>
                    {pluralize(@stats.timeline_unread, "new post", "new posts")}
                  <% else %>
                    You're all caught up
                  <% end %>
                </p>
                <p class="mt-1 text-sm text-white/80">
                  <%= if @stats.timeline_unread > 0 do %>
                    Fresh updates from your connections are waiting.
                  <% else %>
                    Share something or see what your connections are up to.
                  <% end %>
                </p>
              </div>
              <div class="flex size-14 shrink-0 items-center justify-center rounded-2xl bg-white/20 backdrop-blur-sm ring-1 ring-white/30 transition-transform duration-300 group-hover:scale-105">
                <.phx_icon name="hero-arrow-right" class="size-6 text-white" />
              </div>
            </div>
          </div>
        </.link>

        <%!-- Quick actions --%>
        <section aria-labelledby="dash-quick-actions-title">
          <h2
            id="dash-quick-actions-title"
            class="mb-4 text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400"
          >
            Quick actions
          </h2>
          <div class="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
            <.dash_action
              navigate={~p"/app/timeline?compose=1"}
              icon="hero-pencil-square"
              icon_bg="bg-gradient-to-br from-teal-500 to-emerald-600 shadow-emerald-500/30"
              title="New post"
            />
            <.dash_action
              navigate={~p"/app/timeline"}
              icon="hero-rectangle-stack"
              icon_bg="bg-gradient-to-br from-emerald-500 to-cyan-600 shadow-cyan-500/30"
              title="Timeline"
            />
            <.dash_action
              navigate={~p"/app/users/connections"}
              icon="hero-users"
              icon_bg="bg-gradient-to-br from-cyan-500 to-blue-600 shadow-blue-500/30"
              title="Connections"
            />
            <.dash_action
              navigate={~p"/app/circles"}
              icon="hero-user-group"
              icon_bg="bg-gradient-to-br from-blue-500 to-indigo-600 shadow-indigo-500/30"
              title="Circles"
            />
            <.dash_action
              navigate={~p"/app/journal"}
              icon="hero-book-open"
              icon_bg="bg-gradient-to-br from-violet-500 to-fuchsia-600 shadow-violet-500/30"
              title="Journal"
            />
            <.dash_action
              navigate={~p"/app/profile/#{@profile_slug}"}
              icon="hero-identification"
              icon_bg="bg-gradient-to-br from-fuchsia-500 to-pink-600 shadow-pink-500/30"
              title="My profile"
            />
          </div>
        </section>

        <%!-- At-a-glance --%>
        <section aria-labelledby="dash-glance-title">
          <h2
            id="dash-glance-title"
            class="mb-4 text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400"
          >
            At a glance
          </h2>
          <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
            <.dash_stat
              navigate={~p"/app/users/connections"}
              icon="hero-users"
              icon_class="text-teal-600 dark:text-teal-400"
              icon_bg="bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30"
              label="Connections"
              value={@stats.connections}
              badge={@stats.pending_connections}
              badge_suffix="pending"
            />
            <.dash_stat
              navigate={~p"/app/circles"}
              icon="hero-user-group"
              icon_class="text-blue-600 dark:text-blue-400"
              icon_bg="bg-gradient-to-br from-blue-100 to-indigo-100 dark:from-blue-900/30 dark:to-indigo-900/30"
              label="Circles"
              value={@stats.circles}
              badge={@stats.pending_circles}
              badge_suffix="invites"
            />
            <.dash_stat
              navigate={~p"/app/timeline"}
              icon="hero-rectangle-stack"
              icon_class="text-cyan-600 dark:text-cyan-400"
              icon_bg="bg-gradient-to-br from-cyan-100 to-sky-100 dark:from-cyan-900/30 dark:to-sky-900/30"
              label="Timeline posts"
              value={@stats.timeline_total}
              badge={@stats.timeline_unread}
              badge_suffix="new"
            />
            <.dash_stat
              navigate={~p"/app/journal"}
              icon="hero-book-open"
              icon_class="text-violet-600 dark:text-violet-400"
              icon_bg="bg-gradient-to-br from-violet-100 to-fuchsia-100 dark:from-violet-900/30 dark:to-fuchsia-900/30"
              label="Journal entries"
              value={@stats.journal_entries}
            />
          </div>
        </section>

        <%!-- Your spaces (Family / Business) --%>
        <section :if={@families != [] || @businesses != []} aria-labelledby="dash-spaces-title">
          <h2
            id="dash-spaces-title"
            class="mb-4 text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400"
          >
            Your spaces
          </h2>
          <div class="grid gap-4 sm:grid-cols-2">
            <.dash_space
              :for={family <- @families}
              navigate={~p"/app/family/#{family.org.slug}"}
              id={"dash-family-#{family.org.id}"}
              icon="hero-heart"
              icon_bg="bg-gradient-to-br from-rose-400 to-pink-500 shadow-rose-500/30"
              name={family.org.name}
              kind="Family"
              owner?={family.owner?}
              active?={family.active?}
            />
            <.dash_space
              :for={business <- @businesses}
              navigate={~p"/app/business/#{business.org.slug}"}
              id={"dash-business-#{business.org.id}"}
              icon="hero-building-office-2"
              icon_bg="bg-gradient-to-br from-slate-500 to-slate-700 shadow-slate-500/30"
              name={business.org.name}
              kind="Business"
              owner?={business.owner?}
              active?={business.active?}
            />
          </div>
        </section>
      </.liquid_container>
    </div>
    """
  end

  # ── Dashboard sub-components ──────────────────────────────────────────────────

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, required: true
  attr :title, :string, required: true

  defp dash_action(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="group flex flex-col items-center gap-3 rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm p-4 text-center shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 transition-all duration-300 hover:-translate-y-1 hover:border-emerald-300/70 dark:hover:border-emerald-600/50 hover:shadow-xl hover:shadow-emerald-500/10"
    >
      <div class={[
        "flex size-12 items-center justify-center rounded-xl shadow-md transition-transform duration-300 group-hover:scale-110",
        @icon_bg
      ]}>
        <.phx_icon name={@icon} class="size-6 text-white" />
      </div>
      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{@title}</span>
    </.link>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, required: true
  attr :icon_class, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :badge, :integer, default: 0
  attr :badge_suffix, :string, default: nil

  defp dash_stat(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="group block rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm p-5 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl hover:shadow-emerald-500/10 hover:border-emerald-300/70 dark:hover:border-emerald-600/50"
    >
      <div class="flex items-center justify-between">
        <div class={[
          "flex size-10 items-center justify-center rounded-xl transition-transform duration-300 group-hover:scale-110",
          @icon_bg
        ]}>
          <.phx_icon name={@icon} class={["size-5", @icon_class]} />
        </div>
        <span
          :if={@badge > 0 && @badge_suffix}
          class="inline-flex items-center rounded-full bg-emerald-100 dark:bg-emerald-900/40 px-2 py-0.5 text-xs font-semibold text-emerald-700 dark:text-emerald-300"
        >
          {@badge} {@badge_suffix}
        </span>
      </div>
      <p class="mt-4 text-3xl font-bold text-slate-900 dark:text-slate-100">{@value}</p>
      <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">{@label}</p>
    </.link>
    """
  end

  attr :navigate, :string, required: true
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :icon_bg, :string, required: true
  attr :name, :string, required: true
  attr :kind, :string, required: true
  attr :owner?, :boolean, default: false
  attr :active?, :boolean, default: false

  defp dash_space(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      id={@id}
      class="group flex items-center gap-4 rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm p-4 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-xl hover:border-emerald-300/70 dark:hover:border-emerald-600/50"
    >
      <div class={[
        "flex size-12 shrink-0 items-center justify-center rounded-xl shadow-md transition-transform duration-300 group-hover:scale-105",
        @icon_bg
      ]}>
        <.phx_icon name={@icon} class="size-6 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2">
          <p class="truncate font-semibold text-slate-900 dark:text-slate-100">{@name}</p>
          <span
            :if={@owner?}
            class="inline-flex items-center rounded-full bg-teal-100 dark:bg-teal-900/40 px-2 py-0.5 text-xs font-medium text-teal-700 dark:text-teal-300"
          >
            Owner
          </span>
        </div>
        <p class="mt-0.5 flex items-center gap-1.5 text-xs text-slate-500 dark:text-slate-400">
          {@kind}
          <span :if={!@active?} class="text-amber-600 dark:text-amber-400">· inactive</span>
        </p>
      </div>
      <.phx_icon
        name="hero-chevron-right"
        class="size-5 text-slate-400 transition-transform duration-300 group-hover:translate-x-0.5"
      />
    </.link>
    """
  end

  # ── Onboarding (no profile yet) ──────────────────────────────────────────────

  attr :current_scope, :map, required: true

  defp dashboard_onboarding(assigns) do
    ~H"""
    <.liquid_container class="py-8">
      <h1 class="sr-only">Home</h1>

      <%!-- Profile creation prompt for confirmed users without a profile --%>
      <div
        :if={
          is_nil(@current_scope.user.connection.profile) ||
            (is_nil(@current_scope.user.connection.profile.slug) &&
               @current_scope.user.confirmed_at)
        }
        class="mb-8"
      >
        <.liquid_card padding="lg" class="max-w-2xl mx-auto">
          <div class="text-center space-y-6">
            <div class="flex size-16 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 mx-auto">
              <.phx_icon name="hero-user-circle" class="size-8 text-white" />
            </div>
            <div>
              <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
                Create your profile
              </h2>
              <p class="text-slate-600 dark:text-slate-400">
                Get started by setting up your profile to connect with others.
              </p>
            </div>
            <.liquid_button
              phx-click={JS.navigate(~p"/app/users/edit-profile")}
              variant="primary"
              color="teal"
              size="lg"
              icon="hero-plus"
            >
              Create Profile
            </.liquid_button>
          </div>
        </.liquid_card>
      </div>

      <%!-- Unconfirmed account notice --%>
      <div
        :if={
          (is_nil(@current_scope.user.connection.profile) ||
             is_nil(@current_scope.user.connection.profile.slug)) &&
            !@current_scope.user.confirmed_at
        }
        class="my-5 max-w-prose rounded-lg border border-amber-300 bg-amber-50 dark:border-amber-700 dark:bg-amber-950/40 p-4 text-amber-800 dark:text-amber-200"
        role="alert"
      >
        <p class="font-semibold">{gettext("🤫 Unconfirmed account")}</p>
        <p class="mt-1 text-sm">
          {gettext(
            "Please check your email for a confirmation link or click the button below to enter your email and send another. Once your email has been confirmed then you can get started creating your profile! 🥳"
          )}
        </p>
        <.liquid_button
          variant="secondary"
          color="amber"
          class="mt-4"
          phx-click={JS.patch(~p"/auth/confirm")}
        >
          Confirm my account
        </.liquid_button>
      </div>
    </.liquid_container>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp pluralize(1, singular, _plural), do: "1 #{singular}"
  defp pluralize(count, _singular, plural), do: "#{count} #{plural}"
end
