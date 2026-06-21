defmodule MossletWeb.MentionIndicatorLive do
  @moduledoc """
  Business-only global unread-@mention indicator (Task #281).

  A small, indigo floating pill — rendered once as a sticky nested LiveView in
  the authenticated layout so it persists across navigations and stays realtime
  regardless of which page the member is on. It shows the AGGREGATE count of
  unread `@mentions` across every business circle the viewer belongs to, a
  Slack-style "you have N pings waiting somewhere" affordance.

  Clicking it routes the member STRAIGHT to where the ping is, not to a generic
  landing page: when exactly one circle has unread mentions, the pill is a direct
  link to that circle's chat; when several do, it spins open a small popover that
  lists each circle (with its own count) as a direct link to that circle's chat.

  Deliberately scoped to Business: it's a productivity, don't-miss-a-ping
  workflow. Family stays calmer/relational (it gets the per-circle dashboard
  badge from Task #280, but no global nag), and personal-only users see nothing.

  Server-authoritative + ZK-safe: the counts are derived from
  `GroupMessageMention` records (UUIDs the server already holds) — never from
  ciphertext or client params (I1). Circle NAMES stay encrypted at rest and are
  decrypted browser-side via the `DecryptGroupMetadata` hook using the viewer's
  sealed group key, exactly like the dashboard circle cards. It subscribes once
  to each business circle's `group:` topic and recomputes on `new_message` (a
  mention may have just arrived) and `mentions_read` (the viewer just read a
  circle), so it both appears and clears live without a reload.
  """
  use Phoenix.LiveView, layout: false

  import MossletWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: MossletWeb.Endpoint,
    router: MossletWeb.Router,
    statics: MossletWeb.static_paths()

  alias Mosslet.Accounts
  alias Mosslet.GroupMessages
  alias Mosslet.Groups
  alias Mosslet.Orgs

  @impl true
  def mount(_params, session, socket) do
    user = load_user(session["user_id"])
    business? = !!user && Orgs.has_active_org_of_type?(user, :business)

    circles = if business?, do: business_circles(user), else: []

    # Subscribe ONCE (PubSub double-subscribe is not idempotent) to each business
    # circle so a new message anywhere — or a read elsewhere — refreshes the
    # aggregate live.
    if connected?(socket) and business? do
      Enum.each(circles, fn circle ->
        Phoenix.PubSub.subscribe(Mosslet.PubSub, "group:#{circle.group_id}")
      end)
    end

    {:ok,
     socket
     |> assign(:business?, business?)
     |> assign(:circles, circles)
     |> recompute()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      :if={@business? && @count > 0}
      id="mention-indicator-root"
      class="fixed bottom-4 left-4 z-50"
      x-data="{ open: false }"
      @keydown.escape.window="open = false"
      @click.away="open = false"
    >
      <%!-- Single circle → click goes straight to its chat (fewest clicks). --%>
      <.link
        :if={length(@mention_circles) == 1}
        id="mention-indicator"
        navigate={circle_chat_path(hd(@mention_circles))}
        title="Open the circle with your unread @mentions"
        class={pill_classes()}
      >
        <.pill_inner count={@count} multi?={false} />
      </.link>

      <%!-- Several circles → spin open a popover of direct links. --%>
      <button
        :if={length(@mention_circles) > 1}
        id="mention-indicator"
        type="button"
        @click="open = !open"
        x-bind:aria-expanded="open"
        aria-haspopup="true"
        title="Show circles with unread @mentions"
        class={pill_classes()}
      >
        <.pill_inner count={@count} multi?={true} />
      </button>

      <%!-- Popover (multi only): each circle a direct link to its chat. --%>
      <div
        :if={length(@mention_circles) > 1}
        id="mention-indicator-panel"
        x-show="open"
        x-cloak
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0 translate-y-1"
        x-transition:enter-end="opacity-100 translate-y-0"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100 translate-y-0"
        x-transition:leave-end="opacity-0 translate-y-1"
        class={[
          "absolute bottom-full left-0 mb-2 w-72 origin-bottom-left overflow-hidden rounded-2xl",
          "bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm",
          "shadow-xl shadow-indigo-900/15 dark:shadow-black/40",
          "ring-1 ring-slate-200/60 dark:ring-slate-700/60"
        ]}
      >
        <div class="flex items-center gap-2 border-b border-slate-100 dark:border-slate-700/60 px-4 py-2.5">
          <.phx_icon name="hero-at-symbol" class="size-4 text-indigo-500 dark:text-indigo-400" />
          <span class="text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
            Unread mentions
          </span>
        </div>
        <ul role="list" class="max-h-80 overflow-y-auto py-1">
          <li :for={circle <- @mention_circles} data-hook-scope={scope_id(circle)}>
            <div
              id={"decrypt-#{scope_id(circle)}"}
              phx-hook="DecryptGroupMetadata"
              data-sealed-group-key={circle.sealed_group_key}
              data-encrypted-name={circle.encrypted_name}
              data-scope-id={scope_id(circle)}
            >
            </div>
            <.link
              navigate={circle_chat_path(circle)}
              class={[
                "group flex items-center gap-3 px-4 py-2.5 transition-colors duration-150",
                "hover:bg-indigo-50/70 dark:hover:bg-indigo-900/20"
              ]}
            >
              <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-500 to-violet-500 text-white shadow-sm">
                <.phx_icon name="hero-chat-bubble-left-right" class="size-4" />
              </div>
              <span class="min-w-0 flex-1 truncate text-sm font-medium text-slate-900 dark:text-slate-100">
                <span data-decrypt-group-name>Business circle</span>
              </span>
              <span class="inline-flex h-5 min-w-5 shrink-0 items-center justify-center rounded-full bg-indigo-100 px-1.5 text-[11px] font-bold text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300">
                {if circle.count > 9, do: "9+", else: circle.count}
              </span>
              <.phx_icon
                name="hero-chevron-right"
                class="size-4 shrink-0 text-slate-300 dark:text-slate-600 group-hover:text-indigo-500 dark:group-hover:text-indigo-400"
              />
            </.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :multi?, :boolean, required: true

  defp pill_inner(assigns) do
    ~H"""
    <span class="relative flex h-2.5 w-2.5" aria-hidden="true">
      <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-white/70"></span>
      <span class="relative inline-flex h-2.5 w-2.5 rounded-full bg-white"></span>
    </span>
    <.phx_icon name="hero-at-symbol" class="size-4" />
    <span id="mention-indicator-count">{if @count > 9, do: "9+", else: @count}</span>
    <span class="hidden sm:inline">{if @count == 1, do: "mention", else: "mentions"}</span>
    <span
      :if={@multi?}
      class="transition-transform duration-200"
      x-bind:class="open ? 'rotate-180' : ''"
    >
      <.phx_icon name="hero-chevron-up" class="size-3.5" />
    </span>
    """
  end

  @impl true
  def handle_info(%{event: event}, socket)
      when event in ["new_message", "mentions_read"] do
    {:noreply, recompute(socket)}
  end

  # Ignore everything else (other group-topic events, telemetry, etc.). Only
  # business instances ever subscribe, so non-business ones never reach here.
  def handle_info(_message, socket), do: {:noreply, socket}

  ## Helpers

  defp load_user(user_id) when is_binary(user_id), do: Accounts.get_user!(user_id)
  defp load_user(_), do: nil

  # Every business circle the viewer belongs to across ALL their ACTIVE business
  # orgs (a user may belong to more than one), as lightweight view-models. The
  # sealed group key + encrypted name let the browser decrypt the circle's name
  # in the popover (ZK), and the org slug + group id form the direct chat link.
  # Org-scoped via `list_business_circles/2`.
  defp business_circles(user) do
    user
    |> Orgs.list_orgs()
    |> Enum.filter(fn org -> org.type == :business and Orgs.org_active?(org) end)
    |> Enum.flat_map(fn org ->
      org
      |> Groups.list_business_circles(user)
      |> Enum.map(fn group ->
        user_group = Enum.find(group.user_groups, &(&1.user_id == user.id))

        %{
          group_id: group.id,
          org_slug: org.slug,
          user_group_id: user_group && user_group.id,
          sealed_group_key: user_group && user_group.key,
          encrypted_name: group.name,
          count: 0
        }
      end)
    end)
    |> Enum.reject(&is_nil(&1.user_group_id))
  end

  # Recompute the per-circle unread-@mention counts (server-authoritative, ZK-safe)
  # from the circles we already hold: which circles have pings, and the total.
  defp recompute(socket) do
    circles = socket.assigns.circles
    user_group_ids = Enum.map(circles, & &1.user_group_id)
    counts = GroupMessages.get_unread_mention_counts_by_group(user_group_ids)

    mention_circles =
      circles
      |> Enum.map(fn circle -> %{circle | count: Map.get(counts, circle.group_id, 0)} end)
      |> Enum.filter(&(&1.count > 0))
      |> Enum.sort_by(& &1.count, :desc)

    total = mention_circles |> Enum.map(& &1.count) |> Enum.sum()

    socket
    |> assign(:mention_circles, mention_circles)
    |> assign(:count, total)
  end

  defp circle_chat_path(circle),
    do: ~p"/app/business/#{circle.org_slug}/circles/#{circle.group_id}"

  defp scope_id(circle), do: "mention-circle-#{circle.group_id}"

  # Shared liquid-metal pill styling for both the single-circle direct link and
  # the multi-circle popover toggle, so they're visually identical.
  defp pill_classes do
    [
      "group inline-flex items-center gap-2 rounded-full",
      "bg-gradient-to-br from-indigo-500 to-violet-500 px-4 py-2.5",
      "text-sm font-semibold text-white",
      "shadow-lg shadow-indigo-500/30 ring-1 ring-white/20 dark:ring-slate-800",
      "transition-all duration-200 ease-out hover:scale-105 active:scale-95",
      "hover:shadow-xl hover:shadow-indigo-500/40",
      "focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-400"
    ]
  end
end
