defmodule MossletWeb.PostLive.Index do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias MossletWeb.Endpoint
  alias Mosslet.Groups
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  alias MossletWeb.PostLive.Components

  @page_default 1
  @per_page_default 10

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Accounts.subscribe_account_deleted()
      Timeline.private_subscribe(current_user)
      Timeline.private_reply_subscribe(current_user)
      Timeline.connections_subscribe(current_user)
      Timeline.connections_reply_subscribe(current_user)
      Groups.private_subscribe(current_user)
    end

    {:ok,
     socket
     |> assign(:post_loading_count, 0)
     |> assign(:post_loading, false)
     |> assign(:post_loading_done, false)
     |> assign(:filter, %{user_id: ""})
     |> assign(:finished_loading_list, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)
    group = if params["group_id"], do: Groups.get_group!(params["group_id"]), else: ""

    page = param_to_integer(params["page"], @page_default)
    per_page = param_to_integer(params["per_page"], @per_page_default) |> limit_per_page()
    filter = %{user_id: params["user_id"] || params["filter"]["user_id"] || ""}

    options = %{
      filter: filter,
      sort_by: sort_by,
      sort_order: sort_order,
      page: page,
      per_page: per_page,
      current_user_id: current_user.id
    }

    posts = Timeline.list_posts(current_user, options)

    loading_list = Enum.with_index(posts, fn element, index -> {index, element} end)
    groups = Groups.list_groups(current_user)

    if connected?(socket) && !Enum.empty?(groups) do
      for group <- groups do
        Endpoint.subscribe("group:#{group.id}")
      end
    end

    url =
      if options.page == @page_default && options.per_page == @per_page_default &&
           filter.user_id == "",
         do: ~p"/app/timeline",
         else: ~p"/app/timeline?#{options}"

    socket =
      socket
      |> assign(
        :shared_users,
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          socket.assigns.key,
          :post
        )
      )
      |> assign(:groups, groups)
      |> assign(:post_count, Timeline.post_count(current_user, options))
      |> assign(:loading_list, loading_list)
      |> assign(:options, options)
      |> assign(:return_url, url)
      |> assign(:group, group)
      |> assign(:post_loading_count, socket.assigns[:post_loading_count] || 0)
      |> assign(:post_loading, socket.assigns[:post_loading] || false)
      |> assign(:post_loading_done, socket.assigns[:post_loading_done] || false)
      |> assign(:finished_loading_list, socket.assigns[:finished_loading_list] || [])
      |> assign(:filter, filter)
      |> stream(:posts, posts, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :reply, %{"id" => id}) do
    socket
    |> assign(:page_title, "Reply to Post")
    |> assign(:post, Timeline.get_post!(id))
  end

  defp apply_action(socket, :reply_edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit reply to Post")
    |> assign(:post, Timeline.get_post!(id))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, Timeline.get_post!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Post")
    |> assign(:post, %Post{})
    |> assign(:group, nil)
  end

  defp apply_action(socket, :new_group, %{"group_id" => group_id} = _params) do
    group = Groups.get_group!(group_id)

    socket
    |> assign(:page_title, "New Group Post")
    |> assign(:post, %Post{})
    |> assign(:group, group)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Your Timeline")
    |> assign(:post, nil)
  end

  @impl true
  def handle_info({MossletWeb.PostLive.FormComponent, {:saved, post}}, socket) do
    if post.visibility != :public && is_nil(post.group_id) do
      {:noreply, stream_insert(socket, :posts, post, at: 0, reset: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.PostLive.FormComponent, {:updated, post}}, socket) do
    if post.visibility != :public do
      {:noreply, stream_insert(socket, :posts, post, at: -1, reset: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.PostLive.Index, {:deleted, post}}, socket) do
    if post.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket |> stream_delete(:posts, post) |> push_patch(to: socket.assigns.return_url)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.PostLive.Index, {:reposted, post}}, socket) do
    if post.user_id == socket.assigns.current_user.id do
      {:noreply, stream_insert(socket, :posts, post, at: 0, reset: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    if post.visibility != :public do
      if is_nil(post.group_id) do
        {:noreply, stream_insert(socket, :posts, post, at: 0, reset: true)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_reposted, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post, at: 0, reset: true)}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, stream_insert(socket, :posts, post, at: -1, reset: true)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply, socket |> stream_delete(:posts, post) |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({:reply_created, post, _reply}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  @impl true
  def handle_info({:reply_updated, post, _reply}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  @impl true
  def handle_info({:reply_deleted, post, _reply}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  @impl true
  def handle_info({:repost_deleted, post}, socket) do
    current_user = socket.assigns.current_user

    if current_user.id in post.reposts_list do
      {:noreply, socket |> stream_delete(:posts, post) |> push_navigate(to: ~p"/app/timeline")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:posts_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:replies_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_confirmed, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_username_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_name_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_email_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:account_deleted, _user}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", post_id, post_list, _user_id}}, socket) do
    post_loading_count = socket.assigns.post_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      post_loading_count < Enum.count(post_list) - 1 ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(:post_loading_count, post_loading_count + 1)
          |> assign(:finished_loading_list, [post_id | finished_loading_list] |> Enum.uniq())

        post = Timeline.get_post!(post_id)

        {:noreply, stream_insert(socket, :posts, post, at: -1, reset: true)}

      post_loading_count == Enum.count(post_list) - 1 ->
        finished_loading_list = [post_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:post_loading, false)
          |> assign(:finished_loading_list, [post_id | finished_loading_list] |> Enum.uniq())

        if Enum.count(finished_loading_list) == Enum.count(post_list) do
          post = Timeline.get_post!(post_id)

          socket =
            socket
            |> assign(:post_loading_count, 0)
            |> assign(:post_loading, false)
            |> assign(:post_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :posts, post, at: -1, reset: true)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(:finished_loading_list, [post_id | finished_loading_list] |> Enum.uniq())

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"user_id" => user_id}, socket) do
    params = %{user_id: user_id}
    {:noreply, push_patch(socket, to: ~p"/app/timeline?#{params}")}
  end

  @impl true
  def handle_event("reply", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      post = Timeline.get_post!(id)

      {:noreply,
       socket |> assign(:live_action, :reply) |> assign(:post, post) |> assign(:reply, %Reply{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit-reply", %{"id" => id}, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      reply = Timeline.get_reply!(id)
      post = Timeline.get_post!(reply.post_id)

      {:noreply,
       socket
       |> assign(:live_action, :reply_edit)
       |> assign(:post, post)
       |> assign(:reply, reply)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user

    if post.user_id == user.id do
      {:ok, post} = Timeline.delete_post(post, user: user)
      notify_self({:deleted, post})

      socket = put_flash(socket, :success, "Post deleted successfully.")
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    user = socket.assigns.current_user

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if user && (user.id == reply.user_id || user.id == reply.post.user_id) do
      case Timeline.delete_reply(reply, user: user) do
        {:ok, reply} ->
          notify_self({:deleted, reply})
          {:noreply, put_flash(socket, :success, "Reply deleted successfully.")}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply,
       put_flash(socket, :warning, "You do not have permission to perform this action.")}
    end
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user

    if user.id not in post.favs_list do
      {:ok, post} = Timeline.inc_favs(post)

      Timeline.update_post_fav(post, %{favs_list: List.insert_at(post.favs_list, 0, user.id)},
        user: user
      )

      {:noreply, push_patch(socket, to: ~p"/app/timeline")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user

    if user.id in post.favs_list do
      {:ok, post} = Timeline.decr_favs(post)

      Timeline.update_post_fav(post, %{favs_list: List.delete(post.favs_list, user.id)},
        user: user
      )

      {:noreply, push_patch(socket, to: ~p"/app/timeline")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("repost", %{"id" => id, "body" => body, "username" => username}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key

    if post.user_id != user.id && user.id not in post.reposts_list do
      {:ok, post} = Timeline.inc_reposts(post)

      {:ok, post} =
        Timeline.update_post_repost(
          post,
          %{
            reposts_list: List.insert_at(post.reposts_list, 0, user.id)
          },
          user: user
        )

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
          visibility: post.visibility,
          shared_users: [%{}],
          repost: true
        }
        |> add_shared_users_list(socket.assigns.shared_users)

      {:ok, post} = Timeline.create_repost(repost_params, user: user, key: key)
      notify_self({:reposted, post})

      socket = put_flash(socket, :success, "Post reposted successfully.")
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # When post is being shared with all connections, the
  # shared_users is a list of SharedUser structs.
  #
  # When adding shared_users from a repost, we need to update
  # the shared_users list with the current_user's shared users.
  defp add_shared_users_list(repost_params, shared_users) do
    Map.update(
      repost_params,
      :shared_users,
      Enum.map(shared_users, fn shared_user ->
        Map.from_struct(shared_user)
      end),
      fn _shared_users_list ->
        Enum.map(shared_users, fn shared_user ->
          Map.from_struct(shared_user)
        end)
      end
    )
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id inserted_at updated_at) do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

  defp valid_sort_order(%{"sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_existing_atom(sort_order)
  end

  defp valid_sort_order(_params), do: :desc

  defp param_to_integer(nil, default), do: default

  defp param_to_integer(param, default) do
    case Integer.parse(param) do
      {number, _} -> number
      :error -> default
    end
  end

  defp limit_per_page(per_page) when is_integer(per_page) do
    if per_page > 24, do: 24, else: per_page
  end

  # We use the shared_users because these are
  # NOT public and so we only want to filter
  # by the current_user's connections.
  defp user_options(shared_users) do
    user_options =
      Enum.into(shared_users, [], fn su ->
        ["#{su.username}": "#{su.user_id}"]
      end)
      |> List.flatten()

    [["All Posts": ""] | user_options] |> List.flatten()
  end

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})
end
