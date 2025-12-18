defmodule Mosslet.Timeline.Adapters.Native do
  @moduledoc """
  Native adapter for timeline operations on desktop/mobile apps.

  This adapter communicates with the cloud server via HTTP API and
  caches data locally in SQLite for offline support.

  ## Flow

  1. API calls go to Fly.io server
  2. Server validates and returns data
  3. Data cached locally for offline access
  4. Offline operations queued for sync

  ## Zero-Knowledge

  All encryption/decryption happens locally on the device.
  The server only sees encrypted blobs.
  """

  @behaviour Mosslet.Timeline.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync
  alias Mosslet.Timeline.{Post, Reply, UserPost, Bookmark, BookmarkCategory}

  @impl true
  def get_post(id) do
    with_fallback_to_cache("post", id, fn ->
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{post: post_data}} <- Client.request(:get, "/api/posts/#{id}", %{}, auth: token) do
        cache_post(post_data)
        deserialize_post(post_data)
      else
        _ -> nil
      end
    end)
  end

  @impl true
  def get_post!(id) do
    case get_post(id) do
      nil -> raise Ecto.NoResultsError, queryable: Post
      post -> post
    end
  end

  @impl true
  def get_post_with_nested_replies(id, options \\ %{}) do
    case get_post(id) do
      nil ->
        nil

      post ->
        nested_replies = get_nested_replies_for_post(id, options)
        total_reply_count = count_replies_for_post(id, options)

        post
        |> Map.put(:replies, nested_replies)
        |> Map.put(:total_reply_count, total_reply_count)
    end
  end

  @impl true
  def get_reply(id) do
    with_fallback_to_cache("reply", id, fn ->
      nil
    end)
  end

  @impl true
  def get_reply!(id) do
    case get_reply(id) do
      nil -> raise Ecto.NoResultsError, queryable: Reply
      reply -> reply
    end
  end

  @impl true
  def create_post(attrs \\ %{}, _opts \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{post: post_data}} <- Client.create_post(token, %{post: attrs}) do
        cache_post(post_data)
        {:ok, deserialize_post(post_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = %Post{} |> Post.changeset(attrs) |> apply_api_errors(errors)
          {:error, changeset}

        {:error, reason} ->
          Logger.error("Native create_post failed: #{inspect(reason)}")

          {:error,
           %Post{}
           |> Post.changeset(attrs)
           |> Ecto.Changeset.add_error(:base, "Failed to create post")}
      end
    else
      Cache.queue_for_sync("post", "create", attrs)

      {:error,
       %Post{}
       |> Post.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def create_public_post(attrs \\ %{}, opts \\ []) do
    create_post(Map.put(attrs, :visibility, :public), opts)
  end

  @impl true
  def update_post(%Post{} = post, attrs, _opts \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{post: post_data}} <- Client.update_post(token, post.id, %{post: attrs}) do
        cache_post(post_data)
        {:ok, deserialize_post(post_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = post |> Post.changeset(attrs) |> apply_api_errors(errors)
          {:error, changeset}

        {:error, reason} ->
          Logger.error("Native update_post failed: #{inspect(reason)}")

          {:error,
           post
           |> Post.changeset(attrs)
           |> Ecto.Changeset.add_error(:base, "Failed to update post")}
      end
    else
      Cache.queue_for_sync("post", "update", Map.put(attrs, :id, post.id))

      {:error,
       post
       |> Post.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def update_public_post(%Post{} = post, attrs, opts \\ []) do
    update_post(post, attrs, opts)
  end

  @impl true
  def delete_post(%Post{} = post, _opts \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_post(token, post.id) do
        Cache.delete_cached_item("post", post.id)
        {:ok, post}
      else
        {:error, reason} ->
          Logger.error("Native delete_post failed: #{inspect(reason)}")

          {:error,
           post |> Post.changeset(%{}) |> Ecto.Changeset.add_error(:base, "Failed to delete post")}
      end
    else
      Cache.queue_for_sync("post", "delete", %{id: post.id})

      {:error,
       post |> Post.changeset(%{}) |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def delete_group_post(%Post{} = post, opts \\ []) do
    delete_post(post, opts)
  end

  @impl true
  def create_reply(attrs, _opts \\ []) do
    if Sync.online?() do
      Logger.warning("create_reply via API not yet implemented")

      {:error,
       %Reply{}
       |> Reply.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
    else
      Cache.queue_for_sync("reply", "create", attrs)

      {:error,
       %Reply{}
       |> Reply.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def update_reply(%Reply{} = reply, attrs, _opts \\ []) do
    if Sync.online?() do
      Logger.warning("update_reply via API not yet implemented")

      {:error,
       reply
       |> Reply.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
    else
      Cache.queue_for_sync("reply", "update", Map.put(attrs, :id, reply.id))

      {:error,
       reply
       |> Reply.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def delete_reply(%Reply{} = reply, _opts \\ []) do
    if Sync.online?() do
      Logger.warning("delete_reply via API not yet implemented")

      {:error,
       reply
       |> Reply.changeset(%{})
       |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
    else
      Cache.queue_for_sync("reply", "delete", %{id: reply.id})

      {:error,
       reply
       |> Reply.changeset(%{})
       |> Ecto.Changeset.add_error(:base, "Offline - queued for sync")}
    end
  end

  @impl true
  def list_posts(user, options) do
    with_fallback_to_cached_posts(user, fn ->
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{posts: posts_data}} <- Client.fetch_posts(token, build_list_opts(options)) do
        Enum.each(posts_data, &cache_post/1)
        Enum.map(posts_data, &deserialize_post/1)
      else
        _ -> list_cached_posts_for_user(user.id)
      end
    end)
  end

  @impl true
  def list_user_posts_for_sync(user, opts \\ []) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{posts: posts_data}} <- Client.fetch_posts(token, opts) do
      Enum.each(posts_data, &cache_post/1)
      Enum.map(posts_data, &deserialize_post/1)
    else
      _ -> list_cached_posts_for_user(user.id)
    end
  end

  @impl true
  def list_user_own_posts(user, options) do
    list_posts(user, Map.put(options, :user_id, user.id))
  end

  @impl true
  def list_connection_posts(user, options \\ %{}) do
    list_posts(user, Map.put(options, :tab, :connections))
  end

  @impl true
  def list_group_posts(user, options \\ %{}) do
    list_posts(user, Map.put(options, :tab, :groups))
  end

  @impl true
  def list_discover_posts(_user \\ nil, _options \\ %{}) do
    []
  end

  @impl true
  def filter_timeline_posts(user, options) do
    list_posts(user, options)
  end

  @impl true
  def fetch_timeline_posts_from_db(user, options) do
    list_posts(user, options)
  end

  @impl true
  def list_replies(_post, _options) do
    []
  end

  @impl true
  def list_public_replies(_post, _options) do
    []
  end

  @impl true
  def get_nested_replies_for_post(_post_id, _options \\ %{}) do
    []
  end

  @impl true
  def get_child_replies_for_reply(_parent_reply_id, _options \\ %{}) do
    []
  end

  @impl true
  def inc_favs(%Post{} = _post) do
    {0, nil}
  end

  @impl true
  def decr_favs(%Post{} = _post) do
    {0, nil}
  end

  @impl true
  def inc_reply_favs(%Reply{} = _reply) do
    {0, nil}
  end

  @impl true
  def decr_reply_favs(%Reply{} = _reply) do
    {0, nil}
  end

  @impl true
  def update_post_fav(%Post{} = post, attrs, _opts \\ []) do
    if Sync.online?() do
      Logger.warning("update_post_fav via API not yet implemented")

      {:error,
       post
       |> Post.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
    else
      {:error, post |> Post.changeset(attrs) |> Ecto.Changeset.add_error(:base, "Offline")}
    end
  end

  @impl true
  def update_reply_fav(%Reply{} = reply, attrs, _opts \\ []) do
    if Sync.online?() do
      Logger.warning("update_reply_fav via API not yet implemented")

      {:error,
       reply
       |> Reply.changeset(attrs)
       |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
    else
      {:error, reply |> Reply.changeset(attrs) |> Ecto.Changeset.add_error(:base, "Offline")}
    end
  end

  @impl true
  def create_bookmark(_user, _post, _attrs \\ %{}) do
    Logger.warning("create_bookmark via API not yet implemented")
    {:error, :not_implemented}
  end

  @impl true
  def update_bookmark(_bookmark, _attrs, _user) do
    Logger.warning("update_bookmark via API not yet implemented")

    {:error,
     %Bookmark{}
     |> Bookmark.changeset(%{})
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def delete_bookmark(_bookmark, _user) do
    Logger.warning("delete_bookmark via API not yet implemented")

    {:error,
     %Bookmark{}
     |> Bookmark.changeset(%{})
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def get_bookmark(_user, _post) do
    nil
  end

  @impl true
  def bookmarked?(_user, _post) do
    false
  end

  @impl true
  def list_user_bookmarks(_user, _opts \\ []) do
    []
  end

  @impl true
  def list_user_bookmark_categories(_user) do
    []
  end

  @impl true
  def create_bookmark_category(_user, attrs) do
    {:error,
     %BookmarkCategory{}
     |> BookmarkCategory.changeset(attrs)
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def update_bookmark_category(category, _attrs) do
    {:error,
     category
     |> BookmarkCategory.changeset(%{})
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def delete_bookmark_category(category) do
    {:error,
     category
     |> BookmarkCategory.changeset(%{})
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def get_user_bookmark_category(_user, _category_id) do
    nil
  end

  @impl true
  def count_all_posts() do
    Cache.list_cached_items("post")
    |> length()
  end

  @impl true
  def post_count(user, _options) do
    list_cached_posts_for_user(user.id)
    |> length()
  end

  @impl true
  def count_user_own_posts(user, _filter_prefs \\ %{}) do
    list_cached_posts_for_user(user.id)
    |> Enum.filter(fn post -> post.user_id == user.id end)
    |> length()
  end

  @impl true
  def count_user_group_posts(_user, _filter_prefs \\ %{}) do
    0
  end

  @impl true
  def count_user_connection_posts(_user, _filter_prefs \\ %{}) do
    0
  end

  @impl true
  def count_discover_posts(_user \\ nil, _filter_prefs \\ %{}) do
    0
  end

  @impl true
  def count_unread_posts_for_user(_user) do
    0
  end

  @impl true
  def count_unread_replies_for_user(_user) do
    0
  end

  @impl true
  def count_replies_for_post(_post_id, _options \\ %{}) do
    0
  end

  @impl true
  def count_user_bookmarks(_user, _filter_prefs \\ %{}) do
    0
  end

  @impl true
  def get_timeline_data(user, tab, options \\ %{}) do
    posts = list_posts(user, Map.put(options, :tab, tab))
    count = length(posts)

    %{
      posts: posts,
      count: count,
      tab: tab
    }
  end

  @impl true
  def get_timeline_counts(user) do
    own_count = count_user_own_posts(user)

    %{
      own: own_count,
      connections: 0,
      groups: 0,
      discover: 0,
      bookmarks: 0
    }
  end

  @impl true
  def get_user_timeline_preference(_user) do
    nil
  end

  @impl true
  def update_user_timeline_preference(_user, _attrs, _opts \\ []) do
    Logger.warning("update_user_timeline_preference via API not yet implemented")
    {:error, Ecto.Changeset.add_error(%Ecto.Changeset{}, :base, "Not implemented for native yet")}
  end

  @impl true
  def create_or_update_user_post_receipt(_user_post, _user, _is_read?) do
    {:ok, nil}
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, _user_id) do
    case Cache.get_cached_item("user_post", post_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_user_post(data)

      _ ->
        nil
    end
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    case get_user_post_by_post_id_and_user_id(post_id, user_id) do
      nil -> raise Ecto.NoResultsError, queryable: UserPost
      user_post -> user_post
    end
  end

  @impl true
  def share_post_with_user(_post, _user_to_share_with, _decrypted_post_key, _opts \\ []) do
    Logger.warning("share_post_with_user via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def remove_self_from_shared_post(_user_post, _opts \\ []) do
    Logger.warning("remove_self_from_shared_post via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def delete_user_post(_user_post, _opts \\ []) do
    Logger.warning("delete_user_post via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def get_blocked_user_ids(_user) do
    []
  end

  @impl true
  def hide_post(_user, _post, _attrs \\ %{}) do
    Logger.warning("hide_post via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def unhide_post(_user, _post) do
    Logger.warning("unhide_post via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def post_hidden?(_user, _post) do
    false
  end

  @impl true
  def report_post(_reporter, _reported_user, _post, _attrs) do
    Logger.warning("report_post via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def mark_top_level_replies_read_for_post(_post_id, _user_id) do
    :ok
  end

  @impl true
  def mark_nested_replies_read_for_parent(_parent_reply_id, _user_id) do
    :ok
  end

  @impl true
  def mark_all_replies_read_for_user(_user_id) do
    :ok
  end

  @impl true
  def preload_group(post) do
    post
  end

  @impl true
  def change_post(%Post{} = post, attrs \\ %{}, opts \\ []) do
    Post.changeset(post, attrs, opts)
  end

  @impl true
  def change_reply(%Reply{} = reply, attrs \\ %{}, opts \\ []) do
    Reply.changeset(reply, attrs, opts)
  end

  @impl true
  def inc_reposts(%Post{} = _post) do
    {0, nil}
  end

  @impl true
  def create_public_repost(attrs \\ %{}, _opts \\ []) do
    Logger.warning("create_public_repost via API not yet implemented")

    {:error,
     %Post{}
     |> Post.changeset(attrs)
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def create_repost(attrs \\ %{}, _opts \\ []) do
    Logger.warning("create_repost via API not yet implemented")

    {:error,
     %Post{}
     |> Post.changeset(attrs)
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def create_targeted_share(_attrs \\ %{}, _opts \\ []) do
    Logger.warning("create_targeted_share via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def update_post_shared_users(post, attrs, _opts \\ []) do
    Logger.warning("update_post_shared_users via API not yet implemented")

    {:error,
     post
     |> Post.changeset(attrs)
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def remove_post_shared_user(post, attrs, _opts \\ []) do
    Logger.warning("remove_post_shared_user via API not yet implemented")

    {:error,
     post
     |> Post.changeset(attrs)
     |> Ecto.Changeset.add_error(:base, "Not implemented for native yet")}
  end

  @impl true
  def get_or_create_user_post_for_public(_post, _user) do
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def get_user_post(_post, _user) do
    nil
  end

  @impl true
  def change_user_timeline_preference(pref, attrs, _opts \\ []) do
    Ecto.Changeset.change(pref || %{}, attrs)
  end

  @impl true
  def invalidate_timeline_cache_for_user(_user_id, _affecting_tabs \\ nil) do
    :ok
  end

  @impl true
  def get_expired_ephemeral_posts(_current_time \\ nil) do
    []
  end

  @impl true
  def get_user_ephemeral_posts(_user) do
    []
  end

  defp with_fallback_to_cache(type, id, fetch_fn) do
    if Sync.online?() do
      case fetch_fn.() do
        nil -> get_from_cache(type, id)
        result -> result
      end
    else
      get_from_cache(type, id)
    end
  end

  defp with_fallback_to_cached_posts(user, fetch_fn) do
    if Sync.online?() do
      case fetch_fn.() do
        [] -> list_cached_posts_for_user(user.id)
        posts -> posts
      end
    else
      list_cached_posts_for_user(user.id)
    end
  end

  defp get_from_cache(type, id) do
    case Cache.get_cached_item(type, id) do
      %{encrypted_data: data} when not is_nil(data) ->
        case type do
          "post" -> deserialize_post(data)
          "reply" -> deserialize_reply(data)
          "user_post" -> deserialize_user_post(data)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp list_cached_posts_for_user(user_id) do
    case Cache.list_cached_items("post") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_post(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn post ->
          post.user_id == user_id ||
            Enum.any?(post.user_posts || [], fn up -> up.user_id == user_id end)
        end)

      _ ->
        []
    end
  end

  defp cache_post(post_data) when is_map(post_data) do
    id = post_data["id"] || post_data[:id]
    if id, do: Cache.cache_item("post", id, post_data)
  end

  defp cache_post(_), do: :ok

  defp build_list_opts(options) do
    opts = []
    opts = if options[:since], do: Keyword.put(opts, :since, options[:since]), else: opts
    opts = if options[:limit], do: Keyword.put(opts, :limit, options[:limit]), else: opts
    opts
  end

  defp deserialize_post(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_post(map)
      _ -> nil
    end
  end

  defp deserialize_post(data) when is_map(data) do
    struct(Post, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_post(_), do: nil

  defp deserialize_reply(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_reply(map)
      _ -> nil
    end
  end

  defp deserialize_reply(data) when is_map(data) do
    struct(Reply, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_reply(_), do: nil

  defp deserialize_user_post(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_user_post(map)
      _ -> nil
    end
  end

  defp deserialize_user_post(data) when is_map(data) do
    struct(UserPost, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_user_post(_), do: nil

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> map
  end

  defp apply_api_errors(changeset, errors) when is_map(errors) do
    Enum.reduce(errors, changeset, fn {field, messages}, cs ->
      field_atom =
        if is_binary(field), do: String.to_existing_atom(field), else: field

      messages = if is_list(messages), do: messages, else: [messages]

      Enum.reduce(messages, cs, fn msg, inner_cs ->
        Ecto.Changeset.add_error(inner_cs, field_atom, msg)
      end)
    end)
  rescue
    _ -> changeset
  end
end
