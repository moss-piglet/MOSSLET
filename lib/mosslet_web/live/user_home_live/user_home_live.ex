defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

  import MossletWeb.Helpers

  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserBlock
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post
  alias MossletWeb.Helpers.StatusHelpers
  alias MossletWeb.Helpers.URLPreviewHelpers

  @posts_per_page 10

  def mount(%{"slug" => slug} = _params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    profile_user = Accounts.get_user_from_profile_slug!(slug)
    profile_owner? = current_user.id === profile_user.id

    socket = stream(socket, :presences, [])
    socket = stream(socket, :profile_posts, [])
    socket = stream(socket, :read_posts, [])

    socket =
      if connected?(socket) do
        Accounts.subscribe_user_status(current_user)
        Accounts.subscribe_account_deleted()
        Accounts.block_subscribe(current_user)
        Accounts.subscribe_connection_status(current_user)
        Accounts.private_subscribe(current_user)
        Timeline.reply_subscribe()
        Timeline.subscribe()
        Timeline.connections_reply_subscribe(current_user)
        Timeline.connections_subscribe(current_user)
        Timeline.private_subscribe(current_user)

        if profile_owner? do
          MossletWeb.Presence.track_activity(
            self(),
            %{
              id: current_user.id,
              live_view_name: "home",
              joined_at: System.system_time(:second),
              user_id: current_user.id,
              cache_optimization: true
            }
          )
        end

        MossletWeb.Presence.subscribe()

        socket = stream(socket, :presences, MossletWeb.Presence.list_online_users())

        Accounts.track_user_activity(current_user, :general)
        socket
      else
        socket
      end

    user_connection =
      if profile_owner?, do: nil, else: get_uconn_for_users!(profile_user.id, current_user.id)

    profile_user_block =
      if profile_owner?, do: nil, else: Accounts.get_user_block(current_user, profile_user.id)

    key = socket.assigns.current_scope.key
    user_connections = Accounts.get_all_confirmed_user_connections(current_user.id)

    post_shared_users =
      decrypt_shared_user_connections(user_connections, current_user, key, :post)

    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:page_title, if(profile_owner?, do: "Home", else: "Profile"))
      |> assign(:image_urls, [])
      |> assign(:delete_post_from_cloud_message, nil)
      |> assign(:delete_reply_from_cloud_message, nil)
      |> assign(:uploads_in_progress, false)
      |> assign(:trix_key, nil)
      |> assign(:profile_user, profile_user)
      |> assign(:current_user_is_profile_owner?, profile_owner?)
      |> assign(:user_connection, user_connection)
      |> assign(:user_connections, user_connections)
      |> assign(:post_shared_users, post_shared_users)
      |> assign(:removing_shared_user_id, nil)
      |> assign(:adding_shared_user, nil)
      |> assign(:posts_page, 1)
      |> assign(:posts_loading, false)
      |> assign(:load_more_loading, false)
      |> assign(:posts_count, 0)
      |> assign(:cached_profile_posts, [])
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> assign(:read_posts_count, 0)
      |> assign(:cached_read_posts, [])
      |> assign(:show_share_modal, false)
      |> assign(:share_post_id, nil)
      |> assign(:share_post_body, nil)
      |> assign(:share_post_username, nil)
      |> assign(:show_report_modal, false)
      |> assign(:report_post_id, nil)
      |> assign(:report_user_id, nil)
      |> assign(:report_reply_context, %{})
      |> assign(:show_block_modal, false)
      |> assign(:block_post_id, nil)
      |> assign(:block_user_id, nil)
      |> assign(:block_user_name, nil)
      |> assign(:existing_block, nil)
      |> assign(:block_decrypted_reason, "")
      |> assign(:block_default_type, "full")
      |> assign(:block_update?, false)
      |> assign(:profile_user_block, profile_user_block)
      |> assign(:removing_self_from_post_id, nil)
      |> assign(:pending_repost, nil)
      |> assign(:show_markdown_guide, false)
      |> assign(:show_image_modal, false)
      |> assign(:current_images, [])
      |> assign(:current_image_index, 0)
      |> assign(:current_post_for_images, nil)
      |> assign(:can_download_images, false)
      |> assign(:loaded_replies_counts, %{})
      |> assign(:loaded_nested_replies, %{})
      |> assign(:unread_replies_by_post, %{})
      |> assign(:unread_nested_replies_by_parent, %{})
      |> URLPreviewHelpers.assign_url_preview_defaults()
      |> maybe_load_custom_banner_async(profile_user, profile_owner?)

    profile_fields =
      cond do
        profile_owner? ->
          decrypt_profile_fields(
            current_user.connection.profile,
            current_user,
            key,
            viewing: :own,
            connection: current_user.connection
          )

        user_connection && profile_user.visibility == :connections ->
          decrypt_profile_fields(
            profile_user.connection.profile,
            current_user,
            key,
            viewing: :connection,
            uconn_key: user_connection.key,
            connection: profile_user.connection
          )

        profile_user.visibility == :public ->
          decrypt_profile_fields(
            profile_user.connection.profile,
            current_user,
            key,
            viewing: :public,
            connection: profile_user.connection
          )

        true ->
          nil
      end

    socket = assign(socket, :profile_fields, profile_fields)

    # Pre-decrypt profile identity fields (name, username, email). For own
    # profile, use the pre_decrypt_user fast path. For connection/public
    # profiles, read from profile_fields (which now includes these fields via
    # decrypt_profile_fields with the :connection opt).
    decrypted_profile =
      cond do
        profile_owner? ->
          %{
            name: resolve_decrypted_field(current_user, :name),
            username: resolve_decrypted_field(current_user, :username),
            email: resolve_decrypted_field(current_user, :email)
          }

        profile_fields ->
          %{
            name: profile_fields[:name],
            username: profile_fields[:username],
            email: profile_fields[:email]
          }

        true ->
          %{name: nil, username: nil, email: nil}
      end

    socket = assign(socket, :decrypted_profile, decrypted_profile)

    socket =
      if connected?(socket) do
        socket
        |> maybe_fetch_website_preview(profile_user, current_user, profile_owner?)
        |> load_profile_posts(profile_user, current_user, user_connection)
      else
        socket
      end

    {:ok, socket}
  end

  defp load_profile_posts(socket, profile_user, current_user, user_connection) do
    options = %{post_page: socket.assigns.posts_page, post_per_page: @posts_per_page}
    posts = Timeline.list_profile_posts_visible_to(profile_user, current_user, options)

    posts =
      if user_connection && user_connection.zen? do
        Enum.reject(posts, fn post -> post.user_id == profile_user.id end)
      else
        posts
      end

    posts_count =
      if user_connection && user_connection.zen? do
        0
      else
        Timeline.count_profile_posts_visible_to(profile_user, current_user)
      end

    {unread_posts, read_posts} =
      Enum.split_with(posts, fn post ->
        is_post_unread?(post, current_user)
      end)

    session_key = socket.assigns.current_scope.key

    unread_posts_with_dates =
      unread_posts
      |> add_date_grouping_context()
      |> pre_decrypt_posts(current_user, session_key)

    read_posts_with_dates =
      read_posts
      |> add_date_grouping_context()
      |> pre_decrypt_posts(current_user, session_key)

    socket
    |> assign(:posts_count, posts_count)
    |> assign(:cached_profile_posts, unread_posts_with_dates)
    |> assign(:read_posts_count, length(read_posts))
    |> assign(:cached_read_posts, read_posts_with_dates)
    |> assign(:read_posts_expanded, false)
    |> stream(:profile_posts, unread_posts_with_dates, reset: true)
    |> stream(:read_posts, [], reset: true)
  end

  defp maybe_reload_posts_for_block(socket, block, profile_user, current_user) do
    if block.block_type in [:full, :posts_only] do
      user_connection = socket.assigns.user_connection
      load_profile_posts(socket, profile_user, current_user, user_connection)
    else
      socket
    end
  end

  defp is_post_unread?(post, current_user) do
    cond do
      Ecto.assoc_loaded?(post.user_post_receipts) ->
        case Enum.find(post.user_post_receipts || [], fn receipt ->
               receipt.user_id == current_user.id
             end) do
          nil -> true
          %{is_read?: is_read} -> !is_read
        end

      true ->
        case Timeline.get_user_post_receipt(current_user, post) do
          nil -> true
          %{is_read?: true} -> false
          %{is_read?: false} -> true
          _ -> true
        end
    end
  end

  def render(assigns) do
    case {assigns.current_user_is_profile_owner?, assigns.profile_user.visibility} do
      {true, _} -> render_own_profile(assigns)
      {false, :public} -> render_public_profile(assigns)
      {false, :connections} -> render_connections_profile(assigns)
      {false, :private} -> render_no_access(assigns)
    end
  end

  @doc """
  Handle params. The "profile_user" assigned in the socket
  is the user whose profile is being viewed.

  The "current_user" is the session user (or "nil" if the
  profile is public and the session is not signed in).
  """
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info({:submit_report, report_params}, socket) do
    handle_event("submit_report", %{"report" => report_params}, socket)
  end

  def handle_info({:close_report_modal, _params}, socket) do
    socket =
      socket
      |> assign(:show_report_modal, false)
      |> assign(:report_post_id, nil)
      |> assign(:report_user_id, nil)
      |> assign(:report_reply_context, %{})

    {:noreply, socket}
  end

  def handle_info({:submit_block, block_params}, socket) do
    handle_event("submit_block", %{"block" => block_params}, socket)
  end

  def handle_info({:close_block_modal}, socket) do
    handle_event("close_block_modal", %{}, socket)
  end

  def handle_info({event, %UserBlock{} = block}, socket)
      when event in [:user_blocked, :user_block_updated] do
    current_user = socket.assigns.current_scope.user
    profile_user = socket.assigns.profile_user

    if block.blocker_id == current_user.id and block.blocked_id == profile_user.id do
      socket =
        socket
        |> assign(:profile_user_block, block)
        |> maybe_reload_posts_for_block(block, profile_user, current_user)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_unblocked, %UserBlock{} = block}, socket) do
    current_user = socket.assigns.current_scope.user
    profile_user = socket.assigns.profile_user

    if block.blocker_id == current_user.id and block.blocked_id == profile_user.id do
      socket =
        socket
        |> assign(:profile_user_block, nil)
        |> maybe_reload_posts_for_block(block, profile_user, current_user)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({MossletWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({MossletWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  def handle_info({:status_updated, user}, socket) do
    profile_user = socket.assigns.profile_user

    if user.id == profile_user.id do
      {:noreply, assign(socket, :profile_user, user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:status_visibility_updated, user}, socket) do
    profile_user = socket.assigns.profile_user

    if user.id == profile_user.id do
      {:noreply, assign(socket, :profile_user, user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)
        {:noreply, assign(socket, :profile_user, user)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)

        if user.connection.profile.visibility in [:connections, :public] do
          {:noreply, assign(socket, :profile_user, user)}
        else
          {:noreply, push_navigate(socket, to: ~p"/app")}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)
        {:noreply, assign(socket, :profile_user, user)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:conn_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)

        if user.connection.profile.visibility in [:connections, :public] do
          {:noreply, assign(socket, :profile_user, user)}
        else
          {:noreply, push_navigate(socket, to: ~p"/app")}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({ref, {:website_preview_result, result}}, socket) do
    Process.demonitor(ref, [:flush])
    profile_key = get_profile_key_for_preview(socket)

    case URLPreviewHelpers.handle_preview_result(
           {ref, {:website_preview_result, result}},
           socket,
           profile_key
         ) do
      {:handled, socket} -> {:noreply, socket}
      {:not_handled, socket} -> {:noreply, socket}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason} = msg, socket) do
    case URLPreviewHelpers.handle_preview_result(msg, socket, nil) do
      {:handled, socket} -> {:noreply, socket}
      {:not_handled, socket} -> {:noreply, socket}
    end
  end

  def handle_info({:post_created, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    is_profile_user_post? = post.user_id == profile_user.id

    is_shared_with_current_user? =
      Enum.any?(post.shared_users || [], &(&1.user_id == current_user.id))

    cond do
      is_profile_user_post? and post_visible_on_profile?(post, profile_user, current_user) ->
        cached_posts = socket.assigns.cached_profile_posts
        already_in_profile_posts? = Enum.any?(cached_posts, &(&1.id == post.id))

        if already_in_profile_posts? do
          {:noreply, socket}
        else
          session_key = socket.assigns.current_scope.key
          post = pre_decrypt_post(post, current_user, session_key)
          post_with_date = add_single_post_date_context(post, cached_posts, at: 0)
          updated_cached = [post_with_date | cached_posts]

          socket =
            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> assign(:posts_count, socket.assigns.posts_count + 1)
            |> maybe_update_old_first_post_separator(cached_posts, post_with_date, at: 0)
            |> stream_insert(:profile_posts, post_with_date, at: 0)

          {:noreply, socket}
        end

      is_profile_user_post? and is_shared_with_current_user? ->
        cached_profile_posts = socket.assigns.cached_profile_posts
        already_in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))

        if already_in_profile_posts? do
          {:noreply, socket}
        else
          session_key = socket.assigns.current_scope.key
          post = pre_decrypt_post(post, current_user, session_key)
          post_with_date = add_single_post_date_context(post, cached_profile_posts, at: 0)
          updated_cached = [post_with_date | cached_profile_posts]

          socket =
            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> assign(:posts_count, socket.assigns.posts_count + 1)
            |> maybe_update_old_first_post_separator(cached_profile_posts, post_with_date, at: 0)
            |> stream_insert(:profile_posts, post_with_date, at: 0)

          {:noreply, socket}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:post_updated, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_updated_fav, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_deleted, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    cached_profile_posts = socket.assigns.cached_profile_posts
    cached_read_posts = socket.assigns.cached_read_posts

    in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
    in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

    socket =
      cond do
        in_profile_posts? ->
          updated_cached = Enum.reject(cached_profile_posts, &(&1.id == post.id))

          socket
          |> assign(:cached_profile_posts, updated_cached)
          |> assign(:posts_count, max(0, socket.assigns.posts_count - 1))
          |> stream_delete(:profile_posts, post)

        in_read_posts? ->
          updated_cached = Enum.reject(cached_read_posts, &(&1.id == post.id))

          socket
          |> assign(:cached_read_posts, updated_cached)
          |> stream_delete(:read_posts, post)

        post.user_id == profile_user.id or post.user_id == current_user.id ->
          socket
          |> assign(:posts_count, max(0, socket.assigns.posts_count - 1))

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:post_shared_users_added, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    Logger.debug(
      "handle_info :post_shared_users_added - post.id=#{post.id}, post.user_id=#{post.user_id}, profile_user.id=#{profile_user.id}, current_user.id=#{current_user.id}"
    )

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      Logger.debug(
        "handle_info :post_shared_users_added - in_profile_posts?=#{in_profile_posts?}, in_read_posts?=#{in_read_posts?}, cached_profile_posts_count=#{length(cached_profile_posts)}"
      )

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, assign(socket, :adding_shared_user, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_shared_users_removed, post}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    Logger.debug(
      "handle_info :post_shared_users_removed - post.id=#{post.id}, post.user_id=#{post.user_id}, profile_user.id=#{profile_user.id}, current_user.id=#{current_user.id}"
    )

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      Logger.debug(
        "handle_info :post_shared_users_removed - in_profile_posts?=#{in_profile_posts?}, in_read_posts?=#{in_read_posts?}, cached_profile_posts_count=#{length(cached_profile_posts)}"
      )

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, assign(socket, :removing_shared_user_id, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_updated_user_removed, post}, socket) do
    cached_profile_posts = socket.assigns.cached_profile_posts
    cached_read_posts = socket.assigns.cached_read_posts

    in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
    in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

    socket =
      cond do
        in_profile_posts? ->
          updated_cached = Enum.reject(cached_profile_posts, &(&1.id == post.id))

          socket
          |> assign(:cached_profile_posts, updated_cached)
          |> stream_delete(:profile_posts, post)

        in_read_posts? ->
          updated_cached = Enum.reject(cached_read_posts, &(&1.id == post.id))

          socket
          |> assign(:cached_read_posts, updated_cached)
          |> stream_delete(:read_posts, post)

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:reply_created, post, _reply}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_deleted, post, _reply}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      socket =
        cond do
          in_profile_posts? ->
            updated_cached = update_cached_post(cached_profile_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_profile_posts, updated_cached)
            |> stream_insert(:profile_posts, post_with_date)

          in_read_posts? ->
            updated_cached = update_cached_post(cached_read_posts, post)
            post_with_date = find_post_with_date(updated_cached, post.id) || post

            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date)

          true ->
            socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_updated_fav, post, reply}, socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_profile_posts = socket.assigns.cached_profile_posts
      cached_read_posts = socket.assigns.cached_read_posts

      in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
      in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

      if in_profile_posts? or in_read_posts? do
        is_liked =
          if post.visibility == :public do
            key = socket.assigns.current_scope.key
            decrypted_favs = decrypt_reply_favs_list(reply, post, current_user, key)
            current_user.id in decrypted_favs
          else
            nil
          end

        {:noreply,
         push_event(socket, "update_reply_fav_count", %{
           reply_id: reply.id,
           favs_count: reply.favs_count,
           is_liked: is_liked
         })}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:submit_share, share_params}, socket) do
    post = Timeline.get_post!(share_params.post_id)
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    decrypted_reposts = decrypt_post_reposts_list(post, user, key)

    if post.user_id != user.id && user.id not in decrypted_reposts do
      selected_user_ids = share_params.selected_user_ids
      note = share_params[:note] || ""
      encrypted_share_note = share_params[:encrypted_share_note]
      username = share_params.username

      all_shared_users = socket.assigns.post_shared_users

      selected_shared_users =
        all_shared_users
        |> Enum.filter(fn su -> su.user_id in selected_user_ids end)
        |> Enum.map(fn su ->
          %{
            sender_id: su.sender_id,
            username: su.username,
            user_id: su.user_id,
            color: su.color
          }
        end)

      case build_repost_encrypt_request(post, selected_shared_users, user: user) do
        {:zk, payload} ->
          # Non-public: push to browser for ZK encryption.
          # If the share note was already encrypted browser-side (with the
          # original post_key), pass it as encrypted_share_note so the
          # RepostFormHook can re-encrypt with the new post_key.
          note_payload =
            if encrypted_share_note do
              %{encrypted_share_note: encrypted_share_note}
            else
              %{note: note}
            end

          {:noreply,
           socket
           |> assign(:pending_repost, %{
             post_id: post.id,
             decrypted_reposts: decrypted_reposts,
             shared_users: selected_shared_users,
             visibility: :connections,
             image_urls_updated_at: post.image_urls_updated_at,
             favs_count: post.favs_count,
             reposts_count: post.reposts_count
           })
           |> push_event(
             "repost_encrypt_request",
             Map.merge(
               payload,
               Map.merge(
                 %{
                   repost_type: "share",
                   selected_user_ids: selected_user_ids
                 },
                 note_payload
               )
             )
           )}

        :server ->
          # Public: use existing server-side path
          do_share_server(
            post,
            user,
            key,
            all_shared_users,
            decrypted_reposts,
            selected_user_ids,
            note,
            username,
            socket
          )
      end
    else
      {:noreply,
       socket
       |> assign(:show_share_modal, false)
       |> put_flash(:error, "You cannot share this post.")}
    end
  end

  def handle_info({:close_share_modal, _params}, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:share_post_id, nil)
     |> assign(:share_post_body, nil)
     |> assign(:share_post_username, nil)}
  end

  def handle_info({:create_reply, reply_params, post_id, visibility}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        post_key = get_post_key(post, current_user)

        case Timeline.create_reply(reply_params,
               user: current_user,
               key: key,
               post: post,
               post_key: post_key,
               visibility: visibility
             ) do
          {:ok, _reply} ->
            Accounts.track_user_activity(current_user, :interaction)
            updated_post = Timeline.get_post!(post_id)

            socket =
              socket
              |> put_flash(:success, "Reply posted successfully!")
              |> update_post_in_streams(updated_post)
              |> push_event("show-reply-thread", %{post_id: post_id})

            {:noreply, socket}

          {:error, changeset} ->
            send_update(MossletWeb.TimelineLive.ReplyComposerComponent,
              id: "reply-composer-#{post_id}",
              form: to_form(changeset, action: :validate)
            )

            {:noreply,
             put_flash(socket, :error, "Failed to post reply. Please check your input.")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  def handle_info({:create_reply_zk, zk_params, post_id, visibility}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        post_key = get_post_key(post, current_user)

        reply_params = %{
          "user_id" => current_user.id,
          "post_id" => post_id,
          "group_id" => zk_params["group_id"],
          "visibility" => to_string(visibility),
          # Browser-encrypted (base64) ciphertext, stored as-is for ZK.
          # Provided here so the changeset's required/length validations pass.
          "body" => zk_params["encrypted_body"],
          "username" => zk_params["encrypted_username"]
        }

        case Timeline.create_reply(reply_params,
               user: current_user,
               key: key,
               post: post,
               post_key: post_key,
               visibility: visibility,
               zk_reply: true
             ) do
          {:ok, _reply} ->
            Accounts.track_user_activity(current_user, :interaction)
            updated_post = Timeline.get_post!(post_id)

            socket =
              socket
              |> put_flash(:success, "Reply posted successfully!")
              |> update_post_in_streams(updated_post)
              |> push_event("show-reply-thread", %{post_id: post_id})

            {:noreply, socket}

          {:error, changeset} ->
            send_update(MossletWeb.TimelineLive.ReplyComposerComponent,
              id: "reply-composer-#{post_id}",
              form: to_form(changeset, action: :validate)
            )

            {:noreply,
             put_flash(socket, :error, "Failed to post reply. Please check your input.")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  def handle_info({:nested_reply_created, post_id, parent_reply_id}, socket) do
    updated_post = Timeline.get_post!(post_id)

    socket =
      socket
      |> update_post_in_streams(updated_post)
      |> put_flash(:success, "Reply created!")
      |> push_event("hide-nested-reply-composer", %{reply_id: parent_reply_id})

    {:noreply, socket}
  end

  def handle_info({:nested_reply_error, error_message}, socket) do
    {:noreply, put_flash(socket, :error, error_message)}
  end

  def handle_info({:nested_reply_cancelled, parent_reply_id}, socket) do
    socket = push_event(socket, "hide-nested-reply-composer", %{reply_id: parent_reply_id})
    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp update_post_in_streams(socket, post) do
    cached_profile_posts = socket.assigns.cached_profile_posts
    cached_read_posts = socket.assigns.cached_read_posts

    in_profile_posts? = Enum.any?(cached_profile_posts, &(&1.id == post.id))
    in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

    cond do
      in_profile_posts? ->
        updated_cached = update_cached_post(cached_profile_posts, post)
        post_with_date = find_post_with_date(updated_cached, post.id) || post

        socket
        |> assign(:cached_profile_posts, updated_cached)
        |> stream_insert(:profile_posts, post_with_date)

      in_read_posts? ->
        updated_cached = update_cached_post(cached_read_posts, post)
        post_with_date = find_post_with_date(updated_cached, post.id) || post

        socket
        |> assign(:cached_read_posts, updated_cached)
        |> stream_insert(:read_posts, post_with_date)

      true ->
        socket
    end
  end

  def handle_event("repost_encrypted", params, socket) do
    user = socket.assigns.current_scope.user
    pending = socket.assigns[:pending_repost]

    if pending do
      original_post_id = params["original_post_id"]
      post = Timeline.get_post!(original_post_id)

      shared_users =
        case params["repost_type"] do
          "share" ->
            selected_ids = params["selected_user_ids"] || []

            pending.shared_users
            |> Enum.filter(fn su ->
              su[:user_id] in selected_ids
            end)

          _ ->
            pending.shared_users
        end

      visibility =
        if params["repost_type"] == "share",
          do: :connections,
          else: pending.visibility

      repost_attrs = %{
        body: params["encrypted_body"],
        username: params["encrypted_username"],
        avatar_url: params["encrypted_avatar_url"],
        image_urls: non_empty_list(params["encrypted_image_urls"]),
        image_alt_texts: non_empty_list(params["encrypted_image_alt_texts"]),
        image_urls_updated_at: pending.image_urls_updated_at,
        url_preview: params["encrypted_url_preview"],
        content_warning: params["encrypted_content_warning"],
        content_warning_category: params["encrypted_content_warning_category"],
        content_warning?: !is_nil(params["encrypted_content_warning"]),
        favs_count: 0,
        reposts_count: 0,
        repost: true,
        user_id: user.id,
        original_post_id: original_post_id,
        visibility: visibility,
        shared_users: shared_users,
        user_post_map: %{
          sealed_author_key: params["sealed_author_key"],
          sealed_recipient_keys: params["sealed_recipient_keys"] || []
        }
      }

      # Add encrypted share note if this is a targeted share
      repost_attrs =
        if params["repost_type"] == "share" && params["encrypted_share_note"] do
          Map.put(repost_attrs, :encrypted_share_note, params["encrypted_share_note"])
        else
          repost_attrs
        end

      result =
        if params["repost_type"] == "share" do
          Timeline.create_targeted_share_zk(repost_attrs, user)
        else
          Timeline.create_repost_zk(repost_attrs, user)
        end

      case result do
        {:ok, _repost} ->
          {:ok, post} = Timeline.inc_reposts(post)

          updated_reposts = [user.id | pending.decrypted_reposts]

          {:ok, _post} =
            Timeline.update_post_repost_zk(
              post,
              %{reposts_list: updated_reposts}
            )

          Accounts.track_user_activity(user, :interaction)

          flash_msg =
            if params["repost_type"] == "share" do
              selected_count = length(params["selected_user_ids"] || [])

              "Shared with #{selected_count} #{if selected_count == 1, do: "person", else: "people"}!"
            else
              "Post reposted successfully."
            end

          {:noreply,
           socket
           |> assign(:pending_repost, nil)
           |> assign(:show_share_modal, false)
           |> assign(:share_post_id, nil)
           |> assign(:share_post_body, nil)
           |> assign(:share_post_username, nil)
           |> put_flash(:success, flash_msg)
           |> push_event("update_post_repost_count", %{
             post_id: post.id,
             reposts_count: post.reposts_count,
             can_repost: false
           })}

        {:error, _changeset} ->
          flash_msg =
            if params["repost_type"] == "share",
              do: "Failed to share. Please try again.",
              else: "Failed to repost. Please try again."

          {:noreply,
           socket
           |> assign(:pending_repost, nil)
           |> assign(:show_share_modal, false)
           |> put_flash(:error, flash_msg)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("repost_encrypt_failed", _params, socket) do
    # Browser encryption failed — block the operation to preserve ZK.
    # No server-side fallback: allowing one would leak plaintext to the server.
    {:noreply,
     socket
     |> assign(:pending_repost, nil)
     |> assign(:show_share_modal, false)
     |> put_flash(:error, "Encryption failed. Please refresh and try again.")}
  end

  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, false)}
  end

  def handle_event("load_more_posts", _params, socket) do
    socket = assign(socket, :load_more_loading, true)
    current_user = socket.assigns.current_scope.user
    profile_user = socket.assigns.profile_user

    current_page = socket.assigns.posts_page
    next_page = current_page + 1

    options = %{post_page: next_page, post_per_page: @posts_per_page}
    new_posts = Timeline.list_profile_posts_visible_to(profile_user, current_user, options)

    if Enum.empty?(new_posts) do
      {:noreply, assign(socket, :load_more_loading, false)}
    else
      {new_unread, new_read_posts} =
        Enum.split_with(new_posts, fn post ->
          is_post_unread?(post, current_user)
        end)

      session_key = socket.assigns.current_scope.key
      cached_read_posts = socket.assigns.cached_read_posts
      cached_profile_posts = socket.assigns.cached_profile_posts

      new_unread_with_dates =
        new_unread
        |> add_date_grouping_context_for_append(cached_profile_posts)
        |> pre_decrypt_posts(current_user, session_key)

      new_read_posts_with_dates =
        new_read_posts
        |> add_date_grouping_context_for_append(cached_read_posts)
        |> pre_decrypt_posts(current_user, session_key)

      updated_cached_profile = cached_profile_posts ++ new_unread_with_dates
      updated_cached_read = cached_read_posts ++ new_read_posts_with_dates

      socket =
        socket
        |> assign(:posts_page, next_page)
        |> assign(:cached_profile_posts, updated_cached_profile)
        |> assign(:cached_read_posts, updated_cached_read)
        |> assign(:load_more_loading, false)

      socket =
        Enum.reduce(new_unread_with_dates, socket, fn post, acc_socket ->
          stream_insert(acc_socket, :profile_posts, post, at: -1)
        end)

      socket =
        Enum.reduce(new_read_posts_with_dates, socket, fn post, acc_socket ->
          stream_insert(acc_socket, :read_posts, post, at: -1)
        end)

      {:noreply, socket}
    end
  end

  def handle_event("toggle_read_posts", _params, socket) do
    if socket.assigns.read_posts_expanded do
      {:noreply,
       socket
       |> assign(:read_posts_expanded, false)
       |> stream(:read_posts, [], reset: true)}
    else
      cached_posts = socket.assigns[:cached_read_posts] || []
      posts_count = socket.assigns.posts_count
      unread_count = length(socket.assigns.cached_profile_posts)
      total_read_available = posts_count - unread_count

      socket =
        if length(cached_posts) < @posts_per_page and length(cached_posts) < total_read_available do
          fetch_additional_read_posts(socket, @posts_per_page - length(cached_posts))
        else
          socket
        end

      cached_posts = socket.assigns[:cached_read_posts] || []
      posts_with_dates = add_date_grouping_context(cached_posts)

      {:noreply,
       socket
       |> assign(:read_posts_expanded, true)
       |> stream(:read_posts, posts_with_dates, reset: true)}
    end
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    decrypted_favs = decrypt_post_favs_list(post, current_user, key)
    is_currently_liked = current_user.id in decrypted_favs

    if not is_currently_liked do
      {:ok, post} = Timeline.inc_favs(post)
      updated_favs = [current_user.id | decrypted_favs]
      encrypted_post_key = get_post_key(post, current_user)

      case Timeline.update_post_fav(
             post,
             %{favs_list: updated_favs},
             user: current_user,
             key: key,
             post_key: encrypted_post_key
           ) do
        {:ok, _post} ->
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    decrypted_favs = decrypt_post_favs_list(post, current_user, key)
    is_currently_liked = current_user.id in decrypted_favs

    if is_currently_liked do
      {:ok, post} = Timeline.decr_favs(post)
      updated_favs = List.delete(decrypted_favs, current_user.id)
      encrypted_post_key = get_post_key(post, current_user)

      case Timeline.update_post_fav(
             post,
             %{favs_list: updated_favs},
             user: current_user,
             key: key,
             post_key: encrypted_post_key
           ) do
        {:ok, _post} ->
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  # ZK fav toggle: browser encrypts the updated favs_list and sends it pre-encrypted.
  def handle_event(
        "toggle_fav_zk",
        %{"id" => id, "encrypted_favs_list" => encrypted_list, "is_liked" => is_liked},
        socket
      ) do
    post = Timeline.get_post!(id)

    if post do
      is_liked_bool = is_liked == "true"

      count_delta = if is_liked_bool, do: 1, else: -1

      updated_post =
        if is_liked_bool do
          {:ok, p} = Timeline.inc_favs(post)
          p
        else
          {:ok, p} = Timeline.decr_favs(post)
          p
        end

      encrypted_favs =
        if encrypted_list && encrypted_list != "" do
          Jason.decode!(encrypted_list)
        else
          []
        end

      Timeline.update_post_fav_zk(post, %{
        favs_list: encrypted_favs,
        favs_count: post.favs_count + count_delta
      })

      Accounts.track_user_activity(socket.assigns.current_scope.user, :interaction)

      {:noreply,
       socket
       |> push_event("update_post_fav_count", %{
         post_id: updated_post.id,
         favs_count: updated_post.favs_count,
         is_liked: is_liked_bool
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_event("bookmark_post", %{"id" => post_id}, socket) do
    current_user = socket.assigns.current_scope.user

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        if Timeline.bookmarked?(current_user, post) do
          bookmark = Timeline.get_bookmark(current_user, post)

          case Timeline.delete_bookmark(bookmark, current_user) do
            {:ok, _bookmark} ->
              Accounts.track_user_activity(current_user, :interaction)

              socket =
                socket
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: false
                })
                |> put_flash(:info, "Bookmark removed successfully.")

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to remove bookmark")}
          end
        else
          case Timeline.create_bookmark(current_user, post, %{}) do
            {:ok, _bookmark} ->
              Accounts.track_user_activity(current_user, :interaction)

              socket =
                socket
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: true
                })
                |> put_flash(:success, "Post bookmarked successfully.")

              {:noreply, socket}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to bookmark post")}
          end
        end

      nil ->
        Logger.error("Post not found for bookmarking: #{post_id}")
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  # ZK bookmark with notes: browser encrypts notes with cached post_key
  def handle_event(
        "bookmark_post_with_notes",
        %{"id" => post_id, "encrypted_notes" => encrypted_notes},
        socket
      ) do
    current_user = socket.assigns.current_scope.user

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        result =
          if post.visibility == :public do
            Timeline.create_bookmark(current_user, post, %{notes: encrypted_notes})
          else
            Timeline.create_bookmark_zk(current_user, post, encrypted_notes)
          end

        case result do
          {:ok, _bookmark} ->
            Accounts.track_user_activity(current_user, :interaction)

            socket =
              socket
              |> push_event("update_post_bookmark", %{
                post_id: post_id,
                is_bookmarked: true
              })
              |> put_flash(:success, "Post bookmarked with notes.")

            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to bookmark post")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  # Update existing bookmark notes (ZK write path)
  def handle_event(
        "update_bookmark_notes",
        %{"id" => post_id, "encrypted_notes" => encrypted_notes},
        socket
      ) do
    current_user = socket.assigns.current_scope.user

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        case Timeline.get_bookmark(current_user, post) do
          nil ->
            {:noreply, put_flash(socket, :error, "Bookmark not found")}

          bookmark ->
            result =
              if post.visibility == :public do
                Timeline.update_bookmark(bookmark, %{notes: encrypted_notes}, current_user)
              else
                Timeline.update_bookmark_zk(bookmark, encrypted_notes)
              end

            case result do
              {:ok, _updated} ->
                {:noreply, put_flash(socket, :success, "Bookmark notes updated.")}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Failed to update bookmark notes")}
            end
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  # ZK path: browser encrypts/decrypts the favs_list using cached post_key.
  def handle_event(
        "toggle_reply_fav_zk",
        %{"id" => id, "encrypted_favs_list" => encrypted_list, "is_liked" => is_liked},
        socket
      ) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_scope.user

    if reply do
      is_liked_bool = is_liked == "true"

      updated_reply =
        if is_liked_bool do
          {:ok, r} = Timeline.inc_reply_favs(reply)
          r
        else
          {:ok, r} = Timeline.decr_reply_favs(reply)
          r
        end

      encrypted_favs =
        if encrypted_list && encrypted_list != "" do
          Jason.decode!(encrypted_list)
        else
          []
        end

      Timeline.update_reply_fav_zk(
        reply,
        %{favs_list: encrypted_favs, favs_count: updated_reply.favs_count},
        current_user
      )

      Accounts.track_user_activity(current_user, :interaction)

      {:noreply,
       socket
       |> push_event("update_reply_fav_count", %{
         reply_id: updated_reply.id,
         favs_count: updated_reply.favs_count,
         is_liked: is_liked_bool
       })}
    else
      {:noreply, put_flash(socket, :error, "Reply not found.")}
    end
  end

  # Server path: for public posts where the server has the post_key.
  def handle_event("fav_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post)

    case Timeline.inc_reply_favs(reply) do
      {:ok, reply} ->
        decrypted_favs = decrypt_reply_favs_list(reply, post, current_user, key)

        if current_user.id not in decrypted_favs do
          new_favs = [current_user.id | decrypted_favs]

          case Timeline.update_reply_fav(
                 reply,
                 %{favs_list: new_favs, favs_count: reply.favs_count},
                 user: current_user,
                 key: key,
                 post_key: post_key,
                 visibility: post.visibility,
                 group_id: post.group_id
               ) do
            {:ok, updated_reply} ->
              Accounts.track_user_activity(current_user, :interaction)

              {:noreply,
               socket
               |> push_event("update_reply_fav_count", %{
                 reply_id: updated_reply.id,
                 favs_count: updated_reply.favs_count,
                 is_liked: true
               })
               |> put_flash(:success, "You loved this reply!")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Operation failed. Please try again.")}
          end
        else
          Timeline.decr_reply_favs(reply)
          {:noreply, socket}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Reply not found. Please try again.")}
    end
  end

  def handle_event("unfav_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post)

    case Timeline.decr_reply_favs(reply) do
      {:ok, reply} ->
        decrypted_favs = decrypt_reply_favs_list(reply, post, current_user, key)

        if current_user.id in decrypted_favs do
          new_favs = List.delete(decrypted_favs, current_user.id)

          case Timeline.update_reply_fav(
                 reply,
                 %{favs_list: new_favs, favs_count: reply.favs_count},
                 user: current_user,
                 key: key,
                 post_key: post_key,
                 visibility: post.visibility,
                 group_id: post.group_id
               ) do
            {:ok, updated_reply} ->
              Accounts.track_user_activity(current_user, :interaction)

              {:noreply,
               socket
               |> push_event("update_reply_fav_count", %{
                 reply_id: updated_reply.id,
                 favs_count: updated_reply.favs_count,
                 is_liked: false
               })
               |> put_flash(:success, "You removed love from this reply.")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to remove love. Please try again.")}
          end
        else
          Timeline.inc_reply_favs(reply)
          {:noreply, socket}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Reply not found. Please try again.")}
    end
  end

  def handle_event(
        "open_share_modal",
        %{"id" => id, "body" => body, "username" => username},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:share_post_id, id)
     |> assign(:share_post_body, body)
     |> assign(:share_post_username, username)}
  end

  def handle_event("close_share_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_share_modal, false)
     |> assign(:share_post_id, nil)
     |> assign(:share_post_body, nil)
     |> assign(:share_post_username, nil)}
  end

  def handle_event("toggle-read-status", %{"id" => post_id}, socket) do
    current_user = socket.assigns.current_scope.user
    post = Timeline.get_post!(post_id)
    receipt = Timeline.get_user_post_receipt(current_user, post)

    result =
      case receipt do
        nil ->
          desired_read_status =
            if post.visibility == :public && post.user_id != current_user.id do
              false
            else
              true
            end

          case Timeline.get_or_create_user_post_for_public(post, current_user) do
            {:ok, user_post} ->
              Timeline.create_or_update_user_post_receipt(
                user_post,
                current_user,
                desired_read_status
              )

            {:error, _reason} ->
              {:error, :failed}
          end

        %{is_read?: true} ->
          Timeline.update_user_post_receipt_unread(receipt.id)

        %{is_read?: false} ->
          Timeline.update_user_post_receipt_read(receipt.id)
      end

    case result do
      {:ok, _, _} ->
        Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

        updated_post =
          Timeline.get_post!(post_id)
          |> Mosslet.Repo.preload([:user, :user_post_receipts], force: true)

        socket = move_post_between_read_streams(socket, updated_post, current_user)

        flash_message =
          if is_post_unread?(updated_post, current_user),
            do: "Post marked as unread",
            else: "Post marked as read"

        {:noreply, put_flash(socket, :info, flash_message)}

      {:ok, _} ->
        Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

        updated_post =
          Timeline.get_post!(post_id)
          |> Mosslet.Repo.preload([:user, :user_post_receipts], force: true)

        socket = move_post_between_read_streams(socket, updated_post, current_user)

        flash_message =
          if is_post_unread?(updated_post, current_user),
            do: "Post marked as unread",
            else: "Post marked as read"

        {:noreply, put_flash(socket, :info, flash_message)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update post status")}
    end
  end

  # ============================================================================
  # MODERATION EVENT HANDLERS
  # ============================================================================

  def handle_event("report_post", %{"id" => post_id}, socket) do
    case Timeline.get_post(post_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Post not found.")}

      post ->
        reported_user = Accounts.get_user!(post.user_id)

        socket =
          socket
          |> assign(:show_report_modal, true)
          |> assign(:report_post_id, post_id)
          |> assign(:report_user_id, reported_user.id)
          |> assign(:report_reply_context, %{})

        {:noreply, socket}
    end
  end

  def handle_event("close_report_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_report_modal, false)
      |> assign(:report_post_id, nil)
      |> assign(:report_user_id, nil)

    {:noreply, socket}
  end

  def handle_event("submit_report", %{"report" => report_params}, socket) do
    current_user = socket.assigns.current_scope.user
    post_id = report_params["post_id"]
    reported_user_id = report_params["reported_user_id"]
    reply_context = socket.assigns[:report_reply_context]

    enhanced_params =
      if reply_context && Map.has_key?(reply_context, :reply_id) do
        report_params
        |> Map.put("reply_id", reply_context.reply_id)
      else
        report_params
      end

    case {Timeline.get_post(post_id), Accounts.get_user(reported_user_id)} do
      {%Timeline.Post{} = post, %Accounts.User{} = reported_user} ->
        report_type =
          if reply_context && Map.has_key?(reply_context, :reply_id),
            do: "reply",
            else: "post"

        case Timeline.report_post(current_user, reported_user, post, enhanced_params) do
          {:ok, _report} ->
            socket =
              socket
              |> assign(:show_report_modal, false)
              |> assign(:report_post_id, nil)
              |> assign(:report_user_id, nil)
              |> assign(:report_reply_context, %{})
              |> put_flash(
                :info,
                "#{String.capitalize(report_type)} reported successfully. Thank you for helping keep our community safe."
              )

            {:noreply, socket}

          {:error, _changeset} ->
            info = "You've already submitted a report for this #{report_type}."
            {:noreply, put_flash(socket, :warning, info)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Post or user not found.")}
    end
  end

  def handle_event(
        "block_user",
        %{"id" => user_id, "user-name" => user_name, "item-id" => block_post_id},
        socket
      ) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    blocked_user_ids = Timeline.get_blocked_user_ids(current_user)
    is_blocked = user_id in blocked_user_ids

    {existing_block, decrypted_reason} =
      if is_blocked do
        case Accounts.get_user_block(current_user, user_id) do
          %UserBlock{} = block ->
            decrypted_reason =
              if block.reason do
                Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                  block.reason,
                  current_user,
                  key
                )
              else
                ""
              end

            {block, decrypted_reason}

          nil ->
            {nil, ""}
        end
      else
        {nil, ""}
      end

    default_block_type =
      cond do
        existing_block -> Atom.to_string(existing_block.block_type)
        true -> "full"
      end

    socket =
      socket
      |> assign(:show_block_modal, true)
      |> assign(:block_post_id, block_post_id)
      |> assign(:block_user_id, user_id)
      |> assign(:block_user_name, user_name)
      |> assign(:existing_block, existing_block)
      |> assign(:block_decrypted_reason, decrypted_reason)
      |> assign(:block_default_type, default_block_type)
      |> assign(:block_update?, is_blocked)

    {:noreply, socket}
  end

  def handle_event("close_block_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_block_modal, false)
      |> assign(:block_user_id, nil)
      |> assign(:block_user_name, nil)

    {:noreply, socket}
  end

  def handle_event("submit_block", %{"block" => block_params}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
    blocked_user_id = block_params["blocked_id"]

    case Accounts.get_user(blocked_user_id) do
      %Accounts.User{} = blocked_user ->
        case Accounts.block_user(current_user, blocked_user, block_params,
               user: current_user,
               key: key
             ) do
          {:ok, _block} ->
            socket =
              socket
              |> assign(:show_block_modal, false)
              |> assign(:block_user_id, nil)
              |> assign(:block_user_name, nil)
              |> put_flash(
                :info,
                "Author blocked successfully. You won't see their content anymore."
              )

            {:noreply, socket}

          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
            error_msg = "Block failed: #{inspect(errors)}"
            {:noreply, put_flash(socket, :error, error_msg)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Author not found.")}
    end
  end

  def handle_event("remove_self_from_post", %{"post-id" => post_id}, socket) do
    current_user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:removing_self_from_post_id, post_id)
      |> start_async(:remove_self_from_post, fn ->
        case Timeline.get_user_post_by_post_id_and_user_id(post_id, current_user.id) do
          nil ->
            post = Timeline.get_post!(post_id)

            case Timeline.hide_post(current_user, post) do
              {:ok, _hide} -> {:ok, post}
              error -> error
            end

          user_post ->
            post = Timeline.get_post!(user_post.post_id)

            with {:ok, updated_post} <-
                   Timeline.remove_self_from_shared_post(user_post, user: current_user) do
              if post.visibility == :public do
                Timeline.hide_post(current_user, updated_post)
              end

              {:ok, updated_post}
            end
        end
      end)

    {:noreply, socket}
  end

  def handle_event(
        "remove_shared_user",
        %{"post-id" => post_id, "user-id" => user_id, "shared-username" => shared_username},
        socket
      ) do
    current_user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:removing_shared_user_id, user_id)
      |> start_async(:remove_shared_user, fn ->
        user_post = Timeline.get_user_post_by_post_id_and_user_id!(post_id, user_id)

        Timeline.delete_user_post(user_post,
          user: current_user,
          shared_username: shared_username
        )
      end)

    {:noreply, socket}
  end

  def handle_event(
        "add_shared_user",
        %{"post-id" => post_id, "user-id" => user_id, "username" => username},
        socket
      ) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    socket =
      socket
      |> assign(:adding_shared_user, %{post_id: post_id, username: username})
      |> start_async(:add_shared_user, fn ->
        post = Timeline.get_post!(post_id)

        if post.user_id == current_user.id do
          user_to_share_with = Accounts.get_user!(user_id)

          encrypted_post_key =
            post.user_posts
            |> Enum.find(fn up -> up.user_id == current_user.id end)
            |> case do
              nil -> nil
              user_post -> user_post.key
            end

          decrypted_post_key =
            case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                   encrypted_post_key,
                   current_user,
                   key
                 ) do
              {:ok, decrypted} -> decrypted
              _ -> nil
            end

          if decrypted_post_key do
            Timeline.share_post_with_user(post, user_to_share_with, decrypted_post_key,
              user: current_user
            )
          else
            {:error, :decryption_failed}
          end
        else
          {:error, :not_owner}
        end
      end)

    {:noreply, socket}
  end

  def handle_event(
        "decrypt_url_preview_image",
        %{"presigned_url" => presigned_url, "post_id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        encrypted_post_key =
          case post.visibility do
            :public -> get_post_key(post)
            _ -> get_post_key(post, current_user)
          end

        case fetch_and_decrypt_url_preview_image(
               presigned_url,
               encrypted_post_key,
               current_user,
               key,
               post.visibility
             ) do
          {:ok, decrypted_image} ->
            {:reply, %{response: "success", decrypted_image: decrypted_image}, socket}

          {:error, reason} ->
            Logger.error("Failed to decrypt URL preview image: #{inspect(reason)}")
            {:reply, %{response: "failed"}, socket}
        end

      nil ->
        {:reply, %{response: "failed"}, socket}
    end
  end

  def handle_event("get_post_image_urls", %{"post_id" => post_id}, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        case post.image_urls do
          [_ | _] = urls ->
            post_key = get_post_key(post, current_user)

            decrypted_urls =
              Enum.map(urls, fn encrypted_url ->
                decr_item(encrypted_url, current_user, post_key, key, post, "body")
              end)

            {:reply, %{response: "success", image_urls: decrypted_urls}, socket}

          _ ->
            {:reply, %{response: "success", image_urls: []}, socket}
        end

      nil ->
        {:reply, %{response: "error", message: "Post not found"}, socket}
    end
  end

  def handle_event(
        "decrypt_post_images",
        %{"sources" => sources, "post_id" => post_id} = _params,
        socket
      ) do
    memories_bucket = Mosslet.Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    post_id =
      if String.contains?(post_id, "-reply-form"),
        do: String.split(post_id, "-reply-form") |> List.first(),
        else: post_id

    post = Timeline.get_post!(post_id)

    # Non-public posts use browser-side ZK decryption via TrixContentPostHook —
    # the server cannot decrypt sealed post keys. Return early so the browser
    # falls back to the ZK image decryption path.
    if post.visibility != :public do
      {:reply, %{response: "failed", decrypted_binaries: []}, socket}
    else
      post_key = get_post_key(post, current_user)

      images =
        Enum.map(sources, fn file_path ->
          webp_path = normalize_to_webp(file_path)

          case get_s3_object(memories_bucket, webp_path) do
            {:ok, %{body: e_obj}} ->
              decrypt_image_for_trix(e_obj, current_user, post_key, key, post, "body", "webp")

            {:error, _} ->
              case get_s3_object(memories_bucket, file_path) do
                {:ok, %{body: e_obj}} ->
                  ext = Path.extname(file_path) |> String.trim_leading(".")
                  ext = if ext == "", do: "webp", else: ext
                  decrypt_image_for_trix(e_obj, current_user, post_key, key, post, "body", ext)

                {:error, error} ->
                  Logger.info("Error getting Post images from cloud in UserHomeLive")
                  Logger.debug(inspect(error))
                  nil
              end
          end
        end)
        |> List.flatten()
        |> Enum.filter(fn source -> !is_nil(source) end)

      if decrypted_image_binaries_for_trix?(images) do
        {:reply, %{response: "success", decrypted_binaries: images}, socket}
      else
        {:reply, %{response: "failed", decrypted_binaries: []}, socket}
      end
    end
  end

  # ZK image path: returns encrypted S3 blobs for browser-side decryption.
  # The server never decrypts the image content — it only proxies the encrypted
  # binary from S3 and base64-encodes it for transport.
  def handle_event(
        "fetch_encrypted_post_images",
        %{"post_id" => post_id},
        socket
      ) do
    memories_bucket = Mosslet.Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        post_key = get_post_key(post, current_user)

        decrypted_paths =
          (post.image_urls || [])
          |> Enum.map(fn encrypted_url ->
            decr_item(encrypted_url, current_user, post_key, key, post, "body")
          end)
          |> Enum.filter(&is_binary/1)

        decrypted_alt_texts =
          (post.image_alt_texts || [])
          |> Enum.map(fn alt_text ->
            decr_item(alt_text, current_user, post_key, key, post, "body")
          end)
          |> Enum.filter(&is_binary/1)

        encrypted_blobs =
          Enum.map(decrypted_paths, fn file_path ->
            webp_path = normalize_to_webp(file_path)

            case get_s3_object(memories_bucket, webp_path) do
              {:ok, %{body: blob}} ->
                Base.encode64(blob)

              {:error, _} ->
                case get_s3_object(memories_bucket, file_path) do
                  {:ok, %{body: blob}} -> Base.encode64(blob)
                  {:error, _} -> nil
                end
            end
          end)

        {:reply,
         %{
           response: "success",
           encrypted_blobs: encrypted_blobs,
           image_alt_texts: decrypted_alt_texts
         }, socket}

      nil ->
        {:reply, %{response: "error", message: "Post not found"}, socket}
    end
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    if post.user_id == current_user.id do
      user_post = Timeline.get_user_post(post, current_user)
      replies = post.replies

      case Timeline.delete_post(post, user: current_user) do
        {:ok, post} ->
          Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

          socket =
            socket
            |> put_flash(:success, "Post deleted successfully.")
            |> start_async(
              :delete_post_from_cloud,
              fn ->
                delete_post_from_cloud(
                  post,
                  user_post,
                  current_user,
                  key
                )
              end
            )
            |> start_async(
              :delete_reply_from_cloud,
              fn ->
                delete_replies_from_cloud(
                  replies,
                  user_post,
                  current_user,
                  key
                )
              end
            )

          {:noreply, stream_delete_profile_post(socket, post)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete post. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You are not authorized to delete this post.")}
    end
  end

  def handle_event("show_timeline_images", %{"post_id" => post_id} = _params, socket) do
    current_user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        can_download = check_download_permission(post, current_user)

        case post.image_urls do
          [_ | _] = urls ->
            post_key = get_post_key(post, current_user)

            decrypted_urls =
              Enum.map(urls, fn encrypted_url ->
                decr_item(encrypted_url, current_user, post_key, key, post, "body")
              end)
              |> Enum.filter(&(!is_nil(&1)))

            {:noreply,
             socket
             |> assign(:show_image_modal, true)
             |> assign(:current_images, decrypted_urls)
             |> assign(:current_image_index, 0)
             |> assign(:current_post_for_images, post)
             |> assign(:can_download_images, can_download)}

          _ ->
            {:noreply, put_flash(socket, :info, "No images found in this post")}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  def handle_event("close_image_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_image_modal, false)
     |> assign(:current_images, [])
     |> assign(:current_image_index, 0)
     |> assign(:current_post_for_images, nil)
     |> assign(:can_download_images, false)
     |> push_event("restore-body-scroll", %{})}
  end

  def handle_event("next_timeline_image", _params, socket) do
    current_index = socket.assigns.current_image_index
    max_index = length(socket.assigns.current_images) - 1

    new_index = if current_index < max_index, do: current_index + 1, else: current_index

    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  def handle_event("prev_timeline_image", _params, socket) do
    current_index = socket.assigns.current_image_index
    new_index = if current_index > 0, do: current_index - 1, else: 0

    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  def handle_event("goto_timeline_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    max_index = length(socket.assigns.current_images) - 1

    new_index = max(0, min(index, max_index))

    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  def handle_event("restore-body-scroll", _params, socket) do
    # this flash only displays after image download sent
    socket =
      socket
      |> clear_flash(:info)
      |> put_flash(:info, "Download complete!")

    {:noreply, socket}
  end

  def handle_event(
        "regenerate_preview_url",
        %{"image_hash" => image_hash, "post_id" => post_id},
        socket
      ) do
    case Mosslet.Extensions.URLPreviewImageProxy.regenerate_presigned_url(image_hash, post_id) do
      {:ok, new_presigned_url} ->
        {:reply, %{response: "success", presigned_url: new_presigned_url}, socket}

      {:error, _reason} ->
        {:reply, %{response: "failed"}, socket}
    end
  end

  def handle_event(
        "expand_nested_replies",
        %{"reply-id" => reply_id, "post-id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_scope.user

    loaded_nested_replies = socket.assigns[:loaded_nested_replies] || %{}
    current_offset = Map.get(loaded_nested_replies, reply_id, 0)

    new_child_replies =
      Timeline.get_child_replies_for_reply(reply_id, %{
        current_user_id: current_user.id,
        limit: 5,
        offset: current_offset
      })

    if Enum.empty?(new_child_replies) do
      {:noreply, put_flash(socket, :info, "No more replies to load.")}
    else
      loaded_replies_counts = socket.assigns[:loaded_replies_counts] || %{}
      post_id_str = to_string(post_id)
      reply_limit = Map.get(loaded_replies_counts, post_id_str, 5)

      post =
        Timeline.get_post_with_nested_replies(post_id, %{
          current_user_id: current_user.id,
          limit: reply_limit
        })

      if post do
        new_offset = current_offset + length(new_child_replies)
        updated_loaded = Map.put(loaded_nested_replies, reply_id, new_offset)

        post_with_date =
          add_single_post_date_context(post, socket.assigns[:cached_profile_posts] || [], at: -1)

        socket =
          socket
          |> assign(:loaded_nested_replies, updated_loaded)
          |> stream_insert(:profile_posts, post_with_date, at: -1)

        {:noreply, socket}
      else
        {:noreply, put_flash(socket, :error, "Post not found.")}
      end
    end
  end

  def handle_event(
        "load_more_replies",
        %{"post-id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_scope.user

    loaded_replies_counts = socket.assigns[:loaded_replies_counts] || %{}
    current_count = Map.get(loaded_replies_counts, post_id, 5)

    new_limit = current_count + 5

    post =
      Timeline.get_post_with_nested_replies(post_id, %{
        current_user_id: current_user.id,
        limit: new_limit
      })

    if post do
      updated_counts = Map.put(loaded_replies_counts, post_id, new_limit)

      post_with_date =
        add_single_post_date_context(post, socket.assigns[:cached_profile_posts] || [], at: -1)

      socket =
        socket
        |> assign(:loaded_replies_counts, updated_counts)
        |> stream_insert(:profile_posts, post_with_date, at: -1)
        |> push_event("animate-new-replies", %{post_id: post_id, start_index: current_count})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  def handle_async(:delete_post_from_cloud, {:ok, _result}, socket) do
    {:noreply, socket}
  end

  def handle_async(:delete_post_from_cloud, {:exit, reason}, socket) do
    Logger.error("Failed to delete post from cloud: #{inspect(reason)}")
    {:noreply, socket}
  end

  def handle_async(:delete_reply_from_cloud, {:ok, _result}, socket) do
    {:noreply, socket}
  end

  def handle_async(:delete_reply_from_cloud, {:exit, reason}, socket) do
    Logger.error("Failed to delete replies from cloud: #{inspect(reason)}")
    {:noreply, socket}
  end

  def handle_async(:remove_shared_user, {:ok, _result}, socket) do
    {:noreply, assign(socket, :removing_shared_user_id, nil)}
  end

  def handle_async(:remove_shared_user, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:removing_shared_user_id, nil)
      |> put_flash(:error, "Failed to remove shared user: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:add_shared_user, {:ok, {:ok, _user_post}} = result, socket) do
    require Logger
    Logger.debug("handle_async :add_shared_user success: #{inspect(result)}")
    {:noreply, assign(socket, :adding_shared_user, nil)}
  end

  def handle_async(:add_shared_user, {:ok, {:error, _reason}} = result, socket) do
    require Logger
    Logger.debug("handle_async :add_shared_user error: #{inspect(result)}")

    socket =
      socket
      |> assign(:adding_shared_user, nil)
      |> put_flash(:error, "Failed to share post with user")

    {:noreply, socket}
  end

  def handle_async(:add_shared_user, {:exit, reason} = result, socket) do
    require Logger
    Logger.debug("handle_async :add_shared_user exit: #{inspect(result)}")

    socket =
      socket
      |> assign(:adding_shared_user, nil)
      |> put_flash(:error, "Failed to share post with user: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:remove_self_from_post, {:ok, {:ok, post}}, socket) do
    socket =
      socket
      |> assign(:removing_self_from_post_id, nil)
      |> stream_delete(:profile_posts, post)
      |> stream_delete(:read_posts, post)
      |> put_flash(:info, "Post removed from your timeline.")

    {:noreply, socket}
  end

  def handle_async(:remove_self_from_post, {:ok, {:error, _changeset}}, socket) do
    socket =
      socket
      |> assign(:removing_self_from_post_id, nil)
      |> put_flash(:error, "Failed to remove post.")

    {:noreply, socket}
  end

  def handle_async(:remove_self_from_post, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:removing_self_from_post_id, nil)
      |> put_flash(:error, "Failed to remove post: #{inspect(reason)}")

    {:noreply, socket}
  end

  defp get_profile_key_for_preview(socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user
    session_key = socket.assigns.current_scope.key
    encrypted_profile_key = profile_user.connection.profile.profile_key

    if encrypted_profile_key && profile_user.visibility != :public do
      {:ok, key} =
        URLPreviewHelpers.get_private_profile_key(
          encrypted_profile_key,
          current_user,
          session_key
        )

      key
    else
      URLPreviewHelpers.get_public_profile_key(encrypted_profile_key)
    end
  end

  defp maybe_fetch_website_preview(socket, profile_user, current_user, _profile_owner?) do
    profile = profile_user.connection.profile
    session_key = socket.assigns.current_scope.key

    {website_url, profile_key} =
      if profile.website_url do
        encrypted_profile_key = profile.profile_key

        if encrypted_profile_key && profile_user.visibility != :public do
          decrypted_url =
            decr_item(
              profile.website_url,
              current_user,
              encrypted_profile_key,
              session_key,
              profile
            )

          {:ok, decrypted_key} =
            URLPreviewHelpers.get_private_profile_key(
              encrypted_profile_key,
              current_user,
              session_key
            )

          {decrypted_url, decrypted_key}
        else
          decrypted_url =
            URLPreviewHelpers.decrypt_public_field(profile.website_url, profile.profile_key)

          decrypted_key = URLPreviewHelpers.get_public_profile_key(profile.profile_key)
          {decrypted_url, decrypted_key}
        end
      else
        {nil, nil}
      end

    connection_id = profile_user.connection.id
    URLPreviewHelpers.maybe_start_preview_fetch(socket, website_url, profile_key, connection_id)
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp render_own_profile(assigns) do
    ~H"""
    <%!-- Enhanced Profile Page with AT Protocol Federation Support --%>
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div id="timeline-container">
        <div phx-hook="ImageDownloadHook" id="image-download-handler" style="display: none;"></div>
        <div phx-hook="RepostFormHook" id="repost-form-handler" style="display: none;"></div>
        <%!-- Hero Section with responsive design --%>
        <div class="relative overflow-hidden">
          <%!-- Banner/Cover Image Section --%>
          <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
            <%!-- Custom banner image if available --%>
            <% banner_data = get_async_banner_data(@custom_banner_src) %>
            <%= cond do %>
              <% @custom_banner_src.loading -> %>
                <div class="absolute inset-0 flex items-center justify-center">
                  <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
                  </div>
                </div>
              <% banner_data -> %>
                <div
                  id="profile-banner-img"
                  phx-hook="DecryptAvatar"
                  data-encrypted-blob={banner_data[:encrypted_blob_b64]}
                  data-sealed-key={banner_data[:sealed_key]}
                  data-mime="image/webp"
                  class="absolute inset-0"
                >
                  <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
                </div>
              <% get_banner_image_for_connection(@profile_user.connection) != "" -> %>
                <div
                  class="absolute inset-0 bg-cover bg-center bg-no-repeat"
                  style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
                >
                  <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
                </div>
              <% true -> %>
            <% end %>

            <%!-- Liquid metal overlay pattern --%>
            <div class="absolute inset-0 opacity-20">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
              </div>
            </div>
          </div>

          <%!-- Profile Header --%>
          <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
            <div class="mx-auto max-w-7xl">
              <div class="relative pb-8">
                <%!-- Avatar and Basic Info --%>
                <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                  <%!-- Enhanced Avatar with built-in status support --%>
                  <div class="relative flex-shrink-0">
                    <MossletWeb.DesignSystem.liquid_avatar
                      src={
                        if not @profile_user.connection.profile.show_avatar?,
                          do: nil
                      }
                      encrypted_avatar_data={
                        if @profile_user.connection.profile.show_avatar?,
                          do: get_encrypted_avatar_data(@current_scope.user, @current_scope.key)
                      }
                      name={@decrypted_profile.name}
                      size="xxl"
                      status={to_string(@current_scope.user.status)}
                      status_message={
                        get_user_status_message(
                          @current_scope.user,
                          @current_scope.user,
                          @current_scope.key
                        )
                      }
                      show_status={
                        can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
                      }
                      user_id={@current_scope.user.id}
                      id="user-home-profile-avatar"
                      verified={@current_scope.user.connection.profile.visibility == "public"}
                    />
                  </div>

                  <%!-- Name, username, and actions --%>
                  <div class="flex-1 text-center sm:text-left space-y-4">
                    <%!-- Name and username --%>
                    <div class="space-y-1">
                      <h1
                        :if={@current_scope.user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                      >
                        {@decrypted_profile.name}
                      </h1>

                      <h1
                        :if={!@current_scope.user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                      >
                        {"Profile 🌿"}
                      </h1>
                      <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
                        <%!-- username badge --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color={
                            if(@profile_user.connection.profile.visibility == "public",
                              do: "cyan",
                              else: "emerald"
                            )
                          }
                          size="sm"
                        >
                          @<span data-decrypt-field="username">{@current_scope.user.decrypted[:username]}</span>
                        </MossletWeb.DesignSystem.liquid_badge>

                        <%!-- Email badge if show_email? is true --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          :if={
                            @current_scope.user.connection.profile.show_email? &&
                              @current_scope.user.connection.profile.email
                          }
                          variant="soft"
                          color={
                            if(@profile_user.connection.profile.visibility == "public",
                              do: "cyan",
                              else: "emerald"
                            )
                          }
                          size="sm"
                        >
                          <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                          <span data-decrypt-field="email">
                            {@current_scope.user.decrypted[:email]}
                          </span>
                        </MossletWeb.DesignSystem.liquid_badge>

                        <%!-- Visibility badge --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color={
                            if(@profile_user.connection.profile.visibility == "public",
                              do: "cyan",
                              else: "emerald"
                            )
                          }
                          size="sm"
                        >
                          <.phx_icon
                            name={
                              if(@current_scope.user.connection.profile.visibility == "public",
                                do: "hero-globe-alt",
                                else: "hero-lock-closed"
                              )
                            }
                            class="size-3 mr-1"
                          />
                          {String.capitalize(
                            to_string(@current_scope.user.connection.profile.visibility)
                          )}
                        </MossletWeb.DesignSystem.liquid_badge>
                      </div>
                    </div>

                    <%!-- Action buttons --%>
                    <div class="flex flex-col sm:flex-row items-center gap-3">
                      <%!-- Edit Profile --%>
                      <MossletWeb.DesignSystem.liquid_button
                        navigate={~p"/app/users/edit-profile"}
                        variant="primary"
                        color="teal"
                        icon="hero-pencil-square"
                        class="w-full sm:w-auto"
                      >
                        Edit Profile
                      </MossletWeb.DesignSystem.liquid_button>

                      <%!-- Status Settings --%>
                      <MossletWeb.DesignSystem.liquid_button
                        navigate={~p"/app/users/edit-status"}
                        variant="secondary"
                        color="blue"
                        icon="hero-face-smile"
                        size="md"
                        class="w-full sm:w-auto"
                      >
                        Status Settings
                      </MossletWeb.DesignSystem.liquid_button>

                      <%!-- Share Profile

                <MossletWeb.DesignSystem.liquid_button
                  variant="ghost"
                  color="slate"
                  icon="hero-share"
                  size="md"
                  phx-click="share_profile"
                  data-tippy-content="Share your profile"
                  phx-hook="TippyHook"
                >
                  Share
                </MossletWeb.DesignSystem.liquid_button>
                --%>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Main Content --%>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
          <%!-- New Post Prompt --%>
          <div class="mb-8">
            <MossletWeb.TimelineComponents.liquid_new_post_prompt
              id="home-new-post-prompt"
              user_name={@decrypted_profile.name}
              user_avatar={
                if not @profile_user.connection.profile.show_avatar?,
                  do: nil
              }
              encrypted_avatar_data={
                if @profile_user.connection.profile.show_avatar?,
                  do: get_encrypted_avatar_data(@current_scope.user, @current_scope.key)
              }
              placeholder="Share something meaningful with your community..."
              current_scope={@current_scope}
              show_status={
                can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
              }
              status_message={
                get_current_user_status_message(@current_scope.user, @current_scope.key)
              }
            />
          </div>

          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <%!-- Left Column: Profile Details & Federation --%>
            <div class="lg:col-span-2 space-y-8" data-profile-scope="own-profile">
              <%!-- DecryptProfileFields hook for browser-side ZK decryption --%>
              <div
                :if={@profile_fields && @profile_fields[:browser_decrypt?]}
                id="decrypt-own-profile-fields"
                phx-hook="DecryptProfileFields"
                phx-update="ignore"
                data-profile-id="own-profile"
                data-sealed-profile-key={@profile_fields[:sealed_profile_key]}
                data-encrypted-about={@profile_fields[:encrypted_about]}
                data-encrypted-alternate-email={@profile_fields[:encrypted_alternate_email]}
                data-encrypted-website-url={@profile_fields[:encrypted_website_url]}
                data-encrypted-website-label={@profile_fields[:encrypted_website_label]}
                data-encrypted-name={@profile_fields[:encrypted_name]}
                data-encrypted-username={@profile_fields[:encrypted_username]}
                data-encrypted-email={@profile_fields[:encrypted_email]}
                class="hidden"
              >
              </div>
              <%!-- Contact & Links Section --%>
              <MossletWeb.DesignSystem.liquid_card
                :if={has_contact_links?(@current_scope.user.connection.profile)}
                heading_level={2}
              >
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                    Contact & Links
                  </div>
                </:title>
                <div class="space-y-4">
                  <div
                    :if={@current_scope.user.connection.profile.alternate_email}
                    class="flex items-center gap-3"
                  >
                    <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                      <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                    </div>
                    <div>
                      <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                      <a
                        data-decrypt-profile="alternate_email"
                        href={
                          if @profile_fields && @profile_fields[:alternate_email],
                            do: "mailto:#{@profile_fields[:alternate_email]}",
                            else: "#"
                        }
                        class={[
                          "text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors",
                          @profile_fields && @profile_fields[:browser_decrypt?] && "animate-pulse"
                        ]}
                      >
                        {if @profile_fields, do: @profile_fields[:alternate_email], else: "..."}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.MediaComponents.website_url_preview
                    :if={@current_scope.user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={if @profile_fields, do: @profile_fields[:website_url]}
                    label={
                      cond do
                        @profile_fields && @profile_fields[:website_label] ->
                          @profile_fields[:website_label]

                        @current_scope.user.connection.profile.website_label ->
                          "..."

                        true ->
                          "Website"
                      end
                    }
                  />
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- About Section --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" />
                    About
                  </div>
                </:title>
                <div
                  :if={@current_scope.user.connection.profile.about}
                  class="prose prose-slate dark:prose-invert max-w-none"
                >
                  <p
                    data-decrypt-profile="about"
                    class={[
                      "text-slate-700 dark:text-slate-300 leading-relaxed",
                      @profile_fields && @profile_fields[:browser_decrypt?] && "animate-pulse"
                    ]}
                  >
                    {if @profile_fields, do: @profile_fields[:about], else: "..."}
                  </p>
                </div>
                <div
                  :if={!@current_scope.user.connection.profile.about}
                  class="text-center py-8"
                >
                  <div class="mb-4">
                    <.phx_icon
                      name="hero-chat-bubble-left-right"
                      class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                    />
                    <p class="text-sm text-slate-600 dark:text-slate-400">
                      Share something about yourself!
                    </p>
                  </div>
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/users/edit-profile"}
                    variant="secondary"
                    color="teal"
                    size="sm"
                    icon="hero-plus"
                  >
                    Add Bio
                  </MossletWeb.DesignSystem.liquid_button>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Posts Section --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center justify-between w-full">
                    <div class="flex items-center gap-2">
                      <.phx_icon
                        name="hero-chat-bubble-bottom-center-text"
                        class="size-5 text-emerald-600 dark:text-emerald-400"
                      />
                      <span>Posts</span>
                    </div>
                    <MossletWeb.DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                      {@posts_count}
                    </MossletWeb.DesignSystem.liquid_badge>
                  </div>
                </:title>
                <div
                  :if={@posts_count == 0}
                  id="profile-posts-empty"
                  class="text-center py-8"
                >
                  <.phx_icon
                    name="hero-pencil-square"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
                    No posts yet. Share your thoughts with your community!
                  </p>
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/timeline"}
                    variant="primary"
                    color="emerald"
                    size="sm"
                    icon="hero-plus"
                  >
                    Create Your First Post
                  </MossletWeb.DesignSystem.liquid_button>
                </div>
                <div id="profile-posts" phx-update="stream" class="space-y-4">
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"profile-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_author_name_data={
                        get_encrypted_profile_post_author_name_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_handle={
                        get_profile_post_author_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_avatar={
                        get_profile_post_author_avatar_fallback(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      encrypted_avatar_data={
                        get_encrypted_profile_post_author_avatar_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_status={
                        get_profile_post_author_status(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status_message={
                        get_profile_post_author_status_message(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      show_post_author_status={
                        can_view_profile_post_author_status?(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_slug={
                        get_profile_post_author_slug(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_visibility={
                        get_profile_post_author_visibility(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_read_posts_divider
                  :if={@posts_count - length(@cached_profile_posts) > 0}
                  count={@posts_count - length(@cached_profile_posts)}
                  expanded={@read_posts_expanded}
                  loading={@read_posts_loading}
                  tab_color="emerald"
                />
                <div
                  :if={@read_posts_expanded}
                  id="profile-read-posts-own"
                  phx-update="stream"
                  class={[
                    "space-y-4",
                    "animate-in fade-in-0 slide-in-from-top-4 duration-500 ease-out"
                  ]}
                >
                  <div
                    :for={{dom_id, post} <- @streams.read_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"read-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_author_name_data={
                        get_encrypted_profile_post_author_name_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_handle={
                        get_profile_post_author_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_avatar={
                        get_profile_post_author_avatar_fallback(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      encrypted_avatar_data={
                        get_encrypted_profile_post_author_avatar_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_status={
                        get_profile_post_author_status(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status_message={
                        get_profile_post_author_status_message(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      show_post_author_status={
                        can_view_profile_post_author_status?(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_slug={
                        get_profile_post_author_slug(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_visibility={
                        get_profile_post_author_visibility(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_timeline_scroll_indicator
                  :if={
                    @read_posts_expanded &&
                      @posts_count > length(@cached_profile_posts) + length(@cached_read_posts)
                  }
                  remaining_count={
                    @posts_count - length(@cached_profile_posts) - length(@cached_read_posts)
                  }
                  load_count={
                    min(10, @posts_count - length(@cached_profile_posts) - length(@cached_read_posts))
                  }
                  loading={@load_more_loading}
                  tab_color="emerald"
                  phx-click="load_more_posts"
                />
              </MossletWeb.DesignSystem.liquid_card>
            </div>

            <%!-- Right Column: Quick Actions & Profile Management --%>
            <div
              :if={@current_scope.user && @current_scope.user.id == @profile_user.id}
              class="lg:col-span-1 space-y-6"
            >
              <%!-- Quick Actions --%>
              <MossletWeb.DesignSystem.liquid_card
                heading_level={2}
                class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
              >
                <:title>
                  <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                    <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                    Quick Actions
                  </div>
                </:title>
                <div class="space-y-3">
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/timeline"}
                    variant="primary"
                    color="teal"
                    icon="hero-newspaper"
                    class="w-full"
                  >
                    View Timeline
                  </MossletWeb.DesignSystem.liquid_button>

                  <div class="space-y-2 pt-2">
                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/users/connections"}
                      icon="hero-users"
                      class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                    >
                      Manage Connections
                    </MossletWeb.DesignSystem.liquid_nav_item>

                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/circles"}
                      icon="hero-circle-stack"
                      class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                    >
                      Join Circles
                    </MossletWeb.DesignSystem.liquid_nav_item>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Profile Stats --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chart-pie"
                      class="size-5 text-purple-600 dark:text-purple-400"
                    /> Profile Stats
                  </div>
                </:title>
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Profile views</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {assigns[:profile_views] || "—"}
                    </span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.inserted_at,
                        do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                        else: "—"}
                    </span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.last_activity_at,
                        do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                        else: "Now"}
                    </span>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Privacy & Security --%>
              <MossletWeb.DesignSystem.liquid_card
                :if={@current_scope.user && @current_scope.user.id == @profile_user.id}
                heading_level={2}
                class="border-emerald-200/40 dark:border-emerald-700/40"
              >
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-shield-check"
                      class="size-5 text-emerald-600 dark:text-emerald-400"
                    /> Privacy & Security
                  </div>
                </:title>
                <div class="space-y-3">
                  <div class="flex items-center gap-3 p-3 bg-emerald-50/50 dark:bg-emerald-900/10 rounded-lg">
                    <div class="size-8 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg flex items-center justify-center">
                      <.phx_icon
                        name="hero-lock-closed"
                        class="size-4 text-emerald-600 dark:text-emerald-400"
                      />
                    </div>
                    <div class="text-sm">
                      <p class="font-medium text-emerald-800 dark:text-emerald-200">
                        End-to-End Encrypted
                      </p>
                      <p class="text-emerald-600 dark:text-emerald-400">Your data is protected</p>
                    </div>
                  </div>

                  <div class="space-y-2">
                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/users/two-factor-authentication"}
                      icon="hero-cog-6-tooth"
                      class="rounded-lg text-sm"
                    >
                      Security Settings
                    </MossletWeb.DesignSystem.liquid_nav_item>

                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/users/edit-visibility"}
                      icon="hero-eye-slash"
                      class="rounded-lg text-sm"
                    >
                      Visibility Controls
                    </MossletWeb.DesignSystem.liquid_nav_item>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>
            </div>
          </div>
        </div>
      </div>

      <MossletWeb.DesignSystem.liquid_image_modal
        id="profile-image-modal"
        show={@show_image_modal}
        images={@current_images}
        current_index={@current_image_index}
        can_download={@can_download_images}
        on_cancel={JS.push("close_image_modal")}
      />

      <MossletWeb.PrivacyComponents.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
    </.layout>
    """
  end

  defp render_public_profile(assigns) do
    ~H"""
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div id="timeline-container">
        <div phx-hook="ImageDownloadHook" id="image-download-handler" style="display: none;"></div>
        <div phx-hook="RepostFormHook" id="repost-form-handler" style="display: none;"></div>
        <div class="relative overflow-hidden">
          <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
            <div
              :if={get_banner_image_for_connection(@profile_user.connection) != ""}
              class="absolute inset-0 bg-cover bg-center bg-no-repeat"
              style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
            >
              <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            </div>

            <div class="absolute inset-0 opacity-20">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
              </div>
            </div>
          </div>

          <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
            <div class="mx-auto max-w-7xl">
              <div class="relative pb-8">
                <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                  <div class="relative flex-shrink-0">
                    <MossletWeb.DesignSystem.liquid_avatar
                      src={
                        if @profile_user.connection.profile.show_avatar?,
                          do: get_public_avatar(@profile_user, @current_scope.user)
                      }
                      name={
                        decrypt_public_field(
                          @profile_user.connection.profile.name,
                          @profile_user.connection.profile.profile_key
                        )
                      }
                      size="xxl"
                      status={get_public_status(@profile_user)}
                      status_message={get_public_status_message(@profile_user)}
                      show_status={
                        can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                      }
                      user_id={@profile_user.id}
                      verified={false}
                    />
                  </div>

                  <div class="flex-1 text-center sm:text-left space-y-4">
                    <div class="space-y-1">
                      <h1
                        :if={@profile_user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                      >
                        {decrypt_public_field(
                          @profile_user.connection.profile.name,
                          @profile_user.connection.profile.profile_key
                        )}
                      </h1>

                      <h1
                        :if={!@profile_user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                      >
                        {"Profile 🌿"}
                      </h1>

                      <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color="cyan"
                          size="sm"
                        >
                          @{decrypt_public_field(
                            @profile_user.connection.profile.username,
                            @profile_user.connection.profile.profile_key
                          )}
                        </MossletWeb.DesignSystem.liquid_badge>

                        <MossletWeb.DesignSystem.liquid_badge
                          :if={
                            @profile_user.connection.profile.show_email? &&
                              @profile_user.connection.profile.email
                          }
                          variant="soft"
                          color="cyan"
                          size="sm"
                        >
                          <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                          {decrypt_public_field(
                            @profile_user.connection.profile.email,
                            @profile_user.connection.profile.profile_key
                          )}
                        </MossletWeb.DesignSystem.liquid_badge>

                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color="cyan"
                          size="sm"
                        >
                          <.phx_icon name="hero-globe-alt" class="size-3 mr-1" /> Public
                        </MossletWeb.DesignSystem.liquid_badge>
                      </div>
                    </div>

                    <div
                      :if={
                        @current_scope.user && !@current_user_is_profile_owner? && !@user_connection
                      }
                      class="flex flex-col sm:flex-row items-center gap-3"
                    >
                      <MossletWeb.DesignSystem.liquid_button
                        navigate={~p"/app/users/connections"}
                        variant="primary"
                        color="teal"
                        icon="hero-user-plus"
                        class="w-full sm:w-auto"
                      >
                        Connect
                      </MossletWeb.DesignSystem.liquid_button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <div class="lg:col-span-2 space-y-8">
              <MossletWeb.DesignSystem.liquid_card
                :if={has_contact_links?(@profile_user.connection.profile)}
                heading_level={2}
              >
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                    Contact & Links
                  </div>
                </:title>
                <div class="space-y-4">
                  <div
                    :if={@profile_user.connection.profile.alternate_email}
                    class="flex items-center gap-3"
                  >
                    <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                      <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                    </div>
                    <div>
                      <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                      <a
                        href={
                          if @profile_fields && @profile_fields[:alternate_email],
                            do: "mailto:#{@profile_fields[:alternate_email]}",
                            else: "#"
                        }
                        class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                      >
                        {if @profile_fields, do: @profile_fields[:alternate_email]}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.MediaComponents.website_url_preview
                    :if={@profile_user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={if @profile_fields, do: @profile_fields[:website_url]}
                    label={
                      cond do
                        @profile_fields && @profile_fields[:website_label] ->
                          @profile_fields[:website_label]

                        @profile_user.connection.profile.website_label ->
                          nil

                        true ->
                          "Website"
                      end
                    }
                  />
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" />
                    About
                  </div>
                </:title>
                <div
                  :if={@profile_user.connection.profile.about}
                  class="prose prose-slate dark:prose-invert max-w-none"
                >
                  <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                    {if @profile_fields, do: @profile_fields[:about]}
                  </p>
                </div>
                <div
                  :if={!@profile_user.connection.profile.about}
                  class="text-center py-8"
                >
                  <div class="text-slate-400 dark:text-slate-500 mb-4">
                    <.phx_icon
                      name="hero-chat-bubble-left-right"
                      class="size-12 mx-auto mb-3 opacity-50"
                    />
                    <p class="text-sm">No bio available.</p>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Posts Section --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center justify-between w-full">
                    <div class="flex items-center gap-2">
                      <.phx_icon
                        name="hero-chat-bubble-bottom-center-text"
                        class="size-5 text-indigo-600 dark:text-indigo-400"
                      />
                      <span>Posts</span>
                    </div>
                    <MossletWeb.DesignSystem.liquid_badge variant="soft" color="indigo" size="sm">
                      {@posts_count}
                    </MossletWeb.DesignSystem.liquid_badge>
                  </div>
                </:title>
                <div
                  :if={@profile_user_block}
                  class="mb-4 p-4 rounded-xl bg-rose-50 dark:bg-rose-900/20 border border-rose-200 dark:border-rose-700/50"
                >
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-no-symbol"
                      class="size-5 text-rose-600 dark:text-rose-400 flex-shrink-0 mt-0.5"
                    />
                    <div>
                      <p class="text-sm font-medium text-rose-800 dark:text-rose-200">
                        You've blocked this user{unless @profile_user_block.block_type == :full,
                          do: "'s #{block_type_label(@profile_user_block.block_type)}"}
                      </p>
                      <p class="text-xs text-rose-700 dark:text-rose-300 mt-1">
                        {block_type_description(@profile_user_block.block_type)}
                      </p>
                    </div>
                  </div>
                </div>
                <div
                  :if={@user_connection && @user_connection.zen?}
                  class="mb-4 p-4 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50"
                >
                  <div class="flex items-start gap-3">
                    <.phx_icon
                      name="hero-speaker-x-mark"
                      class="size-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5"
                    />
                    <div>
                      <p class="text-sm font-medium text-amber-800 dark:text-amber-200">
                        You've muted this author
                      </p>
                      <p class="text-xs text-amber-700 dark:text-amber-300 mt-1">
                        Their posts won't appear in your timeline.
                      </p>
                    </div>
                  </div>
                </div>
                <div
                  :if={@posts_count == 0}
                  id="profile-posts-public-empty"
                  class="text-center py-8"
                >
                  <.phx_icon
                    name="hero-chat-bubble-bottom-center-text"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    No public posts yet.
                  </p>
                </div>
                <div id="profile-posts-public" phx-update="stream" class="space-y-4">
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"public-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={get_public_post_author_name(post, @profile_user)}
                      user_handle={
                        get_public_profile_post_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key
                        )
                      }
                      user_avatar={
                        get_public_post_author_avatar(post, @profile_user, @current_scope.user)
                      }
                      user_status={get_public_status(@profile_user)}
                      user_status_message={get_public_status_message(@profile_user)}
                      show_post_author_status={
                        can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                      }
                      author_profile_slug={
                        get_public_post_author_slug(post, @profile_user, @current_scope.user)
                      }
                      author_profile_visibility={
                        get_public_post_author_visibility(post, @profile_user, @current_scope.user)
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_read_posts_divider
                  :if={@posts_count - length(@cached_profile_posts) > 0}
                  count={@posts_count - length(@cached_profile_posts)}
                  expanded={@read_posts_expanded}
                  loading={@read_posts_loading}
                  tab_color="indigo"
                />
                <div
                  :if={@read_posts_expanded}
                  id="profile-read-posts-public"
                  phx-update="stream"
                  class={[
                    "space-y-4",
                    "animate-in fade-in-0 slide-in-from-top-4 duration-500 ease-out"
                  ]}
                >
                  <div
                    :for={{dom_id, post} <- @streams.read_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"read-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={get_public_post_author_name(post, @profile_user)}
                      user_handle={
                        get_public_profile_post_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key
                        )
                      }
                      user_avatar={
                        get_public_post_author_avatar(post, @profile_user, @current_scope.user)
                      }
                      user_status={get_public_status(@profile_user)}
                      user_status_message={get_public_status_message(@profile_user)}
                      show_post_author_status={
                        can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                      }
                      author_profile_slug={
                        get_public_post_author_slug(post, @profile_user, @current_scope.user)
                      }
                      author_profile_visibility={
                        get_public_post_author_visibility(post, @profile_user, @current_scope.user)
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_timeline_scroll_indicator
                  :if={
                    @read_posts_expanded &&
                      @posts_count > length(@cached_profile_posts) + length(@cached_read_posts)
                  }
                  remaining_count={
                    @posts_count - length(@cached_profile_posts) - length(@cached_read_posts)
                  }
                  load_count={
                    min(10, @posts_count - length(@cached_profile_posts) - length(@cached_read_posts))
                  }
                  loading={@load_more_loading}
                  tab_color="indigo"
                  phx-click="load_more_posts"
                />
              </MossletWeb.DesignSystem.liquid_card>
            </div>

            <div class="lg:col-span-1 space-y-6">
              <%!-- Quick Actions --%>
              <MossletWeb.DesignSystem.liquid_card
                :if={!@current_user_is_profile_owner?}
                heading_level={2}
                class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
              >
                <:title>
                  <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                    <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                    Quick Actions
                  </div>
                </:title>
                <div class="space-y-3">
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/timeline"}
                    variant="primary"
                    color="teal"
                    icon="hero-newspaper"
                    class="w-full"
                  >
                    View Timeline
                  </MossletWeb.DesignSystem.liquid_button>

                  <div class="space-y-2 pt-2">
                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/users/connections"}
                      icon="hero-users"
                      class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                    >
                      Manage Connections
                    </MossletWeb.DesignSystem.liquid_nav_item>

                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/circles"}
                      icon="hero-circle-stack"
                      class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                    >
                      Join Circles
                    </MossletWeb.DesignSystem.liquid_nav_item>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chart-pie"
                      class="size-5 text-purple-600 dark:text-purple-400"
                    /> Profile Stats
                  </div>
                </:title>
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.inserted_at,
                        do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                        else: "—"}
                    </span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.last_activity_at,
                        do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                        else: "Recently"}
                    </span>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>
            </div>
          </div>
        </div>
      </div>

      <.live_component
        :if={@show_report_modal}
        module={MossletWeb.TimelineLive.ReportModalComponent}
        id={"report-modal-component-#{@report_post_id}"}
        show={@show_report_modal}
        post_id={@report_post_id}
        reported_user_id={@report_user_id}
        report_reply_context={@report_reply_context}
      />

      <.live_component
        :if={@show_block_modal}
        module={MossletWeb.TimelineLive.BlockModalComponent}
        id={"block-modal-component-#{@block_user_id}-#{@block_post_id}"}
        post_id={@block_post_id}
        show={@show_block_modal}
        user_id={@block_user_id}
        user_name={@block_user_name}
        existing_block={@existing_block}
        decrypted_reason={@block_decrypted_reason}
        default_block_type={@block_default_type}
        block_update?={@block_update?}
        block_reply_context={assigns[:block_reply_context]}
      />

      <MossletWeb.DesignSystem.liquid_image_modal
        id="profile-image-modal"
        show={@show_image_modal}
        images={@current_images}
        current_index={@current_image_index}
        can_download={@can_download_images}
        on_cancel={JS.push("close_image_modal")}
      />

      <MossletWeb.PrivacyComponents.liquid_markdown_guide_modal
        id="markdown-guide-modal"
        show={@show_markdown_guide}
        on_cancel={JS.push("close_markdown_guide")}
      />
    </.layout>
    """
  end

  defp render_connections_profile(assigns) do
    ~H"""
    <%!-- Connection Profile Page - Current user viewing their connection's profile --%>
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div id="timeline-container" data-profile-scope="conn-profile">
        <div phx-hook="ImageDownloadHook" id="image-download-handler" style="display: none;"></div>
        <div phx-hook="RepostFormHook" id="repost-form-handler" style="display: none;"></div>
        <%!-- Hero Section with responsive design --%>
        <div class="relative overflow-hidden">
          <%!-- Banner/Cover Image Section --%>
          <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
            <%!-- Banner image if available --%>
            <div
              :if={get_banner_image_for_connection(@profile_user.connection) != ""}
              class="absolute inset-0 bg-cover bg-center bg-no-repeat"
              style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
            >
              <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            </div>

            <%!-- Liquid metal overlay pattern --%>
            <div class="absolute inset-0 opacity-20">
              <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
              </div>
            </div>
          </div>

          <%!-- Profile Header --%>
          <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
            <div class="mx-auto max-w-7xl">
              <div class="relative pb-8">
                <%!-- Avatar and Basic Info --%>
                <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                  <%!-- Enhanced Avatar --%>
                  <div class="relative flex-shrink-0">
                    <MossletWeb.DesignSystem.liquid_avatar
                      encrypted_avatar_data={
                        if @profile_user.connection.profile.show_avatar?,
                          do: get_encrypted_avatar_data(@user_connection, @current_scope.key)
                      }
                      id={"profile-user-avatar-#{@profile_user.id}"}
                      name={@decrypted_profile.name || "..."}
                      size="xxl"
                      status={to_string(@profile_user.status)}
                      encrypted_status_data={
                        get_encrypted_status_data(
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key
                        )
                      }
                      show_status={
                        can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                      }
                      user_id={@profile_user.id}
                      verified={false}
                    />
                  </div>

                  <%!-- Name, username, and info --%>
                  <div class="flex-1 text-center sm:text-left space-y-4">
                    <%!-- Name and username --%>
                    <div class="space-y-1">
                      <h1
                        :if={@profile_user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                        data-decrypt-profile="name"
                      >
                        {@decrypted_profile.name || "..."}
                      </h1>
                      <h1
                        :if={!@profile_user.connection.profile.show_name?}
                        class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                      >
                        {"Profile 🌿"}
                      </h1>
                      <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-slate-600 dark:text-slate-400">
                        <%!-- username badge --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color={
                            if(@profile_user.connection.profile.visibility == "public",
                              do: "cyan",
                              else: "emerald"
                            )
                          }
                          size="sm"
                        >
                          @<span data-decrypt-profile="username">{@decrypted_profile.username || "..."}</span>
                        </MossletWeb.DesignSystem.liquid_badge>

                        <%!-- Email badge if show_email? is true --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          :if={
                            @profile_user.connection.profile.show_email? &&
                              @profile_user.connection.profile.email
                          }
                          variant="soft"
                          color={
                            if(@profile_user.connection.profile.visibility == "public",
                              do: "cyan",
                              else: "emerald"
                            )
                          }
                          size="sm"
                        >
                          <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                          <span data-decrypt-profile="email">
                            {@decrypted_profile.email || "..."}
                          </span>
                        </MossletWeb.DesignSystem.liquid_badge>

                        <%!-- Connection badge --%>
                        <MossletWeb.DesignSystem.liquid_badge
                          variant="soft"
                          color="emerald"
                          size="sm"
                        >
                          <.phx_icon
                            name="hero-user-group"
                            class="size-3 mr-1"
                          /> Connection
                        </MossletWeb.DesignSystem.liquid_badge>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Main Content --%>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <%!-- Left Column: Connection Profile Details --%>
            <div class="lg:col-span-2 space-y-8">
              <%!-- DecryptProfileFields hook for browser-side ZK decryption --%>
              <div
                :if={@profile_fields && @profile_fields[:browser_decrypt?]}
                id="decrypt-conn-profile-fields"
                phx-hook="DecryptProfileFields"
                phx-update="ignore"
                data-profile-id="conn-profile"
                data-sealed-profile-key={@profile_fields[:sealed_profile_key]}
                data-encrypted-about={@profile_fields[:encrypted_about]}
                data-encrypted-alternate-email={@profile_fields[:encrypted_alternate_email]}
                data-encrypted-website-url={@profile_fields[:encrypted_website_url]}
                data-encrypted-website-label={@profile_fields[:encrypted_website_label]}
                data-encrypted-name={@profile_fields[:encrypted_name]}
                data-encrypted-username={@profile_fields[:encrypted_username]}
                data-encrypted-email={@profile_fields[:encrypted_email]}
                class="hidden"
              >
              </div>
              <%!-- Contact & Links Section --%>
              <MossletWeb.DesignSystem.liquid_card
                :if={has_contact_links?(@profile_user.connection.profile)}
                heading_level={2}
              >
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                    Contact & Links
                  </div>
                </:title>
                <div class="space-y-4">
                  <div
                    :if={@profile_user.connection.profile.alternate_email}
                    class="flex items-center gap-3"
                  >
                    <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                      <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                    </div>
                    <div>
                      <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                      <a
                        data-decrypt-profile="alternate_email"
                        href={
                          if @profile_fields && @profile_fields[:alternate_email],
                            do: "mailto:#{@profile_fields[:alternate_email]}",
                            else: "#"
                        }
                        class={[
                          "text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors",
                          @profile_fields && @profile_fields[:browser_decrypt?] && "animate-pulse"
                        ]}
                      >
                        {if @profile_fields, do: @profile_fields[:alternate_email], else: "..."}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.MediaComponents.website_url_preview
                    :if={@profile_user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={if @profile_fields, do: @profile_fields[:website_url]}
                    label={
                      cond do
                        @profile_fields && @profile_fields[:website_label] ->
                          @profile_fields[:website_label]

                        @profile_user.connection.profile.website_label ->
                          "..."

                        true ->
                          "Website"
                      end
                    }
                  />
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- About Section --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" />
                    About
                  </div>
                </:title>
                <div
                  :if={@profile_user.connection.profile.about}
                  class="prose prose-slate dark:prose-invert max-w-none"
                >
                  <p
                    data-decrypt-profile="about"
                    class={[
                      "text-slate-700 dark:text-slate-300 leading-relaxed",
                      @profile_fields && @profile_fields[:browser_decrypt?] && "animate-pulse"
                    ]}
                  >
                    {if @profile_fields, do: @profile_fields[:about], else: "..."}
                  </p>
                </div>
                <div
                  :if={!@profile_user.connection.profile.about}
                  class="text-center py-8"
                >
                  <div class="text-slate-400 dark:text-slate-500 mb-4">
                    <.phx_icon
                      name="hero-chat-bubble-left-right"
                      class="size-12 mx-auto mb-3 opacity-50"
                    />
                    <p class="text-sm">This connection hasn't shared a bio yet.</p>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Posts Section --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center justify-between w-full">
                    <div class="flex items-center gap-2">
                      <.phx_icon
                        name="hero-chat-bubble-bottom-center-text"
                        class="size-5 text-emerald-600 dark:text-emerald-400"
                      />
                      <span>Posts</span>
                    </div>
                    <MossletWeb.DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                      {@posts_count}
                    </MossletWeb.DesignSystem.liquid_badge>
                  </div>
                </:title>
                <div
                  :if={@posts_count == 0}
                  id="profile-posts-connections-empty"
                  class="text-center py-8"
                >
                  <.phx_icon
                    name="hero-chat-bubble-bottom-center-text"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    No posts shared with you yet.
                  </p>
                </div>
                <div id="profile-posts-connections" phx-update="stream" class="space-y-4">
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"connections-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_author_name_data={
                        get_encrypted_profile_post_author_name_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_handle={
                        get_profile_post_author_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_avatar={
                        get_profile_post_author_avatar_fallback(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      encrypted_avatar_data={
                        get_encrypted_profile_post_author_avatar_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_status={
                        get_profile_post_author_status(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_status_data={
                        get_profile_post_author_encrypted_status_data(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      show_post_author_status={
                        can_view_profile_post_author_status?(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_slug={
                        get_profile_post_author_slug(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_visibility={
                        get_profile_post_author_visibility(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_read_posts_divider
                  :if={@posts_count - length(@cached_profile_posts) > 0}
                  count={@posts_count - length(@cached_profile_posts)}
                  expanded={@read_posts_expanded}
                  loading={@read_posts_loading}
                  tab_color="emerald"
                />
                <div
                  :if={@read_posts_expanded}
                  id="profile-read-posts-connections"
                  phx-update="stream"
                  class={[
                    "space-y-4",
                    "animate-in fade-in-0 slide-in-from-top-4 duration-500 ease-out"
                  ]}
                >
                  <div
                    :for={{dom_id, post} <- @streams.read_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.TimelineComponents.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false)}
                      id={"read-date-sep-#{post.id}"}
                      datetime={post.inserted_at}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.TimelineComponents.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_author_name_data={
                        get_encrypted_profile_post_author_name_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_handle={
                        get_profile_post_author_handle(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_avatar={
                        get_profile_post_author_avatar_fallback(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      encrypted_avatar_data={
                        get_encrypted_profile_post_author_avatar_data(
                          post,
                          @current_scope.user,
                          @user_connection
                        )
                      }
                      user_status={
                        get_profile_post_author_status(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      encrypted_status_data={
                        get_profile_post_author_encrypted_status_data(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      show_post_author_status={
                        can_view_profile_post_author_status?(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_slug={
                        get_profile_post_author_slug(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      author_profile_visibility={
                        get_profile_post_author_visibility(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={post.content_warning?}
                      content_warning={post.decrypted[:content_warning]}
                      content_warning_category={post.decrypted[:content_warning_category]}
                      content={post.decrypted[:body] || ""}
                      images={post.decrypted[:image_urls] || []}
                      decrypted_url_preview={post.decrypted[:url_preview]}
                      stats={
                        %{
                          replies: Map.get(post, :total_reply_count, count_all_replies(post.replies)),
                          shares: post.reposts_count || 0,
                          likes: post.favs_count || 0
                        }
                      }
                      post_id={post.id}
                      current_user_id={@current_scope.user.id}
                      post_shared_users={@post_shared_users}
                      removing_shared_user_id={@removing_shared_user_id}
                      adding_shared_user={@adding_shared_user}
                      post={post}
                      current_scope={@current_scope}
                      is_repost={post.repost || false}
                      share_note={post.decrypted[:share_note]}
                      liked={@current_scope.user.id in (post.decrypted[:favs_list] || [])}
                      bookmarked={get_post_bookmarked_status(post, @current_scope.user)}
                      can_repost={can_repost_profile?(post, @current_scope.user)}
                      can_reply?={can_reply?(post, @current_scope.user)}
                      can_bookmark?={can_bookmark?(post, @current_scope.user)}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={Map.get(@unread_replies_by_post, post.id, 0)}
                      unread_nested_replies_by_parent={@unread_nested_replies_by_parent}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.TimelineComponents.liquid_timeline_scroll_indicator
                  :if={
                    @read_posts_expanded &&
                      @posts_count > length(@cached_profile_posts) + length(@cached_read_posts)
                  }
                  remaining_count={
                    @posts_count - length(@cached_profile_posts) - length(@cached_read_posts)
                  }
                  load_count={
                    min(10, @posts_count - length(@cached_profile_posts) - length(@cached_read_posts))
                  }
                  loading={@load_more_loading}
                  tab_color="emerald"
                  phx-click="load_more_posts"
                />
              </MossletWeb.DesignSystem.liquid_card>
            </div>

            <%!-- Right Column: Connection Info & Stats --%>
            <div class="lg:col-span-1 space-y-6">
              <%!-- Quick Actions --%>
              <MossletWeb.DesignSystem.liquid_card
                heading_level={2}
                class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
              >
                <:title>
                  <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                    <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                    Quick Actions
                  </div>
                </:title>
                <div class="space-y-3">
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/timeline"}
                    variant="primary"
                    color="teal"
                    icon="hero-newspaper"
                    class="w-full"
                  >
                    View Timeline
                  </MossletWeb.DesignSystem.liquid_button>

                  <div class="space-y-2 pt-2">
                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/users/connections"}
                      icon="hero-users"
                      class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                    >
                      Manage Connections
                    </MossletWeb.DesignSystem.liquid_nav_item>

                    <MossletWeb.DesignSystem.liquid_nav_item
                      navigate={~p"/app/circles"}
                      icon="hero-circle-stack"
                      class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                    >
                      Join Circles
                    </MossletWeb.DesignSystem.liquid_nav_item>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Connection Stats --%>
              <MossletWeb.DesignSystem.liquid_card heading_level={2}>
                <:title>
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chart-pie"
                      class="size-5 text-purple-600 dark:text-purple-400"
                    /> Profile Stats
                  </div>
                </:title>
                <div class="space-y-4">
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.inserted_at,
                        do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                        else: "—"}
                    </span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {if @profile_user.last_activity_at,
                        do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                        else: "Now"}
                    </span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-slate-600 dark:text-slate-400">Status</span>
                    <span class="font-semibold text-slate-900 dark:text-white">
                      {String.capitalize(to_string(@profile_user.status))}
                    </span>
                  </div>
                </div>
              </MossletWeb.DesignSystem.liquid_card>
            </div>
          </div>
        </div>

        <.live_component
          :if={@show_share_modal}
          module={MossletWeb.TimelineLive.ShareModalComponent}
          id={"share-modal-component-#{@share_post_id}"}
          show={@show_share_modal}
          post_id={@share_post_id}
          body={@share_post_body}
          username={@share_post_username}
          connections={@post_shared_users}
          user_connections={@user_connections}
          current_scope={@current_scope}
        />

        <MossletWeb.DesignSystem.liquid_image_modal
          id="profile-image-modal"
          show={@show_image_modal}
          images={@current_images}
          current_index={@current_image_index}
          can_download={@can_download_images}
          on_cancel={JS.push("close_image_modal")}
        />

        <MossletWeb.PrivacyComponents.liquid_markdown_guide_modal
          id="markdown-guide-modal"
          show={@show_markdown_guide}
          on_cancel={JS.push("close_markdown_guide")}
        />
      </div>
    </.layout>
    """
  end

  defp render_no_access(assigns) do
    ~H"""
    <.layout current_page={:home} sidebar_current_page={:home} current_scope={@current_scope}>
      <div class="text-center p-8">
        <p>This profile is not viewable or does not exist.</p>
      </div>
    </.layout>
    """
  end

  defp decrypt_public_field(encrypted_value, encrypted_profile_key) do
    URLPreviewHelpers.decrypt_public_field(encrypted_value, encrypted_profile_key)
  end

  defp get_public_avatar(_profile_user, _current_user) do
    # Public profile avatars are encrypted with profile_key, not conn_key.
    # ZK browser-side decryption for public profiles is a future task.
    nil
  end

  defp get_public_status(profile_user) do
    if StatusHelpers.can_view_status?(profile_user, nil, nil) && profile_user.status do
      to_string(profile_user.status)
    else
      nil
    end
  end

  defp get_public_status_message(profile_user) do
    if StatusHelpers.can_view_status?(profile_user, nil, nil) && profile_user.status_message do
      decrypt_public_field(
        profile_user.status_message,
        profile_user.connection.profile.profile_key
      )
    else
      nil
    end
  end

  defp has_contact_links?(profile) do
    profile.alternate_email || profile.website_url
  end

  defp get_public_post_author_name(_post, profile_user) do
    decrypt_public_field(
      profile_user.connection.profile.name,
      profile_user.connection.profile.profile_key
    )
  end

  defp get_public_post_author_avatar(_post, profile_user, current_user) do
    get_public_avatar(profile_user, current_user)
  end

  defp get_public_profile_post_handle(post, _profile_user, current_user, key) do
    post_key = get_post_key(post, current_user)

    username =
      if post.visibility == :public do
        decrypt_public_field(post.username, post_key)
      else
        decr_item(post.username, current_user, post_key, key, post, "username")
      end

    "@" <>
      case username do
        username when is_binary(username) -> username
        _ -> "author"
      end
  end

  defp get_public_post_author_slug(_post, profile_user, current_user) do
    cond do
      profile_user.id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      true ->
        case profile_user.connection do
          %{profile: %{slug: slug, visibility: visibility}}
          when is_binary(slug) and visibility in [:connections, :public] ->
            slug

          _ ->
            nil
        end
    end
  end

  defp get_public_post_author_visibility(_post, profile_user, current_user) do
    cond do
      profile_user.id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      true ->
        case profile_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end
    end
  end

  defp maybe_load_custom_banner_async(socket, profile_user, profile_owner?) do
    profile = Map.get(profile_user.connection, :profile)
    banner_image = if profile, do: profile.banner_image, else: :waves

    if banner_image == :custom && profile && Map.get(profile, :custom_banner_url) do
      key = socket.assigns.current_scope.key

      if profile_owner? do
        user = socket.assigns.current_scope.user
        connection_id = user.connection.id

        case Mosslet.Extensions.BannerProcessor.get_banner(connection_id) do
          nil ->
            assign_async(socket, :custom_banner_src, fn ->
              result = load_custom_banner(user, profile, key)
              {:ok, %{custom_banner_src: result}}
            end)

          cached_encrypted_binary ->
            assign_async(socket, :custom_banner_src, fn ->
              result = encrypted_banner_data(cached_encrypted_binary, user.conn_key)
              {:ok, %{custom_banner_src: result}}
            end)
        end
      else
        assign(socket, :custom_banner_src, %Phoenix.LiveView.AsyncResult{ok?: true, result: nil})
      end
    else
      assign(socket, :custom_banner_src, %Phoenix.LiveView.AsyncResult{ok?: true, result: nil})
    end
  end

  defp fetch_additional_read_posts(socket, needed) do
    current_user = socket.assigns.current_scope.user
    profile_user = socket.assigns.profile_user
    current_page = socket.assigns.posts_page
    cached_read_posts = socket.assigns.cached_read_posts

    {socket, _} =
      Enum.reduce_while(1..10, {socket, current_page}, fn _, {acc_socket, page} ->
        next_page = page + 1
        options = %{post_page: next_page, post_per_page: @posts_per_page}
        new_posts = Timeline.list_profile_posts_visible_to(profile_user, current_user, options)

        if Enum.empty?(new_posts) do
          {:halt, {acc_socket, next_page}}
        else
          {new_unread, new_read_posts} =
            Enum.split_with(new_posts, fn post ->
              is_post_unread?(post, current_user)
            end)

          current_cached_read = acc_socket.assigns.cached_read_posts
          current_cached_profile = acc_socket.assigns.cached_profile_posts

          new_unread_with_dates =
            add_date_grouping_context_for_append(new_unread, current_cached_profile)

          new_read_posts_with_dates =
            add_date_grouping_context_for_append(new_read_posts, current_cached_read)

          updated_cached_profile = current_cached_profile ++ new_unread_with_dates
          updated_cached_read = current_cached_read ++ new_read_posts_with_dates

          acc_socket = assign(acc_socket, :posts_page, next_page)
          acc_socket = assign(acc_socket, :cached_read_posts, updated_cached_read)
          acc_socket = assign(acc_socket, :cached_profile_posts, updated_cached_profile)

          if length(updated_cached_read) >= length(cached_read_posts) + needed do
            {:halt, {acc_socket, next_page}}
          else
            {:cont, {acc_socket, next_page}}
          end
        end
      end)

    socket
  end

  defp move_post_between_read_streams(socket, post, current_user) do
    is_unread = is_post_unread?(post, current_user)
    cached_profile_posts = socket.assigns.cached_profile_posts
    cached_read_posts = socket.assigns.cached_read_posts

    post_with_date = Map.put(post, :show_date?, false)

    if is_unread do
      updated_read = Enum.reject(cached_read_posts, &(&1.id == post.id))

      updated_profile =
        [post_with_date | cached_profile_posts]
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

      profile_with_dates = add_date_grouping_context(updated_profile)

      socket
      |> stream_delete(:read_posts, post)
      |> assign(:cached_read_posts, updated_read)
      |> assign(:cached_profile_posts, profile_with_dates)
      |> stream(:profile_posts, profile_with_dates, reset: true)
    else
      updated_profile = Enum.reject(cached_profile_posts, &(&1.id == post.id))

      updated_read =
        [post_with_date | cached_read_posts]
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

      profile_with_dates = add_date_grouping_context(updated_profile)
      read_with_dates = add_date_grouping_context(updated_read)

      socket
      |> stream_delete(:profile_posts, post)
      |> assign(:cached_profile_posts, profile_with_dates)
      |> assign(:cached_read_posts, read_with_dates)
      |> stream(:profile_posts, profile_with_dates, reset: true)
      |> then(fn s ->
        if s.assigns.read_posts_expanded do
          stream(s, :read_posts, read_with_dates, reset: true)
        else
          s
        end
      end)
    end
  end

  defp get_async_banner_data(%Phoenix.LiveView.AsyncResult{ok?: true, result: result}),
    do: if(is_map(result), do: result, else: nil)

  defp get_async_banner_data(_), do: nil

  # Helper function to get the profile post author's display name.
  # For non-public posts, returns a placeholder — the browser-side DecryptPost
  # hook will decrypt the author name from the encrypted connection data.
  defp get_profile_post_author_name(post, _profile_user, current_user, _key, _user_connection) do
    if post.visibility != :public do
      # ZK path: return placeholder for browser-side decryption
      if post.user_id == current_user.id do
        current_user.decrypted[:name] || current_user.decrypted[:username] || "..."
      else
        "..."
      end
    else
      # Public posts: server-side decryption
      if post.user_id == current_user.id do
        current_user.decrypted[:name] || current_user.decrypted[:username] || "Private Author"
      else
        "Private Author"
      end
    end
  end

  # Returns encrypted author name data for browser-side ZK decryption on profile pages.
  # For the current user's own posts, returns nil (pre_decrypt_user handles it).
  # For other users' posts, returns the sealed user_connection.key and encrypted
  # connection name/username blobs so the DecryptPost hook can decrypt them.
  defp get_encrypted_profile_post_author_name_data(post, current_user, user_connection) do
    cond do
      post.visibility == :public ->
        nil

      post.user_id == current_user.id ->
        nil

      user_connection && user_connection.connection && is_binary(user_connection.key) ->
        show_name? =
          user_connection.connection.profile != nil and
            user_connection.connection.profile.show_name?

        %{
          sealed_uconn_key: user_connection.key,
          encrypted_name: if(show_name?, do: user_connection.connection.name),
          encrypted_username: user_connection.connection.username,
          show_name: show_name?
        }

      true ->
        nil
    end
  end

  defp get_profile_post_author_handle(post, _profile_user, _current_user, _key, _user_connection) do
    # Use pre-decrypted username from decrypt_post_fields (populated by pre_decrypt_post).
    # For non-public posts, this will be nil (DecryptPost hook decrypts browser-side).
    "@" <> (post.decrypted[:username] || "author")
  end

  # Returns encrypted avatar data for browser-side ZK decryption on profile post cards.
  # For current user: uses conn_key sealed key.
  # For other users: uses UserConnection.key sealed key.
  # Returns nil when avatar is hidden or data unavailable (component falls back to logo).
  defp get_encrypted_profile_post_author_avatar_data(post, current_user, user_connection) do
    if post.user_id == current_user.id do
      if show_avatar?(current_user),
        do: get_encrypted_avatar_data(current_user, nil),
        else: nil
    else
      if user_connection && show_avatar?(user_connection),
        do: get_encrypted_avatar_data(user_connection, nil),
        else: nil
    end
  end

  # Fallback avatar URL for profile post cards when ZK data is nil.
  defp get_profile_post_author_avatar_fallback(post, current_user, user_connection) do
    if post.user_id == current_user.id do
      if show_avatar?(current_user),
        do: mosslet_logo_for_theme(),
        else: "/images/logo.svg"
    else
      if user_connection && show_avatar?(user_connection),
        do: mosslet_logo_for_theme(),
        else: "/images/logo.svg"
    end
  end

  defp get_profile_post_author_status(post, _profile_user, current_user, key, _user_connection) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        case get_user_status_info(post_author, current_user, key) do
          %{status: status} when is_binary(status) -> status
          _ -> nil
        end

      nil ->
        nil
    end
  end

  defp get_profile_post_author_status_message(
         post,
         _profile_user,
         current_user,
         key,
         _user_connection
       ) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        get_user_status_message(post_author, current_user, key)

      nil ->
        nil
    end
  end

  defp get_profile_post_author_encrypted_status_data(
         post,
         _profile_user,
         current_user,
         key,
         _user_connection
       ) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        get_encrypted_status_data(post_author, current_user, key)

      nil ->
        nil
    end
  end

  defp can_view_profile_post_author_status?(
         post,
         _profile_user,
         current_user,
         key,
         _user_connection
       ) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        can_view_status?(post_author, current_user, key)

      nil ->
        false
    end
  end

  defp get_profile_post_author_slug(post, _profile_user, current_user, _key, user_connection) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      is_nil(user_connection) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(post.user_id) do
          %{connection: %{profile: %{slug: slug}}} when is_binary(slug) -> slug
          _ -> nil
        end
    end
  end

  defp get_profile_post_author_visibility(
         post,
         _profile_user,
         current_user,
         _key,
         user_connection
       ) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      is_nil(user_connection) ->
        nil

      true ->
        case Accounts.get_user_with_preloads(post.user_id) do
          %{connection: %{profile: %{visibility: visibility}}} -> visibility
          _ -> nil
        end
    end
  end

  defp format_profile_post_timestamp(naive_datetime)
       when is_struct(naive_datetime, NaiveDateTime) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, naive_datetime)
    diff_minutes = div(diff_seconds, 60)
    diff_hours = div(diff_minutes, 60)
    diff_days = div(diff_hours, 24)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_minutes < 60 -> "#{diff_minutes}m"
      diff_hours < 24 -> "#{diff_hours}h"
      diff_days < 7 -> "#{diff_days}d"
      true -> Calendar.strftime(naive_datetime, "%b %d")
    end
  end

  defp format_profile_post_timestamp(_), do: ""

  defp block_type_description(:full),
    do: "Their posts and replies are hidden from your timeline and profile views."

  defp block_type_description(:posts_only),
    do: "Their posts are hidden, but you can still see their replies."

  defp block_type_description(:replies_only),
    do: "Their replies are hidden, but you can still see their posts."

  defp block_type_description(_), do: "Their content is hidden from your view."

  defp block_type_label(:posts_only), do: "posts"
  defp block_type_label(:replies_only), do: "replies"
  defp block_type_label(_), do: nil

  defp add_date_grouping_context(posts) do
    posts
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      prev_post = if index > 0, do: Enum.at(posts, index - 1)
      post_date = get_post_date(post.inserted_at)

      show_date_separator =
        if prev_post do
          prev_date = get_post_date(prev_post.inserted_at)
          prev_date != post_date
        else
          true
        end

      post
      |> Map.put(:show_date_separator, show_date_separator)
      |> Map.put(:post_date, post_date)
      |> Map.put(:first_separator, index == 0 && show_date_separator)
    end)
  end

  defp add_date_grouping_context_for_append(new_posts, existing_posts) do
    last_existing = List.last(existing_posts)
    last_date = if last_existing, do: get_post_date(last_existing.inserted_at), else: nil

    new_posts
    |> Enum.with_index()
    |> Enum.map(fn {post, index} ->
      post_date = get_post_date(post.inserted_at)

      show_date_separator =
        cond do
          index == 0 && last_date ->
            last_date != post_date

          index == 0 ->
            true

          true ->
            prev_post = Enum.at(new_posts, index - 1)
            prev_date = get_post_date(prev_post.inserted_at)
            prev_date != post_date
        end

      post
      |> Map.put(:show_date_separator, show_date_separator)
      |> Map.put(:post_date, post_date)
      |> Map.put(:first_separator, false)
    end)
  end

  defp add_single_post_date_context(post, existing_posts, opts) do
    post_date = get_post_date(post.inserted_at)
    at_position = Keyword.get(opts, :at, -1)

    show_date_separator =
      cond do
        at_position == 0 ->
          true

        at_position == -1 ->
          last_existing = List.last(existing_posts || [])

          if last_existing do
            existing_date = get_post_date(last_existing.inserted_at)
            existing_date != post_date
          else
            true
          end

        true ->
          true
      end

    post
    |> Map.put(:show_date_separator, show_date_separator)
    |> Map.put(:post_date, post_date)
    |> Map.put(:first_separator, at_position == 0 && show_date_separator)
  end

  defp maybe_update_old_first_post_separator(socket, cached_posts, new_post, opts) do
    at_position = Keyword.get(opts, :at, -1)

    if at_position == 0 do
      first_existing = List.first(cached_posts || [])

      if first_existing && first_existing.id != new_post.id do
        new_post_date = get_post_date(new_post.inserted_at)
        existing_date = get_post_date(first_existing.inserted_at)

        if existing_date == new_post_date && Map.get(first_existing, :show_date_separator, false) do
          updated_old_first =
            first_existing
            |> Map.put(:show_date_separator, false)
            |> Map.put(:first_separator, false)

          stream_insert(socket, :profile_posts, updated_old_first)
        else
          socket
        end
      else
        socket
      end
    else
      socket
    end
  end

  defp get_post_date(datetime) when is_struct(datetime, NaiveDateTime) do
    NaiveDateTime.to_date(datetime)
  end

  defp get_post_date(datetime) when is_struct(datetime, DateTime) do
    DateTime.to_date(datetime)
  end

  defp get_post_date(_), do: nil

  defp update_cached_post(cached_posts, post) do
    if Enum.any?(cached_posts, &(&1.id == post.id)) do
      Enum.map(cached_posts, fn p ->
        if p.id == post.id do
          post
          |> Map.put(:show_date_separator, Map.get(p, :show_date_separator, false))
          |> Map.put(:post_date, Map.get(p, :post_date))
          |> Map.put(:first_separator, Map.get(p, :first_separator, false))
          |> Map.put(:decrypted, Map.get(p, :decrypted))
        else
          p
        end
      end)
    else
      cached_posts
    end
  end

  defp find_post_with_date(cached_posts, post_id) do
    Enum.find(cached_posts, &(&1.id == post_id))
  end

  defp post_visible_on_profile?(post, profile_user, current_user) do
    cond do
      post.user_id != profile_user.id ->
        false

      profile_user.id == current_user.id ->
        true

      Mosslet.Accounts.has_confirmed_user_connection?(profile_user, current_user.id) ->
        post.visibility == :public or
          Enum.any?(post.user_posts || [], &(&1.user_id == current_user.id))

      true ->
        post.visibility == :public
    end
  end

  # Uses pre-decrypted reposts_list from decrypt_post_fields (ZK profile path).
  defp can_repost_profile?(post, current_user) do
    cond do
      !post.allow_shares -> false
      post.user_id == current_user.id -> false
      post.is_ephemeral -> false
      current_user.id in (post.decrypted[:reposts_list] || []) -> false
      true -> post.allow_shares
    end
  end

  defp decrypt_post_reposts_list(post, user, key) do
    case post.reposts_list do
      nil ->
        []

      [] ->
        []

      list when is_list(list) ->
        encrypted_post_key =
          case post.visibility do
            :public -> get_post_key(post)
            _ -> get_post_key(post, user)
          end

        if is_nil(encrypted_post_key) do
          []
        else
          case post.visibility do
            :public ->
              case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
                decrypted_post_key when is_binary(decrypted_post_key) ->
                  Enum.map(list, fn user_id ->
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end

            _ ->
              case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                     encrypted_post_key,
                     user,
                     key
                   ) do
                {:ok, decrypted_post_key} ->
                  Enum.map(list, fn user_id ->
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} -> decrypted_id
                      _ -> user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end
          end
        end
    end
  end

  defp normalize_to_webp(file_path) do
    base = Path.rootname(file_path)
    "#{base}.webp"
  end

  defp stream_delete_profile_post(socket, post) do
    cached_read_posts = socket.assigns[:cached_read_posts] || []
    updated_cached_read = Enum.reject(cached_read_posts, &(&1.id == post.id))

    cached_profile_posts = socket.assigns[:cached_profile_posts] || []
    updated_cached_profile = Enum.reject(cached_profile_posts, &(&1.id == post.id))

    socket
    |> assign(:cached_read_posts, updated_cached_read)
    |> assign(:cached_profile_posts, updated_cached_profile)
    |> assign(:posts_count, max(0, socket.assigns.posts_count - 1))
    |> stream_delete(:profile_posts, post)
    |> stream_delete(:read_posts, post)
  end

  defp delete_post_from_cloud(post, user_post, current_user, key) when is_struct(post) do
    if !post.repost && is_list(post.image_urls) do
      d_image_urls =
        Enum.map(post.image_urls, fn e_image_url ->
          decr_item(
            e_image_url,
            current_user,
            user_post.key,
            key,
            post,
            "body"
          )
        end)

      case delete_object_storage_post_worker(%{"urls" => d_image_urls}) do
        {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
          :ok

        rest ->
          Logger.info("Error deleting Post images from the cloud in UserHomeLive context.")
          Logger.info(inspect(rest))
          Logger.error(rest)
          {:error, "There was an error deleting Post data from the cloud."}
      end
    else
      :ok
    end
  end

  defp delete_post_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_replies_from_cloud(replies, user_post, current_user, key) when is_list(replies) do
    for reply <- replies do
      if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
        d_image_urls =
          Enum.map(reply.image_urls, fn e_image_url ->
            decr_item(
              e_image_url,
              current_user,
              user_post.key,
              key,
              reply,
              "body"
            )
          end)

        case delete_object_storage_post_worker(%{"urls" => d_image_urls}) do
          {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
            :ok

          rest ->
            Logger.info("Error deleting Reply images from the cloud in UserHomeLive context.")
            Logger.info(inspect(rest))
            Logger.error(rest)
            {:error, "There was an error deleting Reply data from the cloud."}
        end
      else
        :ok
      end
    end
  end

  defp delete_replies_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_object_storage_post_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStoragePostWorker.new()
    |> Oban.insert()
  end

  defp check_download_permission(post, current_user) do
    cond do
      post.user_id == current_user.id ->
        true

      post.visibility in [:connections, :specific_users] ->
        can_download_photos_from_shared_item?(post, current_user)

      post.visibility == :public ->
        can_download_photos_from_shared_item?(post, current_user)

      true ->
        false
    end
  end

  defp count_all_replies(replies) when is_list(replies) do
    Enum.reduce(replies, 0, fn reply, acc ->
      child_count = count_all_replies(Map.get(reply, :child_replies, []))
      acc + 1 + child_count
    end)
  end

  defp count_all_replies(_), do: 0

  defp get_post_bookmarked_status(post, current_user) do
    case Timeline.bookmarked?(current_user, post) do
      result when is_boolean(result) -> result
      _ -> false
    end
  end

  # Server-side targeted share path (for public posts or browser encryption fallback)
  defp do_share_server(
         post,
         user,
         key,
         all_shared_users,
         decrypted_reposts,
         selected_user_ids,
         note,
         username,
         socket
       ) do
    encrypted_post_key = get_post_key(post, user)

    decrypted_post_key =
      case post.visibility do
        :public ->
          case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
            decrypted when is_binary(decrypted) -> decrypted
            _ -> nil
          end

        _ ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                 encrypted_post_key,
                 user,
                 key
               ) do
            {:ok, decrypted} -> decrypted
            _ -> nil
          end
      end

    body =
      if is_binary(decrypted_post_key) do
        case Mosslet.Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: post.body}) do
          {:ok, decrypted} -> decrypted
          _ -> ""
        end
      else
        ""
      end

    selected_shared_users =
      all_shared_users
      |> Enum.filter(fn su ->
        su_id = if is_struct(su), do: su.user_id, else: su[:user_id]
        su_id in selected_user_ids
      end)
      |> Enum.map(fn su ->
        if is_struct(su) do
          %{
            sender_id: su.sender_id,
            username: su.username,
            user_id: su.user_id,
            color: su.color
          }
        else
          su
        end
      end)

    repost_params =
      %{
        body: body,
        username: username,
        favs_list: post.favs_list,
        reposts_list: post.reposts_list,
        favs_count: post.favs_count,
        reposts_count: post.reposts_count,
        user_id: user.id,
        original_post_id: post.id,
        visibility: :connections,
        image_urls: decrypt_image_urls_for_repost(post, user, key),
        image_urls_updated_at: post.image_urls_updated_at,
        shared_users: selected_shared_users,
        repost: true,
        share_note: note
      }

    case Timeline.create_targeted_share(repost_params,
           user: user,
           key: key,
           trix_key: decrypted_post_key
         ) do
      {:ok, _shared_post} ->
        {:ok, post} = Timeline.inc_reposts(post)
        updated_reposts = [user.id | decrypted_reposts]
        encrypted_post_key = get_post_key(post, user)

        {:ok, _post} =
          Timeline.update_post_repost(
            post,
            %{reposts_list: updated_reposts},
            user: user,
            key: key,
            post_key: encrypted_post_key
          )

        Accounts.track_user_activity(user, :interaction)

        recipient_count = length(selected_user_ids)

        {:noreply,
         socket
         |> assign(:show_share_modal, false)
         |> assign(:share_post_id, nil)
         |> assign(:share_post_body, nil)
         |> assign(:share_post_username, nil)
         |> put_flash(
           :success,
           "Shared with #{recipient_count} #{if recipient_count == 1, do: "person", else: "people"}!"
         )
         |> push_event("update_post_repost_count", %{
           post_id: post.id,
           reposts_count: post.reposts_count,
           can_repost: false
         })}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_share_modal, false)
         |> put_flash(:error, "Failed to share. Please try again.")}
    end
  end

  defp fetch_and_decrypt_url_preview_image(
         presigned_url,
         encrypted_post_key,
         current_user,
         key,
         visibility
       ) do
    d_post_key =
      case visibility do
        :public ->
          case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
            decrypted when is_binary(decrypted) -> {:ok, decrypted}
            _ -> {:error, :decryption_failed}
          end

        _ ->
          Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
            encrypted_post_key,
            current_user,
            key
          )
      end

    with {:ok, decrypted_key} <- d_post_key,
         {:ok, %{status: 200, body: encrypted_image}} <- Req.get(presigned_url),
         {:ok, decrypted_binary} <-
           Mosslet.Encrypted.Utils.decrypt(%{key: decrypted_key, payload: encrypted_image}) do
      data_url = "data:image/jpeg;base64," <> Base.encode64(decrypted_binary)
      {:ok, data_url}
    else
      {:error, reason} = error ->
        Logger.error("Failed to fetch/decrypt URL preview image: #{inspect(reason)}")
        error

      error ->
        Logger.error("Unexpected error fetching/decrypting URL preview image: #{inspect(error)}")
        {:error, :unknown}
    end
  end

  defp non_empty_list([]), do: nil
  defp non_empty_list(list) when is_list(list), do: list
  defp non_empty_list(_), do: nil
end
