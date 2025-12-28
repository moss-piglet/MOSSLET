defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

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
        Timeline.subscribe()
        Timeline.connections_subscribe(current_user)
        Logger.debug("UserHomeLive subscribed to conn_posts:#{current_user.id}")
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
      |> URLPreviewHelpers.assign_url_preview_defaults()
      |> maybe_load_custom_banner_async(profile_user, profile_owner?)

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

    unread_posts_with_dates = add_date_grouping_context(unread_posts)
    read_posts_with_dates = add_date_grouping_context(read_posts)

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
    {:noreply, assign(socket, :current_user, user)}
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

    is_author? = post.user_id == profile_user.id or post.user_id == current_user.id

    is_shared_with_current_user? =
      Enum.any?(post.shared_users || [], &(&1.user_id == current_user.id))

    cond do
      is_author? and post_visible_on_profile?(post, profile_user, current_user) ->
        cached_posts = socket.assigns.cached_profile_posts
        post_with_date = add_single_post_date_context(post, cached_posts, at: 0)
        updated_cached = [post_with_date | cached_posts]

        socket =
          socket
          |> assign(:cached_profile_posts, updated_cached)
          |> assign(:posts_count, socket.assigns.posts_count + 1)
          |> maybe_update_old_first_post_separator(cached_posts, post_with_date, at: 0)
          |> stream_insert(:profile_posts, post_with_date, at: 0)

        {:noreply, socket}

      is_shared_with_current_user? ->
        cached_read_posts = socket.assigns.cached_read_posts
        already_in_read_posts? = Enum.any?(cached_read_posts, &(&1.id == post.id))

        if already_in_read_posts? do
          {:noreply, socket}
        else
          post_with_date = add_single_post_date_context(post, cached_read_posts, at: 0)
          updated_cached = [post_with_date | cached_read_posts]

          socket =
            socket
            |> assign(:cached_read_posts, updated_cached)
            |> stream_insert(:read_posts, post_with_date, at: 0)

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

    if post.user_id == profile_user.id or post.user_id == current_user.id do
      cached_posts = socket.assigns.cached_profile_posts
      updated_cached = Enum.reject(cached_posts, &(&1.id == post.id))

      socket =
        socket
        |> assign(:cached_profile_posts, updated_cached)
        |> assign(:posts_count, max(0, socket.assigns.posts_count - 1))
        |> stream_delete(:profile_posts, post)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
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

  def handle_info({:submit_share, share_params}, socket) do
    post = Timeline.get_post!(share_params.post_id)
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key
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

    decrypted_reposts = decrypt_post_reposts_list(post, user, key)

    if post.user_id != user.id && user.id not in decrypted_reposts do
      selected_user_ids = share_params.selected_user_ids
      note = share_params.note || ""
      body = share_params.body
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

  def handle_info(_message, socket) do
    Logger.debug("UserHomeLive catch-all handle_info: #{inspect(_message)}")
    {:noreply, socket}
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
      {_new_unread, new_read_posts} =
        Enum.split_with(new_posts, fn post ->
          is_post_unread?(post, current_user)
        end)

      cached_read_posts = socket.assigns.cached_read_posts

      new_read_posts_with_dates =
        add_date_grouping_context_for_append(new_read_posts, cached_read_posts)

      updated_cached_read = cached_read_posts ++ new_read_posts_with_dates

      socket =
        new_read_posts_with_dates
        |> Enum.reduce(socket, fn post, acc_socket ->
          stream_insert(acc_socket, :read_posts, post, at: -1)
        end)
        |> assign(:posts_page, next_page)
        |> assign(:cached_read_posts, updated_cached_read)
        |> assign(:load_more_loading, false)

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
          {_new_unread, new_read_posts} =
            Enum.split_with(new_posts, fn post ->
              is_post_unread?(post, current_user)
            end)

          current_cached = acc_socket.assigns.cached_read_posts

          new_read_posts_with_dates =
            add_date_grouping_context_for_append(new_read_posts, current_cached)

          updated_cached_read = current_cached ++ new_read_posts_with_dates

          acc_socket = assign(acc_socket, :posts_page, next_page)
          acc_socket = assign(acc_socket, :cached_read_posts, updated_cached_read)

          if length(updated_cached_read) >= length(cached_read_posts) + needed do
            {:halt, {acc_socket, next_page}}
          else
            {:cont, {acc_socket, next_page}}
          end
        end
      end)

    socket
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_scope.user

    if current_user.id not in post.favs_list do
      {:ok, post} = Timeline.inc_favs(post)

      case Timeline.update_post_fav(
             post,
             %{favs_list: List.insert_at(post.favs_list, 0, current_user.id)},
             user: current_user
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

    if current_user.id in post.favs_list do
      {:ok, post} = Timeline.decr_favs(post)

      case Timeline.update_post_fav(
             post,
             %{favs_list: List.delete(post.favs_list, current_user.id)},
             user: current_user
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
        <%!-- Hero Section with responsive design --%>
        <div class="relative overflow-hidden">
          <%!-- Banner/Cover Image Section --%>
          <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
            <%!-- Custom banner image if available --%>
            <%= cond do %>
              <% @custom_banner_src.loading -> %>
                <div class="absolute inset-0 flex items-center justify-center">
                  <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
                  </div>
                </div>
              <% get_async_banner_src(@custom_banner_src) -> %>
                <div
                  class="absolute inset-0 bg-cover bg-center bg-no-repeat"
                  style={"background-image: url('#{get_async_banner_src(@custom_banner_src)}')"}
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
                        if @profile_user.connection.profile.show_avatar?,
                          do: maybe_get_user_avatar(@current_scope.user, @current_scope.key)
                      }
                      name={
                        decr_item(
                          @current_scope.user.connection.profile.name,
                          @current_scope.user,
                          @current_scope.user.conn_key,
                          @current_scope.key,
                          @current_scope.user.connection.profile
                        )
                      }
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
                        {"#{decr_item(@current_scope.user.connection.profile.name,
                        @current_scope.user,
                        @current_scope.user.connection.profile.profile_key,
                        @current_scope.key,
                        @current_scope.user.connection.profile)}"}
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
                          @{decr_item(
                            @current_scope.user.connection.profile.username,
                            @current_scope.user,
                            @current_scope.user.connection.profile.profile_key,
                            @current_scope.key,
                            @current_scope.user.connection.profile
                          )}
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
                          {decr_item(
                            @current_scope.user.connection.profile.email,
                            @current_scope.user,
                            @current_scope.user.connection.profile.profile_key,
                            @current_scope.key,
                            @current_scope.user.connection.profile
                          )}
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
            <MossletWeb.DesignSystem.liquid_new_post_prompt
              id="home-new-post-prompt"
              user_name={
                decr_item(
                  @current_scope.user.connection.profile.name,
                  @current_scope.user,
                  @current_scope.user.conn_key,
                  @current_scope.key,
                  @current_scope.user.connection.profile
                )
              }
              user_avatar={
                if @profile_user.connection.profile.show_avatar?,
                  do: maybe_get_user_avatar(@current_scope.user, @current_scope.key)
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
            <div class="lg:col-span-2 space-y-8">
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
                        href={"mailto:#{decr_item(@current_scope.user.connection.profile.alternate_email, @current_scope.user, @current_scope.user.connection.profile.profile_key, @current_scope.key, @current_scope.user.connection.profile)}"}
                        class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                      >
                        {decr_item(
                          @current_scope.user.connection.profile.alternate_email,
                          @current_scope.user,
                          @current_scope.user.connection.profile.profile_key,
                          @current_scope.key,
                          @current_scope.user.connection.profile
                        )}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.DesignSystem.website_url_preview
                    :if={@current_scope.user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={
                      decr_item(
                        @current_scope.user.connection.profile.website_url,
                        @current_scope.user,
                        @current_scope.user.connection.profile.profile_key,
                        @current_scope.key,
                        @current_scope.user.connection.profile
                      )
                    }
                    label={
                      if @current_scope.user.connection.profile.website_label do
                        decr_item(
                          @current_scope.user.connection.profile.website_label,
                          @current_scope.user,
                          @current_scope.user.connection.profile.profile_key,
                          @current_scope.key,
                          @current_scope.user.connection.profile
                        )
                      else
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
                  <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                    {decr_item(
                      @current_scope.user.connection.profile.about,
                      @current_scope.user,
                      @current_scope.user.connection.profile.profile_key,
                      @current_scope.key,
                      @current_scope.user.connection.profile
                    )}
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
                <div id="profile-posts" phx-update="stream" class="space-y-4">
                  <div class="hidden only:block text-center py-8">
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
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
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
                        get_profile_post_author_avatar(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status={nil}
                      user_status_message={nil}
                      show_post_author_status={false}
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_profile_post_content(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_read_posts_divider
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
                    class="profile-post-container opacity-75 hover:opacity-100 transition-opacity duration-300"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
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
                        get_profile_post_author_avatar(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status={nil}
                      user_status_message={nil}
                      show_post_author_status={false}
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_profile_post_content(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_timeline_scroll_indicator
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
                        href={"mailto:#{decrypt_public_field(@profile_user.connection.profile.alternate_email, @profile_user.connection.profile.profile_key)}"}
                        class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                      >
                        {decrypt_public_field(
                          @profile_user.connection.profile.alternate_email,
                          @profile_user.connection.profile.profile_key
                        )}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.DesignSystem.website_url_preview
                    :if={@profile_user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={
                      decrypt_public_field(
                        @profile_user.connection.profile.website_url,
                        @profile_user.connection.profile.profile_key
                      )
                    }
                    label={
                      if @profile_user.connection.profile.website_label do
                        decrypt_public_field(
                          @profile_user.connection.profile.website_label,
                          @profile_user.connection.profile.profile_key
                        )
                      else
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
                    {decrypt_public_field(
                      @profile_user.connection.profile.about,
                      @profile_user.connection.profile.profile_key
                    )}
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
                <div id="profile-posts-public" phx-update="stream" class="space-y-4">
                  <div class="hidden only:block text-center py-8">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                    />
                    <p class="text-sm text-slate-600 dark:text-slate-400">
                      No public posts yet.
                    </p>
                  </div>
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
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
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_public_profile_post_content(post, @current_scope.user, @current_scope.key)
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_read_posts_divider
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
                    class="profile-post-container opacity-75 hover:opacity-100 transition-opacity duration-300"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
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
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_public_profile_post_content(post, @current_scope.user, @current_scope.key)
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_timeline_scroll_indicator
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
      <div id="timeline-container">
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
                      src={
                        if @profile_user.connection.profile.show_avatar?,
                          do:
                            get_connection_avatar_src(
                              @user_connection,
                              @current_scope.user,
                              @current_scope.key
                            )
                      }
                      name={
                        decr_item(
                          @profile_user.connection.profile.name,
                          @current_scope.user,
                          @user_connection.key,
                          @current_scope.key,
                          @profile_user.connection.profile
                        )
                      }
                      size="xxl"
                      status={to_string(@profile_user.status)}
                      status_message={
                        get_user_status_message(
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
                      >
                        {"#{decr_item(@profile_user.connection.profile.name,
                        @current_scope.user,
                        @user_connection.key,
                        @current_scope.key,
                        @profile_user.connection.profile)}"}
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
                          @{decr_item(
                            @profile_user.connection.profile.username,
                            @current_scope.user,
                            @user_connection.key,
                            @current_scope.key,
                            @profile_user.connection.profile
                          )}
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
                          {decr_item(
                            @profile_user.connection.profile.email,
                            @current_scope.user,
                            @user_connection.key,
                            @current_scope.key,
                            @profile_user.connection.profile
                          )}
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
                        href={"mailto:#{decr_uconn(@profile_user.connection.profile.alternate_email, @current_scope.user, @user_connection.key, @current_scope.key)}"}
                        class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                      >
                        {decr_uconn(
                          @profile_user.connection.profile.alternate_email,
                          @current_scope.user,
                          @user_connection.key,
                          @current_scope.key
                        )}
                      </a>
                    </div>
                  </div>

                  <MossletWeb.DesignSystem.website_url_preview
                    :if={@profile_user.connection.profile.website_url}
                    preview={@website_url_preview}
                    loading={@website_url_preview_loading}
                    url={
                      decr_uconn(
                        @profile_user.connection.profile.website_url,
                        @current_scope.user,
                        @user_connection.key,
                        @current_scope.key
                      )
                    }
                    label={
                      if @profile_user.connection.profile.website_label do
                        decr_uconn(
                          @profile_user.connection.profile.website_label,
                          @current_scope.user,
                          @user_connection.key,
                          @current_scope.key
                        )
                      else
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
                  <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                    {decr_uconn(
                      @profile_user.connection.profile.about,
                      @current_scope.user,
                      @user_connection.key,
                      @current_scope.key
                    )}
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
                <div id="profile-posts-connections" phx-update="stream" class="space-y-4">
                  <div class="hidden only:block text-center py-8">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                    />
                    <p class="text-sm text-slate-600 dark:text-slate-400">
                      No posts shared with you yet.
                    </p>
                  </div>
                  <div
                    :for={{dom_id, post} <- @streams.profile_posts}
                    id={dom_id}
                    class="profile-post-container"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
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
                        get_profile_post_author_avatar(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status={nil}
                      user_status_message={nil}
                      show_post_author_status={false}
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_profile_post_content(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_read_posts_divider
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
                    class="profile-post-container opacity-75 hover:opacity-100 transition-opacity duration-300"
                  >
                    <MossletWeb.DesignSystem.liquid_timeline_date_separator
                      :if={Map.get(post, :show_date_separator, false) && Map.get(post, :post_date)}
                      date={post.post_date}
                      first={Map.get(post, :first_separator, false)}
                    />
                    <MossletWeb.DesignSystem.liquid_timeline_post
                      user_name={
                        get_profile_post_author_name(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
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
                        get_profile_post_author_avatar(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      user_status={nil}
                      user_status_message={nil}
                      show_post_author_status={false}
                      timestamp={format_profile_post_timestamp(post.inserted_at)}
                      verified={false}
                      content_warning?={false}
                      content_warning={nil}
                      content_warning_category={nil}
                      content={
                        get_profile_post_content(
                          post,
                          @profile_user,
                          @current_scope.user,
                          @current_scope.key,
                          @user_connection
                        )
                      }
                      images={[]}
                      decrypted_url_preview={nil}
                      stats={
                        %{
                          replies: length(post.replies || []),
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
                      share_note={nil}
                      liked={@current_scope.user.id in (post.favs_list || [])}
                      bookmarked={false}
                      can_repost={can_repost?(@current_scope.user, post, @current_scope.key)}
                      can_reply?={false}
                      can_bookmark?={false}
                      unread?={is_post_unread?(post, @current_scope.user)}
                      unread_replies_count={0}
                      unread_nested_replies_by_parent={%{}}
                      calm_notifications={@current_scope.user.calm_notifications}
                      class="shadow-md hover:shadow-lg transition-shadow duration-300"
                    />
                  </div>
                </div>
                <MossletWeb.DesignSystem.liquid_timeline_scroll_indicator
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

  defp get_public_avatar(profile_user, current_user) do
    avatar_url = profile_user.connection.profile.avatar_url

    if avatar_url && avatar_url != "" do
      maybe_get_public_profile_user_avatar(
        profile_user,
        profile_user.connection.profile,
        current_user
      )
    end
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

  defp get_public_post_author_handle(post, _profile_user) do
    "@" <>
      case decrypt_public_field(post.username, get_post_key(post)) do
        username when is_binary(username) -> username
        _ -> "author"
      end
  end

  defp get_public_post_author_avatar(_post, profile_user, current_user) do
    get_public_avatar(profile_user, current_user)
  end

  defp get_public_profile_post_content(post, current_user, key) do
    post_key = get_post_key(post, current_user)

    if is_nil(post_key) do
      "[Could not decrypt content]"
    else
      if post.visibility == :public do
        case decrypt_public_field(post.body, post_key) do
          content when is_binary(content) -> content
          _ -> "[Could not decrypt content]"
        end
      else
        case decr_item(post.body, current_user, post_key, key, post, "body") do
          content when is_binary(content) -> content
          _ -> "[Could not decrypt content]"
        end
      end
    end
  end

  defp get_public_profile_post_handle(post, profile_user, current_user, key) do
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

  defp get_original_post_user_id(post) do
    case Mosslet.Timeline.get_post(post.original_post_id) do
      %{user_id: user_id} -> user_id
      _ -> post.user_id
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
              result = load_custom_banner(user, profile, key, connection_id)
              {:ok, %{custom_banner_src: result}}
            end)

          cached_encrypted_binary ->
            assign_async(socket, :custom_banner_src, fn ->
              result = decrypt_cached_banner(cached_encrypted_binary, user, key)
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

  defp decrypt_cached_banner(encrypted_binary, user, key) do
    {:ok, d_conn_key} =
      Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    case Mosslet.Encrypted.Utils.decrypt(%{key: d_conn_key, payload: encrypted_binary}) do
      {:ok, decrypted} -> "data:image/webp;base64,#{Base.encode64(decrypted)}"
      {:error, _reason} -> nil
    end
  end

  defp load_custom_banner(user, profile, key, connection_id) do
    if profile && Map.get(profile, :custom_banner_url) do
      d_banner_url =
        decr_banner(
          profile.custom_banner_url,
          user,
          user.conn_key,
          key
        )

      if is_valid_banner_url?(d_banner_url) do
        case fetch_and_decrypt_banner(d_banner_url, user, key, connection_id) do
          {:ok, decrypted_binary} ->
            "data:image/webp;base64,#{Base.encode64(decrypted_binary)}"

          {:error, _reason} ->
            nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp is_valid_banner_url?(nil), do: false
  defp is_valid_banner_url?(""), do: false
  defp is_valid_banner_url?("failed_verification"), do: false
  defp is_valid_banner_url?(url) when is_binary(url), do: String.starts_with?(url, "uploads/")
  defp is_valid_banner_url?(_), do: false

  defp fetch_and_decrypt_banner(banner_url, user, key, connection_id) do
    banners_bucket = Mosslet.Encrypted.Session.banners_bucket()
    host = Mosslet.Encrypted.Session.s3_host()
    host_name = "https://#{banners_bucket}.#{host}"

    config = %{
      region: Mosslet.Encrypted.Session.s3_region(),
      access_key_id: Mosslet.Encrypted.Session.s3_access_key_id(),
      secret_access_key: Mosslet.Encrypted.Session.s3_secret_key_access()
    }

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: 600
    ]

    {:ok, presigned_url} = ExAws.S3.presigned_url(config, :get, host_name, banner_url, options)

    case Req.get(presigned_url,
           retry: :transient,
           retry_delay: fn n -> n * 500 end,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: encrypted_binary}} ->
        Mosslet.Extensions.BannerProcessor.put_banner(connection_id, encrypted_binary)

        {:ok, d_conn_key} =
          Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

        case Mosslet.Encrypted.Utils.decrypt(%{key: d_conn_key, payload: encrypted_binary}) do
          {:ok, decrypted} -> {:ok, decrypted}
          error -> error
        end

      {:ok, %{status: status}} ->
        {:error, "Failed to fetch banner: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch banner: #{inspect(reason)}"}
    end
  end

  defp get_async_banner_src(%Phoenix.LiveView.AsyncResult{ok?: true, result: result}), do: result
  defp get_async_banner_src(_), do: nil

  defp get_profile_post_author_name(post, profile_user, current_user, key, user_connection) do
    profile_owner? = current_user.id == profile_user.id

    if profile_owner? or post.user_id == current_user.id do
      case user_name(current_user, key) do
        name when is_binary(name) -> name
        _ -> "Private Author"
      end
    else
      if user_connection && user_connection.connection do
        profile = user_connection.connection.profile

        if profile && profile.show_name? do
          case decr_uconn(user_connection.connection.name, current_user, user_connection.key, key) do
            name when is_binary(name) -> name
            _ -> "Private Author"
          end
        else
          case decr_uconn(
                 user_connection.connection.username,
                 current_user,
                 user_connection.key,
                 key
               ) do
            username when is_binary(username) -> username
            _ -> "Private Author"
          end
        end
      else
        "Private Author"
      end
    end
  end

  defp get_profile_post_author_handle(post, profile_user, current_user, key, user_connection) do
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

  defp get_profile_post_author_avatar(post, profile_user, current_user, key, user_connection) do
    profile_owner? = current_user.id == profile_user.id

    if profile_owner? or post.user_id == current_user.id do
      if current_user.connection.profile.show_avatar? do
        maybe_get_user_avatar(current_user, key) || "/images/logo.svg"
      else
        "/images/logo.svg"
      end
    else
      if user_connection && show_avatar?(user_connection) do
        case maybe_get_avatar_src(post, current_user, key, []) do
          avatar when is_binary(avatar) and avatar != "" -> avatar
          _ -> "/images/logo.svg"
        end
      else
        "/images/logo.svg"
      end
    end
  end

  defp get_profile_post_key(post, _profile_user, current_user, _user_connection) do
    get_post_key(post, current_user)
  end

  defp get_profile_post_content(post, profile_user, current_user, key, user_connection) do
    post_key = get_profile_post_key(post, profile_user, current_user, user_connection)

    if is_nil(post_key) do
      "[Could not decrypt content]"
    else
      case decr_item(post.body, current_user, post_key, key, post, "body") do
        content when is_binary(content) -> content
        rest -> "#{rest}"
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

  defp can_repost?(user, post, key) do
    cond do
      !post.allow_shares -> false
      post.user_id == user.id -> false
      post.is_ephemeral -> false
      user.id in decrypt_post_reposts_list(post, user, key) -> false
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
end
