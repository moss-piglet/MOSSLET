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
  alias Mosslet.Capsules
  alias Mosslet.Conversations
  alias Mosslet.GroupMessages
  alias Mosslet.Groups
  alias Mosslet.Journal
  alias Mosslet.Orgs
  alias Mosslet.Timeline
  alias MossletWeb.UserHomeLive.ProfileViewModel

  import MossletWeb.DesignSystem

  # Slow, calm cadence for refreshing the content-free "connections are around"
  # hint (EPIC #377, task #381). We deliberately do NOT react to the global
  # presence join/leave stream (that would mean reacting to the whole online set
  # and would flap on tab refreshes); instead we recompute on a gentle timer.
  @around_refresh_ms 60_000

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

      # Surface unread replies on the dashboard ("New replies" card). The
      # user-scoped topics carry connection/private reply activity; the public
      # "replies" topic covers replies to the viewer's PUBLIC posts. Reply
      # events are filtered for relevance in handle_info/2 before refreshing —
      # irrelevant global chatter never touches the DB. ZK-safe: payloads
      # carry only UUIDs + ciphertext.
      Timeline.private_reply_subscribe(current_user)
      Timeline.connections_reply_subscribe(current_user)
      Timeline.reply_subscribe()

      # Surface unread DMs + circle @mentions on the dashboard pulse. Subscribe to
      # the viewer's conversation topic (new/read DMs) and to each confirmed
      # circle's `group:` topic (new mentions or reads elsewhere), mirroring the
      # mention indicator (Task #281). Any of these refreshes the cheap COUNT
      # stats via `handle_info/2`. ZK-safe: payloads carry only UUIDs.
      Conversations.subscribe_to_user(current_user.id)

      Enum.each(confirmed_user_group_ids(current_user), fn {_ug_id, group_id} ->
        Phoenix.PubSub.subscribe(Mosslet.PubSub, "group:#{group_id}")
      end)

      # Shared ritual prompt (EPIC #377): a calm, network-wide prompt. Subscribe
      # so a freshly broadcast prompt appears on the dashboard live.
      Mosslet.Rituals.subscribe()

      # Content-free presence (EPIC #377, task #381): track that this viewer is
      # present in-app (write-free ETS presence — NOT last_activity_at / DB), so
      # they count as "around" for their own connections too. Then, if they've
      # opted in, kick off the slow refresh loop for the who's-around hint.
      MossletWeb.Presence.track_activity(self(), %{
        id: current_user.id,
        live_view_name: "dashboard",
        joined_at: System.system_time(:second),
        user_id: current_user.id,
        cache_optimization: false
      })

      if current_user.show_connections_presence do
        Process.send_after(self(), :refresh_connections_around, @around_refresh_ms)
      end
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
  def handle_event("dismiss_ritual_prompt", _params, socket) do
    {:noreply, assign(socket, :active_ritual_prompt, nil)}
  end

  @impl true
  def handle_event("dismiss_nudge", %{"id" => nudge_id}, socket) do
    current_user = socket.assigns.current_scope.user
    Mosslet.Nudges.mark_seen(nudge_id, current_user)

    nudges = Enum.reject(socket.assigns[:nudges] || [], &(&1.id == nudge_id))
    {:noreply, assign(socket, :nudges, nudges)}
  end

  @impl true
  def handle_event("dismiss_all_nudges", _params, socket) do
    current_user = socket.assigns.current_scope.user
    Mosslet.Nudges.mark_all_seen(current_user)
    {:noreply, assign(socket, :nudges, [])}
  end

  @impl true
  def handle_info({:ritual_prompt, broadcast}, socket) do
    socket =
      if socket.assigns[:has_profile?] and
           socket.assigns.current_scope.user.ritual_prompts_enabled do
        socket
        |> assign(:active_ritual_prompt, broadcast)
        |> assign(:ritual_prompt_answered?, false)
      else
        socket
      end

    {:noreply, socket}
  end

  # A connection tapped "thinking of you" (EPIC #377, task #399). Prepend the
  # metadata-only nudge to the dashboard list; the sender's name resolves
  # client-side via the DecryptNudge hook. Only surfaced for opted-in recipients
  # with a profile, and only if we can resolve the sealed connection data.
  def handle_info({:nudge_received, nudge}, socket) do
    current_user = socket.assigns.current_scope.user

    socket =
      if socket.assigns[:has_profile?] and current_user.nudges_enabled do
        case build_nudge_view(nudge, current_user, socket.assigns.current_scope.key) do
          nil ->
            socket

          view ->
            nudges = [view | socket.assigns[:nudges] || []] |> Enum.uniq_by(& &1.id)
            assign(socket, :nudges, nudges)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  # Content-free "connections are around" refresh (EPIC #377, task #381). Slow,
  # idempotent recompute + reschedule. Never reacts to the global online set;
  # never touches the DB / last_activity_at. Setting the same boolean on each
  # tick is diff-free for LiveView, so there's no re-nag / flapping.
  def handle_info(:refresh_connections_around, socket) do
    socket =
      if socket.assigns[:has_profile?] and
           socket.assigns.current_scope.user.show_connections_presence do
        Process.send_after(self(), :refresh_connections_around, @around_refresh_ms)
        assign_connections_around(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # Reply activity (create/delete) refreshes the "New replies" card + count,
  # but ONLY when the reply actually concerns the viewer — a reply on their
  # post or a reply to their reply. The public "replies" topic is global, so
  # this filter keeps unrelated platform chatter from hitting the DB: direct
  # replies are filtered on the broadcast struct alone; nested replies need a
  # cheap primary-key check on the parent reply.
  def handle_info({event, post, reply}, socket)
      when event in [:reply_created, :reply_deleted] do
    current_user = socket.assigns.current_scope.user

    socket =
      if socket.assigns[:has_profile?] &&
           reply_activity_relevant?(post, reply, current_user) do
        socket
        |> assign_dashboard_stats()
        |> assign_reply_activity()
      else
        socket
      end

    {:noreply, socket}
  end

  # Other reply broadcasts (:reply_updated, :reply_updated_fav) don't change
  # the unread set, so there's nothing to recompute — and they must NOT fall
  # through to the catch-all stat refresh.
  def handle_info({event, _post, _reply}, socket)
      when event in [:reply_updated, :reply_updated_fav] do
    {:noreply, socket}
  end

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

  # Cheap-first relevance filter for reply broadcasts: a reply matters to the
  # dashboard when it's on the viewer's own post (struct check, no DB) or when
  # it's nested under one of the viewer's own replies (one PK lookup).
  defp reply_activity_relevant?(post, reply, current_user) do
    cond do
      post.user_id == current_user.id ->
        true

      is_nil(reply.parent_reply_id) ->
        false

      true ->
        case Timeline.get_reply(reply.parent_reply_id) do
          nil -> false
          parent -> parent.user_id == current_user.id
        end
    end
  end

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
    |> assign(:local_today, MossletWeb.Helpers.JournalHelpers.get_local_today(socket))
    |> assign_dashboard_stats()
    |> assign_reply_activity()
    |> assign_org_spaces()
    |> assign_dashboard_ritual_prompt(current_user)
    |> assign_connections_around()
    |> assign_dashboard_nudges(current_user)
  end

  # Content-free presence hint (EPIC #377, task #381). Computes a single boolean:
  # "is at least one of the viewer's AUTHORIZED connections currently present
  # in-app?" — nothing more. NO count, NO names, NO reacting to the global online
  # set, and NO DB writes on this path.
  #
  # Privacy: reuses the write-free ETS presence signal
  # (`Presence.user_active_in_app?/1`) and gates EVERY candidate through the
  # existing consent check `Statuses.can_view_user_status?/3` (which already
  # honors user.visibility × status_visibility × show_online_presence × ZK
  # membership). The hint is strictly less information than the status the target
  # already consented to share. `Enum.any?/2` short-circuits at the first match.
  defp assign_connections_around(socket) do
    current_user = socket.assigns.current_scope.user

    around? =
      if current_user.show_connections_presence do
        key = socket.assigns.current_scope.key

        current_user.id
        |> Accounts.get_all_confirmed_user_connections()
        |> Enum.map(fn uconn ->
          if uconn.user_id == current_user.id,
            do: uconn.reverse_user_id,
            else: uconn.user_id
        end)
        |> Enum.uniq()
        |> Enum.filter(&MossletWeb.Presence.user_active_in_app?/1)
        |> Enum.any?(fn other_id ->
          case Accounts.get_user_with_preloads(other_id) do
            nil ->
              false

            target_user ->
              match?(
                {:ok, _},
                Mosslet.Statuses.can_view_user_status?(target_user, current_user, key)
              )
          end
        end)
      else
        false
      end

    assign(socket, :connections_around?, around?)
  end

  # Shared ritual prompt (EPIC #377, task #384): surface the active prompt on the
  # dashboard for opted-in users, plus whether they already answered it
  # (metadata-only) so the card shows a warm acknowledgment. Tapping "Share your
  # answer" routes to the timeline composer pre-seeded with the prompt.
  defp assign_dashboard_ritual_prompt(socket, current_user) do
    prompt =
      if current_user.ritual_prompts_enabled do
        Mosslet.Rituals.active_prompt()
      end

    answered? = prompt != nil and Mosslet.Rituals.answered?(current_user.id, prompt.id)

    socket
    |> assign(:active_ritual_prompt, prompt)
    |> assign(:ritual_prompt_answered?, answered?)
  end

  # Content-free "thinking of you" nudges (EPIC #377, task #399). Loads the
  # recipient's recent UNSEEN nudges as metadata-only rows and resolves each
  # sender's sealed connection data so the card can decrypt the name CLIENT-SIDE
  # (via the DecryptNudge hook). Nudges we can't map back to a live connection
  # (e.g. deleted connection) are skipped. Only for opted-in profiled users.
  defp assign_dashboard_nudges(socket, current_user) do
    nudges =
      if current_user.nudges_enabled do
        key = socket.assigns.current_scope.key

        current_user.id
        |> Mosslet.Nudges.list_unseen_nudges()
        |> Enum.map(&build_nudge_view(&1, current_user, key))
        |> Enum.reject(&is_nil/1)
      else
        []
      end

    assign(socket, :nudges, nudges)
  end

  # Build a render view for a single nudge by pairing the metadata-only row with
  # the recipient's OWN sealed connection data for the sender. The name is never
  # decrypted here — only the opaque sealed key + encrypted name blob are passed
  # to the browser hook. Returns nil if the sender is no longer a connection.
  defp build_nudge_view(nudge, current_user, _key) do
    uconn =
      current_user.id
      |> Accounts.get_all_confirmed_user_connections()
      |> Enum.find(fn uconn ->
        peer_id =
          if uconn.user_id == current_user.id, do: uconn.reverse_user_id, else: uconn.user_id

        peer_id == nudge.from_user_id
      end)

    case uconn do
      nil ->
        nil

      uconn ->
        %{
          id: nudge.id,
          inserted_at: nudge.inserted_at,
          sealed_uconn_key: uconn.key,
          encrypted_name: uconn.connection.name
        }
    end
  end

  defp assign_dashboard_stats(socket) do
    user = socket.assigns.current_scope.user
    user_group_ids = confirmed_user_group_ids(user) |> Enum.map(&elem(&1, 0))

    # The viewer's local "today" is captured at mount (connect_params carries
    # the timezone and is only readable while mounting); handle_info refreshes
    # reuse the assign instead of reading connect_params again, which raises.
    local_today = socket.assigns[:local_today] || Date.utc_today()

    stats = %{
      connections: length(Accounts.get_all_confirmed_user_connections(user.id)),
      pending_connections: Accounts.arrivals_count(user),
      circles: Groups.group_count_confirmed(user),
      pending_circles: length(Groups.list_unconfirmed_groups(user)),
      timeline_total: Timeline.count_home_timeline(user),
      timeline_unread: Timeline.count_unread_home_timeline(user),
      journal_entries: Journal.count_entries(user),
      capsules_opening_today: Capsules.count_opening_today(user, local_today),
      unread_dms: Conversations.count_unread_messages(user.id),
      unread_mentions: GroupMessages.count_unread_mentions(user_group_ids),
      unread_replies: Timeline.count_unread_replies_for_user(user)
    }

    assign(socket, :stats, stats)
  end

  # Unread reply activity for the "New replies" dashboard card: replies to the
  # viewer's posts AND replies to the viewer's own replies, GROUPED BY POST so
  # a busy thread collapses into one calm row ("…and 2 others") instead of
  # flooding the card. Each row is a lightweight view-model keyed by the
  # group's newest reply (also the deep-link scroll target) — author names are
  # decrypted CLIENT-SIDE by the DecryptReplyAuthor hook (ZK), exactly like the
  # nudge cards. Public posts are the exception: the server already holds that
  # key, so the name is decrypted server-side (same as the feed's fast-path).
  defp assign_reply_activity(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    reply_activity =
      current_user
      |> Timeline.list_unread_replies_for_user(%{limit: 25})
      |> Enum.group_by(& &1.post_id)
      |> Enum.map(fn {_post_id, replies} ->
        replies
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> build_reply_group_view(current_user, key)
      end)
      |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
      |> Enum.take(5)

    assign(socket, :reply_activity, reply_activity)
  end

  defp build_reply_group_view([newest | _] = replies, current_user, key) do
    post = newest.post
    browser_decrypt? = post.visibility != :public

    %{
      id: newest.id,
      post_id: post.id,
      count: length(replies),
      kind: if(is_nil(newest.parent_reply_id), do: :post, else: :reply),
      direct?: Enum.any?(replies, &is_nil(&1.parent_reply_id)),
      nested?: Enum.any?(replies, &(not is_nil(&1.parent_reply_id))),
      latest_at: newest.inserted_at,
      browser_decrypt?: browser_decrypt?,
      sealed_post_key: if(browser_decrypt?, do: sealed_post_key_for(post, current_user)),
      encrypted_username: if(browser_decrypt?, do: newest.username),
      author_name:
        if(browser_decrypt?,
          do: nil,
          else: get_safe_reply_author_name(newest, current_user, key)
        )
    }
  end

  # Total unread replies across the shown groups — the "View all" link appears
  # only when the card is truncated (more unread than shown).
  defp reply_activity_count(groups), do: Enum.sum(Enum.map(groups, & &1.count))

  defp reply_group_action_text(group) do
    cond do
      group.count == 1 and group.kind == :post -> "replied to your post"
      group.count == 1 -> "replied to your reply"
      group.direct? and group.nested? -> "replied to your post and replies"
      group.nested? -> "replied to your replies"
      true -> "replied to your post"
    end
  end

  # Resolves the viewer's sealed post key from the preloaded user_posts so the
  # browser can unseal the post_key and decrypt the reply author name locally
  # (ZK). Group posts carry a single shared UserPost row; everything else is
  # keyed per-recipient. Returns nil when the viewer has no key — the row then
  # keeps its "Someone" placeholder (graceful, no server-side decryption).
  defp sealed_post_key_for(post, current_user) do
    if post.group_id do
      case List.first(post.user_posts) do
        nil -> nil
        user_post -> user_post.key
      end
    else
      Enum.find_value(post.user_posts, &(&1.user_id == current_user.id && &1.key))
    end
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
          active_ritual_prompt={@active_ritual_prompt}
          ritual_prompt_answered?={@ritual_prompt_answered?}
          connections_around?={@connections_around?}
          nudges={@nudges}
          reply_activity={@reply_activity}
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
  attr :active_ritual_prompt, :map, default: nil
  attr :ritual_prompt_answered?, :boolean, default: false
  attr :connections_around?, :boolean, default: false
  attr :nudges, :list, default: []
  attr :reply_activity, :list, default: []

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
        <%!-- Shared ritual prompt (EPIC #377, task #384): a calm, network-wide
              prompt. Tapping through opens the timeline composer pre-seeded. --%>
        <div :if={@active_ritual_prompt} id="dashboard-ritual-prompt">
          <MossletWeb.TimelineComponents.liquid_ritual_prompt_card
            id="dashboard-ritual-prompt-card"
            prompt={@active_ritual_prompt.prompt}
            prompt_id={@active_ritual_prompt.id}
            theme={@active_ritual_prompt.theme}
            answered={@ritual_prompt_answered?}
          />
        </div>
        <%!-- Content-free "who's around" hint (EPIC #377, task #381). A quiet,
              count-free, name-free affordance: just a soft sense that some of
              your people are present. Only rendered for opted-in viewers when at
              least one authorized connection is currently around. --%>
        <div
          :if={@connections_around?}
          id="connections-around-hint"
          class="flex items-center gap-3 rounded-2xl border border-emerald-200/60 dark:border-emerald-800/40 bg-gradient-to-br from-emerald-50/70 to-teal-50/50 dark:from-emerald-950/30 dark:to-teal-950/20 px-5 py-4"
        >
          <span class="relative flex size-3 shrink-0">
            <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400/70 opacity-75"></span>
            <span class="relative inline-flex size-3 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500"></span>
          </span>
          <p class="text-sm font-medium text-emerald-800 dark:text-emerald-200">
            Some of your people are around right now.
          </p>
        </div>
        <%!-- Thinking-of-you nudges (EPIC #377, task #399). Content-free hellos
              from connections. The row is pure metadata; the sender's name is
              decrypted CLIENT-SIDE by the DecryptNudge hook from the recipient's
              own sealed connection data. Server never sees a name or a message. --%>
        <div :if={@nudges != []} id="dashboard-nudges" class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-rose-500 dark:text-rose-400">
              Thinking of you
            </h2>
            <button
              :if={length(@nudges) > 1}
              type="button"
              phx-click="dismiss_all_nudges"
              class="text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition-colors"
            >
              Clear all
            </button>
          </div>

          <div
            :for={nudge <- @nudges}
            id={"nudge-#{nudge.id}"}
            class="group relative flex items-center gap-4 rounded-2xl border border-rose-200/70 dark:border-rose-800/50 bg-gradient-to-br from-rose-50 to-fuchsia-50 dark:from-rose-950/40 dark:to-fuchsia-950/30 px-5 py-4"
          >
            <%!-- DecryptNudge hook: browser-side ZK decrypt of the sender name --%>
            <div
              :if={nudge.sealed_uconn_key}
              id={"decrypt-nudge-#{nudge.id}"}
              phx-hook="DecryptNudge"
              data-sealed-uconn-key={nudge.sealed_uconn_key}
              data-encrypted-conn-name={nudge.encrypted_name}
              data-target-id={"nudge-name-#{nudge.id}"}
              class="hidden"
            >
            </div>

            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-rose-400 to-fuchsia-500 shadow-md shadow-rose-500/30">
              <.phx_icon name="hero-heart" class="size-5 text-white" />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-rose-900 dark:text-rose-100">
                <span
                  id={"nudge-name-#{nudge.id}"}
                  phx-update="ignore"
                  data-decrypt-nudge-name
                >
                  A connection
                </span>
                <span class="font-normal">was thinking of you</span>
              </p>
              <p class="text-xs text-rose-700/80 dark:text-rose-300/70">
                <.local_time_ago id={"nudge-time-#{nudge.id}"} at={nudge.inserted_at} />
              </p>
            </div>
            <button
              type="button"
              phx-click="dismiss_nudge"
              phx-value-id={nudge.id}
              aria-label="Dismiss this nudge"
              class="flex size-11 shrink-0 items-center justify-center rounded-full text-rose-400 hover:text-rose-600 dark:hover:text-rose-300 hover:bg-rose-100/60 dark:hover:bg-rose-900/30 transition-all"
            >
              <.phx_icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
        </div>
        <%!-- New replies (replies to your posts + replies to your replies),
              grouped by post so busy threads collapse into one calm row.
              Rows are metadata + ciphertext only: author names are decrypted
              CLIENT-SIDE by the DecryptReplyAuthor hook with the viewer's
              sealed post key (ZK) — the same pattern as the nudge cards.
              Each row deep-links into the timeline at the group's newest
              reply, which expands the thread, scrolls to it, and marks it
              read — the thread itself is the "fan out". --%>
        <div :if={@reply_activity != []} id="dashboard-replies" class="space-y-3">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold uppercase tracking-wide text-emerald-600 dark:text-emerald-400">
              New replies
            </h2>
            <.link
              :if={@stats.unread_replies > reply_activity_count(@reply_activity)}
              navigate={~p"/app/timeline"}
              id="dashboard-replies-view-all"
              class="text-xs font-medium text-emerald-700/80 dark:text-emerald-300/70 hover:text-emerald-800 dark:hover:text-emerald-200 transition-colors"
            >
              View all {@stats.unread_replies} in timeline
            </.link>
          </div>

          <.link
            :for={reply <- @reply_activity}
            navigate={~p"/app/timeline?#{%{post_id: reply.post_id, reply_id: reply.id}}"}
            id={"dash-reply-#{reply.id}"}
            class="group relative flex items-center gap-4 rounded-2xl border border-emerald-200/70 dark:border-emerald-800/50 bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-950/40 dark:to-teal-950/30 px-5 py-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-emerald-500/10"
          >
            <div
              :if={reply.browser_decrypt?}
              id={"decrypt-reply-author-#{reply.id}"}
              phx-hook="DecryptReplyAuthor"
              phx-update="ignore"
              data-post-id={reply.post_id}
              data-sealed-post-key={reply.sealed_post_key}
              data-encrypted-username={reply.encrypted_username}
              data-target-id={"dash-reply-author-#{reply.id}"}
              class="hidden"
            >
            </div>

            <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-400 to-teal-500 shadow-md shadow-emerald-500/30">
              <.phx_icon
                name={
                  cond do
                    reply.count > 1 -> "hero-chat-bubble-left-ellipsis"
                    reply.kind == :reply -> "hero-arrow-uturn-left"
                    true -> "hero-chat-bubble-left-right"
                  end
                }
                class="size-5 text-white"
              />
            </div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-semibold text-emerald-900 dark:text-emerald-100">
                <span
                  :if={reply.browser_decrypt?}
                  id={"dash-reply-author-#{reply.id}"}
                  phx-update="ignore"
                >
                  Someone
                </span>
                <span :if={!reply.browser_decrypt?}>{reply.author_name}</span>
                <span :if={reply.count > 1} class="font-normal">
                  and {reply.count - 1} {if reply.count == 2, do: "other", else: "others"}
                </span>
                <span class="font-normal">
                  {reply_group_action_text(reply)}
                </span>
              </p>
              <p class="text-xs text-emerald-700/80 dark:text-emerald-300/70">
                <.local_time_ago id={"dash-reply-time-#{reply.id}"} at={reply.latest_at} />
              </p>
            </div>
            <span
              :if={reply.count > 1}
              id={"dash-reply-count-#{reply.post_id}"}
              class="inline-flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-emerald-100 px-1.5 text-[11px] font-bold text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300"
            >
              {if reply.count > 9, do: "9+", else: reply.count}
            </span>
            <.phx_icon
              name="hero-chevron-right"
              class="size-5 shrink-0 text-emerald-500 transition-transform duration-300 group-hover:translate-x-0.5"
            />
          </.link>
        </div>

        <%!-- A letter to your future self has arrived. A calm return-reason,
              gated purely on the plaintext deliver_on date — content stays ZK. --%>
        <.link
          :if={@stats.capsules_opening_today > 0}
          navigate={~p"/app/capsules"}
          id="nudge-capsule-opening"
          class="group flex items-center gap-4 rounded-2xl border border-amber-200/70 dark:border-amber-800/50 bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-950/40 dark:to-orange-950/30 px-5 py-4 transition-all duration-300 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-amber-500/10"
        >
          <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-amber-400 to-orange-500 shadow-md shadow-amber-500/30">
            <.phx_icon name="hero-envelope-open" class="size-5 text-white" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="text-sm font-semibold text-amber-900 dark:text-amber-100">
              {if @stats.capsules_opening_today == 1,
                do: "A letter to your future self is ready",
                else: "#{@stats.capsules_opening_today} letters to your future self are ready"}
            </p>
            <p class="text-xs text-amber-700/80 dark:text-amber-300/70">
              You sealed {if @stats.capsules_opening_today == 1, do: "it", else: "them"} for today — open when you're ready
            </p>
          </div>
          <.phx_icon
            name="hero-chevron-right"
            class="size-5 text-amber-500 transition-transform duration-300 group-hover:translate-x-0.5"
          />
        </.link>
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
