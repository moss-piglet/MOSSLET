defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post

  import MossletWeb.UserHomeLive.Components

  @folder "uploads/trix"

  def mount(%{"slug" => slug} = _params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      if current_user do
        Accounts.private_subscribe(current_user)
        Timeline.private_subscribe(current_user)
        Timeline.connections_subscribe(current_user)
      else
        Accounts.subscribe()
      end
    end

    user = Accounts.get_user_from_profile_slug!(slug)

    {:ok,
     socket
     |> assign(:post_shared_users_result, Phoenix.LiveView.AsyncResult.loading())
     |> assign(:slug, slug)
     |> assign(:page_title, "Home")
     |> assign(:image_urls, [])
     |> assign(:delete_post_from_cloud_message, nil)
     |> assign(:delete_reply_from_cloud_message, nil)
     |> assign(:uploads_in_progress, false)
     |> assign(:trix_key, nil)
     |> assign(:user, user)}
  end

  @doc """
  Handle params. The "profile_user" assigned in the socket
  is the user whose profile is being viewed.

  The "current_user" is the session user (or "nil" if the
  profile is public and the session is not signed in).
  """
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    unread_posts = Timeline.unread_posts(current_user)

    socket =
      socket
      |> stream(:unread_posts, unread_posts, reset: true)
      |> start_async(:assign_post_shared_users, fn ->
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          key,
          :post
        )
      end)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({:post_created, post}, socket) do
    current_user = socket.assigns.current_user

    if current_user.is_subscribed_to_marketing_notifications do
      unread_post = Timeline.get_unread_post_for_user_and_post(post, current_user)

      {:noreply, stream_insert(socket, :unread_posts, unread_post, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
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
    Logger.error("Error removing Trix image in UserHomeLive")
    Logger.debug(inspect(url))
    Logger.error("Error removing Trix image in UserHomeLive: #{url}")
    socket = assign(socket, :uploads_in_progress, flag)

    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("trix_key", _params, socket) do
    current_user = socket.assigns.current_user
    # we check if there's a post assigned to the socket,
    # if so, then we can infer that it's a Reply being
    # created and the trix_key will be the already saved
    # post_key (it'll also already be encrypted as well)
    #
    # In this instance we are working with a live_component,
    # so this may be slightly different than the implementation
    # in TimelineLive.Index.
    post = socket.assigns[:post]

    trix_key = socket.assigns.trix_key

    trix_key = if trix_key, do: trix_key, else: generate_and_encrypt_trix_key(current_user, post)

    socket =
      socket
      |> assign(:trix_key, trix_key)

    {:reply, %{response: "success", trix_key: trix_key}, socket}
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
    updated_urls = [file_path | image_urls] |> Enum.uniq()

    socket =
      socket
      |> assign(:image_urls, updated_urls)

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

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in UserHomeLive")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  def handle_async(:assign_post_shared_users, {:ok, fetched_shared_users}, socket) do
    %{post_shared_users_result: result} = socket.assigns

    socket =
      socket
      |> assign(
        :post_shared_users_result,
        Phoenix.LiveView.AsyncResult.ok(result, fetched_shared_users)
      )
      |> assign(:post_shared_users, fetched_shared_users)

    {:noreply, socket}
  end

  def handle_async(:assign_post_shared_users, {:exit, reason}, socket) do
    %{post_shared_users_result: result} = socket.assigns

    socket =
      socket
      |> assign(
        :post_shared_users_result,
        Phoenix.LiveView.AsyncResult.failed(result, {:exit, reason})
      )

    {:noreply, socket}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Home")
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
