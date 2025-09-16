defmodule MossletWeb.TimelineLive.Index do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  import MossletWeb.TimelineLive.Components

  alias Phoenix.LiveView.AsyncResult
  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  @post_page_default 1
  @post_per_page_default 25
  @folder "uploads/trix"

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    changeset =
      Timeline.change_post(%Post{}, %{}, user: current_user)

    socket =
      socket
      |> assign(:post_form, to_form(changeset))
      |> assign(:user_list, [])
      |> assign(:selector, "private")
      |> assign(:post_loading_count, 0)
      |> assign(:post_loading, false)
      |> assign(:post_loading_done, false)
      |> assign(:post_finished_loading_list, [])
      |> assign(:image_urls, [])
      |> assign(:delete_post_from_cloud_message, nil)
      |> assign(:delete_reply_from_cloud_message, nil)
      |> assign(:uploads_in_progress, false)
      |> stream(:posts, [])

    {:ok, assign(socket, page_title: "Timeline")}
  end

  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Accounts.subscribe_account_deleted()
      Timeline.private_subscribe(current_user)
      Timeline.private_reply_subscribe(current_user)
      Timeline.connections_subscribe(current_user)
      Timeline.connections_reply_subscribe(current_user)
    end

    post_sort_by = valid_sort_by(params)
    post_sort_order = valid_sort_order(params)

    post_page = param_to_integer(params["post_page"], @post_page_default)

    post_per_page =
      param_to_integer(
        params["post_per_page"] || params["filter"]["post_per_page"],
        @post_per_page_default
      )
      |> limit_post_per_page()

    filter = %{
      user_id: params["user_id"] || params["filter"]["user_id"] || "",
      post_per_page: post_per_page
    }

    options = %{
      filter: filter,
      post_sort_by: post_sort_by,
      post_sort_order: post_sort_order,
      post_page: post_page,
      post_per_page: post_per_page,
      current_user_id: current_user.id
    }

    # create the return_url with memory and post pagination options
    url = construct_return_url(options)

    posts = Timeline.filter_timeline_posts(current_user, options)
    post_loading_list = Enum.with_index(posts, fn element, index -> {index, element} end)

    socket =
      socket
      |> assign(
        :post_shared_users,
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          key,
          :post
        )
      )
      |> assign(:post_loading_list, post_loading_list)
      |> assign(:post_count, Timeline.timeline_post_count(current_user, options))
      |> assign(:options, options)
      |> assign(:return_url, url)
      |> assign(:filter, filter)
      |> stream(:posts, posts, reset: true)

    {:noreply, socket}
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({_ref, {"get_user_avatar", post_id, post_list, _user_id}}, socket) do
    post_loading_count = socket.assigns.post_loading_count
    post_finished_loading_list = socket.assigns.post_finished_loading_list

    cond do
      post_loading_count < Enum.count(post_list) - 1 ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(:post_loading_count, post_loading_count + 1)
          |> assign(
            :post_finished_loading_list,
            [post_id | post_finished_loading_list] |> Enum.uniq()
          )

        post = Timeline.get_post!(post_id)

        {:noreply, stream_insert(socket, :posts, post, at: -1)}

      post_loading_count == Enum.count(post_list) - 1 ->
        post_finished_loading_list = [post_id | post_finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:post_loading, false)
          |> assign(
            :post_finished_loading_list,
            [post_id | post_finished_loading_list] |> Enum.uniq()
          )

        if Enum.count(post_finished_loading_list) == Enum.count(post_list) do
          post = Timeline.get_post!(post_id)

          socket =
            socket
            |> assign(:post_loading_count, 0)
            |> assign(:post_loading, false)
            |> assign(:post_loading_done, true)
            |> assign(:post_finished_loading_list, [])

          {:noreply, stream_insert(socket, :posts, post, at: -1)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:post_loading, true)
          |> assign(
            :post_finished_loading_list,
            [post_id | post_finished_loading_list] |> Enum.uniq()
          )

        {:noreply, socket}
    end
  end

  def handle_info({:reply_created, _post, reply}, socket) do
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url

    if current_user.id == reply.user_id do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: return_url)}
    end
  end

  def handle_info({:reply_updated, _post, _reply}, socket) do
    return_url = socket.assigns.return_url

    {:noreply, push_patch(socket, to: return_url)}
  end

  def handle_info({:reply_deleted, _post, _reply}, socket) do
    return_url = socket.assigns.return_url

    {:noreply, push_patch(socket, to: return_url)}
  end

  def handle_info({:post_created, post}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    if post.user_id == current_user.id do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: return_url)}
    end
  end

  def handle_info({:post_updated, _post}, socket) do
    return_url = socket.assigns.return_url

    {:noreply, socket |> push_patch(to: return_url)}
  end

  def handle_info({:post_updated_fav, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:post_deleted, post}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    if post.user_id == current_user.id do
      {:noreply, socket}
    else
      {:noreply, socket |> stream_delete(:posts, post) |> push_patch(to: return_url)}
    end
  end

  def handle_info({:post_reposted, post}, socket) do
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url

    if current_user.id == post.user_id do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> stream_insert(:posts, post, at: 0)
       |> push_patch(to: return_url)}
    end
  end

  def handle_info({:repost_deleted, post}, socket) do
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url
    # this is handling the broadcasted message
    # so it will be a different user than the current user
    # if the post is not deleted directly by the current user
    if current_user.id == post.user_id do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> stream_delete(:posts, post)
       |> push_patch(to: return_url)}
    end
  end

  def handle_info({:memory_created, _memory}, socket) do
    return_url = socket.assigns.return_url

    {:noreply, socket |> push_patch(to: return_url)}
  end

  def handle_info({:memory_deleted, memory}, socket) do
    socket =
      socket
      |> stream_delete(:memories, memory)

    {:noreply, socket}
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    cond do
      uconn.user_id == current_user.id && uconn.confirmed_at ->
        {:noreply, socket |> push_patch(to: return_url)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_deleted, uconn}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    cond do
      uconn.user_id == current_user.id && uconn.confirmed_at ->
        {:noreply, socket |> push_patch(to: return_url)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_confirmed, uconn}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    cond do
      uconn.user_id == current_user.id && uconn.confirmed_at ->
        {:noreply, socket |> push_patch(to: return_url)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:post_deleted_from_cloud, {_image_url, user_id}}, socket) do
    return_url = socket.assigns.return_url
    current_user = socket.assigns.current_user

    if current_user.id == user_id do
      {:noreply,
       socket
       |> put_flash(:success, "Post image deleted from cloud successfully.")
       |> push_patch(to: return_url)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("filter", %{"user_id" => user_id}, socket) do
    filter = socket.assigns.filter
    params = %{filter | user_id: user_id}
    {:noreply, push_patch(socket, to: ~p"/app/timeline?#{params}")}
  end

  def handle_event("filter", %{"post_per_page" => post_per_page}, socket) do
    filter = socket.assigns.filter
    params = %{filter | post_per_page: post_per_page}
    {:noreply, push_patch(socket, to: ~p"/app/timeline?#{params}")}
  end

  def handle_event("validate_post", %{"post" => post_params} = _params, socket) do
    post_shared_users = socket.assigns.post_shared_users
    current_user = socket.assigns.current_user

    post_params =
      post_params
      |> Map.put("image_urls", socket.assigns.image_urls)
      |> add_shared_users_list_for_new_post(post_shared_users)

    changeset = Timeline.change_post(%Post{}, post_params, user: current_user)

    socket =
      socket
      |> assign(:post_form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("uploads_in_progress", %{"flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("file_too_large", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("nsfw", %{"message" => message, "flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)
      |> put_flash(:warning, message)

    {:noreply, socket}
  end

  def handle_event("remove_files", %{"flag" => flag}, socket) do
    socket =
      socket
      |> clear_flash(:warning)
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("error_uploading", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event(
        "error_removing",
        %{"message" => message, "url" => url, "flag" => flag},
        socket
      ) do
    Logger.error("Error removing Trix image in TimelineLive.Index")
    Logger.debug(inspect(url))
    Logger.error("Error removing Trix image in TimelineLive.Index: #{url}")
    socket = assign(socket, :uploads_in_progress, flag)

    {:noreply, put_flash(socket, :warning, message)}
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

    socket =
      socket
      |> assign(:image_urls, [file_path | image_urls] |> Enum.uniq())

    {:reply, %{response: "success"}, socket}
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

  def handle_event("toggle-read", %{"id" => user_post_receipt_id}, socket) do
    Timeline.update_user_post_receipt_read(user_post_receipt_id)
    {:noreply, socket}
  end

  def handle_event("toggle-unread", %{"id" => user_post_receipt_id}, socket) do
    Timeline.update_user_post_receipt_unread(user_post_receipt_id)
    {:noreply, socket}
  end

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in TimelineLive.Index")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  def handle_event("save_post", %{"post" => post_params}, socket) do
    if connected?(socket) do
      post_shared_users = socket.assigns.post_shared_users

      post_params =
        post_params
        |> Map.put("image_urls", socket.assigns.image_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())
        |> add_shared_users_list_for_new_post(post_shared_users)

      current_user = socket.assigns.current_user
      key = socket.assigns.key
      trix_key = socket.assigns[:trix_key]

      if post_params["user_id"] == current_user.id do
        case Timeline.create_post(post_params, user: current_user, key: key, trix_key: trix_key) do
          {:ok, _post} ->
            socket =
              socket
              |> assign(:trix_key, nil)
              |> assign(
                :post_form,
                to_form(Timeline.change_post(%Post{}, %{}, user: current_user))
              )
              |> assign(:image_urls, [])
              |> put_flash(:success, "Post created successfully")
              |> push_navigate(to: socket.assigns.return_url)

            {:noreply, socket}

          {:error, changeset} ->
            socket =
              socket
              |> assign(:post_form, to_form(changeset, action: :validate))
              |> put_flash(:error, "#{changeset.message}")
              |> push_patch(to: socket.assigns.return_url)

            {:noreply, socket}
        end
      else
        {:noreply,
         socket
         |> put_flash(:warning, "You do not have permission to create this post.")
         |> push_patch(to: socket.assigns.return_url)}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "You are not connected to the internet. Please refresh your page and try again."
       )
       |> push_patch(to: socket.assigns.return_url)}
    end
  end

  def handle_event("new_post", _params, socket) do
    post_shared_users = socket.assigns.post_shared_users

    socket =
      socket
      |> assign(:live_action, :new_post)
      |> assign(:post_shared_users, post_shared_users)
      |> assign(:post, %Post{})

    {:noreply, socket}
  end

  def handle_event("live_select_change", %{"id" => id, "text" => text}, socket) do
    if id == "group-select" do
      options =
        if text == "" do
          socket.assigns.group_list
        else
          socket.assigns.group_list
          |> Enum.filter(&(String.downcase(&1[:key]) |> String.contains?(String.downcase(text))))
        end

      send_update(LiveSelect.Component, options: options, id: id)

      {:noreply, socket}
    else
      # work with embedded SharedUser schema for LiveSelect
      options =
        socket.assigns.shared_users
        |> Enum.filter(&(String.downcase(&1.username) |> String.contains?(String.downcase(text))))
        |> Enum.map(&value_mapper/1)

      send_update(LiveSelect.Component, options: options, id: id)

      {:noreply, socket}
    end
  end

  def handle_event("set-user-default", %{"id" => id}, socket) do
    options =
      socket.assigns.shared_users
      |> Enum.map(&value_mapper/1)

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_event("set-user-default", %{"id" => id, "text" => text}, socket) do
    options =
      if text == "" do
        socket.assigns.shared_users
      else
        socket.assigns.shared_users
        |> Enum.filter(&(String.downcase(&1[:label]) |> String.contains?(String.downcase(text))))
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  def handle_event("fav", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user

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
    current_user = socket.assigns.current_user

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
    post_shared_users = socket.assigns.post_shared_users
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
          image_urls: decrypt_image_urls_for_repost(post, user, key),
          image_urls_updated_at: post.image_urls_updated_at,
          shared_users: [%{}],
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

  def handle_event("edit_post", %{"id" => id, "url" => return_url}, socket) do
    # we assign the post to be editted to a new variable
    # to not interrupt the new_post_form
    post = Timeline.get_post!(id)

    socket =
      socket
      |> assign(:live_action, :edit_post)
      |> assign(:return_url, return_url)
      |> assign(:post, post)
      |> assign(:image_urls, if(post.image_urls, do: post.image_urls, else: []))

    {:noreply, socket}
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    return_url = socket.assigns.return_url
    key = socket.assigns.key

    if post.user_id == current_user.id do
      user_post = Timeline.get_user_post(post, current_user)
      replies = post.replies

      case Timeline.delete_post(post, user: current_user) do
        {:ok, post} ->
          socket =
            socket
            |> put_flash(:success, "Post deleted successfully.")
            |> assign(:delete_post_from_cloud_message, AsyncResult.loading())
            |> assign(:image_urls, [])
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

          {:noreply, push_patch(socket, to: return_url)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You are not authorized to delete this post.")}
    end
  end

  def handle_event("reply", %{"id" => id, "url" => return_url}, socket) do
    post = Timeline.get_post!(id)

    socket =
      socket
      |> assign(:live_action, :reply)
      |> assign(:return_url, return_url)
      |> assign(:post, post)
      |> assign(:reply, %Reply{})
      |> assign(:image_urls, [])

    {:noreply, socket}
  end

  def handle_event("edit_reply", %{"id" => id, "url" => return_url}, socket) do
    reply = Timeline.get_reply!(id)

    socket =
      socket
      |> assign(:live_action, :reply_edit)
      |> assign(:return_url, return_url)
      |> assign(:post, reply.post)
      |> assign(:reply, reply)
      |> assign(:image_urls, if(reply.image_urls, do: reply.image_urls, else: []))

    {:noreply, socket}
  end

  def handle_event("delete_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # The creator of the post can delete any replies for it.
    # this gives them the ability to moderate replies to their posts
    if current_user.id == reply.user_id || current_user.id == reply.post.user_id do
      post = Timeline.get_post!(reply.post_id)
      user_post = Timeline.get_user_post(post, current_user)

      case Timeline.delete_reply(reply, user: current_user) do
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
                  current_user,
                  key
                )
              end
            )

          {:noreply, push_patch(socket, to: socket.assigns.return_url)}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply, put_flash(socket, :warning, "You do not have permission to delete this Reply.")}
    end
  end

  def handle_event(
        "delete_user_post",
        %{"post-id" => post_id, "user-id" => user_id, "shared-username" => shared_username},
        socket
      ) do
    current_user = socket.assigns.current_user
    # delete the user_post for the shared_with user
    user_post = Timeline.get_user_post_by_post_id_and_user_id!(post_id, user_id)

    Timeline.delete_user_post(user_post,
      user: current_user,
      shared_username: shared_username
    )

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

    {:noreply,
     assign(socket, :delete_post_from_cloud_message, AsyncResult.ok(del_message, message))}
  end

  def handle_async(:delete_post_from_cloud, {:exit, reason}, socket) do
    %{delete_post_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(
        :warning,
        "Post image(s) could not be deleted from cloud: #{inspect(reason)}"
      )

    {:noreply,
     assign(
       socket,
       :delete_post_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

  def handle_async(:delete_reply_from_cloud, {:ok, message}, socket) do
    {:noreply, assign(socket, :delete_reply_from_cloud_message, AsyncResult.ok(message))}
  end

  def handle_async(:delete_reply_from_cloud, {:exit, reason}, socket) do
    %{delete_reply_from_cloud_message: del_message} = socket.assigns

    socket =
      socket
      |> clear_flash(:warning)
      |> put_flash(
        :warning,
        "Reply image(s) could not be deleted from cloud: #{inspect(reason)}"
      )

    {:noreply,
     assign(
       socket,
       :delete_reply_from_cloud_message,
       AsyncResult.failed(del_message, {:exit, reason})
     )}
  end

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
          Logger.info("Error deleting Post images from the cloud in TimelineLive.Index context.")
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
          Logger.info("Error deleting Reply images from the cloud in TimelineLive.Index context.")
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
            Logger.info(
              "Error deleting Reply images from the cloud in TimelineLive.Index context."
            )

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

  defp delete_object_storage_reply_worker(params) do
    params
    |> Mosslet.Workers.DeleteObjectStorageReplyWorker.new()
    |> Oban.insert()
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

  defp add_shared_users_list_for_new_post(post_params, shared_users) do
    Map.update(
      post_params,
      "shared_users",
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

  defp value_mapper(%Post.SharedUser{username: username} = value) do
    %{label: username, value: value}
  end

  defp value_mapper(value) do
    {:ok, value} = Jason.decode(value)

    %{
      label: value["username"],
      value: %Post.SharedUser{
        id: value["id"],
        sender_id: value["sender_id"],
        user_id: value["user_id"],
        username: value["username"]
      }
    }
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id inserted_at) do
    String.to_atom(sort_by)
  end

  defp valid_sort_by(%{"post_sort_by" => sort_by})
       when sort_by in ~w(id inserted_at) do
    String.to_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

  defp valid_sort_order(%{"sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_atom(sort_order)
  end

  defp valid_sort_order(%{"post_sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_atom(sort_order)
  end

  defp valid_sort_order(_params), do: :desc

  defp param_to_integer(nil, default), do: default

  defp param_to_integer(param, default) do
    case Integer.parse(param) do
      {number, _} -> number
      :error -> default
    end
  end

  defp limit_post_per_page(per_page) when is_integer(per_page) do
    if per_page > 50, do: 4, else: per_page
  end

  defp construct_return_url(options) do
    if options.post_page == @post_page_default &&
         options.post_per_page == @post_per_page_default && options.filter.user_id == "" &&
         options.filter.post_per_page == @post_per_page_default,
       do: ~p"/app/timeline",
       else: ~p"/app/timeline?#{options}"
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
end
