defmodule MossletWeb.BusinessLive.CircleShow do
  @moduledoc """
  Org-scoped business circle dashboard (Task #221, see
  `docs/ZK_FILE_SHARING_DESIGN.md`).

  A business circle's files, members, and chat are fully self-contained here in
  the org dashboard — never in the personal Circles realm. This is also the
  surface a paid org-branding subdomain would tailor (board #228).

  The crypto-sensitive circle plumbing (ZK file sharing, the member-seal
  handshake, catch-up, leave/remove + sealed-access revocation, embedded chat)
  lives in the shared `MossletWeb.OrgCircleSupport` and `OrgCircleComponents`,
  reused VERBATIM by `MossletWeb.FamilyLive.CircleShow` (Task #271). This module
  stays thin and owns only what must remain business-specific: the business
  routes/auth guard, the page header, and the ZK announcements panel (#229c).
  """
  use MossletWeb, :live_view

  alias Mosslet.Announcements
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
         |> put_flash(:info, "That organization isn't available.")
         |> push_navigate(to: ~p"/app/business")}

      org.type != :business ->
        {:ok,
         socket
         |> put_flash(:error, "Not a business organization")
         |> push_navigate(to: ~p"/app/business")}

      is_nil(group) or group.org_id != org.id ->
        {:ok,
         socket
         |> put_flash(:info, "This circle no longer exists.")
         |> push_navigate(to: ~p"/app/business/#{org.slug}")}

      not OrgCircleSupport.member_of_circle?(group, current_user.id) ->
        {:ok,
         socket
         |> put_flash(:info, "You're not a member of this circle.")
         |> push_navigate(to: ~p"/app/business/#{org.slug}")}

      true ->
        if connected?(socket) do
          Orgs.subscribe_org(org)
          Groups.group_subscribe(group)
        end

        membership = Orgs.get_membership!(current_user, slug)

        {:ok,
         socket
         |> assign(:org, org)
         |> assign(:group, group)
         |> assign(:membership, membership)
         |> assign(:page_title, "Business circle")
         |> assign(:circle_org_path, ~p"/app/business/#{org.slug}")
         |> assign(:refresh_circle_fun, &assign_circle_data/1)
         |> assign(:show_announcement_form?, false)
         |> assign(
           :announcement_form,
           to_form(%{"title" => "", "body" => "", "priority" => "normal"}, as: :announcement)
         )
         |> OrgCircleSupport.assign_circle_base()
         |> assign_circle_data()
         |> OrgCircleSupport.assign_chat()}
    end
  end

  # Membership-scoped org lookup that returns nil (instead of raising) when the
  # viewer isn't a member of `slug`. A non-member who hits a circle URL gets a
  # friendly redirect rather than a crash.
  defp safe_get_org(user, slug) do
    Orgs.get_org!(user, slug)
  rescue
    Ecto.NoResultsError -> nil
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
      <div class="mx-auto max-w-3xl px-4 py-6 sm:px-6 lg:px-8 lg:py-10 space-y-6">
        <header class="flex items-center gap-3">
          <.link
            navigate={~p"/app/business/#{@org.slug}"}
            class="p-2 -ml-2 rounded-xl text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800/60 transition-all duration-200"
            aria-label="Back to organization"
          >
            <.phx_icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div class="flex items-start gap-3 min-w-0">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-chat-bubble-left-right" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0 space-y-1">
              <h1
                id="circle-name"
                class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate"
              >
                <%!-- phx-update="ignore" so a LiveView DOM patch (chat stream,
                     roster refresh) can't clobber the browser-decrypted ZK name
                     back to the server placeholder. --%>
                <span id={"circle-name-text-#{@group.id}"} phx-update="ignore">
                  <span data-decrypt-group-name>Business circle</span>
                </span>
              </h1>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {@member_count} member{if @member_count != 1, do: "s"} · {@org.name}
              </p>
              <%!-- Circle description (ZK): decrypted browser-side via the
                   DecryptGroupMetadata hook below. phx-update="ignore" keeps a
                   LiveView patch from clobbering the decrypted text. --%>
              <p
                :if={@group.description not in [nil, ""]}
                id={"circle-description-#{@group.id}"}
                phx-update="ignore"
                class="text-sm leading-relaxed text-slate-600 dark:text-slate-400"
                data-decrypt-group-description
              >
                Decrypting description…
              </p>
            </div>
          </div>
        </header>

        <%!-- Decrypt the circle name + description browser-side (ZK) via the
             existing hook. --%>
        <div
          id={"decrypt-circle-#{@group.id}"}
          phx-hook="DecryptGroupMetadata"
          data-sealed-group-key={@sealed_group_key}
          data-encrypted-name={@group.name}
          data-encrypted-description={@group.description}
          data-scope-id={"business-circle-#{@group.id}"}
        >
        </div>

        <%!-- Circle-level ZK announcements (Task #229c) --%>
        <.announcements_panel
          tier={:circle}
          sealed_key={@sealed_group_key}
          can_post?={@can_post_announcement?}
          show_form?={@show_announcement_form?}
          form={@announcement_form}
          banner={@announcement_banner}
          recent={@announcement_recent}
          unread_count={@announcement_unread_count}
          current_user_id={@current_scope.user.id}
        />

        <.circle_files_panel
          shared_files={@shared_files}
          can_catch_up?={@can_catch_up?}
          viewer_missing_files?={@viewer_missing_files?}
          current_user={@current_scope.user}
          membership={@membership}
          viewer_sealed_org_key={@viewer_sealed_org_key}
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
          org_path={~p"/app/business/#{@org.slug}"}
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
          current_page={:business}
          viewer_sealed_org_key={@viewer_sealed_org_key}
          org_display_names={@org_display_names}
          org_avatars={@org_avatars}
        />
      </div>
    </.layout>
    """
  end

  ## Circle-level ZK announcements (Task #229c — business-only)

  @impl true
  def handle_event("show_announcement_form", _params, socket) do
    {:noreply, assign(socket, :show_announcement_form?, true)}
  end

  @impl true
  def handle_event("hide_announcement_form", _params, socket) do
    {:noreply, assign(socket, :show_announcement_form?, false)}
  end

  # The browser encrypted the title/body with the circle's group_key and pushed
  # the ciphertext. Persist it (server re-checks the team-lead authority gate —
  # I1). The raw group_key + plaintext NEVER reach the server.
  @impl true
  def handle_event("save_announcement", params, socket) do
    user = socket.assigns.current_scope.user
    group = socket.assigns.group

    attrs = %{
      "encrypted_title" => params["encrypted_title"],
      "encrypted_body" => params["encrypted_body"],
      "priority" => Announcements.parse_priority(params["priority"]),
      "expires_at" => Announcements.parse_expires_at(params["expires_at"])
    }

    case Announcements.create_circle_announcement(group, user, attrs) do
      {:ok, announcement} ->
        Announcements.mark_read(announcement, user)

        {:noreply,
         socket
         |> put_flash(:success, "Announcement posted")
         |> assign(:show_announcement_form?, false)
         |> assign_circle_data()}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to post announcements.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not post that announcement.")}
    end
  end

  # Fallback when browser crypto is unavailable (ZK — never persist plaintext).
  @impl true
  def handle_event("create_announcement", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Your browser couldn't prepare encryption keys. Please reload and try again."
     )}
  end

  @impl true
  def handle_event("announcement_invalid", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please add a message (up to 5000 characters).")}
  end

  @impl true
  def handle_event("delete_announcement", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    announcement = Announcements.get_announcement(id)

    cond do
      is_nil(announcement) or announcement.group_id != socket.assigns.group.id ->
        {:noreply, socket}

      true ->
        case Announcements.delete_announcement(announcement, user) do
          {:ok, :deleted} ->
            {:noreply, socket |> put_flash(:info, "Announcement deleted") |> assign_circle_data()}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can't delete that announcement.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Could not delete that announcement.")}
        end
    end
  end

  @impl true
  def handle_event("mark_announcements_read", _params, socket) do
    Announcements.mark_all_read_circle(socket.assigns.group, socket.assigns.current_scope.user)
    {:noreply, assign_circle_data(socket)}
  end

  # Shared circle events (files, catch-up, add-members, leave/remove, org-key
  # seal, markdown guide) → OrgCircleSupport; then the embedded ZK chat events →
  # ChatSupport. Both keep everything realm-agnostic (no business routes).
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

  ## Realtime circle announcement (Task #229c — business-only)

  @impl true
  def handle_info({:announcement_published, %{scope: :circle, author_id: author_id}}, socket) do
    socket = assign_circle_data(socket)

    socket =
      if author_id == socket.assigns.current_scope.user.id do
        socket
      else
        put_flash(socket, :info, "New announcement posted")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:announcements_updated, %{scope: :circle}}, socket) do
    {:noreply, assign_circle_data(socket)}
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

  ## Data loading

  # The universal circle state comes from OrgCircleSupport; business layers its
  # ZK announcement state on top. Used at mount and after announcement events;
  # `refresh_circle_fun` (set in mount) routes the shared handlers here too, so
  # announcement assigns never go stale.
  defp assign_circle_data(socket) do
    socket
    |> OrgCircleSupport.assign_circle_data()
    |> assign_announcements()
  end

  defp assign_announcements(socket) do
    group = socket.assigns.group
    current_user = socket.assigns.current_scope.user
    user_group = socket.assigns.current_user_group

    circle_announcements = Announcements.list_circle_announcements(group)

    {announcement_banner, announcement_recent} =
      Announcements.partition_pinned(circle_announcements)

    can_post_announcement? =
      is_struct(user_group) and user_group.role in [:owner, :admin, :moderator]

    socket
    |> assign(:announcement_banner, announcement_banner)
    |> assign(:announcement_recent, announcement_recent)
    |> assign(:announcement_unread_count, Announcements.unread_circle_count(group, current_user))
    |> assign(:can_post_announcement?, can_post_announcement?)
  end
end
