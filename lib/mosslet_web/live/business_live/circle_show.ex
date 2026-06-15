defmodule MossletWeb.BusinessLive.CircleShow do
  @moduledoc """
  Org-scoped business circle dashboard (Task #221, see
  `docs/ZK_FILE_SHARING_DESIGN.md`).

  A business circle's files, members, and (incrementally) chat are fully
  self-contained here in the org dashboard — never in the personal Circles
  realm. This is also the surface a paid org-branding subdomain would tailor
  (board #228).

  ZK file sharing: members upload files encrypted in the browser with a per-file
  `file_key`; the opaque blob lands on object storage and the `file_key` is
  sealed per recipient (the circle's server-authoritative member set — I1). The
  server never sees the `file_key` or plaintext (I2/I3). A mandatory
  transparency surface lists exactly who can read each file (I4); revocation is
  cryptographically honest (I5).
  """
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Files
  alias Mosslet.Groups
  alias Mosslet.GroupMessages
  alias Mosslet.Orgs
  alias MossletWeb.GroupLive.{Group, GroupMessage.EditForm}
  alias MossletWeb.GroupLive.ChatSupport

  require Logger

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

      not member_of_circle?(group, current_user.id) ->
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
         |> assign(:pending_shared_file, nil)
         |> assign(:blob_buffers, %{})
         |> assign(:show_markdown_guide, false)
         |> assign(:show_add_members?, false)
         |> assign(:pending_add_member_ids, [])
         |> ChatSupport.assign_scrolled_to_top()
         |> assign_circle_data()
         |> assign_chat()}
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
          <div class="flex items-center gap-3 min-w-0">
            <div class="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-teal-500 to-emerald-600 shadow-lg shadow-emerald-500/25">
              <.phx_icon name="hero-chat-bubble-left-right" class="h-6 w-6 text-white" />
            </div>
            <div class="min-w-0">
              <h1
                id="circle-name"
                class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 truncate"
              >
                <span data-decrypt-group-name>Business circle</span>
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
          data-scope-id={"business-circle-#{@group.id}"}
        >
        </div>

        <%!-- Files panel (ZK file sharing — Task #221) --%>
        <section
          id="shared-files-panel"
          phx-hook="SharedFileHook"
          data-max-bytes={Files.max_size_bytes()}
          class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
        >
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                Files
              </h2>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                Encrypted on your device and shared only with this circle. Mosslet can't read them.
              </p>
            </div>
            <label
              for="shared-file-input"
              class="inline-flex cursor-pointer items-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30"
            >
              <.phx_icon name="hero-arrow-up-tray" class="size-4" /> Upload
              <input
                id="shared-file-input"
                type="file"
                data-shared-file-input
                class="sr-only"
              />
            </label>
          </div>

          <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60">
            <li
              :for={file <- @shared_files}
              id={"shared-file-#{file.id}"}
              class="py-3 flex items-center justify-between gap-3"
            >
              <div class="flex items-center gap-3 min-w-0">
                <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                  <.phx_icon name="hero-document" class="size-4" />
                </div>
                <div class="min-w-0">
                  <%!-- Filename is encrypted with the file_key (ZK). Decrypt it
                       in-place: unseal the viewer's file_key, then decrypt the
                       filename — same path as download. --%>
                  <div
                    :if={file.viewer_sealed_key && file.encrypted_filename}
                    id={"decrypt-filename-#{file.id}"}
                    phx-hook="DecryptSharedFileName"
                    phx-update="ignore"
                    data-sealed-file-key={file.viewer_sealed_key}
                    data-encrypted-filename={file.encrypted_filename}
                  >
                    <p
                      data-shared-filename
                      class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
                    >
                      Decrypting…
                    </p>
                  </div>
                  <p
                    :if={!(file.viewer_sealed_key && file.encrypted_filename)}
                    class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"
                  >
                    Encrypted file
                  </p>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    {format_size(file.size_bytes)} · {file.reader_count} can read
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <button
                  type="button"
                  data-download-shared-file={file.id}
                  id={"download-#{file.id}"}
                  class="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-900/20 transition-colors duration-200"
                >
                  <.phx_icon name="hero-arrow-down-tray" class="size-3.5" /> Download
                </button>
                <button
                  :if={can_delete_file?(file, @current_scope.user, @membership)}
                  type="button"
                  phx-click="delete_shared_file"
                  phx-value-id={file.id}
                  id={"delete-#{file.id}"}
                  data-confirm="Delete this file for everyone in the circle? We can't recall copies already downloaded."
                  class="text-xs font-medium text-rose-500 hover:text-rose-600"
                >
                  Remove
                </button>
              </div>
            </li>
            <li :if={@shared_files == []} class="py-3 text-xs text-slate-500 dark:text-slate-400">
              No files shared yet. Upload one to share it securely with this circle.
            </li>
          </ul>

          <%!-- Transparency surface (mandatory — I4) --%>
          <div class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-teal-50/60 dark:bg-teal-900/20 p-4">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
              Who can read these files
            </p>
            <p class="mt-0.5 text-xs text-slate-600 dark:text-slate-300">
              Everyone in this circle can open these files with their own key. Mosslet's servers
              can't read them. Adding someone to the circle later does <strong>not</strong>
              give them existing files — only files shared after they join. Deleting a file removes
              it for everyone, but can't recall copies already downloaded.
            </p>
          </div>
        </section>

        <%!-- Members --%>
        <section
          id="circle-members-roster"
          phx-hook="OrgMembers"
          data-sealed-org-key={@viewer_sealed_org_key}
          data-current-user-id={@current_scope.user.id}
          class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm p-5 space-y-4"
        >
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                Members
              </h2>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                {@member_count} {if @member_count == 1, do: "person", else: "people"} in this circle.
              </p>
            </div>
            <button
              :if={@can_manage_circle? && !@show_add_members? && @addable_members != []}
              type="button"
              phx-click="show_add_members"
              id="show-add-members-button"
              class="inline-flex cursor-pointer items-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30"
            >
              <.phx_icon name="hero-user-plus" class="size-4" /> Add
            </button>
          </div>

          <ul role="list" class="divide-y divide-slate-100 dark:divide-slate-700/60">
            <li
              :for={member <- @members}
              id={"circle-member-#{member.user.id}"}
              class="py-2.5 flex items-center gap-3"
              data-org-member-row
              data-encrypted-display-name={member.encrypted_display_name}
            >
              <div class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/40 dark:to-emerald-900/40 text-teal-600 dark:text-teal-300">
                <.phx_icon name="hero-user" class="size-4" />
              </div>
              <p class="min-w-0 text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                <span {MossletWeb.OrgIdentity.org_name_target(member)}>
                  {MossletWeb.OrgIdentity.placeholder_label(member)}
                </span>
              </p>
              <span
                :if={member.self?}
                class="ml-auto shrink-0 rounded-full bg-slate-100 dark:bg-slate-700/60 px-2 py-0.5 text-[11px] font-medium text-slate-500 dark:text-slate-400"
              >
                You
              </span>
            </li>
          </ul>

          <%!-- Add members (ZK write path — only the circle owner/admin).
               Any org member can be added; org membership (not a personal
               connection) is the only prerequisite, since the shared org_key
               lets the adder seal the circle key + read each member's org
               display name client-side. --%>
          <form
            :if={@can_manage_circle? && @show_add_members?}
            id="add-members-form"
            phx-hook="CircleAddMembersHook"
            data-sealed-group-key={@sealed_group_key}
            data-sealed-org-key={@viewer_sealed_org_key}
            class="rounded-xl border border-teal-200/60 dark:border-teal-800/50 bg-gradient-to-br from-teal-50/60 to-emerald-50/40 dark:from-teal-900/15 dark:to-emerald-900/10 p-4 space-y-3"
          >
            <div class="flex items-start gap-2.5">
              <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-white/70 dark:bg-slate-800/60 text-teal-600 dark:text-teal-300 shadow-sm">
                <.phx_icon name="hero-user-plus" class="size-4" />
              </div>
              <div>
                <p class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  Add people from your organization
                </p>
                <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                  They'll join the chat and can read files shared <strong>after</strong> they join.
                </p>
              </div>
            </div>

            <ul
              role="list"
              class="max-h-56 overflow-y-auto rounded-lg border border-slate-200/60 dark:border-slate-700/60 bg-white/60 dark:bg-slate-900/30 divide-y divide-slate-100 dark:divide-slate-700/50"
            >
              <li
                :for={member <- @addable_members}
                id={"add-member-row-#{member.user.id}"}
                data-org-member-row
                data-encrypted-display-name={member.encrypted_display_name}
              >
                <label
                  for={"add-member-#{member.user.id}"}
                  class="flex items-center gap-3 cursor-pointer px-3 py-2.5 hover:bg-teal-50/60 dark:hover:bg-teal-900/15 transition-colors duration-150"
                >
                  <input
                    type="checkbox"
                    id={"add-member-#{member.user.id}"}
                    name="add_members[]"
                    value={member.user.id}
                    class="size-4 rounded border-slate-300 dark:border-slate-600 text-teal-600 focus:ring-teal-500 focus:ring-offset-0"
                  />
                  <div class="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-slate-100 to-slate-200 dark:from-slate-700 dark:to-slate-600 text-slate-500 dark:text-slate-300">
                    <.phx_icon name="hero-user" class="size-3.5" />
                  </div>
                  <span
                    class="min-w-0 flex-1 text-sm text-slate-900 dark:text-slate-100 truncate"
                    data-decrypt-org-name
                  >
                    {member.personal_name || "Org member"}
                  </span>
                </label>
              </li>
            </ul>

            <div class="flex items-center justify-end gap-2">
              <button
                type="button"
                phx-click="hide_add_members"
                class="inline-flex items-center justify-center rounded-full px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-white/70 dark:hover:bg-slate-800/60 transition-colors duration-200"
              >
                Cancel
              </button>
              <button
                type="submit"
                id="add-members-submit"
                phx-disable-with="Adding…"
                class="inline-flex items-center gap-1.5 rounded-full bg-gradient-to-r from-teal-500 to-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm shadow-emerald-500/25 transition-all duration-200 hover:shadow-md hover:shadow-emerald-500/30"
              >
                <.phx_icon name="hero-check" class="size-4" /> Add to circle
              </button>
            </div>
          </form>

          <p
            :if={@can_manage_circle? && !@show_add_members? && @addable_members == []}
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            Everyone in this organization is already in this circle.
            <.link
              navigate={~p"/app/business/#{@org.slug}"}
              class="font-medium text-teal-600 dark:text-teal-400 hover:underline"
            >
              Invite more people
            </.link>
            to add them.
          </p>
        </section>

        <%!-- Encrypted chat (reused ZK group chat — self-contained per circle) --%>
        <section
          id="circle-chat-panel"
          class="rounded-2xl border border-slate-200/60 dark:border-slate-700/60 bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm shadow-sm overflow-hidden"
        >
          <div class="flex items-center justify-between gap-3 px-5 py-4 border-b border-slate-200/60 dark:border-slate-700/60">
            <div>
              <h2 class="text-base font-semibold text-slate-900 dark:text-slate-100">
                Chat
              </h2>
              <p class="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
                End-to-end encrypted. {@total_messages_count} message{if @total_messages_count != 1,
                  do: "s"}.
              </p>
            </div>
            <span class="relative flex h-2.5 w-2.5" title="Live">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
            </span>
          </div>

          <%!-- Decrypt the chat's group metadata browser-side (ZK). --%>
          <div
            id="circle-chat-metadata"
            phx-hook="DecryptGroupMetadata"
            data-sealed-group-key={@group_metadata[:sealed_group_key]}
            data-encrypted-name={@group_metadata[:encrypted_name]}
            data-encrypted-moniker={@group_metadata[:encrypted_moniker]}
            data-browser-decrypt={@group_metadata[:browser_decrypt?]}
          >
          </div>

          <div class="h-[32rem] flex flex-col">
            <Group.show
              :if={@current_user_group}
              messages={@streams.messages}
              messages_list={@messages_list}
              current_scope={@current_scope}
              group={@group}
              user_group={@current_user_group}
              scrolled_to_top={@scrolled_to_top}
              current_page={:business}
            />
          </div>
        </section>
      </div>

      <.live_component
        module={EditForm}
        message={@message}
        id="message-edit-form"
        current_scope={@current_scope}
        user_group_key={if(@current_user_group, do: @current_user_group.key)}
        public?={@group.public?}
      />

      <MossletWeb.PrivacyComponents.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
    </.layout>
    """
  end

  ## File upload (write path, two-phase ZK)

  @impl true
  def handle_event("create_shared_file", params, socket) do
    %{
      "upload_ref" => ref,
      "encrypted_filename" => encrypted_filename,
      "checksum" => checksum,
      "size_bytes" => size_bytes,
      "blob_chunks_total" => total
    } = params

    socket =
      assign(socket, :pending_shared_file, %{
        ref: ref,
        encrypted_filename: encrypted_filename,
        checksum: checksum,
        size_bytes: size_bytes,
        total: total
      })

    {:noreply, put_in_blob_buffer(socket, ref, [])}
  end

  @impl true
  def handle_event(
        "shared_file_chunk",
        %{"upload_ref" => ref, "index" => index, "total" => total, "chunk_b64" => chunk},
        socket
      ) do
    buffers = socket.assigns.blob_buffers
    chunks = Map.get(buffers, ref, [])
    chunks = [{index, chunk} | chunks]
    socket = assign(socket, :blob_buffers, Map.put(buffers, ref, chunks))

    if length(chunks) == total do
      {:noreply, finalize_blob_upload(socket, ref)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("finalize_shared_file", params, socket) do
    %{"shared_file_id" => file_id, "sealed_recipients" => sealed} = params

    case Files.get_shared_file(file_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Upload could not be finalized.")}

      shared_file ->
        {:ok, _count} = Files.finalize_shared_file_zk(shared_file, sealed)

        {:noreply,
         socket
         |> put_flash(:success, "File shared with the circle.")
         |> assign_circle_data()}
    end
  end

  @impl true
  def handle_event("shared_file_too_large", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "That file is larger than the #{format_size(Files.max_size_bytes())} limit."
     )}
  end

  @impl true
  def handle_event("shared_file_upload_failed", _params, socket) do
    {:noreply,
     put_flash(socket, :error, "Couldn't encrypt and share that file. Please try again.")}
  end

  ## File download (read path)

  @impl true
  def handle_event("request_shared_file", %{"shared_file_id" => file_id}, socket) do
    current_user = socket.assigns.current_scope.user

    with shared_file when not is_nil(shared_file) <- Files.get_shared_file(file_id),
         %{key: sealed_key} <- Files.get_user_shared_file(shared_file, current_user),
         {:ok, url} <- Files.presigned_download_url(shared_file, current_user) do
      {:noreply,
       push_event(socket, "shared_file_ready", %{
         shared_file_id: file_id,
         sealed_key: sealed_key,
         presigned_url: url,
         encrypted_filename: shared_file.encrypted_filename,
         checksum: shared_file.checksum
       })}
    else
      _ -> {:noreply, put_flash(socket, :error, "You can't download that file.")}
    end
  end

  @impl true
  def handle_event("shared_file_downloaded", %{"verified" => false}, socket) do
    {:noreply,
     put_flash(
       socket,
       :warning,
       "This file downloaded, but its integrity check did not match. Treat it with caution."
     )}
  end

  @impl true
  def handle_event("shared_file_downloaded", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("shared_file_download_failed", _params, socket) do
    {:noreply, put_flash(socket, :error, "Couldn't open that file. Please try again.")}
  end

  ## Revocation (I5)

  @impl true
  def handle_event("delete_shared_file", %{"id" => file_id}, socket) do
    current_user = socket.assigns.current_scope.user

    case Files.get_shared_file(file_id) do
      nil ->
        {:noreply, assign_circle_data(socket)}

      shared_file ->
        case Files.delete_shared_file(shared_file, current_user) do
          {:ok, :revoked} ->
            {:noreply,
             socket
             |> put_flash(:info, "File removed. (Copies already downloaded can't be recalled.)")
             |> assign_circle_data()}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "You can't remove that file.")}

          _ ->
            {:noreply, put_flash(socket, :error, "Couldn't remove that file.")}
        end
    end
  end

  ## Org-scoped ZK identity seal/bootstrap (shared with the OrgMembers hook)

  @impl true
  def handle_event("finalize_org_key", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    case MossletWeb.OrgIdentity.finalize_org_key(socket.assigns.org, sealed_members) do
      {:ok, _count} -> {:noreply, assign_circle_data(socket)}
      _ -> {:noreply, socket}
    end
  end

  ## Embedded ZK chat (reused from the personal Circles realm — see ChatSupport)

  @impl true
  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  @impl true
  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, false)}
  end

  ## Add members to this circle (ZK write path — two-phase)

  @impl true
  def handle_event("show_add_members", _params, socket) do
    {:noreply, assign(socket, :show_add_members?, true)}
  end

  @impl true
  def handle_event("hide_add_members", _params, socket) do
    {:noreply, assign(socket, :show_add_members?, false)}
  end

  # Phase 1: the browser sent the selected org-member ids. Only the circle
  # owner/admin may add members. Resolve each member's public keys + their org
  # `display_name` ciphertext (decryptable client-side with the `org_key` the
  # adder already holds) + a server-generated moniker/avatar for the browser to
  # encrypt with the circle `group_key`. The candidate set is server-
  # authoritative (I1): `members_to_add/2` intersects with current org
  # membership, so a tampered client can never seal a circle key for an outsider.
  # No personal `UserConnection` is required — org membership is the only gate.
  @impl true
  def handle_event("request_add_members", %{"user_ids" => user_ids}, socket)
      when is_list(user_ids) do
    current_user = socket.assigns.current_scope.user

    cond do
      not can_edit_group?(socket.assigns.current_user_group, current_user) ->
        {:noreply, put_flash(socket, :error, "You don't have permission to add members.")}

      true ->
        eligible_ids = MapSet.new(socket.assigns.addable_members, & &1.user.id)
        selected_ids = Enum.filter(user_ids, &MapSet.member?(eligible_ids, &1))

        members =
          socket.assigns.org
          |> MossletWeb.OrgIdentity.members_to_add(selected_ids)
          |> Enum.map(fn member ->
            member
            |> Map.put(:moniker, FriendlyID.generate(3))
            |> Map.put(:avatar_img, random_avatar())
          end)

        if members == [] do
          {:noreply, put_flash(socket, :info, "No eligible org members selected.")}
        else
          {:noreply,
           socket
           |> assign(:pending_add_member_ids, Enum.map(members, & &1.user_id))
           |> push_event("seal_group_key_for_new_members", %{members: members})}
        end
    end
  end

  # Phase 2: the browser sealed the circle group_key for each new member and
  # encrypted their display name/moniker/avatar with it. Persist via the shared
  # ZK write path, which RE-ENFORCES org-membership eligibility (I1) server-side.
  # The raw group_key NEVER reaches the server.
  @impl true
  def handle_event("finalize_group_members_zk", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    current_user = socket.assigns.current_scope.user

    if can_edit_group?(socket.assigns.current_user_group, current_user) do
      {:ok, added} = Groups.add_group_members_zk(socket.assigns.group, sealed_members)

      {:noreply,
       socket
       |> put_flash(
         :success,
         "#{added} member#{if added != 1, do: "s"} added to the circle."
       )
       |> assign(:show_add_members?, false)
       |> assign(:pending_add_member_ids, [])
       |> assign_circle_data()}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to add members.")}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    case ChatSupport.handle_chat_event(event, params, socket) do
      {:halt, socket} -> {:noreply, socket}
      :cont -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:org_updated, _org_id}, socket) do
    {:noreply, assign_circle_data(socket)}
  end

  # A member was removed from (or left) this circle: bounce them back to the org
  # dashboard if it's them, otherwise just refresh the roster/files.
  @impl true
  def handle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    cond do
      group.id != socket.assigns.group.id ->
        {:noreply, socket}

      kicked_user_id == socket.assigns.current_scope.user.id ->
        {:noreply,
         socket
         |> put_flash(:info, "You're no longer a member of this circle.")
         |> push_navigate(to: ~p"/app/business/#{socket.assigns.org.slug}")}

      true ->
        {:noreply, assign_circle_data(socket)}
    end
  end

  @impl true
  def handle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    cond do
      group.id != socket.assigns.group.id ->
        {:noreply, socket}

      blocked_user_id == socket.assigns.current_scope.user.id ->
        {:noreply,
         socket
         |> put_flash(:info, "You're no longer a member of this circle.")
         |> push_navigate(to: ~p"/app/business/#{socket.assigns.org.slug}")}

      true ->
        {:noreply, assign_circle_data(socket)}
    end
  end

  @impl true
  def handle_info({:group_deleted, _group}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "This circle no longer exists.")
     |> push_navigate(to: ~p"/app/business/#{socket.assigns.org.slug}")}
  end

  # Embedded ZK chat: delegate the shared message-stream broadcasts to
  # `ChatSupport`, which keeps everything realm-agnostic (no personal routes).
  @impl true
  def handle_info(message, socket) do
    case ChatSupport.handle_chat_info(message, socket) do
      {:halt, socket} -> {:noreply, socket}
      :cont -> {:noreply, socket}
    end
  end

  ## Data loading

  defp assign_circle_data(socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    org = socket.assigns.org
    group = Groups.get_group!(socket.assigns.group.id)

    user_group = Enum.find(group.user_groups, &(&1.user_id == current_user.id))

    connection_statuses =
      org
      |> Orgs.list_members_by_org()
      |> Enum.map(& &1.id)
      |> then(&Accounts.connection_statuses_for(current_user.id, &1))

    # The ZK org-identity roster is built across ALL org members (it carries the
    # org-display-name ciphertext + connection status). We then scope it to THIS
    # circle's members only — an org member who hasn't been added to the circle
    # must NOT appear here. We keep the full `org_members` list separately to
    # power the "Add members" composer (eligible = connected org members not yet
    # in the circle).
    org_members =
      MossletWeb.OrgIdentity.build_members(
        org,
        current_user,
        fn user -> personal_connection_name(user, current_user, key) end,
        connection_statuses
      )

    circle_member_ids = circle_member_user_ids(group)

    members =
      Enum.filter(org_members, fn m -> MapSet.member?(circle_member_ids, m.user.id) end)

    socket
    |> assign(:group, group)
    |> assign(:current_user_group, user_group)
    |> assign(:sealed_group_key, user_group && user_group.key)
    |> assign(:member_count, MapSet.size(circle_member_ids))
    |> assign(:members, members)
    |> assign(:addable_members, addable_members(org_members, circle_member_ids))
    |> assign(:can_manage_circle?, can_edit_group?(user_group, current_user))
    |> assign(:show_add_members?, socket.assigns[:show_add_members?] || false)
    |> assign(:viewer_sealed_org_key, MossletWeb.OrgIdentity.viewer_sealed_org_key(members))
    |> assign(:shared_files, build_shared_files(group, current_user))
    |> maybe_request_org_key_seal(members)
  end

  # The set of `user_id`s that are CONFIRMED members of this circle (its
  # `user_groups`). The roster + member count are scoped to exactly this set so
  # an org member who hasn't been added to the circle never shows up here.
  defp circle_member_user_ids(group) do
    group.user_groups
    |> Enum.filter(&(not is_nil(&1.confirmed_at)))
    |> MapSet.new(& &1.user_id)
  end

  # Org members the circle owner/admin can add to this circle: ANY current org
  # member not already in the circle. Membership in the org is the ONLY
  # prerequisite — no personal `UserConnection` is required, because every org
  # member shares the org-scoped ZK identity (`org_key`), so the adder's browser
  # can resolve each member's public key (server-provided) and org display name
  # (decrypted client-side with the `org_key`) to seal the circle `group_key`.
  # Self is excluded (the viewer is already a member). The server re-enforces
  # org-eligibility (I1) on the write regardless.
  defp addable_members(org_members, circle_member_ids) do
    Enum.filter(org_members, fn m ->
      not m.self? and not MapSet.member?(circle_member_ids, m.user.id)
    end)
  end

  # Reuse the personal-connection name resolution (same as business_live/show.ex)
  # so the composer can label addable teammates with a name the viewer can read.
  defp personal_connection_name(user, current_user, key) do
    case Accounts.get_user_connection_between_users(user.id, current_user.id) do
      nil ->
        nil

      uconn ->
        Mosslet.Encrypted.Users.Utils.decrypt_user_item(
          uconn.connection.name,
          current_user,
          uconn.key,
          key
        )
    end
  end

  # Builds the Files panel view-models. Each carries the VIEWER's own sealed
  # `file_key` (from the preloaded recipient rows) so the browser can unseal it
  # and decrypt the filename in-place (ZK) — exactly like the download path.
  defp build_shared_files(group, current_user) do
    group
    |> Files.list_shared_files_for_group(current_user)
    |> Enum.map(fn file ->
      viewer_row = Enum.find(file.user_shared_files, &(&1.user_id == current_user.id))

      %{
        id: file.id,
        size_bytes: file.size_bytes,
        encrypted_filename: file.encrypted_filename,
        reader_count: length(file.user_shared_files),
        uploader_id: file.uploader_id,
        viewer_sealed_key: viewer_row && viewer_row.key
      }
    end)
  end

  # The embedded ZK chat is loaded once at mount (re-streaming on every
  # files/members refresh would reset scroll position). Live updates arrive via
  # PubSub broadcasts handled by `ChatSupport.handle_chat_info/2`.
  defp assign_chat(socket) do
    current_scope = socket.assigns.current_scope
    group = socket.assigns.group
    user_group = socket.assigns.current_user_group

    if user_group && user_group.confirmed_at do
      GroupMessages.mark_mentions_as_read(user_group.id, group.id)
    end

    socket
    |> assign(
      :group_metadata,
      MossletWeb.Helpers.pre_decrypt_group_metadata(
        group,
        user_group,
        current_scope.user,
        current_scope.key
      )
    )
    |> ChatSupport.assign_active_group_messages()
    |> ChatSupport.assign_last_user_message()
  end

  defp maybe_request_org_key_seal(socket, members) do
    org = socket.assigns.org

    cond do
      not connected?(socket) ->
        socket

      MossletWeb.OrgIdentity.viewer_can_seal_for_others?(members) ->
        push_event(socket, "seal_org_key_for_members", %{
          members: MossletWeb.OrgIdentity.members_to_seal(org)
        })

      true ->
        socket
    end
  end

  ## Internals

  defp put_in_blob_buffer(socket, ref, chunks) do
    assign(socket, :blob_buffers, Map.put(socket.assigns.blob_buffers, ref, chunks))
  end

  defp finalize_blob_upload(socket, ref) do
    pending = socket.assigns.pending_shared_file
    buffers = socket.assigns.blob_buffers
    chunks = Map.get(buffers, ref, [])

    socket = assign(socket, :blob_buffers, Map.delete(buffers, ref))

    if is_nil(pending) or pending.ref != ref do
      socket
    else
      cipher_b64 =
        chunks
        |> Enum.sort_by(fn {index, _} -> index end)
        |> Enum.map_join("", fn {_, chunk} -> chunk end)

      with {:ok, encrypted_binary} <- Base.decode64(cipher_b64),
           {:ok, storage_path} <-
             Mosslet.FileUploads.SharedFileStorage.put_encrypted_blob(encrypted_binary),
           {:ok, shared_file} <-
             Files.create_shared_file_zk(
               socket.assigns.group,
               socket.assigns.current_scope.user,
               %{
                 "storage_path" => storage_path,
                 "encrypted_filename" => pending.encrypted_filename,
                 "checksum" => pending.checksum,
                 "size_bytes" => pending.size_bytes
               }
             ) do
        socket
        |> assign(:pending_shared_file, nil)
        |> push_event("shared_file_created", %{
          shared_file_id: shared_file.id,
          recipients: Files.circle_recipients(socket.assigns.group)
        })
      else
        error ->
          Logger.warning("Shared file upload failed: #{inspect(error)}")

          socket
          |> assign(:pending_shared_file, nil)
          |> put_flash(:error, "Couldn't store that file. Please try again.")
      end
    end
  end

  defp member_of_circle?(group, user_id) do
    group = Groups.get_group!(group.id)

    Enum.any?(group.user_groups, fn ug ->
      ug.user_id == user_id and not is_nil(ug.confirmed_at)
    end)
  end

  defp can_delete_file?(file, user, membership) do
    file.uploader_id == user.id or membership.role == :admin
  end

  defp random_avatar do
    Enum.random(
      ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)
    )
  end

  defp format_size(nil), do: "—"

  defp format_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
end
