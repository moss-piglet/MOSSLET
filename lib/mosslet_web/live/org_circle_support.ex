defmodule MossletWeb.OrgCircleSupport do
  @moduledoc """
  Shared, org-type-agnostic logic for an org-scoped circle dashboard — the
  zero-knowledge file sharing, member-seal handshake, catch-up, leave/remove +
  sealed-access revocation, and embedded ZK chat plumbing.

  This is the single source of truth for the crypto-sensitive circle operations,
  reused VERBATIM by both `MossletWeb.BusinessLive.CircleShow` (Task #221) and
  `MossletWeb.FamilyLive.CircleShow` (Task #271). It mirrors the established
  house pattern of `MossletWeb.GroupLive.ChatSupport` and `MossletWeb.OrgIdentity`
  (logic shared across surfaces; each LiveView stays thin and owns its own
  routing, authorization guard, labels, and feature set).

  ## Contract

  The calling LiveView MUST assign, before invoking the functions here:

    * `:current_scope` — with `.user` and `.key`
    * `:org` — the `%Mosslet.Orgs.Org{}` (already membership-scoped to the viewer)
    * `:group` — the circle `%Mosslet.Groups.Group{}` (its `org_id == org.id`)
    * `:membership` — the viewer's `%Mosslet.Orgs.Membership{}` for the org
    * `:circle_org_path` — the back-to-org path string (e.g.
      `~p"/app/family/\#{slug}"`). All redirects here use this, so the route
      sigil stays compile-time verified in each domain LiveView and family and
      business surfaces can never navigate into each other.

  Announcements, pins, and any dashboard-overview features stay OUT of this
  shared path — they're business-specific and owned by `BusinessLive.CircleShow`.
  """
  use MossletWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView
  import MossletWeb.Helpers, only: [can_edit_group?: 2]

  alias Mosslet.Accounts
  alias Mosslet.Files
  alias Mosslet.Groups
  alias Mosslet.GroupMessages
  alias Mosslet.Orgs
  alias Mosslet.Orgs.Audit
  alias MossletWeb.GroupLive.ChatSupport
  alias MossletWeb.OrgIdentity

  require Logger

  ## Mount

  @doc """
  Assigns the base circle state every circle LiveView needs (upload buffers,
  add-members composer state, markdown-guide flag, chat scroll state). Domain
  LiveViews layer their own assigns (announcements, etc.) on top.
  """
  def assign_circle_base(socket) do
    socket
    |> assign(:pending_shared_file, nil)
    |> assign(:blob_buffers, %{})
    |> assign(:show_markdown_guide, false)
    |> assign(:show_add_members?, false)
    |> assign(:pending_add_member_ids, [])
    |> ChatSupport.assign_scrolled_to_top()
  end

  ## Shared event handling — returns {:halt, socket} | :cont (mirrors ChatSupport)

  # --- File upload (write path, two-phase ZK) ---

  def handle_circle_event("create_shared_file", params, socket) do
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

    {:halt, put_in_blob_buffer(socket, ref, [])}
  end

  def handle_circle_event(
        "shared_file_chunk",
        %{"upload_ref" => ref, "index" => index, "total" => total, "chunk_b64" => chunk},
        socket
      ) do
    buffers = socket.assigns.blob_buffers
    chunks = Map.get(buffers, ref, [])
    chunks = [{index, chunk} | chunks]
    socket = assign(socket, :blob_buffers, Map.put(buffers, ref, chunks))

    if length(chunks) == total do
      {:halt, finalize_blob_upload(socket, ref)}
    else
      {:halt, socket}
    end
  end

  def handle_circle_event("finalize_shared_file", params, socket) do
    %{"shared_file_id" => file_id, "sealed_recipients" => sealed} = params

    case Files.get_shared_file(file_id) do
      nil ->
        {:halt, put_flash(socket, :error, "Upload could not be finalized.")}

      shared_file ->
        {:ok, _count} = Files.finalize_shared_file_zk(shared_file, sealed)

        Audit.record_audit_event(
          socket.assigns.org,
          socket.assigns.current_scope.user,
          "file_shared",
          target_id: shared_file.id,
          target_type: "shared_file"
        )

        {:halt,
         socket
         |> put_flash(:success, "File shared with the circle.")
         |> refresh_circle()}
    end
  end

  def handle_circle_event("shared_file_too_large", _params, socket) do
    {:halt,
     put_flash(
       socket,
       :error,
       "That file is larger than the #{format_size(Files.max_size_bytes())} limit."
     )}
  end

  def handle_circle_event("shared_file_upload_failed", _params, socket) do
    {:halt, put_flash(socket, :error, "Couldn't encrypt and share that file. Please try again.")}
  end

  # --- File download (read path) ---

  def handle_circle_event("request_shared_file", %{"shared_file_id" => file_id}, socket) do
    current_user = socket.assigns.current_scope.user

    with shared_file when not is_nil(shared_file) <- Files.get_shared_file(file_id),
         %{key: sealed_key} <- Files.get_user_shared_file(shared_file, current_user),
         {:ok, url} <- Files.presigned_download_url(shared_file, current_user) do
      {:halt,
       push_event(socket, "shared_file_ready", %{
         shared_file_id: file_id,
         sealed_key: sealed_key,
         presigned_url: url,
         encrypted_filename: shared_file.encrypted_filename,
         checksum: shared_file.checksum
       })}
    else
      _ -> {:halt, put_flash(socket, :error, "You can't download that file.")}
    end
  end

  def handle_circle_event("shared_file_downloaded", %{"verified" => false}, socket) do
    {:halt,
     put_flash(
       socket,
       :warning,
       "This file downloaded, but its integrity check did not match. Treat it with caution."
     )}
  end

  def handle_circle_event("shared_file_downloaded", _params, socket), do: {:halt, socket}

  def handle_circle_event("shared_file_download_failed", _params, socket) do
    {:halt, put_flash(socket, :error, "Couldn't open that file. Please try again.")}
  end

  # --- Revocation (I5) ---

  def handle_circle_event("delete_shared_file", %{"id" => file_id}, socket) do
    current_user = socket.assigns.current_scope.user

    case Files.get_shared_file(file_id) do
      nil ->
        {:halt, refresh_circle(socket)}

      shared_file ->
        case Files.delete_shared_file(shared_file, current_user) do
          {:ok, :revoked} ->
            Audit.record_audit_event(socket.assigns.org, current_user, "file_revoked",
              target_id: shared_file.id,
              target_type: "shared_file"
            )

            {:halt,
             socket
             |> put_flash(:info, "File removed. (Copies already downloaded can't be recalled.)")
             |> refresh_circle()}

          {:error, :unauthorized} ->
            {:halt, put_flash(socket, :error, "You can't remove that file.")}

          _ ->
            {:halt, put_flash(socket, :error, "Couldn't remove that file.")}
        end
    end
  end

  # --- Catch up: grant later-joining members access to EARLIER files (explicit,
  # never silent — Task #231/#232, see docs/ZK_FILE_SHARING_DESIGN.md §6.2). ---

  def handle_circle_event("request_catch_up", _params, socket) do
    if socket.assigns.can_catch_up? do
      current_user = socket.assigns.current_scope.user
      files = Files.catch_up_payload(socket.assigns.group, current_user)

      if files == [] do
        {:halt,
         socket
         |> put_flash(:info, "Everyone can already read the files you have access to.")
         |> refresh_circle()}
      else
        {:halt, push_event(socket, "reseal_files_for_members", %{files: files})}
      end
    else
      {:halt, put_flash(socket, :error, "You don't have permission to share earlier files.")}
    end
  end

  def handle_circle_event("finalize_catch_up_zk", %{"sealed_entries" => sealed_entries}, socket)
      when is_list(sealed_entries) do
    if socket.assigns.can_catch_up? do
      {:ok, added} = Files.finalize_catch_up_zk(socket.assigns.group, sealed_entries)

      message =
        if added > 0 do
          "Shared earlier files with #{added} member#{if added != 1, do: "s"}."
        else
          "Everyone can already read the files you have access to."
        end

      {:halt,
       socket
       |> put_flash(:success, message)
       |> refresh_circle()}
    else
      {:halt, put_flash(socket, :error, "You don't have permission to share earlier files.")}
    end
  end

  def handle_circle_event("catch_up_failed", _params, socket) do
    {:halt, put_flash(socket, :error, "Couldn't share earlier files. Please try again.")}
  end

  # --- Org-scoped ZK identity seal/bootstrap (shared with the OrgMembers hook) ---

  def handle_circle_event("finalize_org_key", %{"sealed_members" => sealed_members}, socket)
      when is_list(sealed_members) do
    case OrgIdentity.finalize_org_key(socket.assigns.org, sealed_members) do
      {:ok, _count} -> {:halt, refresh_circle(socket)}
      _ -> {:halt, socket}
    end
  end

  # --- Markdown guide (chat composer) ---

  def handle_circle_event("open_markdown_guide", _params, socket) do
    {:halt, assign(socket, :show_markdown_guide, true)}
  end

  def handle_circle_event("close_markdown_guide", _params, socket) do
    {:halt, assign(socket, :show_markdown_guide, false)}
  end

  # --- Add members to this circle (ZK write path — two-phase) ---

  def handle_circle_event("show_add_members", _params, socket) do
    {:halt, assign(socket, :show_add_members?, true)}
  end

  def handle_circle_event("hide_add_members", _params, socket) do
    {:halt, assign(socket, :show_add_members?, false)}
  end

  # Phase 1: the browser sent the selected org-member ids. Only the circle
  # owner/admin may add members. Resolve each member's public keys + their org
  # `display_name` ciphertext + a server-generated moniker/avatar. The candidate
  # set is server-authoritative (I1): `members_to_add/2` intersects with current
  # org membership, so a tampered client can never seal a circle key for an
  # outsider. The seal payload also includes the active GUARDIANS of any
  # managed-member participants (server-authoritative from Guardianship records),
  # so the circle group_key is co-sealed for guardians too (Task #271 co-read).
  def handle_circle_event("request_add_members", %{"user_ids" => user_ids}, socket)
      when is_list(user_ids) do
    current_user = socket.assigns.current_scope.user
    org = socket.assigns.org

    if can_edit_group?(socket.assigns.current_user_group, current_user) do
      eligible_ids = MapSet.new(socket.assigns.addable_members, & &1.user.id)
      selected_ids = Enum.filter(user_ids, &MapSet.member?(eligible_ids, &1))

      # Guardian co-read (Task #271): for a family circle, also seal the circle
      # group_key for the active guardians of any selected managed members. The
      # guardian set is server-authoritative (derived from Guardianship records,
      # never client params — I1). Guardians are themselves family-org members,
      # so they're sealed in via the identical `members_to_add/2` payload (proper
      # org identity) and become transparent co-reading members. Only guardians
      # not already in the circle (i.e. in the addable set) are added.
      guardian_ids = guardian_coread_ids(org, selected_ids, eligible_ids)
      all_ids = Enum.uniq(selected_ids ++ guardian_ids)

      members =
        org
        |> OrgIdentity.members_to_add(all_ids)
        |> Enum.map(fn member ->
          member
          |> Map.put(:moniker, FriendlyID.generate(3))
          |> Map.put(:avatar_img, random_avatar())
        end)

      if members == [] do
        {:halt, put_flash(socket, :info, "No eligible org members selected.")}
      else
        {:halt,
         socket
         |> assign(:pending_add_member_ids, Enum.map(members, & &1.user_id))
         |> push_event("seal_group_key_for_new_members", %{members: members})}
      end
    else
      {:halt, put_flash(socket, :error, "You don't have permission to add members.")}
    end
  end

  # Phase 2: the browser sealed the circle group_key for each new member (and any
  # guardian co-readers) and encrypted their display name/moniker/avatar with it.
  # Persist via the shared ZK write path, which RE-ENFORCES org-membership
  # eligibility (I1) server-side. The raw group_key NEVER reaches the server.
  def handle_circle_event(
        "finalize_group_members_zk",
        %{"sealed_members" => sealed_members},
        socket
      )
      when is_list(sealed_members) do
    current_user = socket.assigns.current_scope.user

    if can_edit_group?(socket.assigns.current_user_group, current_user) do
      {:ok, added} = Groups.add_group_members_zk(socket.assigns.group, sealed_members)

      # Realtime: refresh every open org dashboard + circle page (member counts
      # and rosters) without a reload.
      Orgs.broadcast_org_update(socket.assigns.org)

      {:halt,
       socket
       |> put_flash(
         :success,
         "#{added} member#{if added != 1, do: "s"} added to the circle."
       )
       |> assign(:show_add_members?, false)
       |> assign(:pending_add_member_ids, [])
       |> refresh_circle()}
    else
      {:halt, put_flash(socket, :error, "You don't have permission to add members.")}
    end
  end

  # --- Leave / remove (self-organization — Task #231/#234) ---

  def handle_circle_event("leave_circle", _params, socket) do
    current_user = socket.assigns.current_scope.user
    group = socket.assigns.group
    user_group = socket.assigns.current_user_group
    org_path = socket.assigns.circle_org_path

    cond do
      is_nil(user_group) ->
        {:halt, push_navigate(socket, to: org_path)}

      group.user_id == current_user.id ->
        {:halt,
         put_flash(
           socket,
           :error,
           "You own this circle, so you can't leave it. Delete it from the organization dashboard instead."
         )}

      true ->
        {:ok, _} = Groups.delete_user_group(user_group)
        # Revoke the leaver's sealed file_keys for this circle (Task #234). The
        # explicit act of leaving IS the trigger (never silent — design §6.3).
        Files.revoke_member_file_access(group, current_user.id)
        Orgs.broadcast_org_update(socket.assigns.org)

        {:halt,
         socket
         |> put_flash(:info, "You've left the circle.")
         |> push_navigate(to: org_path)}
    end
  end

  def handle_circle_event("remove_member", %{"user_id" => user_id}, socket) do
    group = Groups.get_group!(socket.assigns.group.id)
    actor_ug = socket.assigns.current_user_group
    target_ug = Enum.find(group.user_groups, &(&1.user_id == user_id))

    cond do
      is_nil(target_ug) ->
        {:halt, refresh_circle(socket)}

      not can_remove_member?(socket.assigns.membership, actor_ug, %{
        self?: false,
        user: %{id: user_id}
      }) ->
        {:halt, put_flash(socket, :error, "You don't have permission to remove members.")}

      user_id == group.user_id ->
        {:halt, put_flash(socket, :error, "The circle owner can't be removed.")}

      true ->
        case remove_circle_member(socket.assigns.membership, actor_ug, target_ug) do
          {:ok, _} ->
            # Revoke the removed member's sealed file_keys for this circle (#234).
            Files.revoke_member_file_access(group, user_id)
            Orgs.broadcast_org_update(socket.assigns.org)

            {:halt,
             socket
             |> put_flash(:info, "Member removed from the circle.")
             |> refresh_circle()}

          _ ->
            {:halt, put_flash(socket, :error, "Couldn't remove that member.")}
        end
    end
  end

  def handle_circle_event(_event, _params, _socket), do: :cont

  ## Shared info handling — returns {:halt, socket} | :cont

  def handle_circle_info({:org_updated, _org_id}, socket) do
    current_user = socket.assigns.current_scope.user

    # Realtime membership change (Task #231): if the viewer is no longer a
    # confirmed member of this circle, bounce them back to the org surface.
    if member_of_circle?(socket.assigns.group, current_user.id) do
      {:halt, refresh_circle(socket)}
    else
      {:halt,
       socket
       |> put_flash(:info, "You're no longer a member of this circle.")
       |> push_navigate(to: socket.assigns.circle_org_path)}
    end
  end

  def handle_circle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    member_bounce(socket, group, kicked_user_id)
  end

  def handle_circle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    member_bounce(socket, group, blocked_user_id)
  end

  def handle_circle_info({:group_deleted, _group}, socket) do
    {:halt,
     socket
     |> put_flash(:info, "This circle no longer exists.")
     |> push_navigate(to: socket.assigns.circle_org_path)}
  end

  def handle_circle_info({:shared_files_updated, _id}, socket) do
    {:halt, refresh_circle(socket)}
  end

  def handle_circle_info(_msg, _socket), do: :cont

  defp member_bounce(socket, group, target_user_id) do
    cond do
      group.id != socket.assigns.group.id ->
        {:halt, socket}

      target_user_id == socket.assigns.current_scope.user.id ->
        {:halt,
         socket
         |> put_flash(:info, "You're no longer a member of this circle.")
         |> push_navigate(to: socket.assigns.circle_org_path)}

      true ->
        {:halt, refresh_circle(socket)}
    end
  end

  ## Data loading

  @doc """
  Refreshes the universal circle state (group, roster, files, catch-up, org
  key). Domain LiveViews can override `:refresh_circle_fun` in assigns to also
  refresh domain-specific state (e.g. business announcements) — the shared event
  handlers call `refresh_circle/1`, which honors that override.
  """
  def refresh_circle(socket) do
    case socket.assigns[:refresh_circle_fun] do
      fun when is_function(fun, 1) -> fun.(socket)
      _ -> assign_circle_data(socket)
    end
  end

  @doc """
  Loads the universal circle data: the circle group, the viewer's UserGroup +
  sealed group_key, the circle-scoped member roster (ZK org identity), the
  addable org members, the shared files (with the viewer's sealed file_key for
  in-place filename decryption), and the catch-up affordance state.
  """
  def assign_circle_data(socket) do
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

    org_members =
      OrgIdentity.build_members(
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
    |> assign(:org_display_names, OrgIdentity.display_name_directory(members))
    |> assign(:org_avatars, OrgIdentity.org_avatar_directory(members))
    |> assign(:addable_members, addable_members(org_members, circle_member_ids))
    |> assign(:can_manage_circle?, can_edit_group?(user_group, current_user))
    |> assign(:can_leave_circle?, not is_nil(user_group) and group.user_id != current_user.id)
    |> assign(:show_add_members?, socket.assigns[:show_add_members?] || false)
    |> assign(:viewer_sealed_org_key, OrgIdentity.viewer_sealed_org_key(members))
    |> assign(:shared_files, build_shared_files(group, current_user))
    |> assign_catch_up(group, current_user, user_group)
    |> maybe_request_org_key_seal(members)
  end

  # Catch-up affordance state (Task #231/#233).
  defp assign_catch_up(socket, group, current_user, user_group) do
    missing_count = Files.members_missing_file_access_count(group)
    viewer_missing? = Files.user_missing_file_access?(group, current_user.id)

    authorized? =
      (is_struct(user_group) and user_group.role in [:owner, :admin]) or
        socket.assigns.membership.role == :admin or
        Enum.any?(socket.assigns.shared_files, &(&1.uploader_id == current_user.id))

    socket
    |> assign(:catch_up_missing_count, missing_count)
    |> assign(:viewer_missing_files?, viewer_missing?)
    |> assign(:can_catch_up?, missing_count > 0 and authorized? and not viewer_missing?)
  end

  defp circle_member_user_ids(group) do
    group.user_groups
    |> Enum.filter(&(not is_nil(&1.confirmed_at)))
    |> MapSet.new(& &1.user_id)
  end

  defp addable_members(org_members, circle_member_ids) do
    Enum.filter(org_members, fn m ->
      not m.self? and not MapSet.member?(circle_member_ids, m.user.id)
    end)
  end

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

  @doc """
  Loads the embedded ZK chat once (re-streaming on every files/members refresh
  would reset scroll position). Live updates arrive via `ChatSupport`.
  """
  def assign_chat(socket) do
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

      OrgIdentity.viewer_can_seal_for_others?(members) ->
        push_event(socket, "seal_org_key_for_members", %{
          members: OrgIdentity.members_to_seal(org)
        })

      true ->
        socket
    end
  end

  ## Guardian co-read (Task #271)

  # The active guardians (server-authoritative, from Guardianship records — I1)
  # of the given managed members, restricted to the circle's addable set (org
  # members not already in the circle). Family orgs only; business orgs have no
  # guardianship co-read. Returns a de-duplicated list of guardian `user_id`s to
  # fold into the group-key seal payload, so the circle group_key is co-sealed
  # for each guardian's public key — the identical pattern used for posts/DMs
  # (see `docs/GUARDIANSHIP_DESIGN.md`).
  defp guardian_coread_ids(%{type: :family}, selected_ids, eligible_ids) do
    selected_ids
    |> Enum.flat_map(&Orgs.list_active_guardian_users_for_user/1)
    |> Enum.map(& &1.id)
    |> Enum.uniq()
    |> Enum.filter(&MapSet.member?(eligible_ids, &1))
  end

  defp guardian_coread_ids(_org, _selected_ids, _eligible_ids), do: []

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

  @doc """
  Whether `user_id` is a confirmed member of `group`. Re-fetches the group, so
  callers can pass a stale struct safely.
  """
  def member_of_circle?(group, user_id) do
    group = Groups.get_group!(group.id)

    Enum.any?(group.user_groups, fn ug ->
      ug.user_id == user_id and not is_nil(ug.confirmed_at)
    end)
  end

  @doc """
  Whether `member` (a roster view-model) may be removed by the viewer. Server-
  authoritative: a non-owner member can be removed by the circle owner/admin
  (per-circle role) OR an org admin (org-level role). The circle owner is never
  removable; self never shows a Remove affordance (use Leave instead).
  """
  def can_remove_member?(membership, actor_ug, member) do
    cond do
      member.self? ->
        false

      true ->
        org_admin? = is_struct(membership) and membership.role == :admin
        circle_manager? = is_struct(actor_ug) and actor_ug.role in [:owner, :admin]
        org_admin? or circle_manager?
    end
  end

  defp remove_circle_member(membership, actor_ug, target_ug) do
    cond do
      is_struct(actor_ug) and actor_ug.role in [:owner, :admin] and
          Groups.can_moderate?(actor_ug.role, target_ug.role) ->
        Groups.kick_member(actor_ug, target_ug)

      membership && membership.role == :admin ->
        group = Groups.get_group!(target_ug.group_id)

        case Groups.remove_group_members(group, [target_ug.user_id]) do
          {:ok, n} when n > 0 -> {:ok, n}
          _ -> {:error, :not_removed}
        end

      true ->
        {:error, :unauthorized}
    end
  end

  defp random_avatar do
    Enum.random(
      ~w(astronaut.png bear.png cat.png chicken.png dinosaur.png dog.png panda.png penguin.png rabbit.png sea-lion.png)
    )
  end

  @doc """
  Human-readable byte size for the Files panel. Public so the shared circle
  components can format sizes.
  """
  def format_size(nil), do: "—"

  def format_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end

  @doc """
  Whether the viewer may delete `file` (its uploader, or an org admin).
  """
  def can_delete_file?(file, user, membership) do
    file.uploader_id == user.id or membership.role == :admin
  end
end
