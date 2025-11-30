defmodule MossletWeb.PostLive.Show do
  use MossletWeb, :live_view

  require Logger

  alias Phoenix.LiveView.AsyncResult

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias MossletWeb.Endpoint
  alias Mosslet.Groups
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Reply
  alias MossletWeb.PostLive.Components

  @page_default 1
  @per_page_default 5
  @folder "uploads/trix"

  def mount(%{"id" => id} = _params, _session, socket) do
    current_user = socket.assigns.current_user
    post = Timeline.get_post!(id)
    group = if not is_nil(post.group_id), do: Groups.get_group!(post.group_id), else: nil

    if connected?(socket) do
      Timeline.private_subscribe(current_user)
      Accounts.private_subscribe(current_user)
      Timeline.connections_subscribe(current_user)
      Timeline.connections_reply_subscribe(current_user)
      Groups.private_subscribe(current_user)
      if group, do: Endpoint.subscribe("group:#{group.id}")
    end

    {:ok,
     socket
     |> assign(:post, post)
     |> assign(:group, group)
     |> assign(:reply_loading_count, 0)
     |> assign(:reply_loading, false)
     |> assign(:reply_loading_done, false)
     |> assign(:filter, %{user_id: ""})
     |> assign(:image_urls, [])
     |> assign(:uploads_in_progress, false)
     |> assign(:delete_post_from_cloud_message, nil)
     |> assign(:delete_reply_from_cloud_message, nil)
     |> assign(:finished_loading_list, [])}
  end

  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    post = socket.assigns.post
    key = socket.assigns.key

    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)

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

    replies = Timeline.list_replies(post, options)

    loading_list = Enum.with_index(replies, fn element, index -> {index, element} end)

    url =
      if options.page == @page_default && options.per_page == @per_page_default,
        do: ~p"/app/posts/#{post}",
        else: ~p"/app/posts/#{post}?#{options}"

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
      |> assign(:src, maybe_get_avatar_src(post, current_user, key, loading_list))
      |> assign(:reply_count, Timeline.reply_count(post, options))
      |> assign(:loading_list, loading_list)
      |> assign(:options, options)
      |> assign(:return_url, url)
      |> assign(:reply_loading_count, socket.assigns[:reply_loading_count] || 0)
      |> assign(:reply_loading, socket.assigns[:reply_loading] || false)
      |> assign(:reply_loading_done, socket.assigns[:reply_loading_done] || false)
      |> assign(:finished_loading_list, socket.assigns[:finished_loading_list] || [])
      |> assign(:filter, filter)
      |> assign(:page_title, page_title(socket.assigns.live_action))
      |> stream(:replies, replies, reset: true)

    {:noreply,
     socket
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Post")
    |> assign(:post, Timeline.get_post!(id))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Timeline.get_post!(id)

    socket
    |> assign(:page_title, "Edit Post")
    |> assign(:post, post)
    |> assign(:image_urls, if(post.image_urls, do: post.image_urls, else: []))
  end

  defp apply_action(socket, :reply, %{"id" => id}) do
    post = Timeline.get_post!(id)

    socket
    |> assign(:page_title, "Reply to Post")
    |> assign(:reply, %Reply{})
    |> assign(:image_urls, [])
    |> assign(:post, post)
  end

  defp apply_action(socket, :reply_edit, %{"id" => id, "reply_id" => reply_id}) do
    post = Timeline.get_post!(id)
    reply = Timeline.get_reply!(reply_id)

    socket
    |> assign(:page_title, "Edit reply to Post")
    |> assign(:reply, reply)
    |> assign(:post, post)
    |> assign(:image_urls, if(reply.image_urls, do: reply.image_urls, else: []))
  end

  def handle_info({MossletWeb.PostLive.Show, {:deleted, reply}}, socket) do
    if reply.user_id == socket.assigns.current_user.id do
      {:noreply,
       socket
       |> clear_flash(:success)
       |> put_flash(:success, "Reply deleted successfully.")
       |> push_patch(to: socket.assigns.return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({MossletWeb.PostLive.FormComponent, {:saved, post}}, socket) do
    if post.id == socket.assigns.post.id do
      {:noreply, assign(socket, :post, post)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({MossletWeb.PostLive.Replies.FormComponent, {:saved, reply}}, socket) do
    if reply.post_id == socket.assigns.post.id do
      {:noreply, stream_insert(socket, :replies, reply)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({MossletWeb.PostLive.Replies.FormComponent, {:deleted, reply}}, socket) do
    if reply.post_id == socket.assigns.post.id do
      {:noreply, stream_delete(socket, :replies, reply)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_created, post, reply}, socket) do
    current_user = socket.assigns.current_user

    user_connection =
      Accounts.get_user_connection_for_reply_shared_users(reply.user_id, current_user.id)

    if post.id == socket.assigns.post.id && (user_connection || reply.user_id == current_user.id) do
      reply_count = socket.assigns.reply_count + 1

      {:noreply,
       socket
       |> assign(:reply_count, reply_count)
       |> stream_insert(:replies, reply)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_updated, post, reply}, socket) do
    current_user = socket.assigns.current_user

    user_connection =
      Accounts.get_user_connection_for_reply_shared_users(reply.user_id, current_user.id)

    if post.id == socket.assigns.post.id && (user_connection || reply.user_id == current_user.id) do
      {:noreply, stream_insert(socket, :replies, reply)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_deleted, post, reply}, socket) do
    current_user = socket.assigns.current_user

    user_connection =
      Accounts.get_user_connection_for_reply_shared_users(reply.user_id, current_user.id)

    if post.id == socket.assigns.post.id && (user_connection || reply.user_id == current_user.id) do
      reply_count = max(socket.assigns.reply_count - 1, 0)

      {:noreply,
       socket
       |> assign(:reply_count, reply_count)
       |> stream_delete(:replies, reply)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_updated, post}, socket) do
    if post.id == socket.assigns.post.id do
      {:noreply, socket |> assign(:post, post) |> push_patch(to: socket.assigns.return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_updated_fav, post}, socket) do
    {:noreply, socket |> assign(:post, post)}
  end

  def handle_info({:post_deleted, post}, socket) do
    current_user = socket.assigns.current_user

    if post.id == socket.assigns.post.id && current_user.id != post.user_id do
      # we only navigate other users to the timeline
      # the person who created and thus deleted the post will be
      # navigated to the timeline after their images are removed from the cloud
      # in the handle_async function
      {:noreply,
       socket
       |> put_flash(:warning, "Post has been deleted by its author.")
       |> push_navigate(to: ~p"/app/timeline")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:uconn_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:replies_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_confirmed, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_username_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_name_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_email_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/posts/#{socket.assigns.post}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({_ref, {"get_user_avatar", post_id, _post_list, _user_id}}, socket) do
    post = Timeline.get_post!(post_id)

    socket =
      socket
      |> assign(:post, post)

    {:noreply, socket}
  end

  def handle_info({_ref, {"get_user_avatar_reply", reply_id, reply_list, _user_id}}, socket) do
    reply_loading_count = socket.assigns.reply_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      reply_loading_count < Enum.count(reply_list) - 1 ->
        socket =
          socket
          |> assign(:reply_loading, true)
          |> assign(:reply_loading_count, reply_loading_count + 1)
          |> assign(:finished_loading_list, [reply_id | finished_loading_list] |> Enum.uniq())

        reply = Timeline.get_reply!(reply_id)

        {:noreply, stream_insert(socket, :replies, reply, at: -1, reset: true)}

      reply_loading_count == Enum.count(reply_list) - 1 ->
        finished_loading_list = [reply_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:reply_loading, false)
          |> assign(:finished_loading_list, [reply_id | finished_loading_list] |> Enum.uniq())

        if Enum.count(finished_loading_list) == Enum.count(reply_list) do
          reply = Timeline.get_reply!(reply_id)

          socket =
            socket
            |> assign(:reply_loading_count, 0)
            |> assign(:reply_loading, false)
            |> assign(:reply_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :replies, reply, at: -1, reset: true)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:reply_loading, true)
          |> assign(:finished_loading_list, [reply_id | finished_loading_list] |> Enum.uniq())

        {:noreply, socket}
    end
  end

  def handle_info({:uploads_in_progress, false}, socket) do
    {:noreply, assign(socket, :uploads_in_progress, false)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("reply", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user

    if current_user do
      {:noreply,
       socket
       |> assign(:live_action, :reply)
       |> assign(:post, post)
       |> assign(:reply, %Reply{})
       |> push_patch(to: ~p"/app/posts/#{post}/show/reply")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("edit-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    post = Timeline.get_post!(reply.post_id)
    current_user = socket.assigns.current_user

    if current_user do
      {:noreply,
       socket
       |> assign(:live_action, :reply_edit)
       |> assign(:post, post)
       |> assign(:reply, reply)
       |> push_patch(to: ~p"/app/posts/#{post}/show/#{reply}/edit")}
    else
      {:noreply, socket}
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

      {:noreply, socket}
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

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("repost", %{"id" => id, "body" => body, "username" => username}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    # Add the post_key to the opts as the trix_key.
    #
    # This way, if there are any images in the post, then
    # we will correctly reuse the trix_key from the original
    # post to decrypt the images (this way we don't have to
    # duplicate the images in storage).
    #
    # Also, it's a repost, so it is essentially a duplicate post
    # and thus the duplicate use of the same key.
    post_key = get_post_key(post, user)
    key = socket.assigns.key
    post_shared_users = socket.assigns.shared_users
    return_url = socket.assigns.return_url

    if post.user_id != user.id && user.id not in post.reposts_list do
      # the image urls are now encrypted so we need to decrypt them
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
          image_urls: decrypt_image_urls_for_repost(post, user, key),
          image_urls_updated_at: post.image_urls_updated_at,
          repost: true
        }
        |> add_shared_users_list(post_shared_users)

      case Timeline.create_repost(repost_params, user: user, key: key, trix_key: post_key) do
        {:ok, _repost} ->
          {:ok, post} = Timeline.inc_reposts(post)

          {:ok, _post} =
            Timeline.update_post_repost(
              post,
              %{
                reposts_list: List.insert_at(post.reposts_list, 0, user.id)
              },
              user: user
            )

          socket =
            socket
            |> put_flash(:success, "Post reposted successfully.")

          {:noreply, push_navigate(socket, to: return_url)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "You have already reposted this post or do not have permission to repost."
       )}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key

    if post.user_id == user.id do
      user_post = Timeline.get_user_post(post, user)
      replies = post.replies

      case Timeline.delete_post(post, user: user) do
        {:ok, post} ->
          socket =
            socket
            |> put_flash(:success, "Post deleted successfully.")
            |> assign(:delete_post_from_cloud_message, AsyncResult.loading())
            |> start_async(
              :delete_post_from_cloud,
              fn ->
                delete_post_from_cloud(
                  post,
                  user_post,
                  user,
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
                  user,
                  key
                )
              end
            )

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete-reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if user && (user.id == reply.user_id || user.id == reply.post.user_id) do
      post = Timeline.get_post!(reply.post_id)
      user_post = Timeline.get_user_post(post, user)

      case Timeline.delete_reply(reply, user: user) do
        {:ok, reply} ->
          socket =
            socket
            |> put_flash(:success, "Reply deleted successfully.")
            |> assign(:delete_reply_from_cloud_message, AsyncResult.loading())
            |> start_async(
              :delete_reply_from_cloud,
              fn ->
                delete_reply_from_cloud(
                  reply,
                  user_post,
                  user,
                  key
                )
              end
            )

          {:noreply, push_patch(socket, to: socket.assigns.return_url)}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply,
       put_flash(socket, :warning, "You do not have permission to perform this action.")}
    end
  end

  def handle_event("uploads_in_progress", %{"flag" => flag}, socket) do
    {:noreply, assign(socket, :uploads_in_progress, flag)}
  end

  def handle_event("trix_key", _params, socket) do
    current_user = socket.assigns.current_user
    # we check if there's a post assigned to the socket,
    # if so, then we can infer that it's a Reply being
    # created and the trix_key will be the already saved
    # post_key (it'll also already be encrypted as well)
    post = socket.assigns[:post]

    trix_key =
      Map.get(socket.assigns, :trix_key, generate_and_encrypt_trix_key(current_user, post))

    socket =
      socket
      |> assign(:trix_key, trix_key)

    {:reply, %{response: "success", trix_key: trix_key}, socket}
  end

  def handle_event(
        "decrypt_post_images",
        %{"sources" => sources, "post_id" => post_id} = _params,
        socket
      ) do
    memories_bucket = Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    post_id =
      if String.contains?(post_id, "-reply-form"),
        do: String.split(post_id, "-reply-form") |> List.first(),
        else: post_id

    post = Timeline.get_post!(post_id)
    post_key = get_post_key(post, current_user)

    images =
      Enum.map(sources, fn source ->
        file_key = get_file_key_from_remove_event(source)
        ext = get_ext_from_file_key(source)
        file_path = "#{@folder}/#{file_key}.#{ext}"

        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: e_obj}} ->
            decrypt_image_for_trix(e_obj, current_user, post_key, key, post, "body", ext)

          {:error, error} ->
            Logger.info("Error getting Post images from cloud in TimelineLive.Index")
            Logger.debug(inspect(error))
            Logger.error(error)
            nil
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

  def handle_event(
        "decrypt_reply_images",
        %{"sources" => sources, "reply_id" => reply_id} = _params,
        socket
      ) do
    memories_bucket = Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    reply = Timeline.get_reply!(reply_id)
    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post, current_user)

    images =
      Enum.map(sources, fn source ->
        file_key = get_file_key_from_remove_event(source)
        ext = get_ext_from_file_key(source)
        file_path = "#{@folder}/#{file_key}.#{ext}"

        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: e_obj}} ->
            decrypt_image_for_trix(e_obj, current_user, post_key, key, reply, "body", ext)

          {:error, error} ->
            Logger.info("Error getting Reply images from cloud in TimelineLive.Index")
            Logger.debug(inspect(error))
            Logger.error(error)
            nil
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

  def handle_event(
        "add_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"
    image_urls = socket.assigns.image_urls

    {:reply, %{response: "success"},
     assign(socket, :image_urls, [file_path | image_urls] |> Enum.uniq())}
  end

  def handle_event(
        "remove_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key_from_remove_event(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"
    image_urls = socket.assigns.image_urls

    updated_urls = Enum.reject(image_urls, fn url -> url == file_path end)

    {:reply, %{response: "success"}, assign(socket, :image_urls, updated_urls)}
  end

  @doc """
  We only generate a signed_url if the post's url has expired. We then
  send the presigned_url back to the client.
  """
  def handle_event("generate_signed_urls", %{"src_list" => src_list}, socket) do
    presigned_url_list =
      Enum.map(src_list, fn src ->
        file_key_with_ext = get_file_key_with_ext(src)

        file_path = get_file_path_for_s3(file_key_with_ext)

        case generate_presigned_url(:get, file_path) do
          {:ok, presigned_url} ->
            presigned_url

          _error ->
            "error"
        end
      end)

    if "error" in presigned_url_list do
      {:reply, %{response: "failed"}, socket}
    else
      {:reply, %{response: "success", presigned_url_list: presigned_url_list}, socket}
    end
  end

  # This event comes in from the client side and updates the body of a post
  # to store the updated presigned_urls for any images.
  #
  # The body, username, and avatar_url are all stored encrypted. So, we need
  # to decrypt the username and avatar_url before updating the post (the
  # body is being sent to use from the client already decrypted).

  def handle_event("update_post_body", %{"body" => body, "id" => id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    post = Timeline.get_post!(id)

    # Trim any added \n characters from the client html
    body =
      if body && is_list(body), do: List.to_string(body) |> String.trim(), else: String.trim(body)

    socket =
      socket
      |> assign(:post_image_processing, AsyncResult.loading())
      |> start_async(:update_post_body, fn ->
        update_post_body(post, body, current_user, key)
      end)

    {:noreply, socket}
  end

  def handle_event("update_reply_body", %{"body" => body, "id" => id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    reply = Timeline.get_reply!(id)

    # Trim any added \n characters from the client html
    body =
      if body && is_list(body), do: List.to_string(body) |> String.trim(), else: String.trim(body)

    socket =
      socket
      |> assign(:reply_image_processing, AsyncResult.loading())
      |> start_async(:update_reply_body, fn ->
        update_reply_body(reply, body, current_user, key)
      end)

    {:noreply, socket}
  end

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in PostLive.Show")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  def handle_async(:update_post_body, {:ok, {message, _post}}, socket) do
    socket =
      socket
      |> put_flash(:info, "Update post body successful!")
      |> assign(:post_image_processing, AsyncResult.ok(message))

    if message === "updated" do
      {:noreply,
       push_event(socket, "update-post-body-complete", %{
         response: "success",
         message: message
       })}
    else
      {:noreply,
       push_event(socket, "update-post-body-complete", %{
         response: "failed",
         message: message
       })}
    end
  end

  def handle_async(:update_post_body, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, :post_image_processing, AsyncResult.failed(%AsyncResult{}, {:exit, reason}))}
  end

  def handle_async(:update_reply_body, {:ok, {message, _post}}, socket) do
    socket =
      socket
      |> put_flash(:info, "Update reply body successful!")
      |> assign(:reply_image_processing, AsyncResult.ok(message))

    if message === "updated" do
      {:noreply,
       push_event(socket, "update-reply-body-complete", %{
         response: "success",
         message: message
       })}
    else
      {:noreply,
       push_event(socket, "update-reply-body-complete", %{
         response: "failed",
         message: message
       })}
    end
  end

  def handle_async(:update_reply_body, {:exit, reason}, socket) do
    {:noreply,
     assign(socket, :reply_image_processing, AsyncResult.failed(%AsyncResult{}, {:exit, reason}))}
  end

  def handle_async(:delete_post_from_cloud, {:ok, message}, socket) do
    %{delete_post_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> assign(:delete_post_from_cloud_message, AsyncResult.ok(del_message, message))

    # we navigate away after replies have finished deleting.
    {:noreply, socket}
  end

  def handle_async(:delete_post_from_cloud, {:exit, reason}, socket) do
    %{delete_post_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(:warning, "Post image(s) could not be deleted from cloud: #{inspect(reason)}")

    {:noreply,
     assign(
       socket,
       :delete_post_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

  def handle_async(:delete_reply_from_cloud, {:ok, message}, socket) do
    post = Timeline.get_post(socket.assigns[:post].id)

    # If we are able to fetch a post from the db, then the post wasn't
    # deleted and we don't want to redirect away from the page.
    if post do
      socket =
        socket
        |> clear_flash(:info)
        |> put_flash(:info, "Reply image(s) deleted from cloud successfully.")

      {:noreply, assign(socket, :delete_reply_from_cloud_message, AsyncResult.ok(message))}
    else
      # Post was deleted and we redirect from the page after deleting
      # the replies from the cloud.
      socket =
        socket
        |> assign(:delete_reply_from_cloud_message, AsyncResult.ok(message))

      {:noreply, push_navigate(socket, to: ~p"/app/timeline")}
    end
  end

  def handle_async(:delete_reply_from_cloud, {:exit, reason}, socket) do
    %{delete_reply_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(:warning, "Reply image(s) could not be deleted from cloud: #{inspect(reason)}")

    {:noreply,
     assign(
       socket,
       :delete_reply_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

  defp page_title(:show), do: "Show Post"
  defp page_title(:edit), do: "Edit Post"
  defp page_title(:reply_edit), do: "Edit Reply"
  defp page_title(:reply), do: "New Reply"

  defp update_post_body(post, body, current_user, key) do
    # We have to decrypt the username, and avatar url (if it exists)
    # we already have the decrypted new body html in `body` and
    # just have to update the post with these options (I think *fingers crossed*)
    post_key = get_post_key(post, current_user)

    username =
      decr_item(
        post.username,
        current_user,
        post_key,
        key,
        post,
        "username"
      )

    avatar_url =
      if post.avatar_url do
        decr_item(
          post.avatar_url,
          current_user,
          post_key,
          key,
          post,
          "body"
        )
      end

    post_params =
      if avatar_url do
        %{
          "username" => username,
          "body" => body,
          "avatar_url" => avatar_url,
          "visibility" => post.visibility,
          "group_id" => post.group_id,
          "image_urls_updated_at" => NaiveDateTime.utc_now()
        }
      else
        %{
          "username" => username,
          "body" => body,
          "visibility" => post.visibility,
          "group_id" => post.group_id,
          "image_urls_updated_at" => NaiveDateTime.utc_now()
        }
      end

    case Timeline.update_post(post, post_params,
           update_post: true,
           post_key: post_key,
           user: current_user,
           key: key
         ) do
      {:ok, post} ->
        {"updated", post}

      {:error, error} ->
        {"error", error}
    end
  end

  defp update_reply_body(reply, body, current_user, key) do
    # We have to decrypt the username, and avatar url (if it exists)
    # we already have the decrypted new body html in `body` and
    # just have to update the post with these options (I think *fingers crossed*)
    post = Timeline.get_post!(reply.post_id)
    post_key = get_post_key(post, current_user)

    username =
      decr_item(
        reply.username,
        current_user,
        post_key,
        key,
        reply,
        "username"
      )

    reply_params =
      %{
        "username" => username,
        "body" => body,
        "visibility" => reply.visibility,
        "post_id" => reply.post_id,
        "user_id" => reply.user_id,
        "image_urls_updated_at" => NaiveDateTime.utc_now()
      }

    case Timeline.update_reply(reply, reply_params,
           update_reply: true,
           encrypt_reply: true,
           visibility: reply.visibility,
           post_key: post_key,
           group_id: nil,
           user: current_user,
           key: key
         ) do
      {:ok, reply} ->
        {"updated", reply}

      {:error, error} ->
        {"error", error}
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

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  defp get_file_key_from_remove_event(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split(".")
    |> List.first()
  end

  defp ext(content_type) do
    [ext | _] = MIME.extensions(content_type)
    ext
  end

  defp delete_post_from_cloud(post, user_post, current_user, key) when is_struct(post) do
    # we only want to delete the images if the post is not a repost
    # and if the post contains image urls
    if !post.repost && is_list(post.image_urls) do
      d_image_urls =
        Enum.map(post.image_urls, fn e_image_url ->
          # decrypt the image url
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
          Logger.info("Error deleting Post images from the cloud in PostLive.Show context.")

          Logger.info(inspect(rest))
          Logger.error(rest)
          {:error, "There was an error deleting Post data from the cloud."}
      end
    else
      :ok
    end
  end

  defp delete_post_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_reply_from_cloud(reply, user_post, current_user, key) when is_struct(reply) do
    # we only want to delete the images if the reply contains image_urls
    if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
      d_image_urls =
        Enum.map(reply.image_urls, fn e_image_url ->
          # decrypt the image url
          decr_item(
            e_image_url,
            current_user,
            user_post.key,
            key,
            reply,
            "body"
          )
        end)

      case delete_object_storage_reply_worker(%{"urls" => d_image_urls}) do
        {:ok, %Oban.Job{conflict?: false} = _oban_job} ->
          :ok

        rest ->
          Logger.info("Error deleting Reply images from the cloud in PostLive.Show context.")

          Logger.info(inspect(rest))
          Logger.error(rest)
          {:error, "There was an error deleting Reply data from the cloud."}
      end
    else
      :ok
    end
  end

  defp delete_reply_from_cloud(nil, _user_post, _current_user, _key), do: :ok

  defp delete_replies_from_cloud(replies, user_post, current_user, key) when is_list(replies) do
    # we only want to delete the images if the reply contains image_urls
    for reply <- replies do
      if is_list(reply.image_urls) && !Enum.empty?(reply.image_urls) do
        d_image_urls =
          Enum.map(reply.image_urls, fn e_image_url ->
            # decrypt the image url
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
            Logger.info("Error deleting Reply images from the cloud in PostLive.Show context.")

            Logger.info(inspect(rest))
            Logger.error(rest)
            {:error, "There was an error deleting Reply data from the cloud."}
        end
      else
        :ok
      end
    end
  end

  defp delete_object_storage_post_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStoragePostWorker.new()
    |> Oban.insert()
  end

  defp delete_object_storage_reply_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStorageReplyWorker.new()
    |> Oban.insert()
  end
end
