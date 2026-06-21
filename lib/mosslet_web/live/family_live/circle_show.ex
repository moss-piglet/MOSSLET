defmodule MossletWeb.FamilyLive.CircleShow do
  @moduledoc """
  Family-scoped shared circle (Task #271) — the dedicated family surface for a
  shared circle that family members post into and share files within. It lives
  under the Family dashboard with its own family route, kept structurally
  separate from both personal Circles and Business circles.

  All crypto-sensitive plumbing (ZK file sharing, the member-seal handshake,
  catch-up, leave/remove + sealed-access revocation, embedded chat) is the shared
  `MossletWeb.OrgCircleSupport` / `OrgCircleComponents`, reused verbatim with
  `MossletWeb.BusinessLive.CircleShow`. This module owns only the family-specific
  concerns: the family route/auth guard, the page header/labels, and the
  guardian co-read transparency note.

  ## Guardian co-read (consent-based, transparent — see GUARDIANSHIP_DESIGN.md)

  When a managed member is added to a family circle, the active guardians of that
  member (derived server-side from `Guardianship` records — never client params)
  are co-sealed the circle's `group_key` via the identical ZK seal path
  (`OrgCircleSupport`). Guardians become transparent co-reading members shown in
  the roster; there is no silent path and no master key.
  """
  use MossletWeb, :live_view

  alias Mosslet.Groups
  alias Mosslet.Orgs
  alias MossletWeb.GroupLive.ChatSupport
  alias MossletWeb.OrgCircleSupport

  @impl true
  def mount(%{"slug" => slug, "id" => group_id}, _session, socket) do
    current_user = socket.assigns.current_scope.user
    org = safe_get_org(current_user, slug)
    group = Groups.get_group(group_id)

    cond do
      is_nil(org) ->
        {:ok,
         socket
         |> put_flash(:info, "That family isn't available.")
         |> push_navigate(to: ~p"/app/family")}

      org.type != :family ->
        {:ok,
         socket
         |> put_flash(:error, "Not a family organization")
         |> push_navigate(to: ~p"/app/family")}

      is_nil(group) or group.org_id != org.id ->
        {:ok,
         socket
         |> put_flash(:info, "This family circle no longer exists.")
         |> push_navigate(to: ~p"/app/family/#{org.slug}")}

      not OrgCircleSupport.member_of_circle?(group, current_user.id) ->
        {:ok,
         socket
         |> put_flash(:info, "You're not a member of this family circle.")
         |> push_navigate(to: ~p"/app/family/#{org.slug}")}

      true ->
        if connected?(socket) do
          Orgs.subscribe_org(org)
          Groups.group_subscribe(group)
        end

        membership = Orgs.get_membership!(current_user, slug)
        managed_in_circle = managed_members_in_circle(org, group)

        {:ok,
         socket
         |> assign(:org, org)
         |> assign(:group, group)
         |> assign(:membership, membership)
         |> assign(:managed_in_circle, managed_in_circle)
         |> assign(:page_title, "Family circle")
         |> assign(:circle_org_path, ~p"/app/family/#{org.slug}")
         |> assign(:refresh_circle_fun, &refresh_family_circle/1)
         |> OrgCircleSupport.assign_circle_base()
         |> OrgCircleSupport.assign_circle_data()
         |> OrgCircleSupport.assign_chat()}
    end
  end

  defp safe_get_org(user, slug) do
    Orgs.get_org!(user, slug)
  rescue
    Ecto.NoResultsError -> nil
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
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10 space-y-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/app/family/#{@org.slug}"}
            class="p-2 -ml-2 rounded-xl text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 transition-all duration-200"
            aria-label="Back to family"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div class="flex items-center gap-3 min-w-0">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-home-modern" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1
                id="circle-name"
                class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate"
              >
                <%!-- phx-update="ignore" so a LiveView DOM patch (chat stream,
                     roster refresh) can't clobber the browser-decrypted ZK name
                     back to the server placeholder. --%>
                <span id={"circle-name-text-#{@group.id}"} phx-update="ignore">
                  <span data-decrypt-group-name>Family circle</span>
                </span>
              </h1>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {@member_count} member{if @member_count != 1, do: "s"} · {@org.name}
              </p>
            </div>
          </div>
        </header>

        <%!-- Decrypt the circle name browser-side (ZK) via the existing hook. --%>
        <div
          id={"decrypt-circle-#{@group.id}"}
          phx-hook="DecryptGroupMetadata"
          data-sealed-group-key={@sealed_group_key}
          data-encrypted-name={@group.name}
          data-scope-id={"family-circle-#{@group.id}"}
        >
        </div>

        <%!-- Guardian co-read transparency (mandatory — I2/I4). When a managed
             member is in this circle, their guardian(s) co-read it with their own
             key. We say so plainly: never a silent path. --%>
        <div
          :if={@managed_in_circle != []}
          id="family-circle-guardian-notice"
          class="rounded-2xl border border-teal-200/70 dark:border-teal-800/40 bg-teal-50/70 dark:bg-teal-900/15 p-4"
        >
          <div class="flex items-start gap-2.5">
            <.phx_icon name="hero-eye" class="size-5 text-teal-600 dark:text-teal-400 mt-0.5" />
            <div>
              <p class="text-sm font-semibold text-teal-900 dark:text-teal-100">
                A guardian can read this family circle
              </p>
              <p class="mt-1 text-xs text-teal-800/90 dark:text-teal-200/80">
                Because a managed family member is in this circle, their guardian co-reads its
                chat and files with their own private key — the same consent-based protection that
                covers posts and conversations. Mosslet's servers still can't read anything here.
              </p>
            </div>
          </div>
        </div>

        <.circle_files_panel
          shared_files={@shared_files}
          can_catch_up?={@can_catch_up?}
          viewer_missing_files?={@viewer_missing_files?}
          current_user={@current_scope.user}
          membership={@membership}
        />

        <.circle_members_roster
          members={@members}
          member_count={@member_count}
          addable_members={@addable_members}
          can_manage_circle?={@can_manage_circle?}
          show_add_members?={@show_add_members?}
          can_leave_circle?={@can_leave_circle?}
          current_user_id={@current_scope.user.id}
          membership={@membership}
          current_user_group={@current_user_group}
          sealed_group_key={@sealed_group_key}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          guardian_avatars={@guardian_avatars}
          org_path={~p"/app/family/#{@org.slug}"}
        />

        <.circle_chat_panel
          group={@group}
          current_user_group={@current_user_group}
          messages={@streams.messages}
          messages_list={@messages_list}
          current_scope={@current_scope}
          scrolled_to_top={@scrolled_to_top}
          group_metadata={@group_metadata}
          total_messages_count={@total_messages_count}
          message={@message}
          show_markdown_guide={@show_markdown_guide}
          current_page={:family}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          org_display_names={@org_display_names}
          org_avatars={@org_avatars}
          guardian_avatars={@guardian_avatars}
        />
      </div>
    </.layout>
    """
  end

  # Shared circle events (files, catch-up, add-members, leave/remove, org-key
  # seal, markdown guide) → OrgCircleSupport; then the embedded ZK chat events →
  # ChatSupport. Family carries no announcements.
  @impl true
  def handle_event(event, params, socket) do
    case OrgCircleSupport.handle_circle_event(event, params, socket) do
      {:halt, socket} ->
        {:noreply, socket}

      :cont ->
        case ChatSupport.handle_chat_event(event, params, socket) do
          {:halt, socket} -> {:noreply, socket}
          :cont -> {:noreply, socket}
        end
    end
  end

  # Shared circle broadcasts (org/membership/file changes) → OrgCircleSupport;
  # then the embedded ZK chat broadcasts → ChatSupport.
  @impl true
  def handle_info(message, socket) do
    case OrgCircleSupport.handle_circle_info(message, socket) do
      {:halt, socket} ->
        {:noreply, socket}

      :cont ->
        case ChatSupport.handle_chat_info(message, socket) do
          {:halt, socket} -> {:noreply, socket}
          :cont -> {:noreply, socket}
        end
    end
  end

  # Refresh hook (set in mount): the shared handlers call this to refresh circle
  # state. Family also recomputes the guardian co-read transparency notice, so it
  # stays in sync after a managed member or guardian joins/leaves.
  defp refresh_family_circle(socket) do
    socket
    |> OrgCircleSupport.assign_circle_data()
    |> then(fn s ->
      assign(s, :managed_in_circle, managed_members_in_circle(s.assigns.org, s.assigns.group))
    end)
  end

  # The managed members (server-authoritative) who are confirmed members of this
  # family circle. Drives the guardian co-read transparency notice. Derived from
  # org membership roles + the circle's confirmed `user_groups` — never client
  # params.
  defp managed_members_in_circle(org, group) do
    group = Groups.get_group!(group.id)

    circle_member_ids =
      group.user_groups
      |> Enum.filter(&(not is_nil(&1.confirmed_at)))
      |> MapSet.new(& &1.user_id)

    org
    |> Orgs.list_memberships_with_users()
    |> Enum.filter(fn m ->
      m.role == :managed_member and MapSet.member?(circle_member_ids, m.user_id)
    end)
  end
end
