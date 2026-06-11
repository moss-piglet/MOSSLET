defmodule MossletWeb.TimelineLive.Index do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  # import MossletWeb.TimelineLive.Components
  import MossletWeb.Helpers

  import MossletWeb.Helpers.StatusHelpers,
    only: [
      can_view_status?: 3,
      get_user_status_info: 3,
      get_encrypted_status_data: 3
    ]

  alias Phoenix.LiveView.AsyncResult
  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserBlock
  alias Mosslet.Encrypted
  alias Mosslet.Journal.AI
  alias Mosslet.Timeline
  alias Mosslet.Timeline.{Post, Reply, ContentFilter}

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
      |> assign(:current_image_alt_texts, [])
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
      # Read posts expansion state (show only unread initially)
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> assign(:read_posts_count, 0)
      |> assign(:loaded_read_posts_count, 0)
      |> assign(:cached_read_posts, [])
      |> assign(:cached_unread_posts, [])
      |> assign(:subscribed_status_user_ids, MapSet.new())
      |> assign(:user_statuses, %{})
      # Track dynamic stream limit
      |> assign(:stream_limit, @post_per_page_default)
      # Store user token for uploads
      |> assign(:user_token, user_token)
      # Content warning state
      |> assign(:content_warning_enabled?, false)
      # Enhanced privacy controls state
      |> assign(:privacy_controls_expanded, false)
      # Composer collapsed state for scrolling convenience
      |> assign(:composer_collapsed, true)
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
      # Markdown guide modal state
      |> assign(:show_markdown_guide, false)
      |> assign(:loaded_replies_counts, %{})
      |> assign(:loaded_nested_replies, %{})
      |> assign(:unread_replies_by_post, %{})
      |> assign(:unread_nested_replies_by_parent, %{})
      |> assign(:upload_stages, %{})
      |> assign(:completed_uploads, [])
      |> assign(:composer_trix_key, nil)
      |> assign(:alt_text_modal_open, false)
      |> assign(:alt_text_editing_upload, nil)
      |> assign(:alt_text_editing_value, "")
      |> assign(:image_edit_modal_open, false)
      |> assign(:image_edit_upload, nil)
      |> assign(:image_edit_crop, %{})
      |> assign(:bluesky_sync_enabled, bluesky_sync_enabled?(current_user))
      |> stream(:posts, [])
      |> stream(:read_posts, [])
      |> assign(:timeline_data, AsyncResult.loading())
      |> allow_upload(:photos,
        accept: ~w(.gif .jpg .jpeg .png .webp .heic .heif),
        max_entries: 4,
        max_file_size: 10_000_000,
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

    {:ok, socket |> assign(page_title: "Timeline") |> maybe_load_custom_banner_async()}
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
      current_user_id: current_user.id,
      current_scope: socket.assigns.current_scope
    }

    # create the return_url with post pagination options
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
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> stream(:read_posts, [], reset: true)
      |> start_async(:load_timeline_data, fn ->
        user = Accounts.get_user!(current_user_id)

        posts =
          case current_tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(user, options_with_filters)

            "home" ->
              Timeline.list_home_timeline(user, options_with_filters)

            "bookmarks" ->
              Timeline.list_user_bookmarks(user, options_with_filters)

            _ ->
              options_with_tab = Map.put(options_with_filters, :tab, current_tab_for_async)

              Timeline.filter_timeline_posts(user, options_with_tab)
              |> apply_tab_filtering(current_tab_for_async, user)
          end

        {unread_posts, read_posts} =
          Enum.split_with(posts, fn post ->
            is_post_unread?(post, user, tab: current_tab_for_async)
          end)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)
        unread_replies_by_post = Timeline.count_unread_replies_by_post(user)
        unread_nested_replies_by_parent = Timeline.count_unread_nested_replies_by_parent(user)
        post_count = Timeline.timeline_post_count(user, options)

        %{
          unread_posts: unread_posts,
          read_posts: read_posts,
          read_posts_count: length(read_posts),
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          unread_replies_by_post: unread_replies_by_post,
          unread_nested_replies_by_parent: unread_nested_replies_by_parent,
          post_count: post_count,
          loaded_posts_count: length(unread_posts),
          current_page: options.post_page,
          post_loading_list:
            Enum.with_index(unread_posts, fn element, index -> {index, element} end)
        }
      end)

    {:noreply, socket}
  end

  defp is_post_unread?(post, current_user, opts) do
    tab = Keyword.get(opts, :tab)
    default_when_no_receipt = if tab == "discover", do: false, else: true

    cond do
      Ecto.assoc_loaded?(post.user_post_receipts) ->
        case Enum.find(post.user_post_receipts || [], fn receipt ->
               receipt.user_id == current_user.id
             end) do
          nil -> default_when_no_receipt
          %{is_read?: is_read} -> !is_read
        end

      true ->
        case Timeline.get_user_post_receipt(current_user, post) do
          nil -> default_when_no_receipt
          %{is_read?: true} -> false
          %{is_read?: false} -> true
          _ -> default_when_no_receipt
        end
    end
  end

  def handle_info(:complete_content_filter_toggle, socket) do
    current_state = socket.assigns.show_content_filter

    {:noreply,
     socket
     |> assign(:show_content_filter, !current_state)
     |> assign(:loading_content_filter, false)}
  end

  def handle_info(
        {:upload_ready, entry_ref, %{processed_binary: binary, trix_key: trix_key} = upload_data},
        socket
      ) do
    entry = Enum.find(socket.assigns.uploads.photos.entries, &(&1.ref == entry_ref))

    upload_stages = Map.put(socket.assigns.upload_stages, entry_ref, {:ready, nil})

    temp_path = write_upload_to_temp_file(binary, entry_ref)
    preview_data_url = generate_thumbnail_preview(binary)

    visibility = socket.assigns.selector
    is_zk_path = visibility not in ["public", :public]

    completed_upload = %{
      ref: entry_ref,
      client_name: (entry && entry.client_name) || "photo",
      temp_path: temp_path,
      trix_key: trix_key,
      preview_data_url: preview_data_url,
      upload_visibility: visibility,
      ai_generated: Map.get(upload_data, :ai_generated, false),
      encrypted_path: nil
    }

    socket =
      socket
      |> assign(:upload_stages, upload_stages)
      |> assign(:completed_uploads, socket.assigns.completed_uploads ++ [completed_upload])

    socket =
      if is_zk_path do
        blob_b64 = Base.encode64(binary)
        push_event(socket, "encrypt_post_image", %{blob_b64: blob_b64, upload_ref: entry_ref})
      else
        socket
      end

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
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    if user.id == current_user.id do
      updated_scope = %{socket.assigns.current_scope | user: user}
      new_status = to_string(user.status || "offline")

      {:noreply,
       socket
       |> assign(current_user: user, current_scope: updated_scope)
       |> push_event("update_user_status", %{
         user_id: user.id,
         status: new_status,
         status_message: user.status_message
       })}
    else
      case get_uconn_for_users(user, current_user) do
        %{} = _user_connection ->
          user_with_connection = Accounts.get_user_with_preloads(user.id)
          can_view = can_view_status?(user_with_connection, current_user, key)
          status_info = get_user_status_info(user_with_connection, current_user, key)
          encrypted_data = get_encrypted_status_data(user_with_connection, current_user, key)

          new_status = status_info.status || "offline"
          new_status_message = status_info.status_message

          updated_statuses =
            Map.put(socket.assigns.user_statuses, user.id, %{
              status: new_status,
              status_message: new_status_message,
              encrypted_status_data: encrypted_data,
              can_view: can_view
            })

          {:noreply,
           socket
           |> assign(:user_statuses, updated_statuses)
           |> push_event("update_user_status", %{
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
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case get_uconn_for_users(user, current_user) do
      %{} = _user_connection ->
        user_with_connection = Accounts.get_user_with_preloads(user.id)
        can_view = can_view_status?(user_with_connection, current_user, key)
        status_info = get_user_status_info(user_with_connection, current_user, key)
        encrypted_data = get_encrypted_status_data(user_with_connection, current_user, key)

        {new_status, new_status_message} =
          if can_view do
            {status_info.status, status_info.status_message}
          else
            {nil, nil}
          end

        updated_statuses =
          Map.put(socket.assigns.user_statuses, user.id, %{
            status: new_status,
            status_message: new_status_message,
            encrypted_status_data: if(can_view, do: encrypted_data),
            can_view: can_view
          })

        {:noreply,
         socket
         |> assign(:user_statuses, updated_statuses)
         |> push_event("update_user_status", %{
           user_id: user.id,
           status: new_status,
           status_message: new_status_message
         })}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    current_scope = %{socket.assigns.current_scope | user: user}
    {:noreply, assign(socket, :current_scope, current_scope)}
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

        {:noreply, stream_insert_post(socket, post, socket.assigns.current_user, at: -1)}

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

          {:noreply, stream_insert_post(socket, post, socket.assigns.current_user, at: -1)}
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

        # Ensure username is set server-side (hidden field may be empty if
        # user.decrypted wasn't populated at render time)
        reply_params =
          Map.put(reply_params, "username", username(current_user, key) || "")

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
              |> stream_insert_post(updated_post, current_user, at: -1)
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

  def handle_info({:create_reply_zk, zk_params, post_id, visibility}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Timeline.get_post(post_id) do
      %Mosslet.Timeline.Post{} = post ->
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
            updated_post = get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

            socket =
              socket
              |> put_flash(:success, "Reply posted successfully!")
              |> stream_insert_post(updated_post, current_user, at: -1)
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

  def handle_info({:reply_created, post, reply}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      socket = update_unread_counts_for_new_reply(socket, post, reply, current_user)

      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)

      post_with_limited_replies =
        get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

      socket =
        socket
        |> ensure_user_status_cached(reply.user_id, current_user, key)
        |> stream_insert_post(post_with_limited_replies, current_user, at: -1)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_reply_notification(reply, current_user, "created")

      {:noreply, socket}
    else
      socket =
        socket
        |> update_unread_counts_for_new_reply(post, reply, current_user)
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

      post_with_limited_replies =
        get_post_with_reply_limit(post.id, current_user.id, socket.assigns)

      socket =
        socket
        |> ensure_user_status_cached(reply.user_id, current_user, key)
        |> stream_insert_post(post_with_limited_replies, current_user, at: -1)
        |> recalculate_counts_after_new_post(current_user, options)

      {:noreply, socket}
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
        |> stream_insert_post(post_with_limited_replies, current_user, at: -1)
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

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)

      socket =
        socket
        |> ensure_user_status_cached(post.user_id, current_user, key)
        |> stream_insert_post(post, current_user, at: 0, limit: socket.assigns.stream_limit)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_new_post_notification(post, current_user)

      {:noreply, socket}
    else
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

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)

      socket =
        socket
        |> ensure_user_status_cached(post.user_id, current_user, key)
        |> stream_insert_post(post, current_user, at: -1)
        |> recalculate_counts_after_post_update(current_user, options)

      {:noreply, socket}
    else
      socket =
        socket
        |> stream_delete_post(post)
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
      |> stream_delete_post(post)
      |> recalculate_counts_after_post_update(current_user, options)

    {:noreply, socket}
  end

  def handle_info({:post_shared_users_added, post}, socket) do
    current_user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:removing_shared_user_id, nil)
     |> assign(:adding_shared_user, nil)
     |> stream_insert_post(post, current_user, at: -1)}
  end

  def handle_info({:post_shared_users_removed, post}, socket) do
    current_user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:removing_shared_user_id, nil)
     |> assign(:adding_shared_user, nil)
     |> stream_insert_post(post, current_user, at: -1)}
  end

  def handle_info({:post_updated_fav, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    content_filters = socket.assigns.content_filters
    key = socket.assigns.key

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters do
      decrypted_favs = decrypt_post_favs_list(post, current_user, key)
      is_liked = current_user && current_user.id in decrypted_favs

      {:noreply,
       push_event(socket, "update_post_fav_count", %{
         post_id: post.id,
         favs_count: post.favs_count,
         is_liked: is_liked
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
      # For non-public posts, favs_list is encrypted — only push count.
      # The browser already knows its own liked state from the ZK toggle.
      # For public posts, the server can determine membership.
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
  end

  def handle_info({:post_deleted, post}, socket) do
    current_user = socket.assigns.current_user
    options = socket.assigns.options

    socket =
      socket
      |> stream_delete_post(post)
      |> recalculate_counts_after_post_update(current_user, options)

    {:noreply, socket}
  end

  def handle_info({:post_shared, post}, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options
    content_filters = socket.assigns.content_filters

    shared_user_ids = Enum.map(post.shared_users || [], & &1.user_id)
    is_share_recipient = current_user.id in shared_user_ids

    should_show_post = post_matches_current_tab?(post, current_tab, current_user)
    passes_content_filters = post_passes_content_filters?(post, content_filters)

    if should_show_post and passes_content_filters and is_share_recipient do
      key = socket.assigns.key
      current_user = Accounts.get_user_with_preloads(current_user.id)

      socket =
        socket
        |> ensure_user_status_cached(post.user_id, current_user, key)
        |> stream_insert_post(post, current_user, at: 0, limit: socket.assigns.stream_limit)
        |> recalculate_counts_after_new_post(current_user, options)
        |> add_new_share_post_notification(post, current_user)

      {:noreply, socket}
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

    socket =
      socket
      |> stream_delete_post(post)
      |> recalculate_counts_after_post_update(current_user, options)

    # No notification needed for deleted reposts - just remove silently

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

      socket =
        socket
        |> ensure_user_status_cached(current_user.id, current_user, key)
        |> stream_insert_post(updated_post, current_user, at: -1)
        |> recalculate_counts_after_post_update(current_user, options)
        |> put_flash(:success, "Reply created!")
        |> push_event("hide-nested-reply-composer", %{reply_id: parent_reply_id})

      {:noreply, socket}
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

        "home" ->
          Timeline.list_home_timeline(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    posts_with_dates =
      prepare_posts_for_stream(posts, socket.assigns.current_user, socket.assigns.key)

    socket =
      socket
      |> maybe_update_timeline_counts(current_user, options_with_filters)
      |> assign(:loaded_posts_count, length(posts))
      |> assign(:current_page, 1)
      |> stream(:posts, posts_with_dates, reset: true)
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

        "home" ->
          Timeline.list_home_timeline(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Update timeline counts to reflect the unblock
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    posts_with_dates =
      prepare_posts_for_stream(posts, socket.assigns.current_user, socket.assigns.key)

    socket =
      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:loaded_posts_count, length(posts))
      |> assign(:current_page, 1)
      |> stream(:posts, posts_with_dates, reset: true)
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

        "home" ->
          Timeline.list_home_timeline(current_user, options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # Update timeline counts to reflect the block type change
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    info =
      if block.blocked_id != current_user.id,
        do: "Block settings updated. Timeline refreshed to reflect changes."

    posts_with_dates =
      prepare_posts_for_stream(posts, socket.assigns.current_user, socket.assigns.key)

    socket =
      socket
      |> assign(:posts, posts)
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:current_page, 1)
      |> stream(:posts, posts_with_dates, reset: true)
      |> put_flash(
        :info,
        info
      )

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # SERVER-SIDE REPOST/SHARE HELPERS (fallback for public posts + browser errors)
  # ============================================================================

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
        case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: post.body}) do
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
      {:ok, shared_post} ->
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
        current_tab = socket.assigns.active_tab || "home"
        options = socket.assigns.options
        content_filters = socket.assigns.content_filters

        should_show_post = post_matches_current_tab?(shared_post, current_tab, user)
        passes_content_filters = post_passes_content_filters?(shared_post, content_filters)

        socket =
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
          })

        socket =
          if should_show_post and passes_content_filters do
            socket
            |> stream_insert_post(shared_post, user, at: 0, limit: socket.assigns.stream_limit)
            |> recalculate_counts_after_new_post(user, options)
          else
            socket
            |> recalculate_counts_after_new_post(user, options)
          end

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:show_share_modal, false)
         |> put_flash(:error, "Failed to share. Please try again.")}
    end
  end

  # Server-side repost path (for public posts or browser encryption fallback)
  defp do_repost_server(post, user, key, post_shared_users, decrypted_reposts, socket) do
    username = resolve_decrypted_field(user, :username)
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
        case Encrypted.Utils.decrypt(%{key: decrypted_post_key, payload: post.body}) do
          {:ok, decrypted} -> decrypted
          _ -> ""
        end
      else
        ""
      end

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

        current_tab = socket.assigns.active_tab || "home"
        options = socket.assigns.options
        content_filters = socket.assigns.content_filters

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
            socket
            |> stream_insert_post(repost, user, at: 0, limit: socket.assigns.stream_limit)
            |> recalculate_counts_after_new_post(user, options)
          else
            socket
            |> recalculate_counts_after_new_post(user, options)
          end

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to repost. Please try again.")}
    end
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
          |> stream_insert_post(post, current_user, at: -1)

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
        |> stream_insert_post(post, current_user, at: -1)
        |> push_event("animate-new-replies", %{post_id: post_id, start_index: current_count})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  def handle_event("restore-body-scroll", _params, socket) do
    # this flash only displays after image download sent
    socket =
      socket
      |> clear_flash(:info)
      |> put_flash(:info, "Download complete!")

    {:noreply, socket}
  end

  def handle_event("toggle_read_posts", _params, socket) do
    if socket.assigns.read_posts_expanded do
      {:noreply,
       socket
       |> assign(:read_posts_expanded, false)
       |> stream(:read_posts, [], reset: true)}
    else
      cached_posts = socket.assigns[:cached_read_posts] || []

      posts_with_dates =
        prepare_posts_for_stream(
          cached_posts,
          socket.assigns.current_user,
          socket.assigns.key
        )

      {:noreply,
       socket
       |> assign(:read_posts_expanded, true)
       |> stream(:read_posts, posts_with_dates, reset: true)}
    end
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
      |> Map.put(
        "visibility_groups",
        get_visibility_list(
          post_params,
          "visibility_groups",
          socket.assigns.selected_visibility_groups,
          current_selector
        )
      )
      |> Map.put(
        "visibility_users",
        get_visibility_list(
          post_params,
          "visibility_users",
          socket.assigns.selected_visibility_users,
          current_selector
        )
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
    ref_str = to_string(ref)
    upload_stages = Map.delete(socket.assigns.upload_stages, ref_str)

    {removed, remaining} =
      Enum.split_with(socket.assigns.completed_uploads, &(to_string(&1.ref) == ref_str))

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
    ref_str = to_string(ref)

    upload_stages = Map.delete(socket.assigns.upload_stages, ref_str)

    {removed, remaining} =
      Enum.split_with(socket.assigns.completed_uploads, fn upload ->
        to_string(upload.ref) == ref_str
      end)

    Enum.each(removed, fn upload ->
      if upload[:temp_path], do: cleanup_temp_upload(upload.temp_path)
    end)

    entry_exists? =
      Enum.any?(socket.assigns.uploads.photos.entries, &(to_string(&1.ref) == ref_str))

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

  def handle_event("open_alt_text_modal", %{"ref" => ref}, socket) do
    ref_str = to_string(ref)

    upload =
      Enum.find(socket.assigns.completed_uploads, fn upload ->
        to_string(upload.ref) == ref_str
      end)

    {:noreply,
     socket
     |> assign(:alt_text_modal_open, true)
     |> assign(:alt_text_editing_upload, upload)
     |> assign(:alt_text_editing_value, upload[:alt_text] || "")}
  end

  def handle_event("close_alt_text_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:alt_text_modal_open, false)
     |> assign(:alt_text_editing_upload, nil)
     |> assign(:alt_text_editing_value, "")}
  end

  def handle_event("save_alt_text", %{"ref" => ref, "alt_text" => alt_text}, socket) do
    ref_str = to_string(ref)

    updated_uploads =
      Enum.map(socket.assigns.completed_uploads, fn upload ->
        if to_string(upload.ref) == ref_str do
          Map.put(upload, :alt_text, String.trim(alt_text))
        else
          upload
        end
      end)

    {:noreply,
     socket
     |> assign(:completed_uploads, updated_uploads)
     |> assign(:alt_text_modal_open, false)
     |> assign(:alt_text_editing_upload, nil)
     |> assign(:alt_text_editing_value, "")}
  end

  def handle_event("open_image_edit_modal", %{"ref" => ref}, socket) do
    ref_str = to_string(ref)

    upload =
      Enum.find(socket.assigns.completed_uploads, fn upload ->
        to_string(upload.ref) == ref_str
      end)

    {:noreply,
     socket
     |> assign(:image_edit_modal_open, true)
     |> assign(:image_edit_upload, upload)
     |> assign(:image_edit_crop, upload[:crop] || %{})}
  end

  def handle_event("close_image_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:image_edit_modal_open, false)
     |> assign(:image_edit_upload, nil)
     |> assign(:image_edit_crop, %{})}
  end

  def handle_event("save_image_crop", %{"ref" => ref, "crop" => crop}, socket) do
    ref_str = to_string(ref)

    crop_map =
      case crop do
        %{"x" => x, "y" => y, "width" => w, "height" => h} ->
          %{x: x, y: y, width: w, height: h}

        _ ->
          %{}
      end

    updated_uploads =
      Enum.map(socket.assigns.completed_uploads, fn upload ->
        if to_string(upload.ref) == ref_str do
          upload =
            if is_nil(upload[:original_preview_data_url]) do
              Map.put(upload, :original_preview_data_url, upload.preview_data_url)
            else
              upload
            end

          upload = Map.put(upload, :crop, crop_map)

          if crop_map != %{} do
            case generate_cropped_preview(upload.temp_path, crop_map) do
              {:ok, cropped_preview} -> Map.put(upload, :preview_data_url, cropped_preview)
              _ -> upload
            end
          else
            Map.put(
              upload,
              :preview_data_url,
              upload[:original_preview_data_url] || upload.preview_data_url
            )
          end
        else
          upload
        end
      end)

    {:noreply,
     socket
     |> assign(:completed_uploads, updated_uploads)
     |> assign(:image_edit_modal_open, false)
     |> assign(:image_edit_upload, nil)
     |> assign(:image_edit_crop, %{})}
  end

  def handle_event("reset_crop", %{"ref" => ref}, socket) do
    ref_str = to_string(ref)

    updated_uploads =
      Enum.map(socket.assigns.completed_uploads, fn upload ->
        if to_string(upload.ref) == ref_str do
          upload = Map.delete(upload, :crop)

          if upload[:original_preview_data_url] do
            Map.put(upload, :preview_data_url, upload.original_preview_data_url)
          else
            upload
          end
        else
          upload
        end
      end)

    upload = Enum.find(updated_uploads, fn u -> to_string(u.ref) == ref_str end)

    {:noreply,
     socket
     |> assign(:completed_uploads, updated_uploads)
     |> assign(:image_edit_upload, upload)
     |> assign(:image_edit_crop, %{})}
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
        case post.image_urls do
          [_ | _] = urls ->
            post_key = get_post_key(post, current_user)

            decrypted_urls =
              Enum.map(urls, fn encrypted_url ->
                decr_item(encrypted_url, current_user, post_key, key, post, "body")
              end)

            decrypted_alt_texts =
              (post.image_alt_texts || [])
              |> Enum.map(fn alt_text ->
                decr_item(alt_text, current_user, post_key, key, post, "body")
              end)

            {:reply,
             %{
               response: "success",
               image_urls: decrypted_urls,
               image_alt_texts: decrypted_alt_texts
             }, socket}

          _ ->
            {:reply, %{response: "success", image_urls: [], image_alt_texts: []}, socket}
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
  end

  # ZK image path: returns encrypted S3 blobs for browser-side decryption.
  # The server never decrypts the image content — it only proxies the encrypted
  # binary from S3 and base64-encodes it for transport. The browser decrypts
  # using the post_key it already unsealed via the DecryptPost hook.
  def handle_event(
        "fetch_encrypted_post_images",
        %{"post_id" => post_id},
        socket
      ) do
    memories_bucket = Encrypted.Session.memories_bucket()
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        post_key = get_post_key(post, current_user)

        # Decrypt the image_urls (S3 file paths) server-side — these are
        # operational metadata, not user content. The actual image blobs
        # remain encrypted.
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

        # Fetch encrypted blobs from S3 and return them as base64 (still
        # encrypted with post_key — the browser will decrypt).
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

    # Only accept plaintext body updates for public posts (server has the key).
    # Non-public posts must use the ZK path (update_post_body_zk).
    if post.visibility != :public do
      {:noreply, socket}
    else
      # Trim any added \n characters from the client html
      body =
        if body && is_list(body),
          do: List.to_string(body) |> String.trim(),
          else: String.trim(body)

      socket =
        socket
        |> assign(:post_image_processing, AsyncResult.loading())
        |> start_async(:update_post_body, fn ->
          update_post_body(post, body, current_user, key)
        end)

      {:noreply, socket}
    end
  end

  # ZK path: browser re-encrypted the body with the cached post_key.
  # Store the ciphertext directly — the raw body never enters server memory.
  def handle_event(
        "update_post_body_zk",
        %{"encrypted_body" => encrypted_body, "id" => id},
        socket
      ) do
    post = Timeline.get_post!(id)

    socket =
      socket
      |> assign(:post_image_processing, AsyncResult.loading())
      |> start_async(:update_post_body, fn ->
        case Timeline.update_post_body_zk(post, Base.decode64!(encrypted_body)) do
          {:ok, post} -> {"updated", post}
          {:error, error} -> {"error", error}
        end
      end)

    {:noreply, socket}
  end

  def handle_event("update_reply_body", %{"body" => body, "id" => id}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    reply = Timeline.get_reply!(id)
    post = Timeline.get_post!(reply.post_id)

    # Only accept plaintext body updates for public posts (server has the key).
    # Non-public posts must use the ZK path (update_reply_body_zk).
    if post.visibility != :public do
      {:noreply, socket}
    else
      # Trim any added \n characters from the client html
      body =
        if body && is_list(body),
          do: List.to_string(body) |> String.trim(),
          else: String.trim(body)

      socket =
        socket
        |> assign(:reply_image_processing, AsyncResult.loading())
        |> start_async(:update_reply_body, fn ->
          update_reply_body(reply, body, current_user, key)
        end)

      {:noreply, socket}
    end
  end

  # ZK path: browser re-encrypted the reply body with the cached post_key.
  def handle_event(
        "update_reply_body_zk",
        %{"encrypted_body" => encrypted_body, "id" => id},
        socket
      ) do
    reply = Timeline.get_reply!(id)

    socket =
      socket
      |> assign(:reply_image_processing, AsyncResult.loading())
      |> start_async(:update_reply_body, fn ->
        case Timeline.update_reply_body_zk(reply, Base.decode64!(encrypted_body)) do
          {:ok, reply} -> {"updated", reply}
          {:error, error} -> {"error", error}
        end
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

                updated_post =
                  get_post_with_reply_limit(post_id, current_user.id, socket.assigns)
                  |> Mosslet.Repo.preload([:user_post_receipts], force: true)

                content_filter_prefs = socket.assigns.content_filters

                options_with_filters =
                  Map.put(options, :content_filter_prefs, content_filter_prefs)

                unread_counts = calculate_unread_counts(current_user, options_with_filters)

                flash_message =
                  if desired_read_status, do: "Post marked as read", else: "Post marked as unread"

                socket =
                  socket
                  |> move_post_between_streams(updated_post, current_user)
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
              |> move_post_between_streams(updated_post, current_user)
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
              |> move_post_between_streams(updated_post, current_user)
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

  def handle_event("collapse_composer_esc", _params, socket) do
    any_modal_open? =
      socket.assigns.show_markdown_guide ||
        socket.assigns.show_image_modal ||
        socket.assigns.show_report_modal ||
        socket.assigns.show_block_modal ||
        socket.assigns.show_share_modal

    if any_modal_open? do
      {:noreply, socket}
    else
      {:noreply, assign(socket, :composer_collapsed, true)}
    end
  end

  def handle_event("open_composer_keyboard", _params, socket) do
    {:noreply, assign(socket, :composer_collapsed, false)}
  end

  def handle_event("update_privacy_visibility", %{"visibility" => visibility}, socket) do
    current_expires_option = socket.assigns.expires_at_option

    expires_at_option =
      if visibility == "public" and current_expires_option in ["1_hour", "6_hours"] do
        "24_hours"
      else
        current_expires_option
      end

    {:noreply,
     socket
     |> assign(:selector, visibility)
     |> assign(:expires_at_option, expires_at_option)}
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

  # True ZK write path — Phase 1: browser sends encrypted body + CW.
  # Server gathers metadata (recipients, image paths, url_preview, avatar_url,
  # username) and pushes it back for the browser to encrypt ALL fields and seal
  # the post_key for every recipient. The server NEVER unseals the post_key.
  def handle_event(
        "save_post_encrypted",
        %{"encrypted_body" => encrypted_body} = params,
        socket
      ) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      key = socket.assigns.key
      post_shared_users = socket.assigns.post_shared_users
      visibility = socket.assigns.selector

      # Public posts must go through the normal save_post path (server needs
      # plaintext for moderation, SEO, and federation). If the hook
      # accidentally fires for a public post, reject gracefully.
      if visibility == "public" do
        {:noreply, put_flash(socket, :warning, "Please submit your post again.")}
      else
        {uploaded_photo_urls, uploaded_alt_texts, _trix_key} =
          process_uploaded_photos(socket, current_user, key)

        any_ai_generated =
          Enum.any?(socket.assigns.completed_uploads, fn upload ->
            Map.get(upload, :ai_generated, false)
          end)

        body = Ecto.Changeset.get_field(socket.assigns.post_form.source, :body) || ""

        # Build partial post_params — fields that don't need encryption
        post_params =
          %{
            "body" => body,
            "username" => username(current_user, key) || "",
            "image_urls" => socket.assigns.image_urls ++ uploaded_photo_urls,
            "image_alt_texts" => uploaded_alt_texts,
            "image_urls_updated_at" => NaiveDateTime.utc_now(),
            "visibility" => visibility,
            "user_id" => current_user.id,
            "content_warning?" => socket.assigns.content_warning_enabled?,
            "ai_generated" => any_ai_generated,
            "allow_replies" => socket.assigns.allow_replies,
            "allow_shares" => socket.assigns.allow_shares,
            "allow_bookmarks" => socket.assigns.allow_bookmarks,
            "is_ephemeral" => socket.assigns.is_ephemeral,
            "require_follow_to_reply" => socket.assigns.require_follow_to_reply,
            "mature_content" => socket.assigns.mature_content,
            "local_only" => socket.assigns.local_only,
            "expires_at_option" => socket.assigns.expires_at_option,
            "visibility_groups" => socket.assigns.selected_visibility_groups || [],
            "visibility_users" => socket.assigns.selected_visibility_users || []
          }
          |> maybe_put_url_preview(socket)
          |> Map.put(
            "url_preview_fetched_at",
            if(socket.assigns.url_preview, do: NaiveDateTime.utc_now(), else: nil)
          )
          |> add_shared_users_list_for_new_post(post_shared_users, %{
            visibility_setting: visibility,
            current_user: current_user,
            key: key
          })

        # Gather plaintext fields that the browser must encrypt with post_key.
        # The server provides these values but never the post_key itself.
        plaintext_username = username(current_user, key) || ""

        plaintext_avatar_url =
          if current_user.decrypted,
            do: current_user.decrypted[:avatar_url],
            else: nil

        plaintext_image_urls = post_params["image_urls"] || []
        plaintext_image_alt_texts = post_params["image_alt_texts"] || []

        plaintext_url_preview =
          case post_params["url_preview"] do
            preview when is_map(preview) and map_size(preview) > 0 ->
              preview
              |> Enum.map(fn {k, v} -> {to_string(k), v} end)
              |> Enum.into(%{})

            _ ->
              nil
          end

        # Build recipient list with public keys for browser-side key sealing.
        # The browser will seal the post_key for each recipient + the author.
        shared_users = post_params["shared_users"] || []

        recipient_keys =
          Enum.map(shared_users, fn su ->
            su = Map.new(su, fn {k, v} -> {to_string(k), v} end)
            user = Accounts.get_user!(su["user_id"])

            %{
              user_id: user.id,
              public_key: user.key_pair["public"],
              pq_public_key: user.pq_public_key
            }
          end)

        # Stash the post_params and encrypted fragments for finalize_post_encrypted.
        # This avoids a second round of recipient resolution.
        encrypted_opts = [encrypted_body: encrypted_body]

        encrypted_opts =
          if params["encrypted_content_warning"],
            do:
              encrypted_opts ++ [encrypted_content_warning: params["encrypted_content_warning"]],
            else: encrypted_opts

        encrypted_opts =
          if params["encrypted_content_warning_category"],
            do:
              encrypted_opts ++
                [encrypted_content_warning_category: params["encrypted_content_warning_category"]],
            else: encrypted_opts

        socket =
          socket
          |> assign(:pending_zk_post_params, post_params)
          |> assign(:pending_zk_encrypted_opts, encrypted_opts)
          |> push_event("encrypt_post_fields", %{
            username: plaintext_username,
            avatar_url: plaintext_avatar_url,
            image_urls: plaintext_image_urls,
            image_alt_texts: plaintext_image_alt_texts,
            url_preview: plaintext_url_preview,
            recipient_keys: recipient_keys
          })

        {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :warning, "Not connected. Please refresh and try again.")}
    end
  end

  # True ZK write path — Phase 2: browser encrypted ALL fields and sealed
  # the post_key for every recipient. The server stores everything as-is.
  # The raw post_key NEVER exists in server memory.
  def handle_event("finalize_post_encrypted", params, socket) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      key = socket.assigns.key
      post_params = socket.assigns[:pending_zk_post_params]
      encrypted_opts = socket.assigns[:pending_zk_encrypted_opts] || []

      if is_nil(post_params) do
        {:noreply, put_flash(socket, :error, "No pending post to finalize. Please try again.")}
      else
        # Merge browser-encrypted fields into the post_params.
        # The post creation pipeline will use these pre-encrypted values
        # instead of encrypting server-side.
        zk_fields = %{
          encrypted_username: params["encrypted_username"],
          encrypted_avatar_url: params["encrypted_avatar_url"],
          encrypted_image_urls: params["encrypted_image_urls"] || [],
          encrypted_image_alt_texts: params["encrypted_image_alt_texts"] || [],
          encrypted_url_preview: params["encrypted_url_preview"],
          sealed_recipient_keys: params["sealed_recipient_keys"] || [],
          sealed_author_key: params["sealed_author_key"]
        }

        all_opts = encrypted_opts ++ [zk_fields: zk_fields]

        socket =
          socket
          |> assign(:pending_zk_post_params, nil)
          |> assign(:pending_zk_encrypted_opts, nil)

        create_post_and_respond(
          socket,
          post_params,
          current_user,
          key,
          # trix_key: nil — the server does not have the post_key
          nil,
          all_opts
        )
      end
    else
      {:noreply, put_flash(socket, :warning, "Not connected. Please refresh and try again.")}
    end
  end

  # ZK write path: browser encrypted a post image with the post_key.
  # Upload the already-encrypted blob directly to S3 — the server never
  # decrypts it or sees the encryption key.
  def handle_event(
        "post_image_encrypted",
        %{"encrypted_blob_b64" => encrypted_blob_b64, "upload_ref" => upload_ref},
        socket
      ) do
    encrypted_binary = Base.decode64!(encrypted_blob_b64)

    case Mosslet.FileUploads.ImageUploadWriter.upload_pre_encrypted_to_storage(encrypted_binary) do
      {:ok, file_path} ->
        completed_uploads =
          Enum.map(socket.assigns.completed_uploads, fn upload ->
            if upload.ref == upload_ref do
              upload |> Map.put(:encrypted_path, file_path) |> Map.drop([:temp_path])
            else
              upload
            end
          end)

        {:noreply, assign(socket, :completed_uploads, completed_uploads)}

      {:error, reason} ->
        Logger.error("Failed to upload pre-encrypted (ZK) image: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_event(
        "post_image_encrypted_failed",
        %{"upload_ref" => upload_ref, "reason" => reason},
        socket
      ) do
    Logger.error("ZK image encryption failed for #{upload_ref}: #{reason}")
    {:noreply, socket}
  end

  def handle_event("client_moderation_blocked", %{"reason" => reason}, socket) do
    {:noreply,
     put_flash(
       socket,
       :warning,
       "This post wasn't shared because it may violate community guidelines: '#{reason}' You can edit it or change visibility to not be public."
     )}
  end

  def handle_event("save_post", %{"post" => post_params}, socket) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      key = socket.assigns.key
      post_shared_users = socket.assigns.post_shared_users
      visibility = socket.assigns.selector
      body = post_params["body"] || ""

      text_moderation_result =
        if visibility == "public" && String.trim(body) != "" do
          AI.moderate_public_post(body)
        else
          {:ok, :approved}
        end

      image_moderation_result =
        if visibility == "public" do
          moderate_uploads_for_public_visibility(socket.assigns.completed_uploads)
        else
          {:ok, :approved}
        end

      case {text_moderation_result, image_moderation_result} do
        {{:error, reason}, _} ->
          socket =
            socket
            |> put_flash(
              :warning,
              "This post wasn't shared because it may violate community guidelines: '#{reason}' You can edit it or change visibility to not be public."
            )

          {:noreply, socket}

        {_, {:error, reason}} ->
          socket =
            socket
            |> put_flash(
              :warning,
              "This post wasn't shared because an image may violate community guidelines: '#{reason}' You can remove the image or change visibility to not be public."
            )

          {:noreply, socket}

        {{:ok, :approved}, {:ok, :approved}} ->
          # Process uploaded photos and get their URLs with alt texts and trix_key
          {uploaded_photo_urls, uploaded_alt_texts, trix_key} =
            process_uploaded_photos(socket, current_user, key)

          any_ai_generated =
            Enum.any?(socket.assigns.completed_uploads, fn upload ->
              Map.get(upload, :ai_generated, false)
            end)

          post_params =
            post_params
            |> Map.put("image_urls", socket.assigns.image_urls ++ uploaded_photo_urls)
            |> Map.put("image_alt_texts", uploaded_alt_texts)
            |> Map.put("image_urls_updated_at", NaiveDateTime.utc_now())
            |> Map.put("visibility", socket.assigns.selector)
            |> Map.put("user_id", current_user.id)
            |> Map.put("content_warning?", socket.assigns.content_warning_enabled?)
            |> Map.put("ai_generated", any_ai_generated)
            |> maybe_put_url_preview(socket)
            |> Map.put(
              "url_preview_fetched_at",
              if(socket.assigns.url_preview, do: NaiveDateTime.utc_now(), else: nil)
            )
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
            |> Map.put(
              "visibility_groups",
              post_params["visibility_groups"] || socket.assigns.selected_visibility_groups || []
            )
            |> Map.put(
              "visibility_users",
              post_params["visibility_users"] || socket.assigns.selected_visibility_users || []
            )
            |> add_shared_users_list_for_new_post(post_shared_users, %{
              visibility_setting: socket.assigns.selector,
              current_user: current_user,
              key: key
            })

          if post_params["user_id"] == current_user.id do
            create_post_and_respond(socket, post_params, current_user, key, trix_key)
          else
            {:noreply,
             socket
             |> put_flash(:warning, "You do not have permission to create this post.")}
          end
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
      muted_users: [],
      author_filter: :all
    }

    {:ok, new_prefs} =
      ContentFilter.update_filter_preferences(current_user.id, clear_prefs,
        user: current_user,
        key: key
      )

    socket = refresh_timeline_with_filters(socket, new_prefs)
    {:noreply, put_flash(socket, :info, "All filters cleared")}
  end

  def handle_event("set_author_filter", %{"filter" => filter_value}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    author_filter =
      case filter_value do
        "mine" -> :mine
        "connections" -> :connections
        _ -> :all
      end

    current_prefs = socket.assigns.content_filters
    updated_prefs = Map.put(current_prefs, :author_filter, author_filter)

    {:ok, new_prefs} =
      ContentFilter.update_filter_preferences(current_user.id, updated_prefs,
        user: current_user,
        key: key
      )

    socket = refresh_timeline_with_filters(socket, new_prefs)
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

  def handle_event("scroll_to_top", _params, socket) do
    {:noreply, push_event(socket, "scroll-to-top", %{})}
  end

  def handle_event("load_more_posts", _params, socket) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    current_options = socket.assigns.options

    socket = assign(socket, :load_more_loading, true)

    loaded_read_posts_count = socket.assigns[:loaded_read_posts_count] || 0
    posts_per_page = current_options.post_per_page

    next_read_page = div(loaded_read_posts_count, posts_per_page) + 1
    updated_options = Map.put(current_options, :post_page, next_read_page)

    content_filter_prefs = socket.assigns.content_filters
    updated_options_with_filters = Map.put(updated_options, :filter_prefs, content_filter_prefs)

    new_posts =
      case current_tab do
        "discover" ->
          Timeline.list_discover_posts(current_user, updated_options_with_filters)

        "home" ->
          Timeline.list_home_timeline(current_user, updated_options_with_filters)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, updated_options_with_filters)

        _ ->
          Timeline.filter_timeline_posts(current_user, updated_options_with_filters)
          |> apply_tab_filtering(current_tab, current_user)
      end

    {_new_unread, new_read_posts} =
      Enum.split_with(new_posts, fn post ->
        is_post_unread?(post, current_user, tab: current_tab)
      end)

    session_key = socket.assigns.key

    new_read_posts_decrypted =
      prepare_posts_for_stream(new_read_posts, current_user, session_key)

    new_loaded_read_count = loaded_read_posts_count + length(new_read_posts_decrypted)

    new_user_statuses =
      build_user_statuses_map(new_read_posts_decrypted, current_user, session_key)

    cached_read_posts = socket.assigns[:cached_read_posts] || []
    updated_cached_read_posts = cached_read_posts ++ new_read_posts_decrypted

    socket =
      new_read_posts_decrypted
      |> Enum.reduce(socket, fn post, acc_socket ->
        stream_insert(acc_socket, :read_posts, post, at: -1)
      end)
      |> assign(:options, updated_options)
      |> assign(:loaded_read_posts_count, new_loaded_read_count)
      |> assign(:read_posts_count, length(updated_cached_read_posts))
      |> assign(:cached_read_posts, updated_cached_read_posts)
      |> assign(:user_statuses, Map.merge(socket.assigns.user_statuses, new_user_statuses))
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

    socket =
      socket
      |> assign(:options, options)
      |> assign(:load_more_loading, false)
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> assign(:loaded_read_posts_count, 0)
      |> stream(:read_posts, [], reset: true)
      |> start_async(:load_timeline_data, fn ->
        user = Accounts.get_user!(current_user_id)

        posts =
          case tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(user, options_with_filters)

            "home" ->
              Timeline.list_home_timeline(user, options_with_filters)

            "bookmarks" ->
              Timeline.list_user_bookmarks(user, options_with_filters)

            _ ->
              Timeline.filter_timeline_posts(user, options_with_filters)
              |> apply_tab_filtering(tab_for_async, user)
          end

        {unread_posts, read_posts} =
          Enum.split_with(posts, fn post ->
            is_post_unread?(post, user, tab: tab_for_async)
          end)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)
        unread_replies_by_post = Timeline.count_unread_replies_by_post(user)
        unread_nested_replies_by_parent = Timeline.count_unread_nested_replies_by_parent(user)

        %{
          unread_posts: unread_posts,
          read_posts: read_posts,
          read_posts_count: length(read_posts),
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          unread_replies_by_post: unread_replies_by_post,
          unread_nested_replies_by_parent: unread_nested_replies_by_parent,
          post_count: Timeline.timeline_post_count(user, options),
          loaded_posts_count: length(unread_posts),
          current_page: 1,
          post_loading_list:
            Enum.with_index(unread_posts, fn element, index -> {index, element} end)
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
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> stream(:read_posts, [], reset: true)
      |> start_async(:load_timeline_data, fn ->
        user = Accounts.get_user!(current_user_id)

        posts =
          case current_tab_for_async do
            "discover" ->
              Timeline.list_discover_posts(user, options_with_filters)

            "home" ->
              Timeline.list_home_timeline(user, options_with_filters)

            "bookmarks" ->
              Timeline.list_user_bookmarks(user, options_with_filters)

            _ ->
              options_with_tab = Map.put(options_with_filters, :tab, current_tab_for_async)

              Timeline.filter_timeline_posts(user, options_with_tab)
              |> apply_tab_filtering(current_tab_for_async, user)
          end

        {unread_posts, read_posts} =
          Enum.split_with(posts, fn post ->
            is_post_unread?(post, user, tab: current_tab_for_async)
          end)

        options_with_content_filters =
          Map.put(options_with_filters, :content_filter_prefs, content_filter_prefs)

        timeline_counts = calculate_timeline_counts(user, options_with_content_filters)
        unread_counts = calculate_unread_counts(user, options_with_content_filters)
        unread_replies_by_post = Timeline.count_unread_replies_by_post(user)
        unread_nested_replies_by_parent = Timeline.count_unread_nested_replies_by_parent(user)
        post_count = Timeline.timeline_post_count(user, options)

        %{
          unread_posts: unread_posts,
          read_posts: read_posts,
          read_posts_count: length(read_posts),
          timeline_counts: timeline_counts,
          unread_counts: unread_counts,
          unread_replies_by_post: unread_replies_by_post,
          unread_nested_replies_by_parent: unread_nested_replies_by_parent,
          post_count: post_count,
          loaded_posts_count: length(unread_posts),
          current_page: options.post_page,
          post_loading_list:
            Enum.with_index(unread_posts, fn element, index -> {index, element} end)
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
              unread_counts = calculate_unread_counts(current_user, options_with_filters)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> assign(:unread_counts, unread_counts)
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: false
                })
                |> put_flash(:info, "Bookmark removed successfully.")

              socket =
                if current_tab == "bookmarks" do
                  stream_delete_post(socket, post)
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
              unread_counts = calculate_unread_counts(current_user, options_with_filters)

              socket =
                socket
                |> assign(:timeline_counts, timeline_counts)
                |> assign(:unread_counts, unread_counts)
                |> push_event("update_post_bookmark", %{
                  post_id: post_id,
                  is_bookmarked: true
                })
                |> put_flash(:success, "Post bookmarked successfully.")

              socket =
                if current_tab == "bookmarks" do
                  updated_post =
                    get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

                  stream_insert_post(socket, updated_post, current_user,
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

  # ZK bookmark with notes: browser encrypts notes with cached post_key
  def handle_event(
        "bookmark_post_with_notes",
        %{"id" => post_id, "encrypted_notes" => encrypted_notes},
        socket
      ) do
    current_user = socket.assigns.current_user
    current_tab = socket.assigns.active_tab || "home"
    options = socket.assigns.options

    case Timeline.get_post(post_id) do
      %Post{} = post ->
        result =
          if post.visibility == :public do
            # Public post: server encrypts the notes
            Timeline.create_bookmark(current_user, post, %{notes: encrypted_notes})
          else
            # Non-public post: notes are already encrypted by browser
            Timeline.create_bookmark_zk(current_user, post, encrypted_notes)
          end

        case result do
          {:ok, _bookmark} ->
            Accounts.track_user_activity(current_user, :interaction)
            content_filter_prefs = socket.assigns.content_filters
            options_with_filters = Map.put(options, :content_filter_prefs, content_filter_prefs)
            timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
            unread_counts = calculate_unread_counts(current_user, options_with_filters)

            socket =
              socket
              |> assign(:timeline_counts, timeline_counts)
              |> assign(:unread_counts, unread_counts)
              |> push_event("update_post_bookmark", %{
                post_id: post_id,
                is_bookmarked: true
              })
              |> put_flash(:success, "Post bookmarked with notes.")

            socket =
              if current_tab == "bookmarks" do
                updated_post =
                  get_post_with_reply_limit(post_id, current_user.id, socket.assigns)

                stream_insert_post(socket, updated_post, current_user,
                  at: 0,
                  limit: @post_per_page_default
                )
              else
                socket
              end

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
    current_user = socket.assigns.current_user

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

  def handle_event("fav", %{"id" => id}, socket), do: do_toggle_fav(id, socket)
  def handle_event("unfav", %{"id" => id}, socket), do: do_toggle_fav(id, socket)

  def handle_event(
        "toggle_fav_zk",
        %{"id" => id, "encrypted_favs_list" => encrypted_list, "is_liked" => is_liked},
        socket
      ) do
    post = Timeline.get_post!(id)

    if post do
      is_liked_bool = is_liked == "true"

      {count_delta, _action_label} =
        if is_liked_bool do
          {1, :fav}
        else
          {-1, :unfav}
        end

      # Update fav count
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

      Accounts.track_user_activity(socket.assigns.current_user, :interaction)

      {:noreply,
       socket
       |> push_event("update_post_fav_count", %{
         post_id: updated_post.id,
         favs_count: updated_post.favs_count,
         is_liked: is_liked_bool
       })}
    else
      {:noreply, put_flash(socket, :error, "Post not found.")}
    end
  end

  # ZK path: browser encrypts/decrypts the favs_list using cached post_key.
  # Mirrors the toggle_fav_zk pattern for posts.
  def handle_event(
        "toggle_reply_fav_zk",
        %{"id" => id, "encrypted_favs_list" => encrypted_list, "is_liked" => is_liked},
        socket
      ) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user

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
    current_user = socket.assigns.current_user
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
          # Already liked — decrement back
          Timeline.decr_reply_favs(reply)
          {:noreply, socket}
        end

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Reply not found. Please try again.")}
    end
  end

  def handle_event("unfav_reply", %{"id" => id}, socket) do
    reply = Timeline.get_reply!(id)
    current_user = socket.assigns.current_user
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
          # Wasn't liked — increment back
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

  def handle_event("repost", %{"id" => id} = _params, socket) do
    post = Timeline.get_post!(id)
    user = socket.assigns.current_user
    key = socket.assigns.key
    post_shared_users = socket.assigns.post_shared_users

    # Decrypt reposts list to check if user already reposted
    decrypted_reposts = decrypt_post_reposts_list(post, user, key)

    if post.user_id != user.id && user.id not in decrypted_reposts do
      shared_users_list =
        post_shared_users
        |> Enum.map(fn su -> Map.from_struct(su) end)

      case build_repost_encrypt_request(post, shared_users_list, user: user) do
        {:zk, payload} ->
          # Non-public: push to browser for ZK encryption
          {:noreply,
           socket
           |> assign(:pending_repost, %{
             post_id: post.id,
             decrypted_reposts: decrypted_reposts,
             shared_users: shared_users_list,
             visibility: post.visibility,
             image_urls_updated_at: post.image_urls_updated_at,
             favs_count: post.favs_count,
             reposts_count: post.reposts_count
           })
           |> push_event(
             "repost_encrypt_request",
             Map.merge(payload, %{
               repost_type: "repost",
               selected_user_ids: nil,
               note: nil
             })
           )}

        :server ->
          # Public: use existing server-side path
          do_repost_server(post, user, key, post_shared_users, decrypted_reposts, socket)
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

  def handle_event("repost_encrypted", params, socket) do
    user = socket.assigns.current_user
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
        {:ok, repost} ->
          {:ok, post} = Timeline.inc_reposts(post)

          updated_reposts = [user.id | pending.decrypted_reposts]

          {:ok, _post} =
            Timeline.update_post_repost_zk(
              post,
              %{reposts_list: updated_reposts}
            )

          Accounts.track_user_activity(user, :interaction)

          current_tab = socket.assigns.active_tab || "home"
          options = socket.assigns.options
          content_filters = socket.assigns.content_filters

          should_show_post = post_matches_current_tab?(repost, current_tab, user)
          passes_content_filters = post_passes_content_filters?(repost, content_filters)

          flash_msg =
            if params["repost_type"] == "share" do
              selected_count = length(params["selected_user_ids"] || [])

              "Shared with #{selected_count} #{if selected_count == 1, do: "person", else: "people"}!"
            else
              "Post reposted successfully."
            end

          socket =
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
            })

          socket =
            if should_show_post and passes_content_filters do
              socket
              |> stream_insert_post(repost, user, at: 0, limit: socket.assigns.stream_limit)
              |> recalculate_counts_after_new_post(user, options)
            else
              socket
              |> recalculate_counts_after_new_post(user, options)
            end

          {:noreply, socket}

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

          {:noreply, socket |> stream_delete_post(post)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete post. Please try again.")}
      end
    else
      {:noreply, socket |> put_flash(:error, "You are not authorized to delete this post.")}
    end
  end

  def handle_event("sync_post_to_bluesky", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user

    if post.user_id == current_user.id && post.visibility == :public && is_nil(post.external_uri) do
      case Mosslet.Bluesky.get_account_for_user(current_user.id) do
        nil ->
          {:noreply, put_flash(socket, :warning, "Please connect your Bluesky account first.")}

        account ->
          case Mosslet.Bluesky.Workers.ExportSyncWorker.enqueue_single_post_export(id, account.id) do
            {:ok, _job} ->
              {:noreply, put_flash(socket, :success, "Post queued for sync to Bluesky.")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to queue post for sync.")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "This post cannot be synced to Bluesky.")}
    end
  end

  def handle_event("unlink_post_from_bluesky", %{"id" => id}, socket) do
    post = Timeline.get_post!(id)
    current_user = socket.assigns.current_user

    if post.user_id == current_user.id && post.external_uri do
      case Mosslet.Bluesky.get_account_for_user(current_user.id) do
        nil ->
          {:noreply, put_flash(socket, :warning, "Please connect your Bluesky account first.")}

        account ->
          case Mosslet.Bluesky.Workers.DeleteSyncWorker.enqueue_delete(id, account.id) do
            {:ok, _job} ->
              {:noreply,
               put_flash(
                 socket,
                 :success,
                 "Post will be removed from Bluesky but kept on Mosslet."
               )}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to unlink post from Bluesky.")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "This post cannot be unlinked from Bluesky.")}
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
            |> stream_insert_post(updated_post, current_user, at: -1)
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

  def handle_event("remove_self_from_post", %{"post-id" => post_id}, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:removing_self_from_post_id, post_id)
      |> start_async(:remove_self_from_post, fn ->
        user_post = Timeline.get_user_post_by_post_id_and_user_id!(post_id, current_user.id)

        Timeline.remove_self_from_shared_post(user_post,
          user: current_user
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

  def handle_event("open_markdown_guide", _params, socket) do
    {:noreply, assign(socket, :show_markdown_guide, true)}
  end

  def handle_event("close_markdown_guide", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_markdown_guide, false)
     |> push_event("restore-body-scroll", %{})}
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
  def handle_event("show_timeline_images", %{"post_id" => post_id} = _params, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

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

            decrypted_alt_texts =
              (post.image_alt_texts || [])
              |> Enum.map(fn alt_text ->
                decr_item(alt_text, current_user, post_key, key, post, "body")
              end)

            {:noreply,
             socket
             |> assign(:show_image_modal, true)
             |> assign(:current_images, decrypted_urls)
             |> assign(:current_image_alt_texts, decrypted_alt_texts)
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
     |> assign(:current_image_alt_texts, [])
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

  def handle_event("mark_replies_read", %{"post_id" => post_id}, socket) do
    current_user = socket.assigns.current_user
    Timeline.mark_top_level_replies_read_for_post(post_id, current_user.id)

    remaining_nested_count =
      Timeline.count_unread_nested_replies_for_post(post_id, current_user.id)

    unread_replies_by_post = socket.assigns.unread_replies_by_post

    updated_map =
      if remaining_nested_count > 0 do
        Map.put(unread_replies_by_post, post_id, remaining_nested_count)
      else
        Map.delete(unread_replies_by_post, post_id)
      end

    {:noreply,
     socket
     |> assign(:unread_replies_by_post, updated_map)
     |> push_event("update-reply-badge", %{
       post_id: post_id,
       count: remaining_nested_count
     })}
  end

  def handle_event(
        "mark_nested_replies_read",
        %{"reply_id" => reply_id, "post_id" => post_id},
        socket
      ) do
    current_user = socket.assigns.current_user
    marked_count = Map.get(socket.assigns.unread_nested_replies_by_parent, reply_id, 0)
    Timeline.mark_nested_replies_read_for_parent(reply_id, current_user.id)

    unread_nested_replies_by_parent = socket.assigns.unread_nested_replies_by_parent
    updated_nested_map = Map.delete(unread_nested_replies_by_parent, reply_id)

    unread_replies_by_post = socket.assigns.unread_replies_by_post
    current_post_count = Map.get(unread_replies_by_post, post_id, 0)
    new_post_count = max(0, current_post_count - marked_count)

    updated_post_map =
      if new_post_count > 0 do
        Map.put(unread_replies_by_post, post_id, new_post_count)
      else
        Map.delete(unread_replies_by_post, post_id)
      end

    {:noreply,
     socket
     |> assign(:unread_nested_replies_by_parent, updated_nested_map)
     |> assign(:unread_replies_by_post, updated_post_map)}
  end

  def handle_event("mark_nested_replies_read", %{"reply_id" => reply_id}, socket) do
    current_user = socket.assigns.current_user
    Timeline.mark_nested_replies_read_for_parent(reply_id, current_user.id)

    unread_nested_replies_by_parent = socket.assigns.unread_nested_replies_by_parent
    updated_map = Map.delete(unread_nested_replies_by_parent, reply_id)
    {:noreply, assign(socket, :unread_nested_replies_by_parent, updated_map)}
  end

  def handle_async(:load_timeline_data, {:ok, timeline_result}, socket) do
    %{
      unread_posts: unread_posts,
      read_posts: read_posts,
      read_posts_count: read_posts_count,
      timeline_counts: timeline_counts,
      unread_counts: unread_counts,
      post_count: post_count,
      loaded_posts_count: loaded_posts_count,
      current_page: current_page,
      post_loading_list: post_loading_list
    } = timeline_result

    unread_replies_by_post = Map.get(timeline_result, :unread_replies_by_post, %{})

    unread_nested_replies_by_parent =
      Map.get(timeline_result, :unread_nested_replies_by_parent, %{})

    unread_posts_with_dates =
      prepare_posts_for_stream(unread_posts, socket.assigns.current_user, socket.assigns.key)

    read_posts_with_dates =
      prepare_posts_for_stream(read_posts, socket.assigns.current_user, socket.assigns.key)

    all_posts = unread_posts ++ read_posts

    user_statuses =
      build_user_statuses_map(all_posts, socket.assigns.current_user, socket.assigns.key)

    {:noreply,
     socket
     |> assign(:timeline_data, AsyncResult.ok(socket.assigns.timeline_data, timeline_result))
     |> assign(:loading_tab, nil)
     |> assign(:post_loading_list, post_loading_list)
     |> assign(:post_count, post_count)
     |> assign(:timeline_counts, timeline_counts)
     |> assign(:unread_counts, unread_counts)
     |> assign(:unread_replies_by_post, unread_replies_by_post)
     |> assign(:unread_nested_replies_by_parent, unread_nested_replies_by_parent)
     |> assign(:loaded_posts_count, loaded_posts_count)
     |> assign(:current_page, current_page)
     |> assign(:read_posts_count, read_posts_count)
     |> assign(:loaded_read_posts_count, read_posts_count)
     |> assign(:cached_read_posts, read_posts_with_dates)
     |> assign(:cached_unread_posts, unread_posts_with_dates)
     |> assign(:user_statuses, Map.merge(socket.assigns.user_statuses, user_statuses))
     |> stream(:posts, unread_posts_with_dates, reset: true)}
  end

  def handle_async(:load_timeline_data, {:exit, reason}, socket) do
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
     |> assign(:read_posts_count, 0)
     |> assign(:loaded_read_posts_count, 0)
     |> stream(:posts, [], reset: true)
     |> stream(:read_posts, [], reset: true)}
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

  def handle_async(:remove_self_from_post, {:ok, {:ok, post}}, socket) do
    socket =
      socket
      |> stream_delete(:posts, post)
      |> assign(:removing_self_from_post_id, nil)
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

  defp do_toggle_fav(id, socket) do
    case Mosslet.Repo.get(Post, id) do
      nil ->
        {:noreply,
         socket
         |> stream_delete(:posts, %Post{id: id})
         |> put_flash(:error, "This post is no longer available.")}

      _found ->
        post = Timeline.get_post!(id)
        current_user = socket.assigns.current_user
        key = socket.assigns.key

        decrypted_favs = decrypt_post_favs_list(post, current_user, key)
        is_currently_liked = current_user.id in decrypted_favs

        if is_currently_liked do
          {:ok, post} = Timeline.decr_favs(post)

          updated_favs = List.delete(decrypted_favs, current_user.id)
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

              {:noreply, socket}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to remove love. Please try again.")}
          end
        else
          {:ok, post} = Timeline.inc_favs(post)

          updated_favs = [current_user.id | decrypted_favs]
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

              {:noreply, socket}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Operation failed. Please try again.")}
          end
        end
    end
  end

  defp create_post_and_respond(socket, post_params, current_user, key, trix_key, opts \\ []) do
    create_opts =
      [user: current_user, key: key, trix_key: trix_key] ++ opts

    case Timeline.create_post(post_params, create_opts) do
      {:ok, post} ->
        Accounts.track_user_activity(current_user, :post)
        process_email_notifications_for_offline_users(post, current_user, key)
        maybe_enqueue_bluesky_export(post, current_user)

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
          |> cancel_all_upload_entries(:photos)
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

        current_tab = socket.assigns.active_tab || "home"
        options = socket.assigns.options
        content_filters = socket.assigns.content_filters

        should_show_post = post_matches_current_tab?(post, current_tab, current_user)
        passes_content_filters = post_passes_content_filters?(post, content_filters)

        socket =
          if should_show_post and passes_content_filters do
            socket
            |> stream_insert_post(post, current_user,
              at: 0,
              limit: socket.assigns.stream_limit
            )
            |> recalculate_counts_after_new_post(current_user, options)
          else
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

  defp get_visibility_list(post_params, key, fallback, selector) do
    cond do
      Map.has_key?(post_params, key) ->
        post_params[key] || []

      key == "visibility_users" and selector == "specific_users" ->
        []

      key == "visibility_groups" and selector == "specific_groups" ->
        []

      true ->
        fallback || []
    end
  end

  defp maybe_update_visibility_users(socket, post_params) do
    case post_params["visibility_users"] do
      nil ->
        assign(socket, :selected_visibility_users, [])

      users when is_list(users) ->
        socket
        |> assign(:selected_visibility_users, users)
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
    |> maybe_set_default_expires_at_option(post_params)
  end

  defp maybe_set_default_expires_at_option(socket, post_params) do
    is_ephemeral = post_params["is_ephemeral"] in ["true", true]
    current_expires = socket.assigns.expires_at_option
    visibility = socket.assigns.selector

    if is_ephemeral and current_expires in [nil, ""] do
      default = if visibility == "public", do: "24_hours", else: "1_hour"
      assign(socket, :expires_at_option, default)
    else
      socket
    end
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

    # Check muted keywords against content_warning_category_hash
    keywords_pass =
      case content_filters[:keywords] do
        keywords when is_list(keywords) and keywords != [] ->
          category_hash = post.content_warning_category_hash

          if is_nil(category_hash) do
            true
          else
            muted_hashes = Enum.map(keywords, &String.downcase/1)
            category_hash not in muted_hashes
          end

        _ ->
          true
      end

    # Post passes if it passes all filters
    content_warning_pass and mature_content_pass and blocked_users_pass and muted_users_pass and
      keywords_pass
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

  defp non_empty_list([]), do: nil
  defp non_empty_list(list) when is_list(list), do: list
  defp non_empty_list(_), do: nil

  defp add_shared_users_list_for_new_post(post_params, shared_users, options) do
    visibility_setting = options[:visibility_setting]
    current_user = options[:current_user]
    key = options[:key]

    cond do
      visibility_setting == "private" ->
        Map.put(post_params, "shared_users", [])

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
        posts

      "bookmarks" ->
        bookmarked_posts =
          Timeline.list_user_bookmarks(current_user)
          |> Enum.map(fn bookmark -> bookmark.post end)
          |> Enum.filter(&(&1 != nil))

        bookmarked_posts
        |> Enum.map(fn post ->
          if post.visibility == :public do
            Timeline.get_post!(post.id)
          else
            post
          end
        end)

      "discover" ->
        Timeline.list_discover_posts(current_user, %{})

      _ ->
        posts
    end
  end

  # Helper function to check if a new post should appear in the current tab
  defp post_matches_current_tab?(post, current_tab, current_user) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    case current_tab do
      "home" ->
        cond do
          post.user_id == current_user.id ->
            true

          post.visibility == :private ->
            false

          post.user_id in connection_user_ids ->
            post.visibility in [:connections, :specific_users, :specific_groups]

          true ->
            false
        end

      "discover" ->
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

  defp update_unread_counts_for_new_reply(socket, post, reply, current_user) do
    if reply.user_id == current_user.id do
      socket
    else
      is_nested_reply = not is_nil(reply.parent_reply_id)

      if is_nested_reply do
        parent_reply = reply.parent_reply

        if parent_reply && parent_reply.user_id == current_user.id do
          unread_nested_map = socket.assigns.unread_nested_replies_by_parent
          current_nested_count = Map.get(unread_nested_map, reply.parent_reply_id, 0)

          updated_nested_map =
            Map.put(unread_nested_map, reply.parent_reply_id, current_nested_count + 1)

          unread_replies_by_post = socket.assigns.unread_replies_by_post
          current_post_count = Map.get(unread_replies_by_post, post.id, 0)
          updated_post_map = Map.put(unread_replies_by_post, post.id, current_post_count + 1)

          socket
          |> assign(:unread_nested_replies_by_parent, updated_nested_map)
          |> assign(:unread_replies_by_post, updated_post_map)
        else
          socket
        end
      else
        if post.user_id == current_user.id do
          unread_replies_by_post = socket.assigns.unread_replies_by_post
          current_count = Map.get(unread_replies_by_post, post.id, 0)
          updated_map = Map.put(unread_replies_by_post, post.id, current_count + 1)
          assign(socket, :unread_replies_by_post, updated_map)
        else
          socket
        end
      end
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
      # For non-public replies, use a generic message to avoid server-side
      # decryption of the reply username (ZK: the server should not see it).
      # Public replies can still use the decrypted author name.
      message =
        if reply.visibility == :public do
          author_name = get_safe_reply_author_name(reply, current_user, socket.assigns.key)

          case action do
            "created" -> "New reply from #{author_name}"
            "updated" -> "Reply updated by #{author_name}"
            _ -> "Reply from #{author_name}"
          end
        else
          case action do
            "created" -> "New reply on your post"
            "updated" -> "A reply was updated"
            _ -> "New reply activity"
          end
        end

      # Add a gentle flash message
      put_flash(socket, :info, message)
    end
  end

  # Returns a display name for flash notifications. Uses pre-decrypted data
  # for own posts and public posts; returns a privacy-safe placeholder for
  # non-public posts from other users (ZK — server doesn't decrypt those).
  defp get_safe_post_author_name(post, current_user, key) do
    cond do
      post.user_id == current_user.id ->
        current_user.decrypted[:username] || "You"

      post.visibility == :public ->
        case username(post, current_user, key) do
          name when is_binary(name) -> "@" <> name
          _ -> "a connection"
        end

      true ->
        # Non-public post from another user — the server must not decrypt
        # the author name (ZK path). The browser-side DecryptPost hook
        # handles the actual display.
        "a connection"
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

  defp calculate_remaining_read_posts(
         timeline_counts,
         unread_counts,
         active_tab,
         loaded_read_posts_count
       ) do
    tab_atom = String.to_existing_atom(active_tab)
    total_posts = Map.get(timeline_counts, tab_atom, 0)
    unread_posts = Map.get(unread_counts, tab_atom, 0)
    total_read_posts = max(0, total_posts - unread_posts)
    max(0, total_read_posts - loaded_read_posts_count)
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
      home: Timeline.count_home_timeline(current_user, content_filter_prefs),
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
      home: Timeline.count_unread_home_timeline(current_user, content_filter_prefs),
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

  # Returns encrypted avatar data for browser-side ZK decryption on post cards.
  # For current user: uses conn_key sealed key.
  # For other users: uses UserConnection.key sealed key.
  # Returns nil when avatar is hidden or data unavailable (component falls back to logo).
  defp get_encrypted_post_author_avatar_data(post, current_user, _key) do
    if post.user_id == current_user.id do
      if show_avatar?(current_user),
        do: get_encrypted_avatar_data(current_user, nil),
        else: nil
    else
      user_connection = get_uconn_for_shared_item(post, current_user)

      if show_avatar?(user_connection),
        do: get_encrypted_avatar_data(user_connection, nil),
        else: nil
    end
  end

  # Fallback avatar URL for post cards when ZK data is nil (avatar hidden or unavailable).
  defp get_post_author_avatar_fallback(post, current_user) do
    if post.user_id == current_user.id do
      if show_avatar?(current_user), do: mosslet_logo_for_theme(), else: "/images/logo.svg"
    else
      user_connection = get_uconn_for_shared_item(post, current_user)
      if show_avatar?(user_connection), do: mosslet_logo_for_theme(), else: "/images/logo.svg"
    end
  end

  # Build a map of user_id => %{status: ..., status_message: ..., encrypted_status_data: ..., can_view: ...}
  # for all post authors. Called once when timeline loads, updated via PubSub events.
  defp build_user_statuses_map(posts, current_user, key) do
    posts
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn user_id, acc ->
      case Accounts.get_user_with_preloads(user_id) do
        %{} = user ->
          can_view = can_view_status?(user, current_user, key)
          status_info = get_user_status_info(user, current_user, key)
          encrypted_data = get_encrypted_status_data(user, current_user, key)

          Map.put(acc, user_id, %{
            status: status_info.status,
            status_message: status_info.status_message,
            encrypted_status_data: encrypted_data,
            can_view: can_view
          })

        nil ->
          Map.put(acc, user_id, %{
            status: nil,
            status_message: nil,
            encrypted_status_data: nil,
            can_view: false
          })
      end
    end)
  end

  # Get status from the cached user_statuses map, with fallback
  defp get_cached_user_status(user_statuses, user_id) do
    case Map.get(user_statuses, user_id) do
      %{status: status} when is_binary(status) -> status
      _ -> nil
    end
  end

  defp get_cached_encrypted_status_data(user_statuses, user_id) do
    case Map.get(user_statuses, user_id) do
      %{encrypted_status_data: data} -> data
      _ -> nil
    end
  end

  defp can_view_cached_status?(user_statuses, user_id) do
    case Map.get(user_statuses, user_id) do
      %{can_view: can_view} -> can_view
      _ -> false
    end
  end

  defp ensure_user_status_cached(socket, user_id, current_user, key) do
    if Map.has_key?(socket.assigns.user_statuses, user_id) do
      socket
    else
      case Accounts.get_user_with_preloads(user_id) do
        %{} = user ->
          can_view = can_view_status?(user, current_user, key)
          status_info = get_user_status_info(user, current_user, key)
          encrypted_data = get_encrypted_status_data(user, current_user, key)

          updated_statuses =
            Map.put(socket.assigns.user_statuses, user_id, %{
              status: status_info.status,
              status_message: status_info.status_message,
              encrypted_status_data: encrypted_data,
              can_view: can_view
            })

          assign(socket, :user_statuses, updated_statuses)

        nil ->
          updated_statuses =
            Map.put(socket.assigns.user_statuses, user_id, %{
              status: nil,
              status_message: nil,
              encrypted_status_data: nil,
              can_view: false
            })

          assign(socket, :user_statuses, updated_statuses)
      end
    end
  end

  # Returns a display name for the post author in timeline cards.
  # For public posts, uses the already-decrypted username from post.decrypted
  # (populated by pre_decrypt_post via decrypt_post_fields).
  # For non-public posts, returns a placeholder — the browser-side DecryptPost
  # hook overwrites it via `data-decrypt-author-name-target`.
  defp get_post_author_name(post, current_user, _key) do
    cond do
      post.user_id == current_user.id ->
        current_user.decrypted[:name] || current_user.decrypted[:username] || "..."

      post.decrypted[:username] ->
        post.decrypted[:username]

      true ->
        "..."
    end
  end

  # Returns encrypted author name data for browser-side ZK decryption.
  # For the current user's own posts, returns nil (pre_decrypt_user handles it).
  # For other users' posts, returns the sealed user_connection.key and encrypted
  # connection name/username blobs so the DecryptPost hook can decrypt them.
  defp get_encrypted_post_author_name_data(post, current_user) do
    cond do
      post.visibility == :public ->
        nil

      post.user_id == current_user.id ->
        nil

      true ->
        uconn = get_uconn_for_shared_item(post, current_user)

        if uconn && uconn.connection && is_binary(uconn.key) do
          show_name? =
            uconn.connection.profile != nil and uconn.connection.profile.show_name?

          %{
            sealed_uconn_key: uconn.key,
            encrypted_name: if(show_name?, do: uconn.connection.name),
            encrypted_username: uconn.connection.username,
            show_name: show_name?
          }
        end
    end
  end

  defp get_post_author_profile_slug(post, current_user, _key) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{slug: slug}} when is_binary(slug) -> slug
          _ -> nil
        end

      true ->
        user_connection = get_uconn_for_shared_item(post, current_user)

        if user_connection do
          case Accounts.get_user_with_preloads(post.user_id) do
            %{connection: %{profile: %{slug: slug}}} when is_binary(slug) -> slug
            _ -> nil
          end
        else
          nil
        end
    end
  end

  defp get_post_author_profile_visibility(post, current_user, _key) do
    cond do
      post.user_id == current_user.id ->
        case current_user.connection do
          %{profile: %{visibility: visibility}} -> visibility
          _ -> nil
        end

      true ->
        user_connection = get_uconn_for_shared_item(post, current_user)

        if user_connection do
          case Accounts.get_user_with_preloads(post.user_id) do
            %{connection: %{profile: %{visibility: visibility}}} -> visibility
            _ -> nil
          end
        else
          nil
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

  # Same as can_repost_with_decryption? but uses pre-decrypted reposts_list.
  # For browser_decrypt? posts, reposts_list is nil (decrypted browser-side),
  # so we do structural checks only — the JS hook corrects after decryption.
  defp can_repost_with_pre_decrypted?(post, current_user) do
    cond do
      !post.allow_shares -> false
      post.user_id == current_user.id -> false
      post.is_ephemeral -> false
      current_user.id in (post.decrypted[:reposts_list] || []) -> false
      true -> post.allow_shares
    end
  end

  # Helper function to process uploaded photos.
  #
  # Two paths:
  #   1. ZK path (encrypted_path present, non-public visibility): Image was
  #      already encrypted by the browser and uploaded to S3 via the
  #      post_image_encrypted event. Return the path directly — no server-side
  #      encryption needed.
  #   2. Legacy path (no encrypted_path, or public visibility): Server-side
  #      encryption with trix_key (public posts, or ZK images that haven't
  #      completed encryption yet).
  #
  # Returns {upload_paths, alt_texts, trix_key} tuple for idiomatic Elixir/Phoenix
  defp process_uploaded_photos(socket, _current_user, _key) do
    completed_uploads = socket.assigns.completed_uploads
    is_zk_path = socket.assigns.selector not in ["public", :public]

    if completed_uploads == [] do
      {[], [], nil}
    else
      trix_key = socket.assigns[:composer_trix_key]

      upload_results =
        Enum.map(completed_uploads, fn upload ->
          if upload.encrypted_path && is_zk_path do
            # ZK path — already encrypted by browser, already on S3
            {upload.encrypted_path, upload[:alt_text] || "", trix_key}
          else
            actual_trix_key = trix_key || upload.trix_key

            binary = File.read!(upload.temp_path)
            binary = maybe_apply_crop(binary, upload[:crop])

            case Mosslet.FileUploads.ImageUploadWriter.upload_to_storage(
                   binary,
                   actual_trix_key
                 ) do
              {:ok, file_path} ->
                cleanup_temp_upload(upload.temp_path)
                {file_path, upload[:alt_text] || "", actual_trix_key}

              {:error, reason} ->
                Logger.error("📷 PROCESS_UPLOADED_PHOTOS: Upload failed: #{inspect(reason)}")
                nil
            end
          end
        end)

      successful_results = Enum.filter(upload_results, &(&1 != nil))

      case successful_results do
        [] ->
          {[], [], trix_key}

        [{_first_path, _first_alt, first_trix_key} | _] ->
          paths = Enum.map(successful_results, fn {path, _alt, _key} -> path end)
          alt_texts = Enum.map(successful_results, fn {_path, alt, _key} -> alt end)
          {paths, alt_texts, first_trix_key}
      end
    end
  end

  defp moderate_uploads_for_public_visibility(completed_uploads) do
    require Logger
    Logger.info("📷 MODERATE_UPLOADS: checking #{length(completed_uploads)} uploads")

    uploads_needing_moderation =
      Enum.filter(completed_uploads, fn upload ->
        Logger.info(
          "📷 MODERATE_UPLOADS: upload visibility = #{inspect(upload[:upload_visibility])}"
        )

        upload[:upload_visibility] not in ["public", :public]
      end)

    Logger.info("📷 MODERATE_UPLOADS: #{length(uploads_needing_moderation)} need moderation")

    if uploads_needing_moderation == [] do
      {:ok, :approved}
    else
      Enum.reduce_while(uploads_needing_moderation, {:ok, :approved}, fn upload, _acc ->
        Logger.info("📷 MODERATE_UPLOADS: reading #{upload.temp_path}")

        case File.read(upload.temp_path) do
          {:ok, binary} ->
            Logger.info("📷 MODERATE_UPLOADS: got #{byte_size(binary)} bytes")

            case Image.from_binary(binary) do
              {:ok, image} ->
                Logger.info("📷 MODERATE_UPLOADS: calling moderate_public_image")
                result = Mosslet.AI.Images.moderate_public_image(image, "image/webp")
                Logger.info("📷 MODERATE_UPLOADS: result = #{inspect(result)}")

                case result do
                  {:ok, :approved} -> {:cont, {:ok, :approved}}
                  {:error, reason} -> {:halt, {:error, reason}}
                end

              {:error, reason} ->
                Logger.info("📷 MODERATE_UPLOADS: Image.from_binary failed: #{inspect(reason)}")
                {:cont, {:ok, :approved}}
            end

          {:error, reason} ->
            Logger.info("📷 MODERATE_UPLOADS: File.read failed: #{inspect(reason)}")
            {:cont, {:ok, :approved}}
        end
      end)
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
    author_active = Map.get(filters, :author_filter, :all) != :all

    keywords_active || cw_active || mature_active || users_active || reposts_active ||
      author_active
  end

  # Helper function to refresh timeline with new filters
  defp refresh_timeline_with_filters(socket, new_prefs) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # CRITICAL: Invalidate timeline cache when filters change
    Mosslet.Timeline.Performance.TimelineCache.invalidate_timeline(current_user.id)

    # Reload and decrypt content filters to get fresh state
    # Refresh content filters in socket assigns
    fresh_filters = load_and_decrypt_content_filters(current_user, key)

    # Preserve author_filter from new_prefs since it's not persisted to database
    fresh_filters = Map.put(fresh_filters, :author_filter, new_prefs[:author_filter] || :all)

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

        "home" ->
          Timeline.list_home_timeline(current_user, reset_options)

        "bookmarks" ->
          Timeline.list_user_bookmarks(current_user, reset_options)

        _ ->
          Timeline.filter_timeline_posts(current_user, reset_options)
          |> apply_tab_filtering(current_tab, current_user)
      end

    # CRITICAL FIX: Split posts by read/unread status like initial load does
    {unread_posts, read_posts} =
      Enum.split_with(posts, fn post ->
        is_post_unread?(post, current_user, tab: current_tab)
      end)

    # CRITICAL FIX: Recalculate timeline counts with new filters
    options_with_filters = Map.put(reset_options, :content_filter_prefs, fresh_filters)
    timeline_counts = calculate_timeline_counts(current_user, options_with_filters)
    unread_counts = calculate_unread_counts(current_user, options_with_filters)

    unread_posts_with_dates =
      prepare_posts_for_stream(unread_posts, current_user, socket.assigns.key)

    read_posts_with_dates =
      prepare_posts_for_stream(read_posts, current_user, socket.assigns.key)

    socket =
      socket
      |> assign(:timeline_counts, timeline_counts)
      |> assign(:unread_counts, unread_counts)
      |> assign(:options, reset_options)
      |> assign(:loaded_posts_count, length(unread_posts))
      |> assign(:current_page, 1)
      |> assign(:load_more_loading, false)
      |> assign(:read_posts_expanded, false)
      |> assign(:read_posts_loading, false)
      |> assign(:loaded_read_posts_count, length(read_posts))
      |> assign(:cached_read_posts, read_posts_with_dates)
      |> assign(:cached_unread_posts, unread_posts_with_dates)
      |> stream(:posts, unread_posts_with_dates, reset: true)
      |> stream(:read_posts, [], reset: true)

    socket
  end

  # Helper function to load and decrypt content filters
  defp load_and_decrypt_content_filters(user, key) do
    muted_connection_user_ids = Accounts.get_muted_connection_user_ids(user)

    case Timeline.get_user_timeline_preference(user) do
      %Timeline.UserTimelinePreference{} = prefs ->
        decrypted_keywords =
          if prefs.mute_keywords && prefs.mute_keywords != [] do
            Enum.map(prefs.mute_keywords, fn encrypted_keyword ->
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_keyword, user, key)
            end)
            |> Enum.reject(&is_nil/1)
          else
            []
          end

        decrypted_muted_users =
          if prefs.muted_users && prefs.muted_users != [] do
            Enum.map(prefs.muted_users, fn encrypted_user_id ->
              Mosslet.Encrypted.Users.Utils.decrypt_user_data(encrypted_user_id, user, key)
            end)
            |> Enum.reject(&is_nil/1)
          else
            []
          end

        all_muted_users =
          (decrypted_muted_users ++ muted_connection_user_ids)
          |> Enum.uniq()

        blocked_user_ids = Timeline.get_blocked_user_ids(user)

        %{
          keywords: decrypted_keywords,
          muted_users: all_muted_users,
          blocked_users: blocked_user_ids,
          content_warnings: %{
            hide_all: prefs.hide_content_warnings || false,
            hide_mature: prefs.hide_mature_content || false
          },
          hide_reposts: prefs.hide_reposts || false,
          author_filter: :all,
          raw_preferences: prefs
        }

      nil ->
        blocked_user_ids = Timeline.get_blocked_user_ids(user)

        %{
          keywords: [],
          muted_users: muted_connection_user_ids,
          blocked_users: blocked_user_ids,
          content_warnings: %{
            hide_all: false,
            hide_mature: false
          },
          hide_reposts: false,
          author_filter: :all,
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
    # Run in a short-lived task so the LiveView isn't blocked.
    # The session key exists only in this task's process memory and is
    # discarded when the task completes (typically < 1 second).
    Task.start(fn ->
      Mosslet.Notifications.EmailNotificationsProcessor.process_post_notifications(
        post,
        current_user,
        session_key
      )
    end)
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
    temp_path =
      Mosslet.FileUploads.TempStorage.temp_path("timeline_uploads", entry_ref) <> ".webp"

    File.write!(temp_path, binary)
    temp_path
  end

  defp generate_thumbnail_preview(binary) do
    case Image.from_binary(binary, pages: :all) do
      {:ok, image} ->
        is_animated = Image.pages(image) > 1

        thumb_result =
          if is_animated do
            Image.map_join_pages(image, fn page ->
              Image.thumbnail(page, "400x400", crop: :attention)
            end)
          else
            Image.thumbnail(image, "400x400", crop: :attention)
          end

        case thumb_result do
          {:ok, thumb} ->
            write_opts =
              if is_animated,
                do: [suffix: ".webp", webp: [quality: 75, minimize_file_size: true]],
                else: [suffix: ".webp", webp: [quality: 75]]

            case Image.write(thumb, :memory, write_opts) do
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

  defp cancel_all_upload_entries(socket, upload_name) do
    entries = socket.assigns.uploads[upload_name].entries

    Enum.reduce(entries, socket, fn entry, acc ->
      cancel_upload(acc, upload_name, entry.ref)
    end)
  end

  defp cleanup_temp_upload(nil), do: :ok

  defp cleanup_temp_upload(temp_path) do
    case File.rm(temp_path) do
      :ok ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to cleanup temp upload at #{temp_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp stream_insert_post(socket, post, current_user, opts) do
    # Ensure the post has its .decrypted map populated before streaming.
    # Some callers (e.g. reply handlers) fetch a fresh post from the DB
    # without calling pre_decrypt_post first.
    post =
      if Map.has_key?(post, :decrypted) and is_map(post.decrypted),
        do: post,
        else: pre_decrypt_post(post, current_user, socket.assigns.key)

    current_tab = socket.assigns[:active_tab] || "home"

    if is_post_unread?(post, current_user, tab: current_tab) do
      cached_unread_posts = socket.assigns[:cached_unread_posts] || []
      post_with_date = add_single_post_date_context(post, cached_unread_posts, opts)
      updated_cached = update_or_add_cached_post(cached_unread_posts, post_with_date)

      socket =
        socket
        |> assign(:cached_unread_posts, updated_cached)
        |> maybe_update_old_first_post_separator(
          :posts,
          cached_unread_posts,
          post_with_date,
          opts
        )

      stream_insert(socket, :posts, post_with_date, opts)
    else
      cached_read_posts = socket.assigns[:cached_read_posts] || []
      is_new_read_post = not Enum.any?(cached_read_posts, &(&1.id == post.id))
      post_with_date = add_single_post_date_context(post, cached_read_posts, opts)
      updated_cached = update_or_add_cached_post(cached_read_posts, post_with_date)

      loaded_read_count = socket.assigns[:loaded_read_posts_count] || 0

      new_loaded_read_count =
        if is_new_read_post, do: loaded_read_count + 1, else: loaded_read_count

      socket =
        socket
        |> assign(:cached_read_posts, updated_cached)
        |> assign(:loaded_read_posts_count, new_loaded_read_count)
        |> maybe_update_old_first_post_separator(
          :read_posts,
          cached_read_posts,
          post_with_date,
          opts
        )

      maybe_stream_insert_read_post(socket, post_with_date, opts)
    end
  end

  defp maybe_stream_insert_read_post(socket, post, opts) do
    if socket.assigns[:read_posts_expanded] do
      stream_insert(socket, :read_posts, post, opts)
    else
      socket
    end
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

  defp maybe_update_old_first_post_separator(socket, stream_name, cached_posts, new_post, opts) do
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

          stream_insert(socket, stream_name, updated_old_first)
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

  defp update_or_add_cached_post(cached_posts, post) do
    if Enum.any?(cached_posts, &(&1.id == post.id)) do
      Enum.map(cached_posts, fn p ->
        if p.id == post.id do
          # Preserve .decrypted from the cached post if the incoming one lacks it.
          # PubSub updates carry fresh metadata but the encrypted content is unchanged.
          if is_map(Map.get(post, :decrypted)) do
            post
          else
            Map.put(post, :decrypted, Map.get(p, :decrypted))
          end
        else
          p
        end
      end)
    else
      [post | cached_posts]
    end
  end

  defp stream_delete_post(socket, post) do
    cached_read_posts = socket.assigns[:cached_read_posts] || []
    updated_cached_read = Enum.reject(cached_read_posts, &(&1.id == post.id))

    cached_unread_posts = socket.assigns[:cached_unread_posts] || []
    updated_cached_unread = Enum.reject(cached_unread_posts, &(&1.id == post.id))

    socket
    |> assign(:cached_read_posts, updated_cached_read)
    |> assign(:cached_unread_posts, updated_cached_unread)
    |> stream_delete(:posts, post)
    |> stream_delete(:read_posts, post)
  end

  defp move_post_between_streams(socket, post, current_user) do
    current_tab = socket.assigns[:active_tab] || "home"
    key = socket.assigns.key

    # Preserve bookmark_notes from the cached version of this post.
    # The field is a virtual attribute attached by list_user_bookmarks,
    # not a DB column, so re-fetching the post via get_post_with_reply_limit
    # loses it. Carry it forward from whichever cache still has it.
    post = preserve_bookmark_notes(post, socket.assigns)

    if is_post_unread?(post, current_user, tab: current_tab) do
      # Post became unread — move from read stream to unread stream
      cached_read_posts = socket.assigns[:cached_read_posts] || []
      updated_cached_read = Enum.reject(cached_read_posts, &(&1.id == post.id))
      loaded_read_count = socket.assigns[:loaded_read_posts_count] || 0

      cached_unread_posts = socket.assigns[:cached_unread_posts] || []

      updated_cached_unread =
        update_or_add_cached_post(cached_unread_posts, post)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

      unread_with_dates = prepare_posts_for_stream(updated_cached_unread, current_user, key)

      socket
      |> assign(:cached_read_posts, updated_cached_read)
      |> assign(:cached_unread_posts, updated_cached_unread)
      |> assign(:loaded_read_posts_count, max(0, loaded_read_count - 1))
      |> stream_delete(:read_posts, post)
      |> stream(:posts, unread_with_dates, reset: true)
      |> maybe_reset_read_posts_stream(updated_cached_read)
    else
      # Post became read — move from unread stream to read stream
      cached_read_posts = socket.assigns[:cached_read_posts] || []

      updated_cached_read =
        update_or_add_cached_post(cached_read_posts, post)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

      loaded_read_count = socket.assigns[:loaded_read_posts_count] || 0

      cached_unread_posts = socket.assigns[:cached_unread_posts] || []
      updated_cached_unread = Enum.reject(cached_unread_posts, &(&1.id == post.id))

      unread_with_dates = prepare_posts_for_stream(updated_cached_unread, current_user, key)

      socket
      |> assign(:cached_read_posts, updated_cached_read)
      |> assign(:cached_unread_posts, updated_cached_unread)
      |> assign(:loaded_read_posts_count, loaded_read_count + 1)
      |> stream(:posts, unread_with_dates, reset: true)
      |> maybe_reset_read_posts_stream(updated_cached_read)
    end
  end

  defp maybe_reset_read_posts_stream(socket, cached_read_posts) do
    if socket.assigns[:read_posts_expanded] do
      posts_with_dates =
        prepare_posts_for_stream(
          cached_read_posts,
          socket.assigns.current_user,
          socket.assigns.key
        )

      stream(socket, :read_posts, posts_with_dates, reset: true)
    else
      socket
    end
  end

  # Carries forward :bookmark_notes from the cached version of a post.
  # bookmark_notes is a virtual field set by list_user_bookmarks, not a DB
  # column, so it's lost when the post is re-fetched. Look it up from
  # whichever cache (unread or read) still holds the previous version.
  defp preserve_bookmark_notes(post, assigns) do
    if Map.get(post, :bookmark_notes) do
      post
    else
      cached =
        find_cached_post(assigns[:cached_unread_posts], post.id) ||
          find_cached_post(assigns[:cached_read_posts], post.id)

      if cached && Map.get(cached, :bookmark_notes) do
        Map.put(post, :bookmark_notes, cached.bookmark_notes)
      else
        post
      end
    end
  end

  defp find_cached_post(nil, _id), do: nil
  defp find_cached_post(posts, id), do: Enum.find(posts, &(&1.id == id))

  # Prepares posts for streaming: adds date separators and pre-decrypts all
  # encrypted fields in a single pass (unsealing each post_key only once).
  defp prepare_posts_for_stream(posts, current_user, session_key) do
    posts
    |> add_date_grouping_context()
    |> pre_decrypt_posts(current_user, session_key)
  end

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

  defp get_post_date(datetime) when is_struct(datetime, NaiveDateTime) do
    NaiveDateTime.to_date(datetime)
  end

  defp get_post_date(datetime) when is_struct(datetime, DateTime) do
    DateTime.to_date(datetime)
  end

  defp get_post_date(_), do: nil

  defp maybe_load_custom_banner_async(socket) do
    user = socket.assigns.current_user
    profile = Map.get(user.connection, :profile)
    banner_image = if profile, do: profile.banner_image, else: :waves

    if banner_image == :custom && profile && Map.get(profile, :custom_banner_url) do
      key = socket.assigns.key
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
      assign(socket, :custom_banner_src, %AsyncResult{ok?: true, result: nil})
    end
  end

  defp get_async_banner_data(%AsyncResult{ok?: true, result: result}),
    do: if(is_map(result), do: result, else: nil)

  defp get_async_banner_data(_), do: nil

  defp maybe_enqueue_bluesky_export(post, user) do
    if post.visibility == :public && post.source == :mosslet do
      case Mosslet.Bluesky.get_account_for_user(user.id) do
        %{sync_enabled: true, sync_posts_to_bsky: true} = account ->
          Mosslet.Bluesky.Workers.ExportSyncWorker.enqueue_single_post_export(post.id, account.id)

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp bluesky_sync_enabled?(user) do
    case Mosslet.Bluesky.get_account_for_user(user.id) do
      %{sync_enabled: true, sync_posts_to_bsky: true} -> true
      _ -> false
    end
  end

  defp maybe_apply_crop(binary, nil), do: binary
  defp maybe_apply_crop(binary, crop) when crop == %{}, do: binary

  defp maybe_apply_crop(binary, %{x: x, y: y, width: w, height: h}) do
    case Image.from_binary(binary, pages: :all) do
      {:ok, image} ->
        is_animated = Image.pages(image) > 1
        {img_width, img_height, _} = Image.shape(image)

        crop_x = round(x * img_width)
        crop_y = round(y * img_height)
        crop_w = round(w * img_width)
        crop_h = round(h * img_height)

        crop_w = min(crop_w, img_width - crop_x)
        crop_h = min(crop_h, img_height - crop_y)

        crop_result =
          if is_animated do
            Image.map_join_pages(image, fn page ->
              Image.crop(page, crop_x, crop_y, crop_w, crop_h)
            end)
          else
            Image.crop(image, crop_x, crop_y, crop_w, crop_h)
          end

        case crop_result do
          {:ok, cropped} ->
            write_opts =
              if is_animated,
                do: [suffix: ".webp", webp: [quality: 90, minimize_file_size: true]],
                else: [suffix: ".webp", webp: [quality: 90]]

            case Image.write(cropped, :memory, write_opts) do
              {:ok, cropped_binary} -> cropped_binary
              _ -> binary
            end

          _ ->
            binary
        end

      _ ->
        binary
    end
  end

  defp maybe_apply_crop(binary, _), do: binary

  defp generate_cropped_preview(temp_path, %{x: x, y: y, width: w, height: h}) do
    case File.read(temp_path) do
      {:ok, binary} ->
        case Image.from_binary(binary, pages: :all) do
          {:ok, image} ->
            is_animated = Image.pages(image) > 1
            {img_width, img_height, _} = Image.shape(image)

            crop_x = round(x * img_width)
            crop_y = round(y * img_height)
            crop_w = round(w * img_width)
            crop_h = round(h * img_height)

            crop_w = min(crop_w, img_width - crop_x)
            crop_h = min(crop_h, img_height - crop_y)

            crop_result =
              if is_animated do
                Image.map_join_pages(image, fn page ->
                  Image.crop(page, crop_x, crop_y, crop_w, crop_h)
                end)
              else
                Image.crop(image, crop_x, crop_y, crop_w, crop_h)
              end

            case crop_result do
              {:ok, cropped} ->
                thumb_result =
                  if is_animated do
                    Image.map_join_pages(cropped, fn page ->
                      Image.thumbnail(page, "400x400", crop: :attention)
                    end)
                  else
                    Image.thumbnail(cropped, "400x400", crop: :attention)
                  end

                case thumb_result do
                  {:ok, thumb} ->
                    write_opts =
                      if is_animated,
                        do: [suffix: ".webp", webp: [quality: 75, minimize_file_size: true]],
                        else: [suffix: ".webp", webp: [quality: 75]]

                    case Image.write(thumb, :memory, write_opts) do
                      {:ok, thumb_binary} ->
                        {:ok, "data:image/webp;base64,#{Base.encode64(thumb_binary)}"}

                      _ ->
                        {:error, :write_failed}
                    end

                  _ ->
                    {:error, :thumbnail_failed}
                end

              _ ->
                {:error, :crop_failed}
            end

          _ ->
            {:error, :image_load_failed}
        end

      _ ->
        {:error, :file_read_failed}
    end
  end
end
