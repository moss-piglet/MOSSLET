defmodule MossletWeb.PublicLive.PublicTimeline do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post
  alias Mosslet.Encrypted

  @posts_per_page 10
  @stream_limit 100

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Timeline.subscribe()
      Timeline.reply_subscribe()
    end

    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Public Timeline")
     |> assign_new(:meta_description, fn ->
       "Explore public posts on MOSSLET. See what people are sharing in our privacy-first social network."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/discover/discover_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(:og_image_alt, "MOSSLET Public Timeline")
     |> assign(:current_page, 1)
     |> assign(:loading, true)
     |> assign(:has_more, true)
     |> assign(:load_more_loading, false)
     |> assign(:posts_empty, true)
     |> assign(:total_posts_count, 0)
     |> assign(:loaded_posts_count, 0)
     |> assign(:posts_per_page, @posts_per_page)
     |> assign(:new_posts_count, 0)
     |> assign(:show_image_modal, false)
     |> assign(:current_images, [])
     |> assign(:current_image_index, 0)
     |> assign(:first_post_date, nil)
     |> assign(:first_post_id, nil)
     |> assign(:date_separators, %{})
     |> stream(:posts, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    if connected?(socket) do
      send(self(), :load_posts)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:load_posts, socket) do
    posts = load_public_posts(1)
    has_more = length(posts) >= @posts_per_page
    current_scope = socket.assigns[:current_scope]
    total_count = Timeline.count_discover_posts(nil, %{})
    first_post = if posts != [], do: hd(posts), else: nil
    first_post_date = if first_post, do: get_post_date(first_post.inserted_at), else: nil
    first_post_id = if first_post, do: first_post.id, else: nil
    decorated_posts = decorate_posts(posts, current_scope)
    date_separators = build_date_separators_map(decorated_posts)

    {:noreply,
     socket
     |> stream(:posts, decorated_posts, reset: true)
     |> assign(:loading, false)
     |> assign(:has_more, has_more)
     |> assign(:total_posts_count, total_count)
     |> assign(:loaded_posts_count, length(posts))
     |> assign(:posts_empty, posts == [])
     |> assign(:first_post_date, first_post_date)
     |> assign(:first_post_id, first_post_id)
     |> assign(:date_separators, date_separators)}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    if post.visibility == :public do
      current_scope = socket.assigns[:current_scope]
      post = Timeline.get_post_with_preloads(post.id)

      if post do
        new_post_date = get_post_date(post.inserted_at)
        first_post_date = socket.assigns.first_post_date
        first_post_id = socket.assigns.first_post_id
        same_date_as_first = !is_nil(first_post_date) && new_post_date == first_post_date
        decorated = decorate_single_post_with_date(post, current_scope, true)

        date_separators =
          socket.assigns.date_separators
          |> Map.delete(first_post_id)
          |> Map.put(post.id, %{
            show: true,
            date: new_post_date,
            first: true
          })

        socket =
          socket
          |> stream_insert(:posts, decorated, at: 0, limit: @stream_limit)
          |> assign(:posts_empty, false)
          |> assign(:first_post_date, new_post_date)
          |> assign(:first_post_id, post.id)
          |> assign(:date_separators, date_separators)
          |> assign(:new_posts_count, socket.assigns.new_posts_count + 1)
          |> assign(:total_posts_count, socket.assigns.total_posts_count + 1)
          |> assign(:loaded_posts_count, socket.assigns.loaded_posts_count + 1)

        socket =
          if same_date_as_first && first_post_id do
            case Timeline.get_post_with_preloads(first_post_id) do
              nil ->
                socket

              old_first_post ->
                old_decorated =
                  decorate_single_post_with_date(old_first_post, current_scope, false)

                stream_insert(socket, :posts, old_decorated)
            end
          else
            socket
          end

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    current_scope = socket.assigns[:current_scope]

    if post.visibility == :public do
      post = Timeline.get_post_with_preloads(post.id)

      if post do
        {:noreply, stream_insert(socket, :posts, decorate_post_for_update(post, current_scope))}
      else
        {:noreply, socket}
      end
    else
      {:noreply, stream_delete(socket, :posts, %{id: post.id})}
    end
  end

  @impl true
  def handle_info({:post_updated_fav, post}, socket) do
    if post.visibility == :public do
      current_scope = socket.assigns[:current_scope]
      post = Timeline.get_post_with_preloads(post.id)

      if post do
        {:noreply, stream_insert(socket, :posts, decorate_post_for_update(post, current_scope))}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    deleted_id = post.id
    first_post_id = socket.assigns.first_post_id
    date_separators = Map.delete(socket.assigns.date_separators, deleted_id)

    socket =
      socket
      |> stream_delete(:posts, %{id: deleted_id})
      |> assign(:total_posts_count, max(0, socket.assigns.total_posts_count - 1))
      |> assign(:loaded_posts_count, max(0, socket.assigns.loaded_posts_count - 1))
      |> assign(:date_separators, date_separators)

    socket =
      if deleted_id == first_post_id do
        case Timeline.list_discover_posts(nil, %{page: 1, per_page: 1}) do
          [new_first | _] ->
            new_first_date = get_post_date(new_first.inserted_at)

            new_separators =
              Map.put(date_separators, new_first.id, %{
                show: true,
                date: new_first_date,
                first: true
              })

            current_scope = socket.assigns[:current_scope]
            decorated = decorate_single_post_with_date(new_first, current_scope, true)

            socket
            |> stream_insert(:posts, decorated)
            |> assign(:first_post_id, new_first.id)
            |> assign(:first_post_date, new_first_date)
            |> assign(:date_separators, new_separators)

          [] ->
            socket
            |> assign(:first_post_id, nil)
            |> assign(:first_post_date, nil)
            |> assign(:posts_empty, true)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:reply_created, post, _reply}, socket) do
    current_scope = socket.assigns[:current_scope]

    if post.visibility == :public do
      post = Timeline.get_post_with_preloads(post.id)

      if post do
        {:noreply, stream_insert(socket, :posts, decorate_post_for_update(post, current_scope))}
      else
        {:noreply, socket}
      end
    else
      {:noreply, stream_delete(socket, :posts, %{id: post.id})}
    end
  end

  @impl true
  def handle_info({:reply_deleted, post, _reply}, socket) do
    current_scope = socket.assigns[:current_scope]

    if post.visibility == :public do
      post = Timeline.get_post_with_preloads(post.id)

      if post do
        {:noreply, stream_insert(socket, :posts, decorate_post_for_update(post, current_scope))}
      else
        {:noreply, socket}
      end
    else
      {:noreply, stream_delete(socket, :posts, %{id: post.id})}
    end
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clipboard_copied", _params, socket) do
    {:noreply, put_flash(socket, :info, "RSS feed URL copied to clipboard!")}
  end

  def handle_event("load_more", _params, socket) do
    if socket.assigns.load_more_loading || !socket.assigns.has_more do
      {:noreply, socket}
    else
      socket = assign(socket, :load_more_loading, true)
      next_page = socket.assigns.current_page + 1
      new_posts = load_public_posts(next_page)
      has_more = length(new_posts) >= @posts_per_page
      current_scope = socket.assigns[:current_scope]
      new_loaded_count = socket.assigns.loaded_posts_count + length(new_posts)
      decorated_posts = decorate_posts(new_posts, current_scope)
      new_separators = build_date_separators_map(decorated_posts)

      {:noreply,
       socket
       |> stream(:posts, decorated_posts)
       |> assign(:current_page, next_page)
       |> assign(:has_more, has_more)
       |> assign(:loaded_posts_count, new_loaded_count)
       |> assign(:load_more_loading, false)
       |> assign(:date_separators, Map.merge(socket.assigns.date_separators, new_separators))}
    end
  end

  def handle_event("get_post_image_urls", %{"post_id" => post_id}, socket) do
    case Timeline.get_post(post_id) do
      %Post{} = post ->
        case post.image_urls do
          [_ | _] = urls ->
            post_key = get_decrypted_post_key(post)
            decrypted_urls = decrypt_images(urls, post_key)
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
    import MossletWeb.Helpers,
      only: [get_s3_object: 2, decrypt_image_for_trix: 7, decrypted_image_binaries_for_trix?: 1]

    memories_bucket = Encrypted.Session.memories_bucket()

    post_id =
      if String.contains?(post_id, "-reply-form"),
        do: String.split(post_id, "-reply-form") |> List.first(),
        else: post_id

    post = Timeline.get_post!(post_id)
    post_key = get_decrypted_post_key(post)

    images =
      Enum.map(sources, fn file_path ->
        webp_path = normalize_to_webp(file_path)

        case get_s3_object(memories_bucket, webp_path) do
          {:ok, %{body: e_obj}} ->
            decrypt_public_image_for_trix(e_obj, post_key, "webp")

          {:error, _} ->
            case get_s3_object(memories_bucket, file_path) do
              {:ok, %{body: e_obj}} ->
                ext = Path.extname(file_path) |> String.trim_leading(".")
                ext = if ext == "", do: "webp", else: ext
                decrypt_public_image_for_trix(e_obj, post_key, ext)

              {:error, _error} ->
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
        "show_public_timeline_images",
        %{"post_id" => _post_id, "image_index" => image_index, "images" => images},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:show_image_modal, true)
     |> assign(:current_images, images)
     |> assign(:current_image_index, image_index)}
  end

  def handle_event("close_image_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_image_modal, false)
     |> assign(:current_images, [])
     |> assign(:current_image_index, 0)
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

  def handle_event("goto_timeline_image", %{"index" => index}, socket) do
    max_index = length(socket.assigns.current_images) - 1
    new_index = max(0, min(index, max_index))
    {:noreply, assign(socket, :current_image_index, new_index)}
  end

  def handle_event(
        "regenerate_preview_url",
        %{"image_hash" => image_hash, "post_id" => post_id},
        socket
      ) do
    actual_post_id = String.replace_prefix(post_id, "public-post-", "")

    case Mosslet.Extensions.URLPreviewImageProxy.regenerate_presigned_url(
           image_hash,
           actual_post_id
         ) do
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
    actual_post_id = String.replace_prefix(post_id, "public-post-", "")

    case Timeline.get_post(actual_post_id) do
      %Post{} = post ->
        case fetch_and_decrypt_url_preview_image(presigned_url, post) do
          {:ok, decrypted_image} ->
            {:reply, %{response: "success", decrypted_image: decrypted_image}, socket}

          {:error, _reason} ->
            {:reply, %{response: "failed"}, socket}
        end

      nil ->
        {:reply, %{response: "failed"}, socket}
    end
  end

  defp fetch_and_decrypt_url_preview_image(presigned_url, post) do
    post_key = get_decrypted_post_key(post)

    with {:ok, decrypted_key} when is_binary(decrypted_key) <- {:ok, post_key},
         {:ok, %{status: 200, body: encrypted_image}} <- Req.get(presigned_url),
         {:ok, decrypted_binary} <-
           Encrypted.Utils.decrypt(%{key: decrypted_key, payload: encrypted_image}) do
      data_url = "data:image/jpeg;base64," <> Base.encode64(decrypted_binary)
      {:ok, data_url}
    else
      {:ok, nil} ->
        {:error, :no_post_key}

      {:error, reason} ->
        {:error, reason}

      error ->
        {:error, error}
    end
  end

  defp normalize_to_webp(file_path) do
    base = Path.rootname(file_path)
    "#{base}.webp"
  end

  defp decrypt_public_image_for_trix(encrypted_binary, post_key, ext) do
    case Encrypted.Utils.decrypt(%{key: post_key, payload: encrypted_binary}) do
      {:ok, decrypted_binary} ->
        base64 = Base.encode64(decrypted_binary)
        "data:image/#{ext};base64,#{base64}"

      _ ->
        nil
    end
  end

  defp load_public_posts(page) do
    options = %{
      post_page: page,
      post_per_page: @posts_per_page
    }

    Timeline.list_discover_posts(nil, options)
  end

  defp decorate_posts(posts, current_scope) do
    posts
    |> Enum.map(&decorate_post(&1, current_scope))
    |> add_date_grouping_context()
  end

  defp decorate_post(post, current_scope) do
    post_key = get_decrypted_post_key(post)
    current_user = if current_scope, do: current_scope.user, else: nil

    %{
      id: post.id,
      post: post,
      inserted_at: post.inserted_at,
      content: decrypt_with_key(post.body, post_key),
      username: decrypt_with_key(post.username, post_key),
      avatar: get_post_author_avatar(post, current_user, post_key),
      profile_slug: get_author_profile_slug(post),
      profile_visibility: get_author_profile_visibility(post),
      images: decrypt_images(post.image_urls, post_key),
      url_preview: decrypt_url_preview(post, post_key),
      content_warning: decrypt_with_key(post.content_warning, post_key),
      content_warning_category: decrypt_with_key(post.content_warning_category, post_key),
      timestamp: format_timestamp(post.inserted_at),
      reply_count: length(post.replies || [])
    }
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

  defp decorate_single_post_with_date(post, current_scope, show_separator) do
    decorated = decorate_post(post, current_scope)
    post_date = get_post_date(post.inserted_at)

    decorated
    |> Map.put(:show_date_separator, show_separator)
    |> Map.put(:post_date, post_date)
    |> Map.put(:first_separator, show_separator)
  end

  defp decorate_post_for_update(post, current_scope) do
    decorated = decorate_post(post, current_scope)
    post_date = get_post_date(post.inserted_at)

    decorated
    |> Map.put(:show_date_separator, false)
    |> Map.put(:post_date, post_date)
    |> Map.put(:first_separator, false)
  end

  defp build_date_separators_map(decorated_posts) do
    decorated_posts
    |> Enum.filter(&Map.get(&1, :show_date_separator, false))
    |> Enum.map(fn post ->
      {post.post.id,
       %{
         show: true,
         date: Map.get(post, :post_date),
         first: Map.get(post, :first_separator, false)
       }}
    end)
    |> Map.new()
  end

  defp get_separator_show(date_separators, item) do
    case Map.get(date_separators, item.post.id) do
      %{show: true, date: date} when not is_nil(date) -> true
      _ -> false
    end
  end

  defp get_separator_date(date_separators, item) do
    case Map.get(date_separators, item.post.id) do
      %{date: date} -> date
      _ -> nil
    end
  end

  defp get_separator_first(date_separators, item) do
    case Map.get(date_separators, item.post.id) do
      %{first: first} -> first
      _ -> false
    end
  end

  defp get_decrypted_post_key(post) do
    encrypted_key = get_post_key(post)

    case Encrypted.Users.Utils.decrypt_public_item_key(encrypted_key) do
      post_key when is_binary(post_key) -> post_key
      _ -> nil
    end
  end

  defp decrypt_with_key(nil, _post_key), do: nil
  defp decrypt_with_key(_payload, nil), do: nil

  defp decrypt_with_key(payload, post_key) do
    case Encrypted.Utils.decrypt(%{key: post_key, payload: payload}) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp decrypt_images(nil, _post_key), do: []
  defp decrypt_images([], _post_key), do: []
  defp decrypt_images(_urls, nil), do: []

  defp decrypt_images(image_urls, post_key) do
    Enum.map(image_urls, fn encrypted_url ->
      decrypt_with_key(encrypted_url, post_key)
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp decrypt_avatar(post, post_key) do
    if is_nil(post.avatar_url) do
      nil
    else
      decrypt_with_key(post.avatar_url, post_key)
    end
  end

  defp get_post_author_avatar(post, nil, post_key) do
    import MossletWeb.Helpers, only: [show_avatar?: 1]

    user_connection = get_author_user_connection(post)

    if show_avatar?(user_connection) do
      decrypt_avatar(post, post_key)
    else
      nil
    end
  end

  defp get_post_author_avatar(post, current_user, post_key) do
    import MossletWeb.Helpers, only: [show_avatar?: 1]

    if post.user_id == current_user.id do
      user_connection = get_author_user_connection(post)

      if show_avatar?(user_connection) do
        decrypt_avatar(post, post_key)
      else
        nil
      end
    else
      nil
    end
  end

  defp get_author_user_connection(post) do
    case post.user do
      nil -> nil
      user -> user.connection
    end
  end

  defp get_author_profile_slug(post) do
    user = post.user

    cond do
      is_nil(user) -> nil
      user.visibility == :private -> nil
      true -> user.username
    end
  end

  defp get_author_profile_visibility(post) do
    case Mosslet.Accounts.get_user_with_preloads(post.user_id) do
      %{connection: %{profile: %{visibility: visibility}}} -> visibility
      _ -> nil
    end
  end

  defp decrypt_url_preview(post, post_key) do
    url_preview = post.url_preview

    cond do
      is_nil(url_preview) ->
        nil

      is_nil(post_key) ->
        nil

      true ->
        %{
          "url" =>
            decrypt_with_key(Map.get(url_preview, :url) || Map.get(url_preview, "url"), post_key),
          "title" =>
            decrypt_with_key(
              Map.get(url_preview, :title) || Map.get(url_preview, "title"),
              post_key
            ),
          "description" =>
            decrypt_with_key(
              Map.get(url_preview, :description) || Map.get(url_preview, "description"),
              post_key
            ),
          "image" =>
            decrypt_with_key(
              Map.get(url_preview, :image) || Map.get(url_preview, "image"),
              post_key
            ),
          "image_hash" => Map.get(url_preview, :image_hash) || Map.get(url_preview, "image_hash"),
          "site_name" =>
            decrypt_with_key(
              Map.get(url_preview, :site_name) || Map.get(url_preview, "site_name"),
              post_key
            )
        }
    end
  end

  defp format_timestamp(datetime) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604_800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:public_timeline}
      container_max_width={@max_width}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-orange-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-orange-900/10">
        <div class="isolate">
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-orange-400/30 via-amber-400/20 to-yellow-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-3xl lg:max-w-4xl px-4 sm:px-6 pb-16 pt-24 sm:pt-32 lg:px-8">
                <div class="text-center mb-8 sm:mb-12">
                  <div class="flex items-center justify-center gap-3">
                    <h1 class="text-4xl sm:text-5xl font-bold tracking-tight bg-gradient-to-r from-orange-500 to-amber-500 bg-clip-text text-transparent">
                      Discover
                    </h1>
                    <button
                      id="rss-feed-copy-btn"
                      phx-hook="ClipboardHook"
                      data-content={url(~p"/feed/public.xml")}
                      aria-label="Copy RSS feed URL"
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300 text-sm font-medium hover:bg-orange-200 dark:hover:bg-orange-900/50 transition-colors cursor-pointer"
                    >
                      <span
                        id="rss-feed-copy-tooltip"
                        phx-hook="TippyHook"
                        data-tippy-content="Copy RSS feed URL to cliboard"
                      >
                        <.phx_icon name="hero-rss" class="h-4 w-4" />
                        <span class="hidden sm:inline">RSS</span>
                      </span>
                    </button>
                  </div>
                  <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
                    Public posts from our community
                  </p>
                  <div class="mt-6 flex justify-center">
                    <div class="h-1 w-24 rounded-full bg-gradient-to-r from-orange-400 via-amber-400 to-yellow-400 shadow-sm shadow-orange-500/30">
                    </div>
                  </div>
                </div>

                <div :if={@loading} class="space-y-4">
                  <.post_skeleton :for={_ <- 1..3} />
                </div>

                <div :if={!@loading && @posts_empty} class="text-center py-16">
                  <.liquid_card padding="lg" class="max-w-md mx-auto">
                    <div class="flex flex-col items-center gap-4">
                      <div class="p-4 rounded-full bg-orange-100 dark:bg-orange-900/30">
                        <.phx_icon
                          name="hero-globe-alt"
                          class="h-8 w-8 text-orange-500 dark:text-orange-400"
                        />
                      </div>
                      <p class="text-slate-600 dark:text-slate-400">
                        No public posts yet. Be the first to share something!
                      </p>
                      <.liquid_button navigate="/auth/register" color="orange" variant="primary">
                        Join MOSSLET
                      </.liquid_button>
                    </div>
                  </.liquid_card>
                </div>

                <div
                  :if={!@loading && !@posts_empty}
                  id="public-posts"
                  phx-update="stream"
                  class="space-y-4 sm:space-y-5"
                >
                  <div class="hidden only:block text-center py-16">
                    <.liquid_card padding="lg" class="max-w-md mx-auto">
                      <div class="flex flex-col items-center gap-4">
                        <div class="p-4 rounded-full bg-orange-100 dark:bg-orange-900/30">
                          <.phx_icon
                            name="hero-globe-alt"
                            class="h-8 w-8 text-orange-500 dark:text-orange-400"
                          />
                        </div>
                        <p class="text-slate-600 dark:text-slate-400">
                          No public posts yet. Be the first to share something!
                        </p>
                        <.liquid_button navigate="/auth/register" color="orange" variant="primary">
                          Join MOSSLET
                        </.liquid_button>
                      </div>
                    </.liquid_card>
                  </div>
                  <div :for={{dom_id, item} <- @streams.posts} id={dom_id}>
                    <.liquid_timeline_date_separator
                      :if={get_separator_show(@date_separators, item)}
                      date={get_separator_date(@date_separators, item)}
                      first={get_separator_first(@date_separators, item)}
                      color="orange"
                    />
                    <.public_timeline_card
                      id={"public-post-#{item.post.id}"}
                      user_name={item.username || "MOSSLET User"}
                      user_handle={"@" <> (item.username || "author")}
                      user_avatar={item.avatar}
                      author_profile_slug={item.profile_slug}
                      author_profile_visibility={item.profile_visibility}
                      timestamp={item.timestamp}
                      content_warning?={item.post.content_warning? || false}
                      content_warning={item.content_warning}
                      content_warning_category={item.content_warning_category}
                      content={item.content || ""}
                      images={item.images}
                      decrypted_url_preview={item.url_preview}
                      url_preview_fetched_at={item.post.url_preview_fetched_at}
                      stats={%{replies: item.reply_count, likes: item.post.favs_count || 0}}
                    />
                  </div>
                </div>

                <.liquid_timeline_scroll_indicator
                  :if={!@loading && !@posts_empty && @has_more}
                  remaining_count={max(0, @total_posts_count - @loaded_posts_count)}
                  load_count={min(@posts_per_page, max(0, @total_posts_count - @loaded_posts_count))}
                  loading={@load_more_loading}
                  tab_color="orange"
                  phx-click="load_more"
                />

                <div :if={!@loading && !@posts_empty && !@has_more} class="text-center py-12">
                  <div class="inline-flex flex-col items-center gap-4 px-8 py-6 rounded-2xl bg-gradient-to-br from-orange-50/40 via-amber-50/30 to-yellow-50/40 dark:from-orange-900/10 dark:via-amber-900/5 dark:to-yellow-900/10 border border-orange-200/40 dark:border-orange-700/30">
                    <.phx_icon name="hero-heart" class="h-8 w-8 text-orange-500" />
                    <div class="text-center">
                      <p class="text-sm font-medium text-orange-700 dark:text-orange-300 mb-1">
                        You're all caught up!
                      </p>
                      <p class="text-xs text-slate-600 dark:text-slate-400 max-w-xs">
                        Time to step away and enjoy the real world. Our community will be here when you return.
                      </p>
                    </div>
                  </div>
                </div>

                <div class="mt-12 sm:mt-16 text-center">
                  <.liquid_card
                    padding="lg"
                    class="bg-gradient-to-br from-orange-50/40 via-amber-50/30 to-yellow-50/40 dark:from-orange-900/15 dark:via-amber-900/10 dark:to-yellow-900/15 border-orange-200/60 dark:border-orange-700/30"
                  >
                    <h2 class="text-xl font-bold bg-gradient-to-r from-orange-500 to-amber-500 bg-clip-text text-transparent">
                      Want to join the conversation?
                    </h2>
                    <p class="mt-3 text-slate-600 dark:text-slate-400">
                      Create an account to share moments with friends and family, not algorithms.
                    </p>
                    <div class="mt-6 flex flex-col sm:flex-row gap-3 justify-center">
                      <.liquid_button
                        navigate="/auth/register"
                        color="orange"
                        variant="primary"
                        icon="hero-user-plus"
                      >
                        Sign Up Free
                      </.liquid_button>
                      <.liquid_button
                        navigate="/auth/sign_in"
                        color="slate"
                        variant="secondary"
                        icon="hero-arrow-right-on-rectangle"
                      >
                        Sign In
                      </.liquid_button>
                    </div>
                  </.liquid_card>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <.liquid_image_modal
        id="public-timeline-image-modal"
        show={@show_image_modal}
        images={@current_images}
        current_index={@current_image_index}
        can_download={false}
        on_cancel={JS.push("close_image_modal")}
      />
    </.layout>
    """
  end

  defp post_skeleton(assigns) do
    ~H"""
    <.liquid_card padding="md">
      <div class="flex items-start gap-4 animate-pulse">
        <div class="h-12 w-12 rounded-full bg-gradient-to-br from-orange-200/60 to-amber-200/60 dark:from-orange-800/40 dark:to-amber-800/40">
        </div>
        <div class="flex-1 space-y-3">
          <div class="space-y-2">
            <div class="h-4 bg-orange-200/60 dark:bg-orange-800/40 rounded w-32"></div>
            <div class="h-3 bg-slate-200/60 dark:bg-slate-700/40 rounded w-24"></div>
          </div>
          <div class="space-y-2">
            <div class="h-4 bg-slate-200/60 dark:bg-slate-700/40 rounded w-full"></div>
            <div class="h-4 bg-slate-200/60 dark:bg-slate-700/40 rounded w-3/4"></div>
          </div>
        </div>
      </div>
    </.liquid_card>
    """
  end
end
