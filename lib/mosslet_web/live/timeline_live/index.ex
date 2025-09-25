defmodule MossletWeb.TimelineLive.Index do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  # import MossletWeb.TimelineLive.Components
  import MossletWeb.Helpers

  alias Phoenix.LiveView.AsyncResult
  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply}

  @post_page_default 1
  @post_per_page_default 10
  @folder "uploads/trix"

  def mount(_params, session, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    initial_selector = "private"

    # Store the user token from session for later use in uploads
    user_token = session["user_token"]

    # Create changeset with all required fields populated
    changeset =
      Timeline.change_post(
        %Post{},
        %{
          "visibility" => initial_selector,
          "user_id" => current_user.id,
          "username" => user_name(current_user, key) || ""
        },
        user: current_user
      )

    socket =
      socket
      |> assign(:post_form, to_form(changeset))
      |> assign(:user_list, [])
      # Keep selector in sync with form
      |> assign(:selector, initial_selector)
      |> assign(:post_loading_count, 0)
      |> assign(:post_loading, false)
      |> assign(:post_loading_done, false)
      |> assign(:post_finished_loading_list, [])
      |> assign(:image_urls, [])
      |> assign(:delete_post_from_cloud_message, nil)
      |> assign(:delete_reply_from_cloud_message, nil)
      |> assign(:uploads_in_progress, false)
      |> assign(:active_tab, "home")
      |> assign(:timeline_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0})
      |> assign(:unread_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0})
      |> assign(:loaded_posts_count, 0)
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      # Store user token for uploads
      |> assign(:user_token, user_token)
      # Content warning state
      |> assign(:content_warning_enabled, false)
      |> assign(:content_warning_text, "")
      |> assign(:content_warning_category, "")
      # Content warning system state
      |> assign(:content_warning_enabled, false)
      |> assign(:content_warning_text, "")
      |> assign(:content_warning_category, nil)
      |> stream(:posts, [])
      # Configure photo uploads with proper constraints and encryption-ready settings
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png),
        max_entries: 4,
        # 10MB to accommodate modern phone photos
        max_file_size: 10_000_000,
        # 64KB chunks for smooth progress
        chunk_size: 64_000,
        # Upload immediately when selected
        auto_upload: true
      )

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
      # Subscribe to public posts for discover tab realtime updates
      Timeline.subscribe()
      Timeline.reply_subscribe()
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

    # Get the current active tab from socket assigns or default to "home"
    current_tab = socket.assigns[:active_tab] || "home"

    # Load posts for the current active tab
    posts =
      case current_tab do
        "discover" ->
          # Show public posts using dedicated Timeline function for discovery
          Timeline.list_discover_posts(options.post_per_page, 0, current_user)

        "connections" ->
          # Use dedicated Timeline function for connections
          Timeline.list_connection_posts(current_user, options)

        "home" ->
          # Use dedicated Timeline function for user's own posts
          Timeline.list_user_own_posts(current_user, options)

        _ ->
          # Use the helper function for other tabs (groups, bookmarks)
          # Pass tab information to caching system
          options_with_tab = Map.put(options, :tab, current_tab)

          Timeline.filter_timeline_posts(current_user, options_with_tab)
          |> apply_tab_filtering(current_tab, current_user)
      end

    post_loading_list = Enum.with_index(posts, fn element, index -> {index, element} end)

    # Calculate timeline counts for tabs using the new helper function
    timeline_counts = calculate_timeline_counts(current_user, options)
    unread_counts = calculate_unread_counts(current_user, options)

    # Track pagination state for load more functionality
    loaded_posts_count = length(posts)
    current_page = options.post_page

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
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:loaded_posts_count, loaded_posts_count)
      |> assign(:current_page, current_page)
      |> assign(:load_more_loading, false)
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

  def handle_info({:create_reply, reply_params, post_id, visibility}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Timeline.get_post(post_id) do
      %Mosslet.Timeline.Post{} = post ->
        # Extract the post_key for encryption
        post_key = get_post_key(post, current_user)

        # Create the reply using existing Timeline functions
        case Timeline.create_reply(reply_params,
               user: current_user,
               key: key,
               post: post,
               post_key: post_key,
               visibility: visibility
             ) do
          {:ok, _reply} ->
            # Update the post with new reply count in the stream
            # Get fresh post with updated reply count
            updated_post = Timeline.get_post(post_id)

            socket =
              socket
              |> put_flash(:success, "Reply posted successfully!")
              |> stream_insert(:posts, updated_post)
              |> push_event("hide-reply-composer", %{post_id: post_id})

            {:noreply, socket}

          {:error, changeset} ->
            # Update the specific reply composer with validation errors
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
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options

    # Debug logging
    require Logger
    Logger.info("🎯 POST CREATED: #{post.id} by user #{post.user_id}")
    Logger.info("   Current tab: #{current_tab}, Current user: #{current_user.id}")

    # Check if this post should appear in the current tab
    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    Logger.info("   Should show post: #{should_show_post}")

    if should_show_post do
      Logger.info("   Adding post to stream with animations...")
      # Add the new post to the top of the stream - CSS animations will trigger automatically
      socket =
        socket
        |> stream_insert(:posts, post, at: 0)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_new_post_notification(post, current_user)

      {:noreply, socket}
    else
      Logger.info("   Post doesn't match current tab, updating counts only")
      # Post doesn't match current tab, but still update counts
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_subtle_tab_indicator(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:post_updated, _post}, socket) do
    return_url = socket.assigns.return_url

    {:noreply, socket |> push_patch(to: return_url)}
  end

  def handle_info({:post_updated_fav, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:reply_updated_fav, post, _reply}, socket) do
    # When a reply is favorited, we need to update the post that contains it
    # so the reply thread reflects the new favorite state
    {:noreply, socket |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:reply_created, post, reply}, socket) do
    # When a new reply (including nested replies) is created, update the post
    # This handles both top-level and nested reply creation
    current_user = socket.assigns.current_user

    # Only update if this isn't the user's own reply to prevent double updates
    if reply.user_id != current_user.id do
      # Get the updated post with the new nested reply structure
      updated_post = Timeline.get_post!(post.id)
      {:noreply, socket |> stream_insert(:posts, updated_post, at: -1)}
    else
      {:noreply, socket}
    end
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

  def handle_info({:nested_reply_created, post_id, parent_reply_id}, socket) do
    # Update the post stream to reflect the new nested reply
    updated_post = Timeline.get_post!(post_id)

    socket =
      socket
      |> put_flash(:success, "Reply posted!")
      |> stream_insert(:posts, updated_post, at: -1)
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

  # Note: Since we moved to JS.toggle for nested reply composers,
  # the reply_to_reply event handler is no longer needed - the composer
  # is toggled client-side just like the main reply composer

  def handle_info({:nested_reply_created, post_id, parent_reply_id}, socket) do
    # Update the post stream to reflect the new nested reply
    updated_post = Timeline.get_post!(post_id)

    socket =
      socket
      |> put_flash(:success, "Reply posted!")
      |> stream_insert(:posts, updated_post, at: -1)
      |> push_event("hide-nested-composer", %{reply_id: parent_reply_id})

    {:noreply, socket}
  end

  def handle_info({:nested_reply_error, error_message}, socket) do
    {:noreply, put_flash(socket, :error, error_message)}
  end

  def handle_info({:nested_reply_cancelled, parent_reply_id}, socket) do
    socket =
      socket
      |> push_event("hide-nested-composer", %{reply_id: parent_reply_id})

    {:noreply, socket}
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
    current_form = socket.assigns.post_form
    # Add missing key assignment
    key = socket.assigns.key

    # Get the existing changeset to preserve its state
    existing_changeset = current_form.source

    # If we have an existing changeset, apply the new changes to it
    # Otherwise create a new one with complete data
    updated_changeset =
      if existing_changeset && match?(%Ecto.Changeset{}, existing_changeset) do
        # Apply new changes to existing changeset while preserving all existing data
        existing_changeset
        |> Ecto.Changeset.cast(post_params, [
          :body,
          :content_warning,
          :content_warning_category,
          :allow_replies,
          :allow_shares,
          :allow_bookmarks
        ])
        |> Ecto.Changeset.put_change(:visibility, socket.assigns.selector)
        |> Ecto.Changeset.put_change(:image_urls, socket.assigns.image_urls)
        |> Ecto.Changeset.put_change(:user_id, current_user.id)
        |> Ecto.Changeset.put_change(:username, user_name(current_user, key) || "")
      else
        # Fallback: create new changeset with complete params (preserve everything)
        complete_params =
          (current_form.params || %{})
          |> Map.merge(post_params)
          |> Map.put("image_urls", socket.assigns.image_urls)
          |> Map.put("visibility", socket.assigns.selector)
          |> add_shared_users_list_for_new_post(post_shared_users)

        Timeline.change_post(%Post{}, complete_params, user: current_user)
      end

    socket =
      socket
      |> assign(:post_form, to_form(updated_changeset, action: :validate))

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

  def handle_event("get_post_image_urls", %{"post_id" => post_id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        # Get the encrypted image URLs and decrypt them to get actual S3 paths for decrypt_post_images
        case post.image_urls do
          urls when is_list(urls) and length(urls) > 0 ->
            post_key = get_post_key(post, current_user)

            # Decrypt each URL to get the actual S3 file path for the decrypt_post_images handler
            decrypted_urls =
              Enum.map(urls, fn encrypted_url ->
                decr_item(encrypted_url, current_user, post_key, key, post, "body")
              end)

            Logger.info("📷 GET_POST_IMAGE_URLS: Decrypted S3 paths: #{inspect(decrypted_urls)}")
            {:reply, %{response: "success", image_urls: decrypted_urls}, socket}

          _ ->
            Logger.info("📷 GET_POST_IMAGE_URLS: No image URLs found for post #{post_id}")
            {:reply, %{response: "success", image_urls: []}, socket}
        end

      nil ->
        Logger.error("Post not found: #{post_id}")
        {:reply, %{response: "error", message: "Post not found"}, socket}
    end
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
      Enum.map(sources, fn file_path ->
        # Since we now receive the full file path directly, use it as-is
        Logger.info("📷 DECRYPT_POST_IMAGES: Processing file path: #{file_path}")

        case get_s3_object(memories_bucket, file_path) do
          {:ok, %{body: e_obj}} ->
            # Extract extension from the file path
            ext = Path.extname(file_path) |> String.trim_leading(".")
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

    Logger.info("📷 DECRYPT_POST_IMAGES: Successfully decrypted #{length(images)} images")

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

  def handle_event("toggle-read-status", %{"id" => post_id}, socket) do
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Get the post and its current receipt
    post = Timeline.get_post!(post_id)
    receipt = Timeline.get_user_post_receipt(current_user, post)

    IO.inspect(receipt, label: "USER POST RECEIPT")

    case receipt do
      nil ->
        Logger.info("No receipt exists - creating one and marking as read")
        # No receipt exists - create one and mark as read
        # First, get the user_post for this post and user
        user_post = Timeline.get_user_post(post, current_user)

        if user_post do
          case Timeline.create_or_update_user_post_receipt(user_post, current_user, true) do
            {:ok, _receipt} ->
              # Invalidate timeline cache to ensure fresh data
              Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

              # Get the post with fresh user_post_receipts preloaded
              updated_post =
                Timeline.get_post!(post_id)
                |> Mosslet.Repo.preload([:user_post_receipts], force: true)

              # Recalculate unread counts after toggling read status
              unread_counts = calculate_unread_counts(current_user, options)

              socket =
                socket
                |> stream_insert(:posts, updated_post, at: -1)
                |> assign(:unread_counts, unread_counts)
                |> put_flash(:info, "Post marked as read")

              {:noreply, socket}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to mark post as read")}
          end
        else
          {:noreply, put_flash(socket, :info, "You don't have access to this post")}
        end

      %{is_read?: true} ->
        Logger.info("Receipt exists and is read - marking as unread")
        # Receipt exists and is marked as read - mark as unread
        case Timeline.update_user_post_receipt_unread(receipt.id) do
          {:ok, _conn, _post} ->
            Logger.info("Successfully marked as unread")
            # Invalidate timeline cache to ensure fresh data
            Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

            # Get the post with fresh user_post_receipts preloaded
            updated_post =
              Timeline.get_post!(post_id)
              |> Mosslet.Repo.preload([:user_post_receipts], force: true)

            # Recalculate unread counts after toggling read status
            unread_counts = calculate_unread_counts(current_user, options)

            socket =
              socket
              |> stream_insert(:posts, updated_post, at: -1)
              |> assign(:unread_counts, unread_counts)
              |> put_flash(:info, "Post marked as unread")

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to mark as unread: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to mark post as unread")}
        end

      %{is_read?: false} ->
        Logger.info("Receipt exists and is unread - marking as read")
        # Receipt exists and is marked as unread - mark as read
        case Timeline.update_user_post_receipt_read(receipt.id) do
          {:ok, _conn, _post} ->
            Logger.info("Successfully marked as read")
            # Invalidate timeline cache to ensure fresh data
            Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

            # Get the post with fresh user_post_receipts preloaded
            updated_post =
              Timeline.get_post!(post_id)
              |> Mosslet.Repo.preload([:user_post_receipts], force: true)

            # Recalculate unread counts after toggling read status
            unread_counts = calculate_unread_counts(current_user, options)

            socket =
              socket
              |> stream_insert(:posts, updated_post, at: -1)
              |> assign(:unread_counts, unread_counts)
              |> put_flash(:info, "Post marked as read")

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to mark as read: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to mark post as read")}
        end
    end
  end

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in TimelineLive.Index")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  def handle_event("toggle_privacy_selector", _params, socket) do
    # Cycle through privacy levels: private -> connections -> public -> private
    current_selector = socket.assigns.selector

    new_selector =
      case current_selector do
        "private" -> "connections"
        "connections" -> "public"
        "public" -> "private"
        _ -> "private"
      end

    # Only update the selector assign - don't touch the form!
    # The form will pick up the new selector value during next validation
    {:noreply, assign(socket, :selector, new_selector)}
  end

  def handle_event("composer_add_photo", _params, socket) do
    # Trigger the file input dialog by pushing a JavaScript event
    {:noreply, push_event(socket, "trigger-photo-upload", %{})}
  end

  def handle_event("validate_photos", _params, socket) do
    # Validate uploads - this runs automatically when files are selected
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    # Cancel a specific upload
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    # Remove a photo that has already been uploaded
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("composer_add_emoji", _params, socket) do
    # Handle emoji picker functionality
    # For now, just show a message that this feature is coming
    {:noreply, put_flash(socket, :info, "Emoji picker coming soon!")}
  end

  def handle_event("composer_toggle_content_warning", _params, socket) do
    # Toggle content warning state
    current_state = socket.assigns.content_warning_enabled
    new_state = !current_state
    
    socket = 
      socket
      |> assign(:content_warning_enabled, new_state)
      # Clear content warning data when disabled
      |> assign(:content_warning_text, if(new_state, do: socket.assigns.content_warning_text, else: ""))
      |> assign(:content_warning_category, if(new_state, do: socket.assigns.content_warning_category, else: ""))
    
    {:noreply, socket}
  end

  def handle_event("update_content_warning", %{"content_warning_text" => text}, socket) do
    {:noreply, assign(socket, :content_warning_text, text)}
  end

  def handle_event("update_content_warning_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :content_warning_category, category)}
  end

  def handle_event("save_post", %{"post" => post_params}, socket) do
    if connected?(socket) do
      post_shared_users = socket.assigns.post_shared_users
      current_user = socket.assigns.current_user
      key = socket.assigns.key

      # Debug logging for upload entries
      upload_entries = socket.assigns.uploads.photos.entries
      Logger.info("🔍 SAVE_POST DEBUG: Upload entries count: #{length(upload_entries)}")

      Enum.each(upload_entries, fn entry ->
        Logger.info("   Entry #{entry.ref}: #{entry.client_name} (#{entry.client_type})")
      end)

      # Process uploaded photos and get their URLs with trix_key
      {uploaded_photo_urls, trix_key} =
        process_uploaded_photos(socket, current_user, key)

      post_params =
        post_params
        |> Map.put("image_urls", socket.assigns.image_urls ++ uploaded_photo_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())
        |> Map.put("visibility", socket.assigns.selector)
        |> Map.put("user_id", current_user.id)
        |> add_shared_users_list_for_new_post(post_shared_users)
        |> add_content_warning_data(socket.assigns)

      Logger.info("🔍 SAVE_POST DEBUG: Final image_urls: #{inspect(post_params["image_urls"])}")

      if post_params["user_id"] == current_user.id do
        case Timeline.create_post(post_params, user: current_user, key: key, trix_key: trix_key) do
          {:ok, _post} ->
            socket =
              socket
              |> assign(:trix_key, nil)
              |> assign(
                :post_form,
                to_form(
                  Timeline.change_post(%Post{}, %{"visibility" => socket.assigns.selector},
                    user: current_user
                  )
                )
              )
              |> assign(:image_urls, [])
              |> put_flash(:success, "Post created successfully")
              |> push_navigate(to: socket.assigns.return_url)

            {:noreply, socket}

          {:error, changeset} ->
            socket =
              socket
              |> assign(:post_form, to_form(changeset, action: :validate))
              |> put_flash(:error, "Failed to create post. Please check your input.")
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

  def handle_event("scroll_to_top", _params, socket) do
    {:noreply, push_event(socket, "scroll-to-top", %{})}
  end

  def handle_event("load_more_posts", _params, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    current_options = socket.assigns.options
    current_page = socket.assigns.current_page
    loaded_count = socket.assigns.loaded_posts_count

    # Set loading state
    socket = assign(socket, :load_more_loading, true)

    # Calculate next page parameters
    next_page = current_page + 1
    updated_options = Map.put(current_options, :post_page, next_page)

    # Load more posts for the current tab using pagination
    new_posts =
      case current_tab do
        "discover" ->
          offset = loaded_count
          Timeline.list_discover_posts(current_options.post_per_page, offset, current_user)

        "connections" ->
          Timeline.list_connection_posts(current_user, updated_options)

        "home" ->
          Timeline.list_user_own_posts(current_user, updated_options)

        _ ->
          Timeline.filter_timeline_posts(current_user, updated_options)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Calculate updated counts
    new_loaded_count = loaded_count + length(new_posts)

    # Add new posts to the existing stream (at the end)
    socket =
      new_posts
      |> Enum.reduce(socket, fn post, acc_socket ->
        stream_insert(acc_socket, :posts, post, at: -1)
      end)
      |> assign(:options, updated_options)
      |> assign(:loaded_posts_count, new_loaded_count)
      |> assign(:current_page, next_page)
      |> assign(:load_more_loading, false)

    {:noreply, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user
    # Reset pagination when switching tabs
    options =
      socket.assigns.options
      |> Map.put(:timeline_tab, tab)
      |> Map.put(:post_page, 1)

    # Load posts for the specific tab with proper filtering
    posts =
      case tab do
        "discover" ->
          # Show public posts using dedicated Timeline function for discovery
          Timeline.list_discover_posts(options.post_per_page, 0, current_user)

        "connections" ->
          # Use dedicated Timeline function for connections
          Timeline.list_connection_posts(current_user, options)

        "home" ->
          # Use dedicated Timeline function for user's own posts
          Timeline.list_user_own_posts(current_user, options)

        _ ->
          # Use the helper function for other tabs (groups, bookmarks)
          Timeline.filter_timeline_posts(current_user, options)
          |> apply_tab_filtering(tab, current_user)
      end

    # Update tab counts using proper counting logic
    timeline_counts = calculate_timeline_counts(current_user, options)
    unread_counts = calculate_unread_counts(current_user, options)

    # Reset pagination state when switching tabs
    loaded_posts_count = length(posts)

    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:options, options)
      |> assign(:loaded_posts_count, loaded_posts_count)
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      |> stream(:posts, posts, reset: true)

    {:noreply, socket}
  end

  def handle_event("bookmark_post", %{"id" => post_id}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        # Check if post is already bookmarked using Timeline.bookmarked?
        if Timeline.bookmarked?(current_user, post) do
          # Remove existing bookmark
          bookmark = Timeline.get_bookmark(current_user, post)

          case Timeline.delete_bookmark(bookmark, current_user) do
            {:ok, _} ->
              # Recalculate bookmark count
              timeline_counts = calculate_timeline_counts(current_user, options)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> put_flash(:info, "Bookmark removed sucessfully.")

              # Handle stream updates based on current tab
              socket =
                if current_tab == "bookmarks" do
                  # On bookmarks tab: remove the post from stream since it's no longer bookmarked
                  stream_delete(socket, :posts, post)
                else
                  # On other tabs: update the post with new bookmark status
                  updated_post = Timeline.get_post!(post_id)
                  stream_insert(socket, :posts, updated_post, at: -1)
                end

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to remove bookmark")}
          end
        else
          # Create new bookmark
          case Timeline.create_bookmark(current_user, post, %{}) do
            {:ok, _bookmark} ->
              # Recalculate bookmark count
              timeline_counts = calculate_timeline_counts(current_user, options)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> put_flash(:success, "Post bookmarked successfully.")

              # Handle stream updates based on current tab
              socket =
                if current_tab == "bookmarks" do
                  # On bookmarks tab: add the newly bookmarked post to the top of the stream
                  updated_post = Timeline.get_post!(post_id)
                  stream_insert(socket, :posts, updated_post, at: 0)
                else
                  # On other tabs: update the post with new bookmark status
                  updated_post = Timeline.get_post!(post_id)
                  stream_insert(socket, :posts, updated_post, at: -1)
                end

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
          {:noreply, put_flash(socket, :success, "You loved this post!")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Operation failed. Please try again.")}
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
          {:noreply, put_flash(socket, :success, "You removed love from this post.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to remove love. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("fav_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user

    if current_user.id not in reply.favs_list do
      case Timeline.inc_reply_favs(reply) do
        {:ok, reply} ->
          case Timeline.update_reply_fav(
                 reply,
                 %{favs_list: List.insert_at(reply.favs_list, 0, current_user.id)},
                 user: current_user
               ) do
            {:ok, _reply} ->
              {:noreply, put_flash(socket, :success, "You loved this reply!")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Operation failed. Please try again.")}
          end

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Reply not found. Please try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("unfav_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user

    if current_user.id in reply.favs_list do
      case Timeline.decr_reply_favs(reply) do
        {:ok, reply} ->
          case Timeline.update_reply_fav(
                 reply,
                 %{favs_list: List.delete(reply.favs_list, current_user.id)},
                 user: current_user
               ) do
            {:ok, _reply} ->
              {:noreply, put_flash(socket, :success, "You removed love from this reply.")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to remove love. Please try again.")}
          end

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Reply not found. Please try again.")}
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

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to repost. Please try again.")}
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

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete post. Please try again.")}
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

  # Helper function to apply tab-specific filtering
  defp apply_tab_filtering(posts, tab, current_user) do
    case tab do
      "home" ->
        # Show only posts made BY the current user (private + connections + public)
        Enum.filter(posts, fn post -> post.user_id == current_user.id end)

      "connections" ->
        # Use dedicated Timeline function instead of filtering here
        # This case should not be reached when using the switch_tab event
        Timeline.list_connection_posts(current_user, %{})

      "groups" ->
        # Filter timeline posts to only show posts with group_id
        Enum.filter(posts, fn post -> post.group_id != nil end)

      "bookmarks" ->
        # Get bookmarked posts - need to handle both public and private/connection posts
        bookmarked_posts =
          Timeline.list_user_bookmarks(current_user)
          |> Enum.map(fn bookmark -> bookmark.post end)
          |> Enum.filter(&(&1 != nil))

        # For bookmarked posts, we need to ensure they have proper associations
        # Public posts need user_posts loaded for get_post_key to work
        bookmarked_posts
        |> Enum.map(fn post ->
          if post.visibility == :public do
            # For public posts, preload user_posts association
            Timeline.get_post!(post.id)
          else
            # For private/connection posts, they should already be accessible via user timeline
            post
          end
        end)

      "discover" ->
        # Show public posts using dedicated Timeline function for discovery
        # Note: This should probably use Timeline.list_discover_posts instead
        posts

      _ ->
        posts
    end
  end

  # Helper function to check if a new post should appear in the current tab
  defp post_matches_current_tab?(post, current_tab, current_user) do
    case current_tab do
      "home" ->
        # Home tab shows user's own posts - so their new posts should appear
        post.user_id == current_user.id

      "connections" ->
        # Show posts from connected users, but exclude private posts
        connection_user_ids =
          Accounts.get_all_confirmed_user_connections(current_user.id)
          |> Enum.map(& &1.reverse_user_id)
          |> Enum.uniq()

        post.user_id in connection_user_ids and post.visibility != :private

      "groups" ->
        # Show posts from groups the user belongs to
        post.group_id != nil

      "discover" ->
        # Show public posts
        post.visibility == :public

      "bookmarks" ->
        # Don't auto-add to bookmarks (user has to manually bookmark)
        false

      _ ->
        false
    end
  end

  # Helper function to recalculate counts after a new post arrives
  defp recalculate_counts_after_new_post(socket, current_user, options) do
    timeline_counts = calculate_timeline_counts(current_user, options)
    unread_counts = calculate_unread_counts(current_user, options)

    socket
    |> assign(:timeline_counts, timeline_counts)
    |> assign(:unread_counts, unread_counts)
  end

  # Helper function to add a subtle new post notification
  defp add_new_post_notification(socket, post, current_user) do
    # Get author name safely
    author_name = get_safe_post_author_name(post, current_user, socket.assigns.key)

    # Add a gentle flash message for the new post
    put_flash(socket, :info, "New post from #{author_name}")
  end

  # Safe version of get_post_author_name that returns the author name string
  defp get_safe_post_author_name(post, current_user, key) do
    if post.user_id == current_user.id do
      # Current user's own post - use their name
      case user_name(current_user, key) do
        name when is_binary(name) -> name
        :failed_verification -> "You"
        _ -> "You"
      end
    else
      # For other users' posts, respect privacy - use "Private Author"
      # This applies even to public posts where the author hasn't shared
      # their identity with the current user (e.g., group posts, discover posts)
      "Private Author"
    end
  end

  # Helper function to add subtle tab indicators for new posts in other tabs
  defp add_subtle_tab_indicator(socket, current_user, options) do
    # Update unread counts to show there are new posts in other tabs
    unread_counts = calculate_unread_counts(current_user, options)
    assign(socket, :unread_counts, unread_counts)
  end

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  # Helper function to calculate remaining posts for the current tab
  defp calculate_remaining_posts(timeline_counts, active_tab, loaded_posts_count) do
    total_posts = Map.get(timeline_counts, String.to_atom(active_tab), 0)
    max(0, total_posts - loaded_posts_count)
  end

  # Helper function to calculate timeline counts for all tabs
  defp calculate_timeline_counts(current_user, _options) do
    %{
      # Home tab: count TOTAL posts created BY the current user only
      home: Timeline.count_user_own_posts(current_user),
      # Connections tab: count TOTAL posts FROM connected users shared with current user
      connections: Timeline.count_user_connection_posts(current_user),
      # Groups tab: count TOTAL group posts accessible to current user
      groups: Timeline.count_user_group_posts(current_user),
      # Bookmarks tab: count TOTAL bookmarked posts
      bookmarks: Timeline.count_user_bookmarks(current_user),
      # Discover tab: count TOTAL public posts
      discover: Timeline.count_discover_posts()
    }
  end

  # Helper function to calculate unread counts for all tabs
  defp calculate_unread_counts(current_user, _options) do
    # Get unread posts for the current user
    unread_posts = Timeline.unread_posts(current_user)

    %{
      # Home tab: only show unread posts from the current user (since home only shows user's own posts)
      home: Timeline.count_unread_user_own_posts(current_user),
      # Connections tab: only show unread posts from connected users (excluding current user)
      connections: Timeline.count_unread_connection_posts(current_user),
      # Groups tab: only show unread posts with group_id
      groups: Enum.count(unread_posts, fn post -> post.group_id != nil end),
      # Discover tab: only show unread public posts
      discover: Timeline.count_unread_discover_posts(current_user),
      # Bookmarks tab: only show unread bookmarked posts
      bookmarks:
        case Timeline.list_user_bookmarks(current_user) do
          bookmarks when is_list(bookmarks) ->
            user_bookmarks =
              bookmarks
              |> Enum.map(fn bookmark -> bookmark.post end)
              |> Enum.filter(&(&1 != nil))

            Enum.count(user_bookmarks, fn post ->
              Enum.any?(unread_posts, fn unread_post -> unread_post.id == post.id end)
            end)

          _ ->
            0
        end
    }
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

  # Helper function to get the post author's avatar
  defp get_post_author_avatar(post, current_user, key) do
    cond do
      post.user_id == current_user.id ->
        # Current user's own post - use their avatar
        maybe_get_user_avatar(current_user, key) || mosslet_logo_for_theme()

      true ->
        # Other user's post - get their avatar via connection
        case maybe_get_avatar_src(post, current_user, key, []) do
          avatar when is_binary(avatar) and avatar != "" -> avatar
          _ -> mosslet_logo_for_theme()
        end
    end
  end

  # Helper function to get the post author's display name
  defp get_post_author_name(post, current_user, key) do
    cond do
      post.user_id == current_user.id ->
        # Current user's own post - use their name
        case user_name(current_user, key) do
          name when is_binary(name) -> name
          # Graceful fallback for decryption issues
          :failed_verification -> "Private Author"
          _ -> "Private Author"
        end

      true ->
        # Other user's post - need to get their name via connection
        case Accounts.get_user(post.user_id) do
          %{} = _post_user ->
            # Try to get their shared name via connection
            uconn = get_uconn_for_shared_item(post, current_user)

            if uconn && uconn.connection do
              case decr_uconn(uconn.connection.name, current_user, uconn.key, key) do
                name when is_binary(name) -> name
                # User chose to keep identity private
                :failed_verification -> "Private Author"
              end
            else
              # No connection or privacy-focused sharing
              "Private Author"
            end

          nil ->
            # User account not found or deactivated
            "Private Author"
        end
    end
  end

  # Helper function to check if a post is bookmarked by the current user
  defp get_post_bookmarked_status(post, current_user) do
    # Use the existing Timeline.bookmarked? function with fallback
    case Timeline.bookmarked?(current_user, post) do
      result when is_boolean(result) -> result
      _ -> false
    end
  end

  # Helper function to check if a post is unread by the current user
  defp get_post_unread_status(post, current_user) do
    cond do
      Ecto.assoc_loaded?(post.user_post_receipts) ->
        # Find the receipt for the current user from preloaded association
        receipt =
          Enum.find(post.user_post_receipts, fn receipt ->
            receipt.user_id == current_user.id
          end)

        case receipt do
          # No receipt = unread
          nil -> true
          # Receipt exists and marked as read = read
          %{is_read?: true} -> false
          # Receipt exists but marked as unread = unread
          %{is_read?: false} -> true
          # Default to unread for any other case
          _ -> true
        end

      true ->
        # Fallback to database query if receipts not preloaded
        case Timeline.get_user_post_receipt(current_user, post) do
          # No receipt = unread
          nil -> true
          # Receipt exists and marked as read = read
          %{is_read?: true} -> false
          # Receipt exists but marked as unread = unread
          %{is_read?: false} -> true
          # Default to unread for any other case
          _ -> true
        end
    end
  end

  # Helper function to process uploaded photos using Tigris.ex encryption
  # Returns {upload_paths, trix_key} tuple for idiomatic Elixir/Phoenix
  defp process_uploaded_photos(socket, current_user, key) do
    upload_entries = socket.assigns.uploads.photos.entries
    Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Starting with #{length(upload_entries)} entries")

    if length(upload_entries) == 0 do
      {[], nil}
    else
      # Get or generate the trix_key for encryption (same as posts use)
      trix_key =
        socket.assigns[:trix_key] || generate_and_encrypt_trix_key(current_user, nil)

      Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Generated/retrieved trix_key")

      # Process uploads directly in LiveView process - NO TASKS!
      upload_results =
        for entry <- upload_entries do
          Logger.info(
            "📷 PROCESS_UPLOADED_PHOTOS: Processing entry #{entry.ref}: #{entry.client_name}"
          )

          consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
            Logger.info(
              "📷 PROCESS_UPLOADED_PHOTOS: Consuming entry #{entry.ref}, tmp_path: #{tmp_path}"
            )

            # Generate a unique storage key for this photo
            storage_key = Ecto.UUID.generate()
            Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Generated storage_key: #{storage_key}")

            # Use your existing Tigris.ex upload system
            upload_params = %{
              "Content-Type" => entry.client_type,
              "storage_key" => storage_key,
              "file" => %Plug.Upload{
                path: tmp_path,
                content_type: entry.client_type,
                filename: entry.client_name
              },
              "trix_key" => trix_key
            }

            Logger.info(
              "📷 PROCESS_UPLOADED_PHOTOS: Prepared upload_params for #{entry.client_name}"
            )

            # Get session for Tigris.ex (use stored user token from mount)
            session = %{
              "user_token" => socket.assigns.user_token,
              "key" => key
            }

            Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Prepared session")

            Logger.info(
              "📷 PROCESS_UPLOADED_PHOTOS: user_token: #{inspect(session["user_token"])}"
            )

            Logger.info("📷 PROCESS_UPLOADED_PHOTOS: current_user.id: #{inspect(current_user.id)}")

            case Mosslet.FileUploads.Tigris.upload(session, upload_params) do
              {:ok, _presigned_url} ->
                Logger.info(
                  "📷 PROCESS_UPLOADED_PHOTOS: Upload successful for #{entry.client_name}"
                )

                # Build the file path the same way Tigris.ex does internally
                [file_ext | _] = MIME.extensions(entry.client_type)
                file_path = "#{@folder}/#{storage_key}.#{file_ext}"
                Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Built file_path: #{file_path}")
                # Return the path directly since consume_uploaded_entry expects the return value
                file_path

              {:error, {:nsfw, message}} ->
                Logger.error("📷 PROCESS_UPLOADED_PHOTOS: NSFW content detected: #{message}")
                nil

              {:error, reason} ->
                Logger.error("📷 PROCESS_UPLOADED_PHOTOS: Upload failed: #{inspect(reason)}")
                nil
            end
          end)
        end

      Logger.info(
        "📷 PROCESS_UPLOADED_PHOTOS: All uploads processed. Raw results: #{inspect(upload_results)}"
      )

      # Filter out nil values (failed uploads)
      successful_paths =
        upload_results
        |> Enum.filter(&(&1 != nil))

      Logger.info("📷 PROCESS_UPLOADED_PHOTOS: Successful paths: #{inspect(successful_paths)}")

      {successful_paths, trix_key}
    end
  end

  # Helper functions for decrypting and formatting post data
  defp get_decrypted_post_images(post, current_user, key) do
    cond do
      is_list(post.image_urls) and length(post.image_urls) > 0 ->
        post_key = get_post_key(post, current_user)

        Enum.map(post.image_urls, fn encrypted_url ->
          decr_item(encrypted_url, current_user, post_key, key, post, "body")
        end)

      true ->
        []
    end
  end

  defp format_post_timestamp(naive_datetime) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, naive_datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> "#{div(diff_seconds, 604_800)}w ago"
    end
  end

  # Helper function to add content warning data to post params
  defp add_content_warning_data(post_params, assigns) do
    if assigns.content_warning_enabled && String.trim(assigns.content_warning_text) != "" do
      post_params
      |> Map.put("content_warning", String.trim(assigns.content_warning_text))
      |> Map.put("content_warning_category", assigns.content_warning_category)
      |> Map.put("content_warning?", true)
    else
      post_params
      |> Map.put("content_warning", nil)
      |> Map.put("content_warning_category", nil)
      |> Map.put("content_warning?", false)
    end
  end
end
