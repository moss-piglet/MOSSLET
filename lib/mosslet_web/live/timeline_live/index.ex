defmodule MossletWeb.TimelineLive.Index do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  # import MossletWeb.TimelineLive.Components
  import MossletWeb.Helpers

  import MossletWeb.Helpers.StatusHelpers,
    only: [
      can_view_status?: 3,
      get_user_status_message: 3,
      get_user_status_info: 3
    ]

  alias Phoenix.LiveView.AsyncResult
  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserBlock
  alias Mosslet.Encrypted
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply, ContentFilter}
  alias Mosslet.Extensions.URLPreviewServer

  @post_page_default 1
  @post_per_page_default 10
  @folder "uploads/trix"

  def mount(_params, session, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    initial_selector = "connections"
    initial_replies = true
    initial_bookmarks = true
    initial_shares = true
    initial_ephemeral = false

    # Store the user token from session for later use in uploads
    user_token = session["user_token"]

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        Accounts.private_subscribe(current_user)
        Accounts.subscribe_account_deleted()
        Accounts.subscribe_user_status(current_user)
        Accounts.subscribe_connection_status(current_user)
        Timeline.private_subscribe(current_user)
        Timeline.private_reply_subscribe(current_user)
        Timeline.connections_subscribe(current_user)
        Timeline.connections_reply_subscribe(current_user)
        # Subscribe to public posts for discover tab realtime updates
        Timeline.subscribe()
        Timeline.reply_subscribe()
        # Subscribe to block events for real-time filtering
        Accounts.block_subscribe(current_user)

        # PRIVACY-FIRST: Track user presence for cache optimization only
        # No usernames or identifying info shared - just for performance
        MossletWeb.Presence.track_activity(
          self(),
          %{
            id: current_user.id,
            live_view_name: "timeline",
            joined_at: System.system_time(:second),
            user_id: current_user.id,
            cache_optimization: true
          }
        )

        MossletWeb.Presence.subscribe()

        socket = stream(socket, :presences, MossletWeb.Presence.list_online_users())

        # Privately track user activity for auto-status functionality
        Accounts.track_user_activity(current_user, :general)

        socket
      else
        socket
      end

    # Create changeset with all required fields populated
    changeset =
      Timeline.change_post(
        %Post{},
        %{
          "visibility" => initial_selector,
          "user_id" => current_user.id,
          "username" => username(current_user, key) || "",
          "content_warning" => "",
          "content_warning_category" => "",
          # Enhanced privacy control defaults
          "allow_replies" => initial_replies,
          "allow_shares" => initial_shares,
          "allow_bookmarks" => initial_bookmarks,
          "require_follow_to_reply" => false,
          "mature_content" => false,
          "is_ephemeral" => initial_ephemeral,
          "local_only" => false
        },
        user: current_user
      )

    socket =
      socket
      |> assign(:post_form, to_form(changeset))
      |> assign(:user_list, [])
      # Keep selector in sync with form
      |> assign(:selector, initial_selector)
      |> assign(:allow_replies, initial_replies)
      |> assign(:allow_shares, initial_shares)
      |> assign(:allow_bookmarks, initial_bookmarks)
      |> assign(:is_ephemeral, initial_ephemeral)
      # Content warning state preservation
      |> assign(:mature_content, false)
      |> assign(:require_follow_to_reply, false)
      |> assign(:local_only, false)
      |> assign(:expires_at_option, nil)
      |> assign(:post_loading_count, 0)
      |> assign(:post_loading, false)
      |> assign(:post_loading_done, false)
      |> assign(:post_finished_loading_list, [])
      |> assign(:image_urls, [])
      |> assign(:show_image_modal, false)
      |> assign(:current_images, [])
      |> assign(:current_image_index, 0)
      |> assign(:current_post_for_images, nil)
      |> assign(:can_download_images, false)
      |> assign(:delete_post_from_cloud_message, nil)
      |> assign(:delete_reply_from_cloud_message, nil)
      |> assign(:uploads_in_progress, false)
      |> assign(:active_tab, "home")
      |> assign(:timeline_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0})
      |> assign(:unread_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0})
      |> assign(:loaded_posts_count, 0)
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      # Track which tab is currently loading for UI feedback
      |> assign(:loading_tab, nil)
      # Track dynamic stream limit
      |> assign(:stream_limit, @post_per_page_default)
      # Store user token for uploads
      |> assign(:user_token, user_token)
      # Content warning state
      |> assign(:content_warning_enabled?, false)
      # Enhanced privacy controls state
      |> assign(:privacy_controls_expanded, false)
      # Composer collapsed state for scrolling convenience
      |> assign(:composer_collapsed, false)
      # Store selected groups/users to preserve when privacy controls are collapsed
      |> assign(:selected_visibility_groups, [])
      |> assign(:selected_visibility_users, [])
      # Load and cache content filters once in mount
      |> assign(:content_filters, load_and_decrypt_content_filters(current_user, key))
      # Initialize URL preview state
      |> assign(:url_preview, nil)
      |> assign(:url_preview_loading, false)
      |> assign(:current_preview_url, nil)
      # Cache timeline counts to avoid repeated DB queries
      |> assign(:timeline_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0, discover: 0})
      |> assign(:unread_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0, discover: 0})
      # Moderation modal states
      |> assign(:show_report_modal, false)
      |> assign(:report_post_id, nil)
      |> assign(:report_user_id, nil)
      |> assign(:show_block_modal, false)
      |> assign(:block_user_id, nil)
      |> assign(:block_user_name, nil)
      |> assign(:show_share_modal, false)
      |> assign(:share_post_id, nil)
      |> assign(:share_post_body, nil)
      |> assign(:share_post_username, nil)
      |> assign(:removing_shared_user_id, nil)
      |> assign(:adding_shared_user, nil)
      |> assign(:loaded_replies_counts, %{})
      |> assign(:loaded_nested_replies, %{})
      |> assign(:upload_stages, %{})
      |> assign(:completed_uploads, [])
      |> assign(:composer_trix_key, nil)
      |> stream(:posts, [])
      |> assign(:timeline_data, AsyncResult.loading())
      |> allow_upload(:photos,
        accept: ~w(.jpg .jpeg .png .webp .heic .heif),
        max_entries: 10,
        max_file_size: 10_000_000,
        chunk_size: 64_000,
        auto_upload: true,
        progress: &handle_upload_progress/3,
        writer: fn _name, entry, socket ->
          {Mosslet.FileUploads.ImageUploadWriter,
           %{
             lv_pid: self(),
             entry_ref: entry.ref,
             user_token: socket.assigns.user_token,
             key: socket.assigns.key,
             visibility: socket.assigns.selector,
             trix_key: socket.assigns.composer_trix_key,
             expected_size: entry.client_size
           }}
        end
      )

    {:ok, assign(socket, page_title: "Timeline")}
  end

  def terminate(_reason, socket) do
    Enum.each(socket.assigns[:completed_uploads] || [], fn upload ->
      if upload[:temp_path], do: cleanup_temp_upload(upload.temp_path)
    end)

    :ok
  end

  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

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

    # Prepare shared users first as they're needed for both posts and counts
    user_connections = Accounts.get_all_confirmed_user_connections(current_user.id)

    post_shared_users =
      decrypt_shared_user_connections(
        user_connections,
        current_user,
        key,
        :post
      )

    # Hydrate content filters with post_shared_users
    hydrated_content_filters =
      hydrate_content_filters(socket.assigns.content_filters, post_shared_users)

    socket =
      socket
      |> assign(:user_connections, user_connections)
      |> assign(:post_shared_users, post_shared_users)
      |> assign(:content_filters, hydrated_content_filters)
      |> assign(:options, options)
      |> assign(:return_url, url)
      |> assign(:filter, filter)
      |> assign(:show_content_filter, false)
      |> assign(:loading_content_filter, false)
      |> assign_keyword_filter_form()
      |> assign(:load_more_loading, false)

    # Start async operation to load timeline data (posts and counts together)
    # This ensures data synchronization while providing loading UI
    current_user_id = current_user.id
    content_filter_prefs = hydrated_content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)
    current_tab_for_async = current_tab

    socket =
      socket
      |> assign(:timeline_data, AsyncResult.loading())
      |> start_async(:load_timeline_data, fn ->
        # Load posts for the current active tab with content filtering
        posts =
          case current_tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "connections" ->
              Timeline.list_connection_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "home" ->
              Timeline.list_user_own_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "bookmarks" ->
              Timeline.list_user_bookmarks(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "groups" ->
              Timeline.list_group_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            _ ->
              options_with_tab = Map.put(options_with_filters, :tab, current_tab_for_async)
              user = Accounts.get_user!(current_user_id)

              Timeline.filter_timeline_posts(user, options_with_tab)
              |> apply_tab_filtering(current_tab_for_async, user)
          end

        # Calculate all timeline counts with the SAME filtering options
        # This ensures perfect synchronization between displayed posts and counts
        user = Accounts.get_user!(current_user_id)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)
        post_count = Timeline.timeline_post_count(user, options)

        # Return synchronized data as a single unit
        %{
          posts: posts,
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          post_count: post_count,
          loaded_posts_count: length(posts),
          current_page: options.post_page,
          post_loading_list: Enum.with_index(posts, fn element, index -> {index, element} end)
        }
      end)

    {:noreply, socket}
  end

  def handle_info(:complete_content_filter_toggle, socket) do
    current_state = socket.assigns.show_content_filter

    {:noreply,
     socket
     |> assign(:show_content_filter, !current_state)
     |> assign(:loading_content_filter, false)}
  end

  def handle_info(
        {:upload_ready, entry_ref, %{processed_binary: binary, trix_key: trix_key}},
        socket
      ) do
    entry = Enum.find(socket.assigns.uploads.photos.entries, &(&1.ref == entry_ref))

    upload_stages = Map.put(socket.assigns.upload_stages, entry_ref, {:ready, nil})

    temp_path = write_upload_to_temp_file(binary, entry_ref)
    preview_data_url = generate_thumbnail_preview(binary)

    completed_upload = %{
      ref: entry_ref,
      client_name: (entry && entry.client_name) || "photo",
      temp_path: temp_path,
      trix_key: trix_key,
      preview_data_url: preview_data_url
    }

    socket =
      socket
      |> assign(:upload_stages, upload_stages)
      |> assign(:completed_uploads, socket.assigns.completed_uploads ++ [completed_upload])

    {:noreply, socket}
  end

  def handle_info({:upload_progress, entry_ref, stage, value}, socket) do
    upload_stages = Map.put(socket.assigns.upload_stages, entry_ref, {stage, value})
    socket = assign(socket, :upload_stages, upload_stages)

    {:noreply, socket}
  end

  def handle_info({:upload_trix_key, _entry_ref, trix_key}, socket) do
    current_key = socket.assigns.composer_trix_key

    if is_nil(current_key) do
      {:noreply, assign(socket, :composer_trix_key, trix_key)}
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

  def handle_info({:status_updated, user}, socket) do
    # Handle status updates for both current user and connected users
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    if user.id == current_user.id do
      {:noreply,
       socket
       |> assign(current_user: user)}
    else
      # Find the user_connection that represents our connection to this user
      case get_uconn_for_users(user, current_user) do
        %{} = _user_connection ->
          # Use consolidated StatusHelpers for consistent status handling
          user_with_connection = Accounts.get_user_with_preloads(user.id)

          status_info = get_user_status_info(user_with_connection, current_user, key)

          new_status = status_info.status || "offline"
          new_status_message = status_info.status_message

          # Send JS event to update only status elements without disrupting the timeline
          {:noreply,
           push_event(socket, "update_user_status", %{
             user_id: user.id,
             status: new_status,
             status_message: new_status_message
           })}

        nil ->
          {:noreply, socket}
      end
    end
  end

  def handle_info({:status_visibility_updated, user}, socket) do
    # Handle status visibility updates - when someone changes their status visibility,
    # we need to check if the current user can still see their status or not
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Only process if we have a connection to this user (i.e., they appear on our timeline)
    case get_uconn_for_users(user, current_user) do
      %{} = _user_connection ->
        # Get the user with their connection data
        user_with_connection = Accounts.get_user_with_preloads(user.id)

        case can_view_status?(user_with_connection, current_user, key) do
          true ->
            # Check if current_user can see user's status with the new visibility settings
            status_info = get_user_status_info(user_with_connection, current_user, key)

            case status_info do
              %{status: status, status_message: status_message} when not is_nil(status) ->
                # Current user can see the status - show it
                {:noreply,
                 push_event(socket, "update_user_status", %{
                   user_id: user.id,
                   status: status,
                   status_message: status_message,
                   visible: true
                 })}

              %{status: nil} ->
                # Current user cannot see the status - hide it
                {:noreply,
                 push_event(socket, "update_user_status", %{
                   user_id: user.id,
                   visible: false
                 })}

              _ ->
                # Fallback - hide status
                {:noreply,
                 push_event(socket, "update_user_status", %{
                   user_id: user.id,
                   visible: false
                 })}
            end

          false ->
            {:noreply,
             push_event(socket, "update_user_status", %{
               status: nil,
               status_message: nil,
               user_id: user.id,
               visible: false
             })}
        end

      nil ->
        {:noreply, socket}
    end
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
            Accounts.track_user_activity(current_user, :interaction)
            updated_post = get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

            socket =
              socket
              |> put_flash(:success, "Reply posted successfully!")
              |> stream_insert(:posts, updated_post)
              |> push_event("show-reply-thread", %{post_id: post_id})

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

  def handle_info({:reply_created, post, reply}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      reply_user = Accounts.get_user_with_preloads(reply.user_id)
      status_info = get_user_status_info(reply_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message

      post_with_limited_replies =
        get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

      socket =
        socket
        |> stream_insert(:posts, post_with_limited_replies, at: -1)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_reply_notification(reply, current_user, "created")

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: current_user.id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_subtle_tab_indicator(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:reply_updated, post, reply}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      reply_user = Accounts.get_user_with_preloads(reply.user_id)
      status_info = get_user_status_info(reply_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message

      post_with_limited_replies =
        get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

      socket =
        socket
        |> stream_insert(:posts, post_with_limited_replies, at: -1)
        |> recalculate_counts_after_new_post(current_user, options)

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: reply.user_id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:reply_deleted, post, _reply}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      post_with_limited_replies =
        get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

      socket =
        socket
        |> stream_insert(:posts, post_with_limited_replies, at: -1)
        |> recalculate_counts_after_new_post(current_user, options)

      {:noreply, socket}
    else
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:post_created, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    # Check if this post should appear in the current tab
    should_show_post = post_matches_current_tab?(post, current_tab, current_user)

    # Apply content filtering to real-time posts
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      post_user = Accounts.get_user_with_preloads(post.user_id)
      status_info = get_user_status_info(post_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message

      # Add the new post to the top of the stream - CSS animations will trigger automatically
      socket =
        socket
        |> stream_insert(:posts, post, at: 0, limit: socket.assigns.stream_limit)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_new_post_notification(post, current_user)

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: current_user.id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      # Post doesn't match current tab or is filtered out, but still update counts
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_subtle_tab_indicator(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:post_updated, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    # Check if this updated post should appear in the current tab
    should_show_post = post_matches_current_tab?(post, current_tab, current_user)

    # Apply content filtering to the updated post
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      post_user = Accounts.get_user_with_preloads(post.user_id)
      status_info = get_user_status_info(post_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message
      # Update the post in the stream - this will update the existing post in place
      socket =
        socket
        # Update existing post
        |> stream_insert(:posts, post, at: -1)
        |> recalculate_counts_after_post_update(current_user, options)

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: current_user.id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      # Post no longer matches current tab or is now filtered out
      # Remove it from stream and update counts
      socket =
        socket
        |> stream_delete(:posts, post)
        |> recalculate_counts_after_post_update(current_user, options)

      {:noreply,
       socket
       |> assign(:removing_shared_user_id, nil)
       |> assign(:adding_shared_user, nil)}
    end
  end

  def handle_info({:post_updated_user_removed, post}, socket) do
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    socket =
      socket
      |> stream_delete(:posts, post)
      |> recalculate_counts_after_post_update(current_user, options)

    {:noreply, socket}
  end

  def handle_info({:post_shared_users_added, post}, socket) do
    {:noreply,
     socket
     |> assign(:removing_shared_user_id, nil)
     |> assign(:adding_shared_user, nil)
     |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:post_shared_users_removed, post}, socket) do
    {:noreply,
     socket
     |> assign(:removing_shared_user_id, nil)
     |> assign(:adding_shared_user, nil)
     |> stream_insert(:posts, post, at: -1)}
  end

  def handle_info({:post_updated_fav, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      {:noreply,
       push_event(socket, "update_post_fav_count", %{
         post_id: post.id,
         favs_count: post.favs_count
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:reply_updated_fav, post, reply}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      {:noreply,
       push_event(socket, "update_reply_fav_count", %{
         reply_id: reply.id,
         favs_count: reply.favs_count
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_deleted, post}, socket) do
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Always remove the post from the stream regardless of tab
    # since it's been deleted and shouldn't appear anywhere
    socket =
      socket
      |> stream_delete(:posts, post)
      |> recalculate_counts_after_post_update(current_user, options)

    # No notification needed for deleted posts - just remove silently

    {:noreply, socket}
  end

  def handle_info({:post_shared, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      post_user = Accounts.get_user_with_preloads(post.user_id)
      status_info = get_user_status_info(post_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message

      socket =
        socket
        |> stream_insert(:posts, post, at: 0, limit: socket.assigns.stream_limit)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_new_share_post_notification(post, current_user)

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: post.user_id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      socket =
        socket
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_subtle_tab_indicator(current_user, options)

      {:noreply, socket}
    end
  end

  def handle_info({:repost_deleted, post}, socket) do
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Always remove the repost from the stream regardless of tab
    # since it's been deleted and shouldn't appear anywhere
    socket =
      socket
      |> stream_delete(:posts, post)
      |> recalculate_counts_after_post_update(current_user, options)

    # No notification needed for deleted reposts - just remove silently

    {:noreply, socket}
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

      # If user connection affects the current user's permissions and modal is open
      uconn.reverse_user_id == current_user.id && socket.assigns.show_image_modal ->
        post = socket.assigns.current_post_for_images
        can_download = check_download_permission(post, current_user)

        socket =
          socket
          |> assign(:can_download_images, can_download)

        {:noreply, socket}

      # If user connection affects the current user's permissions but modal is closed
      uconn.reverse_user_id == current_user.id ->
        {:noreply, socket}

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
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    updated_post = get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

    should_show_post = post_matches_current_tab?(updated_post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(updated_post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)
      status_info = get_user_status_info(current_user, current_user, key)

      new_status = status_info.status || "offline"
      new_status_message = status_info.status_message

      socket =
        socket
        |> stream_insert(:posts, updated_post, at: -1)
        |> recalculate_counts_after_post_update(current_user, options)
        |> put_flash(:success, "Reply created!")
        |> push_event("hide-nested-reply-composer", %{reply_id: parent_reply_id})

      {:noreply,
       push_event(socket, "update_user_status", %{
         user_id: current_user.id,
         status: new_status,
         status_message: new_status_message
       })}
    else
      socket =
        socket
        |> recalculate_counts_after_post_update(current_user, options)
        |> add_subtle_tab_indicator(current_user, options)

      {:noreply, socket}
    end
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

  # ============================================================================
  # MODERATION MODAL COMPONENT EVENT HANDLERS
  # ============================================================================

  def handle_info({:close_report_modal}, socket) do
    socket =
      socket
      |> assign(:show_report_modal, false)
      |> assign(:report_post_id, nil)
      |> assign(:report_user_id, nil)

    {:noreply, socket}
  end

  def handle_info({:submit_report, report_params}, socket) do
    current_user = socket.assigns.current_user
    post_id = report_params["post_id"]
    reported_user_id = report_params["reported_user_id"]
    reply_context = socket.assigns[:report_reply_context]

    # Add reply_id to params if this is a reply report (instead of details enhancement)
    enhanced_params =
      if reply_context && Map.has_key?(reply_context, :reply_id) do
        report_params
        |> Map.put("reply_id", reply_context.reply_id)
      else
        report_params
      end

    case {Timeline.get_post(post_id), Accounts.get_user(reported_user_id)} do
      {%Timeline.Post{} = post, %Accounts.User{} = reported_user} ->
        # Determine what was reported for better user feedback
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

  def handle_info({:close_block_modal}, socket) do
    socket =
      socket
      |> assign(:show_block_modal, false)
      |> assign(:block_user_id, nil)
      |> assign(:block_user_name, nil)

    {:noreply, socket}
  end

  def handle_info({:submit_block, block_params}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    blocked_user_id = block_params["blocked_id"]

    case Accounts.get_user(blocked_user_id) do
      %Accounts.User{} = blocked_user ->
        case Accounts.block_user(current_user, blocked_user, block_params,
               user: current_user,
               key: key
             ) do
          {:ok, block} ->
            info =
              if block.blocked_id != current_user.id,
                do: "Author blocked successfully. You won't see their content anymore."

            socket =
              socket
              |> assign(:show_block_modal, false)
              |> assign(:block_user_id, nil)
              |> assign(:block_user_name, nil)
              |> put_flash(
                :info,
                info
              )
              # Real-time timeline refresh without full navigation - optimal for our distributed architecture
              |> push_patch(to: ~p"/app/timeline")

            {:noreply, socket}

          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
            error_msg = "Block failed: #{inspect(errors)}"
            {:noreply, put_flash(socket, :error, error_msg)}
        end

      nil ->
        {:noreply, put_flash(socket, :error, "Author not found.")}
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

  def handle_info({:submit_share, share_params}, socket) do
    post = Timeline.get_post!(share_params.post_id)
    user = socket.assigns.current_user
    key = socket.assigns.key
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

  # ============================================================================
  # BLOCK/MODERATION EVENT HANDLERS
  # ============================================================================

  def handle_info({:user_blocked, _block}, socket) do
    # When a user is blocked, refresh the timeline to filter out their content
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Invalidate timeline cache to ensure fresh data without blocked user's content
    Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

    # Refresh timeline with new filtering applied
    # Use cached content filters from socket assigns
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)

    current_tab = socket.assigns.active_tab || "home"

    posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, options_with_filters)

        "connections" ->
          Timeline.list_connection_posts(current_user, options_with_filters)

        "home" ->
          Timeline.list_user_own_posts(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Update timeline counts to reflect the block using cached content filters
    socket =
      socket
      |> maybe_update_timeline_counts(current_user, options_with_filters)
      |> assign(:loaded_posts_count, length(posts))
      |> assign(:current_page, 1)
      |> stream(:posts, posts, reset: true)
      |> put_flash(
        :info,
        "User blocked successfully. Their content has been filtered from your timeline."
      )

    {:noreply, socket}
  end

  def handle_info({:user_unblocked, _block}, socket) do
    # When a user is unblocked, refresh the timeline to show their content again
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Invalidate timeline cache to ensure fresh data with unblocked user's content
    Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

    # Refresh timeline with new filtering applied
    # Use cached content filters from socket assigns
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)

    current_tab = socket.assigns.active_tab || "home"

    posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, options_with_filters)

        "connections" ->
          Timeline.list_connection_posts(current_user, options_with_filters)

        "home" ->
          Timeline.list_user_own_posts(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Update timeline counts to reflect the unblock
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    socket =
      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:loaded_posts_count, length(posts))
      |> assign(:current_page, 1)
      |> stream(:posts, posts, reset: true)
      |> put_flash(
        :info,
        "User unblocked successfully. Their content is now visible in your timeline."
      )

    {:noreply, socket}
  end

  def handle_info({:user_block_updated, block}, socket) do
    # When a block is updated (e.g., changing block type), refresh the timeline
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    # Invalidate timeline cache to ensure fresh data with updated blocking rules
    Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

    # Refresh timeline with updated filtering applied
    # Use cached content filters from socket assigns
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)

    current_tab = socket.assigns.active_tab || "home"

    posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, options_with_filters)

        "connections" ->
          Timeline.list_connection_posts(current_user, options_with_filters)

        "home" ->
          Timeline.list_user_own_posts(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Update timeline counts to reflect the block type change
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    # we only want to show a flash message to the blocker (not the person being blocked)
    info =
      if block.blocked_id != current_user.id,
        do: "Block settings updated. Timeline refreshed to reflect changes."

    socket =
      socket
      |> assign(:posts, posts)
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:current_page, 1)
      |> stream(:posts, posts, reset: true)
      |> put_flash(
        :info,
        info
      )

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "expand_nested_replies",
        %{"reply-id" => reply_id, "post-id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_user

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

        socket =
          socket
          |> assign(:loaded_nested_replies, updated_loaded)
          |> stream_insert(:posts, post, at: -1)

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
    current_user = socket.assigns.current_user

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

      socket =
        socket
        |> assign(:loaded_replies_counts, updated_counts)
        |> stream_insert(:posts, post, at: -1)
        |> push_event("animate-new-replies", %{post_id: post_id, start_index: current_count})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  def handle_event("restore-body-scroll", _params, socket) do
    socket = put_flash(socket, :success, "Download complete!")
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
    key = socket.assigns.key

    # Preserve the current selector value when validating
    # This prevents the enhanced privacy controls from disappearing
    current_selector = socket.assigns.selector

    # Build complete params for validation including enhanced privacy controls
    complete_params =
      post_params
      |> Map.put("image_urls", socket.assigns.image_urls)
      |> Map.put("visibility", current_selector)
      |> Map.put("content_warning?", socket.assigns.content_warning_enabled?)
      |> Map.put("user_id", current_user.id)
      |> Map.put("username", username(current_user, key) || "")
      # Enhanced privacy controls - preserve existing values or use defaults
      |> Map.put_new(
        "allow_replies",
        post_params["allow_replies"] || socket.assigns.allow_replies
      )
      |> Map.put_new("allow_shares", post_params["allow_shares"] || socket.assigns.allow_shares)
      |> Map.put_new(
        "allow_bookmarks",
        post_params["allow_bookmarks"] || socket.assigns.allow_bookmarks
      )
      |> Map.put_new(
        "require_follow_to_reply",
        post_params["require_follow_to_reply"] || socket.assigns.require_follow_to_reply
      )
      |> Map.put_new(
        "mature_content",
        post_params["mature_content"] || socket.assigns.mature_content
      )
      |> Map.put_new("is_ephemeral", post_params["is_ephemeral"] || socket.assigns.is_ephemeral)
      |> Map.put_new("local_only", post_params["local_only"] || socket.assigns.local_only)
      |> Map.put_new(
        "expires_at_option",
        post_params["expires_at_option"] || socket.assigns.expires_at_option
      )
      # Handle visibility groups and users - preserve from socket if not in form params
      |> Map.put(
        "visibility_groups",
        post_params["visibility_groups"] || socket.assigns.selected_visibility_groups || []
      )
      |> Map.put(
        "visibility_users",
        post_params["visibility_users"] || socket.assigns.selected_visibility_users || []
      )
      # Expiration handling now done in Post changeset with virtual field
      |> add_shared_users_list_for_new_post(post_shared_users, %{
        visibility_setting: current_selector,
        current_user: current_user,
        key: key
      })

    # Let Timeline.change_post handle all the changeset logic
    changeset = Timeline.change_post(%Post{}, complete_params, user: current_user)

    current_preview_url = socket.assigns[:current_preview_url]
    new_url = extract_first_url(post_params["body"])

    socket =
      cond do
        new_url && new_url != current_preview_url ->
          user_id = socket.assigns.current_user.id

          socket
          |> assign(:current_preview_url, new_url)
          |> assign(:url_preview_loading, true)
          |> start_async(:url_preview_task, fn ->
            case Mosslet.Extensions.URLPreviewServer.fetch(new_url, user_id: user_id) do
              {:ok, preview} -> {:ok, preview}
              {:error, reason} -> {:error, reason}
            end
          end)

        new_url == nil && current_preview_url != nil ->
          socket
          |> assign(:current_preview_url, nil)
          |> assign(:url_preview, nil)
          |> assign(:url_preview_loading, false)

        true ->
          socket
      end

    socket =
      socket
      |> maybe_update_visibility_groups(post_params)
      |> maybe_update_visibility_users(post_params)
      |> maybe_update_interaction_controls(post_params)
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

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    ref_value = if is_binary(ref), do: String.to_integer(ref), else: ref
    upload_stages = Map.delete(socket.assigns.upload_stages, ref_value)

    {removed, remaining} =
      Enum.split_with(socket.assigns.completed_uploads, &(&1.ref == ref_value))

    Enum.each(removed, fn upload ->
      if upload[:temp_path], do: cleanup_temp_upload(upload.temp_path)
    end)

    {:noreply,
     socket
     |> cancel_upload(:photos, ref)
     |> assign(:upload_stages, upload_stages)
     |> assign(:completed_uploads, remaining)}
  end

  def handle_event("remove_completed_upload", %{"ref" => ref}, socket) do
    ref_value = if is_binary(ref), do: String.to_integer(ref), else: ref

    upload_stages = Map.delete(socket.assigns.upload_stages, ref_value)

    {removed, remaining} =
      Enum.split_with(socket.assigns.completed_uploads, fn upload ->
        upload_ref = if is_binary(upload.ref), do: String.to_integer(upload.ref), else: upload.ref
        upload_ref == ref_value
      end)

    Enum.each(removed, fn upload ->
      if upload[:temp_path], do: cleanup_temp_upload(upload.temp_path)
    end)

    entry_exists? =
      Enum.any?(socket.assigns.uploads.photos.entries, &(&1.ref == ref_value))

    socket =
      if entry_exists? do
        cancel_upload(socket, :photos, ref)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:upload_stages, upload_stages)
     |> assign(:completed_uploads, remaining)}
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
    post = socket.assigns[:post]
    visibility = socket.assigns.selector

    trix_key =
      Map.get(
        socket.assigns,
        :trix_key,
        generate_and_encrypt_trix_key(current_user, post, visibility)
      )

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
          [_ | _] = urls ->
            post_key = get_post_key(post, current_user)

            # Decrypt each URL to get the actual S3 file path for the decrypt_post_images handler
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
                Logger.info("Error getting Post images from cloud in TimelineLive.Index")
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
        ext = ext(get_ext_from_file_key(source))
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

    case receipt do
      nil ->
        # No receipt exists - determine desired state based on current display
        # For public posts from others that show as "read" (no receipt),
        # clicking "Mark as unread" should create an unread receipt

        desired_read_status =
          if post.visibility == :public && post.user_id != current_user.id do
            # Public post from another user - toggle to unread
            false
          else
            # Own post or private/connections post - mark as read
            true
          end

        # Create or get UserPost for this interaction
        case Timeline.get_or_create_user_post_for_public(post, current_user) do
          {:ok, user_post} ->
            case Timeline.create_or_update_user_post_receipt(
                   user_post,
                   current_user,
                   desired_read_status
                 ) do
              {:ok, _receipt} ->
                Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

                updated_post = get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

                content_filter_prefs = socket.assigns.content_filters

                options_with_filters =
                  Map.put(options, :content_filter_prefs, content_filter_prefs)

                unread_counts = calculate_unread_counts(current_user, options_with_filters)

                flash_message =
                  if desired_read_status, do: "Post marked as read", else: "Post marked as unread"

                socket =
                  socket
                  |> stream_insert(:posts, updated_post, at: -1)
                  |> assign(:unread_counts, unread_counts)
                  |> put_flash(:info, flash_message)

                {:noreply, socket}

              {:error, _changeset} ->
                {:noreply, put_flash(socket, :error, "Failed to update post status")}
            end

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to mark post")}
        end

      %{is_read?: true} ->
        # Receipt exists and is marked as read - mark as unread
        case Timeline.update_user_post_receipt_unread(receipt.id) do
          {:ok, _conn, _post} ->
            Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

            updated_post =
              get_post_with_reply_limit(post_id, current_user.id, socket.assigns)
              |> Mosslet.Repo.preload([:user_post_receipts], force: true)

            content_filter_prefs = socket.assigns.content_filters
            options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
            unread_counts = calculate_unread_counts(current_user, options_with_filters)

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
        case Timeline.update_user_post_receipt_read(receipt.id) do
          {:ok, _conn, _post} ->
            Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

            updated_post =
              get_post_with_reply_limit(post_id, current_user.id, socket.assigns)
              |> Mosslet.Repo.preload([:user_post_receipts], force: true)

            content_filter_prefs = socket.assigns.content_filters
            options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
            unread_counts = calculate_unread_counts(current_user, options_with_filters)

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

  def handle_event("toggle_privacy_controls", _params, socket) do
    # Toggle enhanced privacy controls expansion
    current_expanded = socket.assigns.privacy_controls_expanded

    {:noreply, assign(socket, :privacy_controls_expanded, !current_expanded)}
  end

  def handle_event("toggle_composer_collapsed", _params, socket) do
    {:noreply, assign(socket, :composer_collapsed, !socket.assigns.composer_collapsed)}
  end

  def handle_event("update_privacy_visibility", %{"visibility" => visibility}, socket) do
    # Update the privacy visibility from the enhanced controls
    # This handles the radio button selections in the expanded privacy controls
    {:noreply, assign(socket, :selector, visibility)}
  end

  def handle_event("composer_add_photo", _params, socket) do
    # Trigger the file input dialog by pushing a JavaScript event
    {:noreply, push_event(socket, "trigger-photo-upload", %{})}
  end

  def handle_event("validate_photos", _params, socket) do
    # Validate uploads - this runs automatically when files are selected
    {:noreply, socket}
  end

  def handle_event("remove_photo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :photos, ref)}
  end

  def handle_event("toggle_content_filter", _params, socket) do
    socket =
      socket
      |> assign(:loading_content_filter, true)

    Process.send_after(self(), :complete_content_filter_toggle, 150)

    {:noreply, socket}
  end

  def handle_event("remove_url_preview", _params, socket) do
    {:noreply, assign(socket, url_preview: nil, url_preview_loading: false)}
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
        "decrypt_url_preview_image",
        %{"presigned_url" => presigned_url, "post_id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

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

  def handle_event("composer_toggle_content_warning", _params, socket) do
    # Toggle content warning state
    current_state = socket.assigns.content_warning_enabled?
    new_state = !current_state

    # Get current form values
    current_form = socket.assigns.post_form
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    post_shared_users = socket.assigns.post_shared_users

    # Build params with updated content warning state
    params =
      %{
        "body" => current_form[:body].value || "",
        "content_warning" =>
          if(new_state, do: current_form[:content_warning].value || "", else: ""),
        "content_warning_category" =>
          if(new_state, do: current_form[:content_warning_category].value || "", else: ""),
        "content_warning?" => new_state,
        "visibility" => socket.assigns.selector,
        "image_urls" => socket.assigns.image_urls,
        "user_id" => current_user.id,
        "username" => username(current_user, key) || ""
      }
      |> add_shared_users_list_for_new_post(post_shared_users, %{
        visibility_setting: socket.assigns.selector,
        current_user: current_user,
        key: key
      })

    # Let Timeline.change_post handle the changeset
    changeset = Timeline.change_post(%Post{}, params, user: current_user)

    socket =
      socket
      |> assign(:content_warning_enabled?, new_state)
      |> assign(:post_form, to_form(changeset, action: :validate))

    {:noreply, socket}
  end

  def handle_event("save_post", %{"post" => post_params}, socket) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      key = socket.assigns.key
      post_shared_users = socket.assigns.post_shared_users

      # Process uploaded photos and get their URLs with trix_key
      {uploaded_photo_urls, trix_key} =
        process_uploaded_photos(socket, current_user, key)

      post_params =
        post_params
        |> Map.put("image_urls", socket.assigns.image_urls ++ uploaded_photo_urls)
        |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())
        |> Map.put("visibility", socket.assigns.selector)
        |> Map.put("user_id", current_user.id)
        |> Map.put("content_warning?", socket.assigns.content_warning_enabled?)
        |> maybe_put_url_preview(socket)
        |> Map.put(
          "url_preview_fetched_at",
          if(socket.assigns.url_preview, do: NaiveDateTime.utc_now(), else: nil)
        )
        # Handle interaction controls - use stored values if not in form params
        |> Map.put(
          "allow_replies",
          post_params["allow_replies"] || socket.assigns.allow_replies
        )
        |> Map.put(
          "allow_shares",
          post_params["allow_shares"] || socket.assigns.allow_shares
        )
        |> Map.put(
          "allow_bookmarks",
          post_params["allow_bookmarks"] || socket.assigns.allow_bookmarks
        )
        |> Map.put(
          "is_ephemeral",
          post_params["is_ephemeral"] || socket.assigns.is_ephemeral
        )
        |> Map.put(
          "require_follow_to_reply",
          post_params["require_follow_to_reply"] || socket.assigns.require_follow_to_reply
        )
        |> Map.put(
          "mature_content",
          post_params["mature_content"] || socket.assigns.mature_content
        )
        |> Map.put("local_only", post_params["local_only"] || socket.assigns.local_only)
        |> Map.put(
          "expires_at_option",
          post_params["expires_at_option"] || socket.assigns.expires_at_option
        )
        # Handle visibility groups and users - use stored values if not in form params
        |> Map.put(
          "visibility_groups",
          post_params["visibility_groups"] || socket.assigns.selected_visibility_groups || []
        )
        |> Map.put(
          "visibility_users",
          post_params["visibility_users"] || socket.assigns.selected_visibility_users || []
        )
        # Use the updated function to handle connections visibility
        |> add_shared_users_list_for_new_post(post_shared_users, %{
          visibility_setting: socket.assigns.selector,
          current_user: current_user,
          key: key
        })

      # Keep virtual fields for validation in Post changeset

      if post_params["user_id"] == current_user.id do
        case Timeline.create_post(post_params, user: current_user, key: key, trix_key: trix_key) do
          {:ok, post} ->
            # Track user activity for auto-status (post creation is significant activity)
            Accounts.track_user_activity(current_user, :post)

            # Send email notifications to offline users who received this post
            process_email_notifications_for_offline_users(post, current_user, key)

            # Reset form to clean state after successful post creation
            clean_changeset =
              Timeline.change_post(
                %Post{},
                %{
                  "visibility" => socket.assigns.selector,
                  "user_id" => current_user.id,
                  "username" => username(current_user, key) || "",
                  "content_warning" => "",
                  "content_warning_category" => ""
                },
                user: current_user
              )

            socket =
              socket
              |> assign(:trix_key, nil)
              |> assign(:composer_trix_key, nil)
              |> assign(:post_form, to_form(clean_changeset))
              |> assign(:image_urls, [])
              |> assign(:upload_stages, %{})
              |> assign(:completed_uploads, [])
              |> assign(:content_warning_enabled?, false)
              |> assign(:selected_visibility_groups, [])
              |> assign(:selected_visibility_users, [])
              |> assign(:url_preview, nil)
              |> assign(:url_preview_loading, false)
              |> assign(:current_preview_url, nil)
              |> put_flash(:success, "Post created successfully")

            # Instead of push_patch (page reload), update stream and counts like handle_info does
            current_tab = socket.assigns.active_tab || "home"
            options = socket.assigns.options
            content_filters = socket.assigns.content_filters

            # Check if this new post should appear in the current tab
            should_show_post = post_matches_current_tab?(post, current_tab, current_user)
            passes_content_filters = post_passes_content_filters?(post, content_filters)

            socket =
              if should_show_post and passes_content_filters do
                # Add the new post to the top of the stream - same as handle_info
                socket
                |> stream_insert(:posts, post, at: 0, limit: socket.assigns.stream_limit)
                |> recalculate_counts_after_new_post(current_user, options)
              else
                # Post doesn't match current tab, just update counts
                socket
                |> recalculate_counts_after_new_post(current_user, options)
              end

            {:noreply, socket}

          {:error, changeset} ->
            error_message =
              MossletWeb.CoreComponents.combine_changeset_error_messages_sans_key(changeset)

            socket =
              socket
              |> assign(:post_form, to_form(changeset, action: :validate))
              |> put_flash(:warning, String.trim(error_message))

            {:noreply, socket}
        end
      else
        {:noreply,
         socket
         |> put_flash(:warning, "You do not have permission to create this post.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :warning,
         "You are not connected to the internet. Please refresh your page and try again."
       )}
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

  # Content filtering event handlers
  def handle_event("validate_keyword_filter", %{"user_timeline_preference" => params}, socket) do
    current_user = socket.assigns.current_user

    # Get existing preferences or create a new struct for the form
    preferences =
      Timeline.get_user_timeline_preference(current_user) ||
        %Timeline.UserTimelinePreference{user_id: current_user.id}

    # Create changeset for form validation with the current selection
    changeset = Timeline.change_user_timeline_preference(preferences, params)

    # Update the form with the new changeset to reflect selection state
    filters_with_form = Map.put(socket.assigns.content_filters, :keyword_form, to_form(changeset))

    socket = assign(socket, :content_filters, filters_with_form)

    {:noreply, socket}
  end

  def handle_event("add_keyword_filter", %{"user_timeline_preference" => params}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Get the selected category from the form
    mute_keyword = params["mute_keywords"]

    if mute_keyword != "" do
      # Get current decrypted keywords
      current_filters = socket.assigns.content_filters
      current_keywords = current_filters.keywords || []

      # Check if category is already in the list
      if mute_keyword not in current_keywords do
        case ContentFilter.add_keyword_filter(current_user.id, mute_keyword, current_keywords,
               user: current_user,
               key: key
             ) do
          {:ok, new_prefs} ->
            # Refresh timeline with new filters and reset form
            socket =
              socket
              |> refresh_timeline_with_filters(new_prefs)
              |> assign_keyword_filter_form()
              |> put_flash(:success, "Filter added successfully")

            {:noreply, socket}

          {:error, reason} ->
            Logger.error("Failed to add keyword filter: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Failed to add filter")}
        end
      else
        {:noreply, put_flash(socket, :info, "This category is already filtered")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select a category")}
    end
  end

  def handle_event("remove_keyword_filter", %{"keyword" => keyword}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Get current decrypted keywords
    current_filters = socket.assigns.content_filters
    current_keywords = current_filters.keywords || []

    {:ok, new_prefs} =
      ContentFilter.remove_keyword_filter(current_user.id, keyword, current_keywords,
        user: current_user,
        key: key
      )

    socket = refresh_timeline_with_filters(socket, new_prefs)
    {:noreply, socket}
  end

  def handle_event("toggle_content_warning_filter", %{"type" => filter_type}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    filter_type_atom = String.to_existing_atom(filter_type)

    {:ok, new_prefs} =
      ContentFilter.toggle_content_warning_filter(current_user.id, filter_type_atom,
        user: current_user,
        key: key
      )

    # Generate flash message based on the toggle state
    flash_message =
      case {filter_type_atom, get_in(new_prefs, [:content_warnings, :hide_all]),
            get_in(new_prefs, [:content_warnings, :hide_mature])} do
        {:hide_all, true, _} ->
          "All posts with content warnings will now be hidden from your timeline."

        {:hide_all, false, _} ->
          "All posts with content warnings will now be visible in your timeline."

        {:hide_mature, _, true} ->
          "All posts marked as mature content (18+) will now be hidden from your timeline."

        {:hide_mature, _, false} ->
          "All posts marked as mature content (18+) will now be visible in your timeline."

        _ ->
          "Content warning preferences updated."
      end

    socket =
      socket
      |> refresh_timeline_with_filters(new_prefs)
      |> put_flash(:info, flash_message)

    {:noreply, socket}
  end

  def handle_event("clear_all_filters", _params, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    clear_prefs = %{
      keywords: [],
      content_warnings: %{hide_all: false},
      muted_users: []
    }

    {:ok, new_prefs} =
      ContentFilter.update_filter_preferences(current_user.id, clear_prefs,
        user: current_user,
        key: key
      )

    socket = refresh_timeline_with_filters(socket, new_prefs)
    {:noreply, put_flash(socket, :info, "All filters cleared")}
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

  def handle_event("scroll_to_top", _params, socket) do
    {:noreply, push_event(socket, "scroll-to-top", %{})}
  end

  def handle_event("load_more_posts", _params, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    current_options = socket.assigns.options

    # Set loading state
    socket = assign(socket, :load_more_loading, true)

    # Calculate next page parameters
    # CRITICAL FIX: When posts get trimmed by real-time inserts, pagination gets out of sync
    # We need to calculate the actual page based on what we have in the stream vs total available
    # This is what we actually have in the stream
    actual_loaded_count = socket.assigns.stream_limit
    posts_per_page = current_options.post_per_page

    # Calculate which page we should load next based on actual stream content
    next_page = div(actual_loaded_count, posts_per_page) + 1
    updated_options = Map.put(current_options, :post_page, next_page)

    # Always use fresh filter preferences for load more
    # Use cached content filters from socket assigns
    content_filter_prefs = socket.assigns.content_filters
    updated_options_with_filters = Map.put(updated_options, :filter_prefs, content_filter_prefs)

    new_posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, updated_options_with_filters)

        "connections" ->
          Timeline.list_connection_posts(current_user, updated_options_with_filters)

        "home" ->
          Timeline.list_user_own_posts(current_user, updated_options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, updated_options_with_filters)

        "groups" ->
          Timeline.list_group_posts(current_user, updated_options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, updated_options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Calculate updated counts and pagination
    new_loaded_count = actual_loaded_count + length(new_posts)

    # Increase stream limit to accommodate new posts loaded
    # This ensures real-time posts don't prune the posts user just loaded
    new_stream_limit = socket.assigns.stream_limit + length(new_posts)

    # CRITICAL FIX: Recalculate timeline counts to ensure accurate remaining count
    options_with_filters = Map.put(updated_options, :content_filter_prefs, content_filter_prefs)
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)

    # Add new posts to the existing stream (at the end)
    socket =
      new_posts
      |> Enum.reduce(socket, fn post, acc_socket ->
        stream_insert(acc_socket, :posts, post, at: -1)
      end)
      |> assign(:options, updated_options)
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:loaded_posts_count, new_loaded_count)
      |> assign(:current_page, next_page)
      # Update dynamic limit
      |> assign(:stream_limit, new_stream_limit)
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

    # Update the active tab immediately for responsive UI
    # Set loading_tab to show loading indicator on the clicked tab
    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:loading_tab, tab)
      |> assign(:timeline_data, AsyncResult.loading())

    # Prepare variables for async operation
    current_user_id = current_user.id
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)
    tab_for_async = tab

    # Start async operation to load tab data
    socket =
      socket
      |> assign(:options, options)
      |> assign(:load_more_loading, false)
      |> start_async(:load_timeline_data, fn ->
        # Load posts for the specific tab with content filtering
        posts =
          case tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "connections" ->
              Timeline.list_connection_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "home" ->
              Timeline.list_user_own_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "bookmarks" ->
              Timeline.list_user_bookmarks(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "groups" ->
              Timeline.list_group_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            _ ->
              user = Accounts.get_user!(current_user_id)

              Timeline.filter_timeline_posts(user, options_with_filters)
              |> apply_tab_filtering(tab_for_async, user)
          end

        # Update tab counts using proper counting logic with filter support
        user = Accounts.get_user!(current_user_id)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)

        # Return synchronized data
        %{
          posts: posts,
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          post_count: Timeline.timeline_post_count(user, options),
          loaded_posts_count: length(posts),
          current_page: 1,
          post_loading_list: Enum.with_index(posts, fn element, index -> {index, element} end)
        }
      end)

    {:noreply, socket}
  end

  def handle_event("retry_timeline_load", _params, socket) do
    # Re-trigger the async timeline data loading
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :filter_prefs, content_filter_prefs)

    current_user_id = current_user.id
    current_tab_for_async = current_tab

    socket =
      socket
      |> assign(:timeline_data, AsyncResult.loading())
      |> start_async(:load_timeline_data, fn ->
        # Load posts for the current active tab with content filtering
        posts =
          case current_tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "connections" ->
              Timeline.list_connection_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "home" ->
              Timeline.list_user_own_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "bookmarks" ->
              Timeline.list_user_bookmarks(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            "groups" ->
              Timeline.list_group_posts(
                Accounts.get_user!(current_user_id),
                options_with_filters
              )

            _ ->
              options_with_tab = Map.put(options_with_filters, :tab, current_tab_for_async)
              user = Accounts.get_user!(current_user_id)

              Timeline.filter_timeline_posts(user, options_with_tab)
              |> apply_tab_filtering(current_tab_for_async, user)
          end

        # Calculate all timeline counts with the SAME filtering options
        user = Accounts.get_user!(current_user_id)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)
        post_count = Timeline.timeline_post_count(user, options)

        # Return synchronized data
        %{
          posts: posts,
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          post_count: post_count,
          loaded_posts_count: length(posts),
          current_page: options.post_page,
          post_loading_list: Enum.with_index(posts, fn element, index -> {index, element} end)
        }
      end)

    {:noreply, socket}
  end

  def handle_event("bookmark_post", %{"id" => post_id}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        if Timeline.bookmarked?(current_user, post) do
          bookmark = Timeline.get_bookmark(current_user, post)

          case Timeline.delete_bookmark(bookmark, current_user) do
            {:ok, _bookmark} ->
              Accounts.track_user_activity(current_user, :interaction)
              content_filter_prefs = socket.assigns.content_filters
              options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
              timeline_counts = calculate_timeline_counts(current_user, options_with_filters)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: false
                })
                |> put_flash(:info, "Bookmark removed successfully.")

              socket =
                if current_tab == "bookmarks" do
                  stream_delete(socket, :posts, post)
                else
                  socket
                end

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to remove bookmark")}
          end
        else
          case Timeline.create_bookmark(current_user, post, %{}) do
            {:ok, _bookmark} ->
              Accounts.track_user_activity(current_user, :interaction)

              content_filter_prefs = socket.assigns.content_filters
              options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
              timeline_counts = calculate_timeline_counts(current_user, options_with_filters)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: true
                })
                |> put_flash(:success, "Post bookmarked successfully.")

              socket =
                if current_tab == "bookmarks" do
                  updated_post =
                    get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

                  stream_insert(socket, :posts, updated_post,
                    at: 0,
                    limit: @post_per_page_default
                  )
                else
                  socket
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
    key = socket.assigns.key

    # Decrypt in LiveView, pass plaintext to context
    decrypted_favs = decrypt_post_favs_list(post, current_user, key)

    if current_user.id not in decrypted_favs do
      {:ok, post} = Timeline.inc_favs(post)

      updated_favs = [current_user.id | decrypted_favs]

      # Get the existing post_key for encryption
      encrypted_post_key = get_post_key(post, current_user)

      case Timeline.update_post_fav(post, %{favs_list: updated_favs},
             user: current_user,
             key: key,
             post_key: encrypted_post_key
           ) do
        {:ok, updated_post} ->
          Accounts.track_user_activity(current_user, :interaction)

          socket =
            socket
            |> push_event("update_post_fav_count", %{
              post_id: updated_post.id,
              favs_count: updated_post.favs_count,
              is_liked: true
            })
            |> put_flash(:success, "You loved this post!")

          {:noreply, socket}

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
    key = socket.assigns.key

    # Decrypt in LiveView, pass plaintext to context
    decrypted_favs = decrypt_post_favs_list(post, current_user, key)

    if current_user.id in decrypted_favs do
      {:ok, post} = Timeline.decr_favs(post)

      # Remove current user from the decrypted list
      updated_favs = List.delete(decrypted_favs, current_user.id)

      # Get the existing post_key for encryption
      encrypted_post_key = get_post_key(post, current_user)

      case Timeline.update_post_fav(post, %{favs_list: updated_favs},
             user: current_user,
             key: key,
             post_key: encrypted_post_key
           ) do
        {:ok, updated_post} ->
          Accounts.track_user_activity(current_user, :interaction)

          socket =
            socket
            |> push_event("update_post_fav_count", %{
              post_id: updated_post.id,
              favs_count: updated_post.favs_count,
              is_liked: false
            })
            |> put_flash(:success, "You removed love from this post.")

          {:noreply, socket}

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
            {:ok, updated_reply} ->
              Accounts.track_user_activity(current_user, :interaction)

              socket =
                socket
                |> push_event("update_reply_fav_count", %{
                  reply_id: updated_reply.id,
                  favs_count: updated_reply.favs_count,
                  is_liked: true
                })
                |> put_flash(:success, "You loved this reply!")

              {:noreply, socket}

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
            {:ok, updated_reply} ->
              Accounts.track_user_activity(current_user, :interaction)

              socket =
                socket
                |> push_event("update_reply_fav_count", %{
                  reply_id: updated_reply.id,
                  favs_count: updated_reply.favs_count,
                  is_liked: false
                })
                |> put_flash(:success, "You removed love from this reply.")

              {:noreply, socket}

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

  def handle_event("repost", %{"id" => id, "body" => body, "username" => username}, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key
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

    post_shared_users = socket.assigns.post_shared_users

    # Decrypt reposts list to check if user already reposted
    decrypted_reposts = decrypt_post_reposts_list(post, user, key)

    if post.user_id != user.id && user.id not in decrypted_reposts do
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

      case Timeline.create_repost(repost_params,
             user: user,
             key: key,
             trix_key: decrypted_post_key
           ) do
        {:ok, repost} ->
          {:ok, post} = Timeline.inc_reposts(post)

          # Add user to decrypted reposts list
          updated_reposts = [user.id | decrypted_reposts]

          # Get the existing post_key for encryption
          encrypted_post_key = get_post_key(post, user)

          {:ok, _post} =
            Timeline.update_post_repost(
              post,
              %{reposts_list: updated_reposts},
              user: user,
              key: key,
              post_key: encrypted_post_key
            )

          # Track user activity for auto-status (reposting is user interaction)
          Accounts.track_user_activity(user, :interaction)

          # Follow same pattern as save_post - update stream and counts instead of page reload
          current_tab = socket.assigns.active_tab || "home"
          options = socket.assigns.options
          content_filters = socket.assigns.content_filters

          # Check if this repost should appear in the current tab
          should_show_post = post_matches_current_tab?(repost, current_tab, user)
          passes_content_filters = post_passes_content_filters?(repost, content_filters)

          socket =
            socket
            |> put_flash(:success, "Post reposted successfully.")
            |> push_event("update_post_repost_count", %{
              post_id: post.id,
              reposts_count: post.reposts_count,
              can_repost: false
            })

          socket =
            if should_show_post and passes_content_filters do
              # Add the repost to the top of the stream - same as handle_info
              socket
              |> stream_insert(:posts, repost, at: 0, limit: socket.assigns.stream_limit)
              |> recalculate_counts_after_new_post(user, options)
            else
              # Repost doesn't match current tab, just update counts
              socket
              |> recalculate_counts_after_new_post(user, options)
            end

          {:noreply, socket}

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

    image_urls =
      if post.image_urls do
        Enum.filter(post.image_urls, &is_binary/1)
      else
        []
      end

    socket =
      socket
      |> assign(:live_action, :edit_post)
      |> assign(:return_url, return_url)
      |> assign(:post, post)
      |> assign(:image_urls, image_urls)

    {:noreply, socket}
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    if post.user_id == current_user.id do
      user_post = Timeline.get_user_post(post, current_user)
      replies = post.replies

      case Timeline.delete_post(post, user: current_user) do
        {:ok, post} ->
          # Invalidate cache for the post creator (since they don't receive the PubSub message)
          Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

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

          {:noreply, socket |> stream_delete(:posts, post)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete post. Please try again.")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You are not authorized to delete this post.")}
    end
  end

  def handle_event("reply", %{"id" => id, "url" => return_url}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user

    if can_reply?(post, current_user) do
      socket =
        socket
        |> assign(:live_action, :reply)
        |> assign(:return_url, return_url)
        |> assign(:post, post)
        |> assign(:reply, %Reply{})
        |> assign(:image_urls, [])

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:warning, "You cannot reply to this post.")

      {:noreply, socket}
    end
  end

  def handle_event("edit_reply", %{"id" => id, "url" => return_url}, socket) do
    reply = Timeline.get_reply!(id)

    image_urls =
      if reply.image_urls do
        Enum.filter(reply.image_urls, &is_binary/1)
      else
        []
      end

    socket =
      socket
      |> assign(:live_action, :reply_edit)
      |> assign(:return_url, return_url)
      |> assign(:post, reply.post)
      |> assign(:reply, reply)
      |> assign(:image_urls, image_urls)

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
          updated_post =
            get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

          socket =
            socket
            |> put_flash(:success, "Reply deleted successfully.")
            |> stream_insert(:posts, updated_post, at: -1)
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

          {:noreply, socket}

        {:error, message} ->
          {:noreply, put_flash(socket, :warning, message)}
      end
    else
      {:noreply, put_flash(socket, :warning, "You do not have permission to delete this Reply.")}
    end
  end

  def handle_event(
        "report_reply",
        %{
          "id" => reply_id,
          "reported-user-id" => reported_user_id
        },
        socket
      ) do
    # For reply reports, we'll use the existing post report infrastructure
    # but adapt it for replies by including reply context in the report details
    reply = Timeline.get_reply!(reply_id)

    # Redirect to the post report with reply context
    socket =
      socket
      |> assign(:show_report_modal, true)
      |> assign(:report_post_id, reply.post_id)
      |> assign(:report_user_id, reported_user_id)
      |> assign(:report_reply_context, %{
        reply_id: reply_id
      })

    {:noreply, socket}
  end

  def handle_event(
        "block_user_from_reply",
        %{"id" => user_id, "user-name" => user_name, "reply-id" => reply_id},
        socket
      ) do
    # For reply blocks, get the reply to find the post_id
    reply = Timeline.get_reply!(reply_id)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Check if user is already blocked and get block details
    existing_block = Accounts.get_user_block(current_user, user_id)

    # Decrypt existing reason if block exists
    decrypted_reason =
      if existing_block && existing_block.reason do
        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          existing_block.reason,
          current_user,
          key
        )
      else
        ""
      end

    # Determine smart default block type (suggest replies_only for reply context)
    default_block_type =
      cond do
        existing_block -> Atom.to_string(existing_block.block_type)
        # Smart default for reply blocks
        true -> "replies_only"
      end

    # Use the existing block infrastructure with post context
    socket =
      socket
      |> assign(:show_block_modal, true)
      |> assign(:block_user_id, user_id)
      |> assign(:block_user_name, user_name)
      |> assign(:block_post_id, reply.post_id)
      |> assign(:existing_block, existing_block)
      |> assign(:block_decrypted_reason, decrypted_reason)
      |> assign(:block_default_type, default_block_type)
      |> assign(:block_update?, !!existing_block)
      |> assign(:block_reply_context, %{
        reply_id: reply_id
      })

    {:noreply, socket}
  end

  def handle_event(
        "remove_shared_user",
        %{"post-id" => post_id, "user-id" => user_id, "shared-username" => shared_username},
        socket
      ) do
    current_user = socket.assigns.current_user

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
    current_user = socket.assigns.current_user
    key = socket.assigns.key

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
        "delete_user_post",
        %{"post-id" => post_id, "user-id" => user_id, "shared-username" => shared_username},
        socket
      ) do
    current_user = socket.assigns.current_user
    user_post = Timeline.get_user_post_by_post_id_and_user_id!(post_id, user_id)

    Timeline.delete_user_post(user_post,
      user: current_user,
      shared_username: shared_username
    )

    {:noreply, socket}
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
    current_user = socket.assigns.current_user
    post_id = report_params["post_id"]
    reported_user_id = report_params["reported_user_id"]
    reply_context = socket.assigns[:report_reply_context]

    # Add reply_id to params if this is a reply report (instead of details enhancement)
    enhanced_params =
      if reply_context && Map.has_key?(reply_context, :reply_id) do
        report_params
        |> Map.put("reply_id", reply_context.reply_id)
      else
        report_params
      end

    case {Timeline.get_post(post_id), Accounts.get_user(reported_user_id)} do
      {%Timeline.Post{} = post, %Accounts.User{} = reported_user} ->
        # Determine what was reported for better user feedback
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
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    content_filters = socket.assigns.content_filters

    # Check if user is already blocked using existing blocked_users list
    blocked_user_ids = content_filters[:blocked_users] || []
    is_blocked = user_id in blocked_user_ids

    # Get existing block details with decryption if needed
    {existing_block, decrypted_reason} =
      if is_blocked do
        case Accounts.get_user_block(current_user, user_id) do
          %UserBlock{} = block ->
            # Decrypt the reason if it exists
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

    # Determine smart default block type
    default_block_type =
      cond do
        existing_block -> Atom.to_string(existing_block.block_type)
        # Default for new blocks
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
    current_user = socket.assigns.current_user
    key = socket.assigns.key
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

            # Real-time timeline refresh without full navigation - optimal for our distributed architecture

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

  # Image modal event handlers
  def handle_event(
        "show_timeline_images",
        %{"post_id" => post_id, "image_index" => image_index, "images" => images},
        socket
      ) do
    current_user = socket.assigns.current_user

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        # Check if user can download images
        can_download = check_download_permission(post, current_user)

        {:noreply,
         socket
         |> assign(:show_image_modal, true)
         |> assign(:current_images, images)
         |> assign(:current_image_index, image_index)
         |> assign(:current_post_for_images, post)
         |> assign(:can_download_images, can_download)}

      nil ->
        {:noreply, put_flash(socket, :error, "Post not found")}
    end
  end

  def handle_event("show_timeline_images", %{"post_id" => post_id} = _params, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        # Check if user can see this post and download images
        can_download = check_download_permission(post, current_user)

        # Get decrypted image URLs
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

  def handle_event("download_timeline_image", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_user = socket.assigns.current_user

    if socket.assigns.can_download_images do
      case socket.assigns.current_post_for_images do
        %Mosslet.Timeline.Post{} = post ->
          # Generate a secure token for the download
          token =
            Phoenix.Token.sign(MossletWeb.Endpoint, "timeline_image_download", %{
              "post_id" => post.id,
              "image_index" => index,
              "user_id" => current_user.id
            })

          # Generate download URL
          download_url = ~p"/app/timeline/images/download/#{token}"

          {:noreply,
           socket
           |> push_event("download-file", %{
             url: download_url,
             filename: "timeline-image-#{index + 1}"
           })
           |> push_event("restore-body-scroll", %{})
           |> put_flash(:info, "Downloading image...")}

        nil ->
          {:noreply, put_flash(socket, :error, "No post selected for image download")}
      end
    else
      {:noreply,
       put_flash(socket, :error, "You don't have permission to download images from this post")}
    end
  end

  def handle_async(:load_timeline_data, {:ok, timeline_result}, socket) do
    # Update all assigns with synchronized data from our async operation
    # All data comes from the same query context, ensuring perfect synchronization
    %{
      posts: posts,
      timeline_counts: timeline_counts,
      unread_counts: unread_counts,
      post_count: post_count,
      loaded_posts_count: loaded_posts_count,
      current_page: current_page,
      post_loading_list: post_loading_list
    } = timeline_result

    {:noreply,
     socket
     |> assign(:timeline_data, AsyncResult.ok(socket.assigns.timeline_data, timeline_result))
     |> assign(:loading_tab, nil)
     |> assign(:post_loading_list, post_loading_list)
     |> assign(:post_count, post_count)
     |> assign(:timeline_counts, timeline_counts)
     |> assign(:unread_counts, unread_counts)
     |> assign(:loaded_posts_count, loaded_posts_count)
     |> assign(:current_page, current_page)
     |> stream(:posts, posts, reset: true)}
  end

  def handle_async(:load_timeline_data, {:exit, reason}, socket) do
    # Handle async operation failure gracefully with beautiful error state
    Logger.error("Timeline data loading failed: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:timeline_data, AsyncResult.failed(socket.assigns.timeline_data, {:exit, reason}))
     |> assign(:loading_tab, nil)
     |> assign(:timeline_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0, discover: 0})
     |> assign(:unread_counts, %{home: 0, connections: 0, groups: 0, bookmarks: 0, discover: 0})
     |> assign(:loaded_posts_count, 0)
     |> assign(:current_page, 1)
     |> assign(:post_count, 0)
     |> stream(:posts, [], reset: true)}
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

  def handle_async(:remove_shared_user, {:ok, _result}, socket) do
    {:noreply, socket}
  end

  def handle_async(:remove_shared_user, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:removing_shared_user_id, nil)
      |> put_flash(:error, "Failed to remove shared user: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:add_shared_user, {:ok, {:ok, _user_post}}, socket) do
    {:noreply, assign(socket, :adding_shared_user, nil)}
  end

  def handle_async(:add_shared_user, {:ok, {:error, _reason}}, socket) do
    socket =
      socket
      |> assign(:adding_shared_user, nil)
      |> put_flash(:error, "Failed to share post with user")

    {:noreply, socket}
  end

  def handle_async(:add_shared_user, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:adding_shared_user, nil)
      |> put_flash(:error, "Failed to share post with user: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:url_preview_task, {:ok, {:ok, preview}}, socket) do
    socket =
      socket
      |> assign(url_preview: preview, url_preview_loading: false)
      |> normalize_url_in_post_body(preview)

    {:noreply, socket}
  end

  def handle_async(:url_preview_task, {:ok, {:error, :rate_limit_per_minute}}, socket) do
    socket =
      socket
      |> assign(url_preview: nil, url_preview_loading: false)
      |> put_flash(:error, "Too many URL preview requests. Please wait a minute and try again.")

    {:noreply, socket}
  end

  def handle_async(:url_preview_task, {:ok, {:error, :rate_limit_per_hour}}, socket) do
    socket =
      socket
      |> assign(url_preview: nil, url_preview_loading: false)
      |> put_flash(:error, "URL preview rate limit reached. Please try again later.")

    {:noreply, socket}
  end

  def handle_async(:url_preview_task, {:ok, {:error, :private_ip}}, socket) do
    socket =
      socket
      |> assign(url_preview: nil, url_preview_loading: false)
      |> put_flash(:warning, "Cannot preview URLs pointing to private networks.")

    {:noreply, socket}
  end

  def handle_async(:url_preview_task, {:ok, {:error, _}}, socket) do
    {:noreply, assign(socket, url_preview: nil, url_preview_loading: false)}
  end

  def handle_async(:url_preview_task, {:exit, _reason}, socket) do
    {:noreply, assign(socket, url_preview: nil, url_preview_loading: false)}
  end

  # Helper function to update stored visibility groups when they change in the form
  defp maybe_update_visibility_groups(socket, post_params) do
    case post_params["visibility_groups"] do
      nil ->
        socket

      groups when is_list(groups) ->
        socket
        |> assign(:selected_visibility_groups, groups)
        # Clear selected users when groups are selected to avoid confusion
        |> assign(:selected_visibility_users, [])

      _ ->
        socket
    end
  end

  # Helper function to update stored visibility users when they change in the form
  defp maybe_update_visibility_users(socket, post_params) do
    case post_params["visibility_users"] do
      nil ->
        socket

      users when is_list(users) ->
        socket
        |> assign(:selected_visibility_users, users)
        # Clear selected groups when users are selected to avoid confusion
        |> assign(:selected_visibility_groups, [])

      _ ->
        socket
    end
  end

  # Helper function to update interaction control assigns when form values are available
  defp maybe_update_interaction_controls(socket, post_params) do
    socket
    |> maybe_update_assign(:allow_replies, post_params["allow_replies"])
    |> maybe_update_assign(:allow_shares, post_params["allow_shares"])
    |> maybe_update_assign(:allow_bookmarks, post_params["allow_bookmarks"])
    |> maybe_update_assign(:is_ephemeral, post_params["is_ephemeral"])
    |> maybe_update_assign(:mature_content, post_params["mature_content"])
    |> maybe_update_assign(:require_follow_to_reply, post_params["require_follow_to_reply"])
    |> maybe_update_assign(:local_only, post_params["local_only"])
    |> maybe_update_string_assign(:expires_at_option, post_params["expires_at_option"])
  end

  # Helper to update an assign only if the value is present (not nil)
  defp maybe_update_assign(socket, assign_key, value) do
    case value do
      nil -> socket
      "true" -> assign(socket, assign_key, true)
      "false" -> assign(socket, assign_key, false)
      true -> assign(socket, assign_key, true)
      false -> assign(socket, assign_key, false)
      _ -> socket
    end
  end

  # Helper to update a string assign only if the value is present and non-empty
  defp maybe_update_string_assign(socket, assign_key, value) do
    case value do
      nil -> socket
      "" -> socket
      val when is_binary(val) -> assign(socket, assign_key, val)
      _ -> socket
    end
  end

  # Helper function to check if a post passes content filters
  defp post_passes_content_filters?(post, content_filters) do
    cw_settings = content_filters[:content_warnings] || %{}
    hide_all = Map.get(cw_settings, :hide_all, false)
    hide_mature = Map.get(cw_settings, :hide_mature, false)

    # Check content warning filters
    content_warning_pass =
      if hide_all do
        # Hide all content warnings AND mature content
        not post.content_warning? and not post.mature_content
      else
        # Don't filter based on content warnings
        true
      end

    # Check mature content filters (independent of content warnings)
    # hide_all already handles mature content
    mature_content_pass =
      if hide_mature and not hide_all do
        not post.mature_content
      else
        true
      end

    # Check blocked users
    blocked_users_pass =
      if content_filters[:blocked_users] && content_filters[:blocked_users] != [] do
        post.user_id not in content_filters[:blocked_users]
      else
        true
      end

    # Check muted users - handle both legacy format (user IDs) and hydrated format (user objects)
    muted_users_pass =
      if content_filters[:muted_users] && content_filters[:muted_users] != [] do
        muted_user_ids =
          extract_user_ids_from_muted_users_content_filter(content_filters[:muted_users])

        post.user_id not in muted_user_ids
      else
        true
      end

    # Post passes if it passes all filters
    content_warning_pass and mature_content_pass and blocked_users_pass and muted_users_pass
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

  defp add_shared_users_list_for_new_post(post_params, shared_users, options) do
    visibility_setting = options[:visibility_setting]
    current_user = options[:current_user]
    key = options[:key]

    cond do
      # If visibility is "connections" and no specific groups/users are selected,
      # automatically use all shared_users (all connections)
      visibility_setting == "connections" &&
        Enum.empty?(post_params["visibility_groups"] || []) &&
          Enum.empty?(post_params["visibility_users"] || []) ->
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

      # For specific groups or users, filter the shared_users list
      true ->
        # Get the visibility_groups and visibility_users from post_params
        visibility_groups = post_params["visibility_groups"] || []
        visibility_users = post_params["visibility_users"] || []

        # Filter shared_users based on what's selected
        filtered_shared_users =
          if !Enum.empty?(visibility_groups) || !Enum.empty?(visibility_users) do
            # Implement filtering based on visibility groups and users
            resolve_visibility_to_shared_users(
              visibility_groups,
              visibility_users,
              visibility_setting,
              current_user,
              key
            )
          else
            # Use existing shared_users from socket assigns
            shared_users
          end

        Map.update(
          post_params,
          "shared_users",
          Enum.map(filtered_shared_users, fn shared_user ->
            Map.from_struct(shared_user)
          end),
          fn _shared_users_list ->
            Enum.map(filtered_shared_users, fn shared_user ->
              Map.from_struct(shared_user)
            end)
          end
        )
    end
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
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(%{"post_sort_by" => sort_by})
       when sort_by in ~w(id inserted_at) do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

  defp valid_sort_order(%{"sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_existing_atom(sort_order)
  end

  defp valid_sort_order(%{"post_sort_order" => sort_order})
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
        Timeline.list_discover_posts(current_user, %{})

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
        # Never show current user's own posts in connections tab (including their reposts)
        if post.user_id == current_user.id do
          false
        else
          # Show posts from connected users, but with specific visibility rules
          connection_user_ids =
            Accounts.get_all_confirmed_user_connections(current_user.id)
            |> Enum.map(& &1.reverse_user_id)
            |> Enum.uniq()

          cond do
            # Always exclude private posts
            post.visibility == :private ->
              false

            # Exclude group-specific posts (they should only appear in groups tab)
            post.visibility == :specific_groups ->
              false

            # For specific_users posts, only show if current user is in shared_users list
            post.visibility == :specific_users ->
              post.user_id in connection_user_ids and
                Enum.any?(post.shared_users || [], fn shared_user ->
                  shared_user.user_id == current_user.id
                end)

            # For other visibility types (public, connections), show if from connected user
            # OR if it's a repost shared with the current user
            true ->
              post.user_id in connection_user_ids or
                (post.repost == true and
                   Ecto.assoc_loaded?(post.user_posts) and
                   Enum.any?(post.user_posts, fn up -> up.user_id == current_user.id end))
          end
        end

      "groups" ->
        # Show posts from groups the user belongs to
        post.visibility == :specific_groups

      "discover" ->
        # Show public posts
        post.visibility == :public

      "bookmarks" ->
        Timeline.bookmarked?(current_user, post)

      _ ->
        false
    end
  end

  # Helper function to recalculate counts after any post change (create/update/delete)
  defp recalculate_counts_after_post_change(
         socket,
         current_user,
         options,
         increment_loaded
       ) do
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    socket =
      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)

    if increment_loaded do
      assign(socket, :loaded_posts_count, socket.assigns.loaded_posts_count + 1)
    else
      socket
    end
  end

  defp recalculate_counts_after_new_post(socket, current_user, options) do
    recalculate_counts_after_post_change(socket, current_user, options, true)
  end

  defp recalculate_counts_after_post_update(socket, current_user, options) do
    recalculate_counts_after_post_change(socket, current_user, options, false)
  end

  # Generic function to add post notifications (create/update/delete)
  defp add_post_notification(socket, post, current_user, action) do
    # we don't show notifications for the current user's own posts
    if post.user_id === current_user.id do
      socket
    else
      session_key = socket.assigns.key
      author_name = get_safe_post_author_name(post, current_user, session_key)

      message =
        case action do
          "new" ->
            "New post from #{author_name}"

          "updated" ->
            "Post updated by #{author_name}"

          "deleted" ->
            "Post deleted by #{author_name}"

          "reposted" ->
            "Post reposted by #{author_name}"

          "shared" ->
            "Post from #{author_name} shared with you"

          _ ->
            "Post from #{author_name}"
        end

      # Add a gentle flash message
      put_flash(socket, :info, message)
    end
  end

  # Backward compatibility alias
  defp add_new_post_notification(socket, post, current_user) do
    add_post_notification(socket, post, current_user, "new")
  end

  defp add_new_share_post_notification(socket, post, current_user) do
    add_post_notification(socket, post, current_user, "shared")
  end

  # Reply notification function
  defp add_reply_notification(socket, reply, current_user, action) do
    # Don't show notifications for the current user's own replies
    if reply.user_id === current_user.id do
      socket
    else
      # Get reply author name safely
      author_name = get_safe_reply_author_name(reply, current_user, socket.assigns.key)

      message =
        case action do
          "created" -> "New reply from #{author_name}"
          "updated" -> "Reply updated by #{author_name}"
          _ -> "Reply from #{author_name}"
        end

      # Add a gentle flash message
      put_flash(socket, :info, message)
    end
  end

  # Safe version of get_post_author_name that returns the author name string
  defp get_safe_post_author_name(post, current_user, key) do
    if post.user_id == current_user.id do
      # Current user's own post - use their name
      case username(current_user, key) do
        name when is_binary(name) -> name
        :failed_verification -> "You"
        _ -> "You"
      end
    else
      # For other users' posts, respect privacy - use "Private Author"
      # This applies even to public posts where the author hasn't shared
      # their identity with the current user (e.g., group posts, discover posts)
      "@" <> username(post, current_user, key)
    end
  end

  # Helper function to add subtle tab indicators for new posts in other tabs
  defp add_subtle_tab_indicator(socket, current_user, options) do
    # Update unread counts to show there are new posts in other tabs
    # Use cached content filters from socket assigns
    content_filter_prefs = socket.assigns.content_filters
    options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)
    assign(socket, :unread_counts, unread_counts)
  end

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  # Helper function to calculate remaining posts for the current tab (accounts for content filtering)
  defp calculate_remaining_posts(timeline_counts, active_tab, loaded_posts_count) do
    # Use filtered_total_posts instead of raw database counts
    # This ensures the "load more" button reflects actual available posts after filtering
    filtered_total_posts = Map.get(timeline_counts, String.to_existing_atom(active_tab), 0)
    max(0, filtered_total_posts - loaded_posts_count)
  end

  # Helper function to update timeline counts only when they actually change
  defp maybe_update_timeline_counts(socket, current_user, options_with_filters, force \\ false) do
    if force || should_recalculate_counts?(socket) do
      timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
      unread_counts = calculate_unread_counts(current_user, options_with_filters)

      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
    else
      socket
    end
  end

  # Determine if timeline counts need recalculation
  defp should_recalculate_counts?(socket) do
    # Only recalculate if counts are empty/missing or if it's been a while
    counts = socket.assigns[:timeline_counts] || %{}
    Map.values(counts) |> Enum.all?(&(&1 == 0))
  end

  # Helper function to calculate timeline counts for all tabs
  # Now supports accurate filtered counts for "load more" functionality
  defp calculate_timeline_counts(current_user, options) do
    # Get content filter preferences if available in assigns
    content_filter_prefs =
      options[:content_filter_prefs] ||
        load_and_decrypt_content_filters(current_user, options[:key])

    counts = %{
      # All counts now support filtering for accurate "load more" estimates
      home: Timeline.count_user_own_posts(current_user, content_filter_prefs),
      connections: Timeline.count_user_connection_posts(current_user, content_filter_prefs),
      groups: Timeline.count_group_posts(current_user, content_filter_prefs),
      bookmarks: Timeline.count_user_bookmarks(current_user, content_filter_prefs),
      discover: Timeline.count_discover_posts(current_user, content_filter_prefs)
    }

    counts
  end

  # Helper function to calculate unread counts for all tabs
  defp calculate_unread_counts(current_user, options) do
    # Get content filter preferences from options
    content_filter_prefs = options[:content_filter_prefs] || %{}

    %{
      # Home tab: only show unread posts from the current user (since home only shows user's own posts)
      home: Timeline.count_unread_user_own_posts(current_user, content_filter_prefs),
      # Connections tab: only show unread posts from connected users (excluding current user)
      connections: Timeline.count_unread_connection_posts(current_user, content_filter_prefs),
      # Groups tab: only show unread posts with specific_groups visibility
      groups: Timeline.count_unread_group_posts(current_user, content_filter_prefs),
      # Discover tab: only show unread public posts
      discover: Timeline.count_unread_discover_posts(current_user, content_filter_prefs),
      # Bookmarks tab: only show unread bookmarked posts
      bookmarks: Timeline.count_unread_bookmarked_posts(current_user, content_filter_prefs)
    }
  end

  defp get_file_key_from_remove_event(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split(".")
    |> List.first()
  end

  # Helper function to get the post author's avatar
  defp get_post_author_avatar(post, current_user, key) do
    cond do
      post.user_id == current_user.id ->
        # Current user's own post - use their avatar
        if show_avatar?(current_user),
          do: maybe_get_user_avatar(current_user, key) || mosslet_logo_for_theme(),
          else: "/images/logo.svg"

      true ->
        # Other user's post - get their avatar via connection
        user_connection = get_uconn_for_shared_item(post, current_user)

        if show_avatar?(user_connection) do
          case maybe_get_avatar_src(post, current_user, key, []) do
            avatar when is_binary(avatar) and avatar != "" -> avatar
            _ -> mosslet_logo_for_theme()
          end
        else
          "/images/logo.svg"
        end
    end
  end

  # Helper function to get the post author's status if visible to current user
  # REPLACED: Now uses consolidated StatusHelpers for consistency
  defp get_post_author_status(post, current_user, key) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        case get_user_status_info(post_author, current_user, key) do
          %{status: status} when is_binary(status) -> status
          _ -> nil
        end

      nil ->
        # User account not found
        nil
    end
  end

  # Helper function to get the post author's status message if visible to current user
  # Uses consolidated StatusHelpers for consistency
  defp get_post_author_status_message(post, current_user, key) do
    case Accounts.get_user_with_preloads(post.user_id) do
      %{} = post_author ->
        get_user_status_message(post_author, current_user, key)

      nil ->
        # User account not found
        nil
    end
  end

  # REMOVED: can_see_post_author_status? function - now handled by StatusHelpers.get_user_status_info/3
  # This provides consistent privacy checking across the entire application

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
              # we respect the user's preference for displaying their name
              if uconn.connection.profile && uconn.connection.profile.show_name? do
                case decr_uconn(uconn.connection.name, current_user, uconn.key, key) do
                  name when is_binary(name) -> name
                  # User chose to keep identity private
                  :failed_verification -> "Private Author"
                end
              else
                case decr_uconn(uconn.connection.username, current_user, uconn.key, key) do
                  username when is_binary(username) -> username
                  # User chose to keep identity private
                  :failed_verification -> "Private Author"
                end
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

  # Helper function to check if the current user has liked a post
  defp get_post_liked_status(post, current_user, key) do
    # If we don't have a key, we can't decrypt, so assume not liked
    if is_nil(key) do
      false
    else
      decrypted_favs = decrypt_post_favs_list(post, current_user, key)
      current_user.id in decrypted_favs
    end
  end

  # Helper function to check if a post is unread by the current user
  defp get_post_unread_status(post, current_user) do
    cond do
      Ecto.assoc_loaded?(post.user_post_receipts) ->
        case Enum.find(post.user_post_receipts || [], fn receipt ->
               receipt.user_id == current_user.id
             end) do
          # No receipt = treat as unread
          nil -> true
          # Use receipt status
          %{is_read?: is_read} -> !is_read
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

  defp get_decrypted_share_note(post, current_user, key) do
    if Ecto.assoc_loaded?(post.user_posts) do
      user_post = Enum.find(post.user_posts, fn up -> up.user_id == current_user.id end)

      if user_post && user_post.share_note do
        post_key = get_post_key(post, current_user)
        decr_item(user_post.share_note, current_user, post_key, key, post, "body")
      else
        nil
      end
    else
      nil
    end
  end

  # Helper function to check if current user can repost (with encrypted reposts_list support)
  defp can_repost_with_decryption?(post, current_user, key) do
    cond do
      # If sharing is disabled for this post
      !post.allow_shares -> false
      # If user is the post author, they cannot repost their own content
      post.user_id == current_user.id -> false
      # If post is ephemeral, then there are no reposts allowed
      post.is_ephemeral -> false
      # If user has already reposted this post (# Decrypt reposts list and check if user already reposted)
      current_user.id in decrypt_post_reposts_list(post, current_user, key) -> false
      # Otherwise, check if sharing is allowed
      true -> post.allow_shares
    end
  end

  # Helper function to process uploaded photos using Tigris.ex encryption
  # Returns {upload_paths, trix_key} tuple for idiomatic Elixir/Phoenix
  defp process_uploaded_photos(socket, _current_user, _key) do
    completed_uploads = socket.assigns.completed_uploads

    if completed_uploads == [] do
      {[], nil}
    else
      trix_key = socket.assigns[:composer_trix_key]

      upload_results =
        Enum.map(completed_uploads, fn upload ->
          actual_trix_key = trix_key || upload.trix_key

          binary = File.read!(upload.temp_path)

          case Mosslet.FileUploads.ImageUploadWriter.upload_to_storage(
                 binary,
                 actual_trix_key
               ) do
            {:ok, file_path} ->
              cleanup_temp_upload(upload.temp_path)
              {file_path, actual_trix_key}

            {:error, reason} ->
              Logger.error("📷 PROCESS_UPLOADED_PHOTOS: Upload failed: #{inspect(reason)}")
              nil
          end
        end)

      successful_results = Enum.filter(upload_results, &(&1 != nil))

      case successful_results do
        [] ->
          {[], trix_key}

        [{_first_path, first_trix_key} | _] ->
          paths = Enum.map(successful_results, fn {path, _key} -> path end)
          {paths, first_trix_key}
      end
    end
  end

  # Helper functions for mixed encrypted/plaintext data during transition
  # Helper function to decrypt favs_list using the same pattern as UserTimelinePreference
  # Handles both encrypted and plaintext user IDs with idiomatic Elixir pattern matching
  defp decrypt_post_favs_list(post, user, key) do
    case post.favs_list do
      nil ->
        []

      [] ->
        []

      list when is_list(list) ->
        # Handle different visibility types for public vs private posts
        encrypted_post_key =
          case post.visibility do
            # Public posts use server key
            :public -> get_post_key(post)
            # Private/connections posts use user key
            _ -> get_post_key(post, user)
          end

        if is_nil(encrypted_post_key) do
          # Can't decrypt without the key, return empty list
          []
        else
          case post.visibility do
            :public ->
              # FIXED: For public posts, decrypt the post_key first, then use that to decrypt the favs
              # This matches how Post.favs_changeset encrypts the data with the decrypted post_key
              case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
                decrypted_post_key when is_binary(decrypted_post_key) ->
                  # Now decrypt each user_id in the list using the raw post_key
                  Enum.map(list, fn user_id ->
                    # Try to decrypt first (assume encrypted), fallback to plaintext
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} ->
                        decrypted_id

                      _ ->
                        # Decryption failed, assume it's already plaintext (legacy data)
                        user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  # Could not decrypt the post_key, return empty list
                  []
              end

            _ ->
              # For private/connections posts, decrypt the post_key first
              case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                     encrypted_post_key,
                     user,
                     key
                   ) do
                {:ok, decrypted_post_key} ->
                  # Now decrypt each user_id in the list
                  Enum.map(list, fn user_id ->
                    # Try to decrypt first (assume encrypted), fallback to plaintext
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} ->
                        decrypted_id

                      _ ->
                        # Decryption failed, assume it's already plaintext (legacy data)
                        user_id
                    end
                  end)
                  # Remove any nil values
                  |> Enum.reject(&is_nil/1)

                _ ->
                  # Could not decrypt the post_key, return empty list
                  []
              end
          end
        end
    end
  end

  # Helper function to decrypt reposts_list using the same pattern as UserTimelinePreference
  # Handles both encrypted and plaintext user IDs with idiomatic Elixir pattern matching
  defp decrypt_post_reposts_list(post, user, key) do
    case post.reposts_list do
      nil ->
        []

      [] ->
        []

      list when is_list(list) ->
        # Handle different visibility types for public vs private posts
        encrypted_post_key =
          case post.visibility do
            # Public posts use server key
            :public -> get_post_key(post)
            # Private/connections posts use user key
            _ -> get_post_key(post, user)
          end

        if is_nil(encrypted_post_key) do
          # Can't decrypt without the key, return empty list
          []
        else
          case post.visibility do
            :public ->
              # FIXED: For public posts, decrypt the post_key first, then use that to decrypt the reposts
              # This matches how Post.change_post_to_repost_changeset encrypts the data with the decrypted post_key
              case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
                decrypted_post_key when is_binary(decrypted_post_key) ->
                  # Now decrypt each user_id in the list using the raw post_key
                  Enum.map(list, fn user_id ->
                    # Try to decrypt first (assume encrypted), fallback to plaintext
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} ->
                        decrypted_id

                      _ ->
                        # Decryption failed, assume it's already plaintext (legacy data)
                        user_id
                    end
                  end)
                  |> Enum.reject(&is_nil/1)

                _ ->
                  # Could not decrypt the post_key, return empty list
                  []
              end

            _ ->
              # For private/connections posts, decrypt the post_key first
              case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                     encrypted_post_key,
                     user,
                     key
                   ) do
                {:ok, decrypted_post_key} ->
                  # Now decrypt each user_id in the list
                  Enum.map(list, fn user_id ->
                    # Try to decrypt first (assume encrypted), fallback to plaintext
                    case Mosslet.Encrypted.Utils.decrypt(%{
                           key: decrypted_post_key,
                           payload: user_id
                         }) do
                      {:ok, decrypted_id} ->
                        decrypted_id

                      _ ->
                        # Decryption failed, assume it's already plaintext (legacy data)
                        user_id
                    end
                  end)
                  # Remove any nil values
                  |> Enum.reject(&is_nil/1)

                _ ->
                  # Could not decrypt the post_key, return empty list
                  []
              end
          end
        end
    end
  end

  # Helper functions for decrypting and formatting post data
  # All status-related functions have been moved to MossletWeb.Helpers.StatusHelpers for consistency

  defp get_decrypted_post_images(post, current_user, key) do
    cond do
      is_list(post.image_urls) and post.image_urls != [] ->
        encrypted_post_key =
          case post.visibility do
            :public -> get_post_key(post)
            _ -> get_post_key(post, current_user)
          end

        Enum.map(post.image_urls, fn encrypted_url ->
          decr_item(encrypted_url, current_user, encrypted_post_key, key, post, "body")
        end)

      true ->
        []
    end
  end

  defp get_decrypted_url_preview(post, current_user, key) do
    if post.url_preview && is_map(post.url_preview) do
      encrypted_post_key =
        case post.visibility do
          :public -> get_post_key(post)
          _ -> get_post_key(post, current_user)
        end

      d_post_key =
        case post.visibility do
          :public ->
            case Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(encrypted_post_key) do
              decrypted when is_binary(decrypted) -> decrypted
              _ -> nil
            end

          _ ->
            case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
                   encrypted_post_key,
                   current_user,
                   key
                 ) do
              {:ok, decrypted} -> decrypted
              _ -> nil
            end
        end

      if d_post_key do
        decrypted_preview =
          URLPreviewServer.decrypt_preview_with_key(post.url_preview, d_post_key)

        if decrypted_preview && decrypted_preview["url"] do
          url_hash =
            :crypto.hash(:sha512, decrypted_preview["url"]) |> Base.encode16(case: :lower)

          cache_preview_in_ets(url_hash, post.url_preview)
          decrypted_preview
        else
          nil
        end
      else
        nil
      end
    else
      nil
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
           Encrypted.Utils.decrypt(%{key: decrypted_key, payload: encrypted_image}) do
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

  defp cache_preview_in_ets(url_hash, encrypted_url_preview) do
    URLPreviewServer.cache_preview(url_hash, encrypted_url_preview)
  end

  defp format_post_timestamp(naive_datetime) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, naive_datetime, :second)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3_600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3_600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86_400)}d ago"
      true -> "#{div(diff_seconds, 604_800)}w ago"
    end
  end

  # Helper function to check if user has active content filters
  # Helper function to check if user has active content filters
  defp has_active_filters?(filters) do
    keywords_active = (filters.keywords || []) != []
    cw_active = Map.get(filters.content_warnings || %{}, :hide_all, false)
    mature_active = Map.get(filters.content_warnings || %{}, :hide_mature, false)
    users_active = (filters.muted_users || []) != []
    reposts_active = Map.get(filters, :hide_reposts, false)

    keywords_active || cw_active || mature_active || users_active || reposts_active
  end

  # Helper function to refresh timeline with new filters
  defp refresh_timeline_with_filters(socket, _new_prefs) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # CRITICAL: Invalidate timeline cache when filters change
    Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

    # Reload and decrypt content filters to get fresh state
    # Refresh content filters in socket assigns
    fresh_filters = load_and_decrypt_content_filters(current_user, key)

    # Hydrate the fresh filters with post_shared_users
    hydrated_filters = hydrate_content_filters(fresh_filters, socket.assigns.post_shared_users)

    socket =
      socket
      |> assign(:content_filters, hydrated_filters)

    socket =
      socket
      |> assign_keyword_filter_form()

    # Refresh current timeline posts with new filters applied
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options

    # CRITICAL FIX: Reset pagination when filters change to get accurate counts
    reset_options =
      options
      |> Map.put(:post_page, 1)
      # Use hydrated filters instead of fresh_filters
      |> Map.put(:filter_prefs, hydrated_filters)

    posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, reset_options)

        "connections" ->
          Timeline.list_connection_posts(current_user, reset_options)

        "home" ->
          Timeline.list_user_own_posts(current_user, reset_options)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, reset_options)

        _ ->
          Timeline.filter_timeline_posts(current_user, reset_options)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # CRITICAL FIX: Recalculate timeline counts with new filters
    options_with_filters = Map.put(reset_options, :content_filter_prefs, fresh_filters)
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    # CRITICAL FIX: Reset pagination state and update counts
    socket =
      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:options, reset_options)
      |> assign(:loaded_posts_count, length(posts))
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      |> stream(:posts, posts, reset: true)

    socket
  end

  # Helper function to load and decrypt content filters
  defp load_and_decrypt_content_filters(user, key) do
    # Get preferences
    case Timeline.get_user_timeline_preference(user) do
      %Timeline.UserTimelinePreference{} = prefs ->
        # Decrypt keywords - StringList gives us list of asymmetrically encrypted keywords
        decrypted_keywords =
          if prefs.mute_keywords && prefs.mute_keywords != [] do
            Enum.map(prefs.mute_keywords, fn encrypted_keyword ->
              # decrypt_user_data returns the decrypted string directly
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_keyword, user, key)
            end)
            # Remove failed decryptions
            |> Enum.reject(&is_nil/1)
          else
            []
          end

        # Decrypt muted users - StringList gives us list of asymmetrically encrypted user_ids
        decrypted_muted_users =
          if prefs.muted_users && prefs.muted_users != [] do
            Enum.map(prefs.muted_users, fn encrypted_user_id ->
              # decrypt_user_data returns the decrypted string directly
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_user_id, user, key)
            end)
            # Remove failed decryptions
            |> Enum.reject(&is_nil/1)
          else
            []
          end

        # Get blocked users from UserBlock table (no decryption needed - stored as plaintext IDs)
        blocked_user_ids = Timeline.get_blocked_user_ids(user)

        %{
          keywords: decrypted_keywords,
          muted_users: decrypted_muted_users,
          blocked_users: blocked_user_ids,
          content_warnings: %{
            hide_all: prefs.hide_content_warnings || false,
            hide_mature: prefs.hide_mature_content || false
          },
          hide_reposts: prefs.hide_reposts || false,
          raw_preferences: prefs
        }

      nil ->
        # No preferences found - return defaults, but still get blocked users
        blocked_user_ids = Timeline.get_blocked_user_ids(user)

        %{
          keywords: [],
          muted_users: [],
          blocked_users: blocked_user_ids,
          content_warnings: %{
            hide_all: false,
            hide_mature: false
          },
          hide_reposts: false,
          raw_preferences: nil
        }
    end
  end

  # Helper function to extract user IDs from muted users list for content filtering
  # Handles both legacy format (strings) and hydrated format (structs)
  defp extract_user_ids_from_muted_users_content_filter(muted_users) do
    Enum.map(muted_users, fn
      # Handle hydrated user objects
      %{user_id: user_id} when is_binary(user_id) -> user_id
      # Handle legacy user ID strings
      user_id when is_binary(user_id) -> user_id
      # Skip invalid entries
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Helper function to hydrate content filters with user objects
  defp hydrate_content_filters(content_filters, post_shared_users) do
    # Hydrate muted_users from IDs to user objects
    hydrated_muted_users = map_muted_users(content_filters.muted_users, post_shared_users)

    Map.put(content_filters, :muted_users, hydrated_muted_users)
  end

  # Helper function to map muted user IDs to user objects from the shared users list
  defp map_muted_users(muted_user_ids, post_shared_users) do
    # CRITICAL FIX: Ensure we're working with actual user ID strings, not corrupted data
    clean_user_ids =
      Enum.map(muted_user_ids, fn
        # If it's already a string (correct format), use it
        user_id when is_binary(user_id) -> user_id
        # If it's a map with user_id field, extract the user_id
        %{user_id: user_id} when is_binary(user_id) -> user_id
        # If it's a corrupted nested map, try to find the user_id
        %{user_id: %{user_id: user_id}} when is_binary(user_id) -> user_id
        # Last resort: try to extract id field
        %{id: user_id} when is_binary(user_id) -> user_id
        # If we can't extract a valid user_id, skip this entry
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.map(clean_user_ids, fn user_id ->
      # If found in shared users, use that data but create consistent structure
      case Enum.find(post_shared_users, &(&1.user_id == user_id)) do
        user_obj when not is_nil(user_obj) ->
          # Create a consistent structure with actual IDs, not structs
          %{
            id: user_obj.user_id,
            # Extract the actual user_id string
            user_id: user_obj.user_id,
            username: user_obj.username
          }

        nil ->
          # If not found in shared users, create a minimal object with just the ID
          # This handles cases where muted users are not in the user's connections
          %{id: user_id, user_id: user_id, username: "[Unknown User]"}
      end
    end)
  end

  # Helper function to assign keyword filter form
  defp assign_keyword_filter_form(socket) do
    current_user = socket.assigns.current_user

    # Get existing preferences or create a new struct for the form
    preferences =
      Timeline.get_user_timeline_preference(current_user) ||
        %Timeline.UserTimelinePreference{user_id: current_user.id}

    # Create changeset for form with empty mute_keywords selection using Timeline context
    changeset = Timeline.change_user_timeline_preference(preferences, %{"mute_keywords" => ""})

    # Create an updated content_filters map with the form
    current_filters = socket.assigns[:content_filters] || %{}
    filters_with_form = Map.put(current_filters, :keyword_form, to_form(changeset))

    assign(socket, :content_filters, filters_with_form)
  end

  # Helper function to resolve visibility groups and users to shared_users list
  defp resolve_visibility_to_shared_users(
         visibility_groups,
         visibility_users,
         visibility_setting,
         current_user,
         key
       ) do
    cond do
      # If visibility is "connections" and no specific groups/users are selected,
      # automatically share with all connections
      visibility_setting == "connections" &&
        Enum.empty?(visibility_groups) &&
          Enum.empty?(visibility_users) ->
        # Use the same format as the socket assigns for post_shared_users
        Accounts.get_all_confirmed_user_connections(current_user.id)
        |> Enum.map(fn user_connection ->
          # Get the other user in the connection
          other_user_id = user_connection.reverse_user_id

          # Get the decrypted username for display
          username =
            case decr_uconn(
                   user_connection.connection.username,
                   current_user,
                   user_connection.key,
                   key
                 ) do
              :failed_verification -> "[encrypted]"
              "" -> "[encrypted]"
              decrypted -> decrypted
            end

          # Return the same structure as Post.SharedUser
          %Post.SharedUser{
            user_id: other_user_id,
            username: username,
            sender_id: current_user.id
          }
        end)

      # Handle specific groups and users as before
      true ->
        # Resolve visibility groups to user connections
        user_connections =
          if visibility_groups != [] do
            # Get fresh user data with visibility groups
            fresh_user = Mosslet.Accounts.get_user!(current_user.id)

            visibility_groups
            |> Enum.flat_map(fn group_id ->
              case find_group_by_id(fresh_user.visibility_groups, group_id) do
                %{connection_ids: connection_ids} when is_list(connection_ids) ->
                  resolve_connections_from_user_connection_ids(connection_ids, current_user, key)

                _ ->
                  []
              end
            end)
            |> Enum.uniq()
          else
            if visibility_users != [] do
              visibility_users
              |> Enum.map(fn user_id ->
                Accounts.get_user_connection_between_users(user_id, current_user.id)
              end)
              |> Enum.filter(&(&1 != nil))
            else
              []
            end
          end

        # Convert user connections to shared_user format
        user_connections
        |> Enum.map(fn user_connection ->
          # Get the decrypted username for display
          username =
            case decr_uconn(
                   user_connection.connection.username,
                   current_user,
                   user_connection.key,
                   key
                 ) do
              :failed_verification -> "[encrypted]"
              "" -> "[encrypted]"
              decrypted -> decrypted
            end

          user_id =
            if current_user.id == user_connection.user_id,
              do: user_connection.reverse_user_id,
              else: user_connection.user_id

          # Return the same structure as Post.SharedUser
          %Post.SharedUser{
            user_id: user_id,
            username: username,
            sender_id: current_user.id
          }
        end)
    end
  end

  defp find_group_by_id(visibility_groups, group_id) do
    Enum.find(visibility_groups, fn group -> group.id == group_id end)
  end

  defp resolve_connections_from_user_connection_ids(connection_ids, current_user, key) do
    connection_ids
    |> Enum.map(fn encrypted_connection_id ->
      case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
             encrypted_connection_id,
             current_user,
             key
           ) do
        decrypted_id when is_binary(decrypted_id) ->
          # The decrypted_id should be a user_connection_id from the visibility group
          # We then return the user_connection to build the post_shared_users
          Accounts.get_user_connection(decrypted_id)

        _ ->
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  # Helper function to check download permissions
  defp check_download_permission(post, current_user) do
    cond do
      # User can always download their own post images
      post.user_id == current_user.id ->
        true

      # For shared posts, check if user has photos permission
      post.visibility in [:connections, :specific_users] ->
        can_download_photos_from_shared_item?(post, current_user)

      # Public posts can be viewed but not downloaded unless there's a connection
      post.visibility == :public ->
        can_download_photos_from_shared_item?(post, current_user)

      # Default: no download permission
      true ->
        false
    end
  end

  # Email notification helper function
  defp process_email_notifications_for_offline_users(post, current_user, session_key) do
    # Simply pass the post data to the EmailNotificationsProcessor
    # It will handle all filtering, offline checking, and processing
    Mosslet.Notifications.EmailNotificationsProcessor.process_post_notifications(
      post,
      current_user,
      session_key
    )
  end

  defp normalize_to_webp(file_path) do
    base = Path.rootname(file_path)
    "#{base}.webp"
  end

  # For previewing post urls (URL Preview Server)
  defp extract_first_url(text) do
    regex_with_protocol = ~r/https?:\/\/[^\s<>\"]+/
    regex_without_protocol = ~r/\b[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+[^\s]*/

    case Regex.run(regex_with_protocol, text || "") do
      [url | _] ->
        clean_url(url)

      nil ->
        case Regex.run(regex_without_protocol, text || "") do
          [url | _] -> clean_url(url)
          _ -> nil
        end
    end
  end

  defp clean_url(url) do
    graphemes = String.graphemes(url)

    reversed_valid =
      graphemes
      |> Enum.reverse()
      |> drop_trailing_punctuation([])
      |> Enum.reverse()

    result = Enum.join(reversed_valid)
    balance_parentheses(result)
  end

  defp drop_trailing_punctuation([], acc), do: acc

  defp drop_trailing_punctuation([char | rest] = all_chars, acc) do
    cond do
      char in [")", "]", "}"] ->
        matching_open = matching_bracket(char)

        open_in_rest = Enum.count(rest, &(&1 == matching_open))
        close_in_all = Enum.count(all_chars, &(&1 == char))
        close_in_acc = Enum.count(acc, &(&1 == char))

        close_in_rest = close_in_all - close_in_acc - 1

        if close_in_rest >= open_in_rest do
          drop_trailing_punctuation(rest, acc)
        else
          [char | rest]
        end

      char in ["!", "?", ".", ",", ";", ":", "'", "\""] and acc == [] ->
        drop_trailing_punctuation(rest, acc)

      true ->
        all_chars
    end
  end

  defp matching_bracket(")"), do: "("
  defp matching_bracket("]"), do: "["
  defp matching_bracket("}"), do: "{"

  defp balance_parentheses(url) do
    graphemes = String.graphemes(url)
    open_parens = Enum.count(graphemes, &(&1 == "("))
    close_parens = Enum.count(graphemes, &(&1 == ")"))

    if open_parens > close_parens do
      url <> String.duplicate(")", open_parens - close_parens)
    else
      url
    end
  end

  defp normalize_url_in_post_body(socket, preview) do
    normalized_url = preview["url"]
    current_body = get_in(socket.assigns.post_form.params, ["body"]) || ""

    if normalized_url && current_body != "" do
      original_url = extract_first_url(current_body)

      if original_url && original_url != normalized_url do
        updated_body = replace_url_preserve_punctuation(current_body, normalized_url)

        current_user = socket.assigns.current_user
        key = socket.assigns.key

        updated_params =
          socket.assigns.post_form.params
          |> Map.put("body", updated_body)
          |> Map.put("user_id", current_user.id)
          |> Map.put("key", key)

        changeset = Timeline.change_post(%Post{}, updated_params, user: current_user)

        assign(socket, :post_form, to_form(changeset, action: :validate))
      else
        socket
      end
    else
      socket
    end
  end

  defp replace_url_preserve_punctuation(text, normalized_url) do
    regex = ~r/https?:\/\/[^\s<>\"]+/

    case Regex.run(regex, text, return: :index) do
      [{start_pos, length}] ->
        captured = String.slice(text, start_pos, length)
        cleaned = clean_url(captured)

        before = String.slice(text, 0, start_pos)
        trimmed_suffix = String.slice(captured, String.length(cleaned)..-1//1)
        after_url = String.slice(text, start_pos + length, String.length(text))

        before <> normalized_url <> trimmed_suffix <> after_url

      _ ->
        text
    end
  end

  defp maybe_put_url_preview(params, socket) do
    case socket.assigns[:url_preview] do
      nil ->
        params

      preview when is_map(preview) ->
        Map.put(params, "url_preview", preview)
    end
  end

  defp count_all_replies(replies) when is_list(replies) do
    Enum.reduce(replies, 0, fn reply, acc ->
      child_count = count_all_replies(Map.get(reply, :child_replies, []))
      acc + 1 + child_count
    end)
  end

  defp count_all_replies(_), do: 0

  defp get_post_with_reply_limit(post_id, current_user_id, assigns) do
    loaded_replies_counts = assigns[:loaded_replies_counts] || %{}
    post_id_str = to_string(post_id)
    limit = Map.get(loaded_replies_counts, post_id_str, 5)

    Timeline.get_post_with_nested_replies(post_id, %{
      current_user_id: current_user_id,
      limit: limit
    })
  end

  defp handle_upload_progress(:photos, _entry, socket) do
    {:noreply, socket}
  end

  defp write_upload_to_temp_file(binary, entry_ref) do
    temp_dir = Path.join(System.tmp_dir!(), "mosslet_uploads")
    File.mkdir_p!(temp_dir)
    temp_path = Path.join(temp_dir, "#{entry_ref}.webp")
    File.write!(temp_path, binary)
    temp_path
  end

  defp generate_thumbnail_preview(binary) do
    case Image.from_binary(binary) do
      {:ok, image} ->
        case Image.thumbnail(image, "400x400", crop: :attention) do
          {:ok, thumb} ->
            case Image.write(thumb, :memory, suffix: ".webp", webp: [quality: 75]) do
              {:ok, thumb_binary} ->
                "data:image/webp;base64,#{Base.encode64(thumb_binary)}"

              _ ->
                nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp cleanup_temp_upload(nil), do: :ok

  defp cleanup_temp_upload(temp_path) do
    case File.rm(temp_path) do
      :ok ->
        :ok

      # Already gone, that's fine
      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to cleanup temp upload at #{temp_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
