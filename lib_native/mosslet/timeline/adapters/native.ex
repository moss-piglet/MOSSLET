defmodule Mosslet.Timeline.Adapters.Native do
  @moduledoc """
  Native adapter for timeline operations.

  This adapter uses HTTP API calls to the cloud server via `Mosslet.API.Client`
  and local SQLite cache via `Mosslet.Cache`.

  This adapter is used for desktop and mobile native app deployments.
  """

  @behaviour Mosslet.Timeline.Adapter

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync

  defp get_token do
    case NativeSession.get_token() do
      {:ok, token} -> token
      _ -> nil
    end
  end

  @impl true
  def get_post(id) do
    if :new == id || "new" == id do
      nil
    else
      token = get_token()

      if Sync.online?() && token do
        case Client.get_post(token, id) do
          {:ok, %{post: post_data}} -> deserialize_post(post_data)
          {:error, _reason} -> get_cached_post(id)
        end
      else
        get_cached_post(id)
      end
    end
  end

  @impl true
  def get_post!(id) do
    case get_post(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.Post
      post -> post
    end
  end

  @impl true
  def get_reply(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_reply(token, id) do
        {:ok, %{reply: reply_data}} -> deserialize_reply(reply_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_reply!(id) do
    case get_reply(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.Reply
      reply -> reply
    end
  end

  @impl true
  def get_user_post!(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post(token, id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
    end
  end

  @impl true
  def get_user_post_receipt!(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_receipt(token, id) do
        {:ok, %{receipt: receipt_data}} ->
          deserialize_user_post_receipt(receipt_data)

        {:error, _reason} ->
          raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPostReceipt
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPostReceipt
    end
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_by_post_and_user(token, post_id, user_id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
    end
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_by_post_and_user(token, post_id, user_id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_all_posts(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_posts(token, user.id) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def get_all_shared_posts(user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_shared_posts(token, user_id) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_user_posts_for_sync(_user, opts \\ []) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_posts(token, opts) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_user_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def preload_group(post) do
    post
  end

  @impl true
  def count_all_posts do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_all_posts(token) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def post_count(user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.post_count(token, user.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def shared_between_users_post_count(user_id, current_user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.shared_between_users_post_count(token, user_id, current_user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def timeline_post_count(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.timeline_post_count(token, current_user.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def reply_count(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.reply_count(token, post.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_reply_count(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_reply_count(token, post.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def group_post_count(group) do
    token = get_token()

    if Sync.online?() && token do
      case Client.group_post_count(token, group.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_post_count_filtered(_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_post_count_filtered(token, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_post_count(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_post_count(token, user.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_user_own_posts(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_user_own_posts(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_user_group_posts(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_user_group_posts(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_user_connection_posts(current_user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_user_connection_posts(token, current_user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_user_own_posts(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_user_own_posts(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_bookmarked_posts(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_bookmarked_posts(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_posts_for_user(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_posts_for_user(token, user.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_replies_for_user(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_replies_for_user(token, user.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_replies_to_user_replies(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_replies_to_user_replies(token, user.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_replies_by_post(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_replies_by_post(token, user.id) do
        {:ok, %{counts: counts}} -> counts
        {:error, _reason} -> %{}
      end
    else
      %{}
    end
  end

  @impl true
  def count_unread_nested_replies_by_parent(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_nested_replies_by_parent(token, user.id) do
        {:ok, %{counts: counts}} -> counts
        {:error, _reason} -> %{}
      end
    else
      %{}
    end
  end

  @impl true
  def count_unread_replies_to_user_replies_by_post(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_replies_to_user_replies_by_post(token, user.id) do
        {:ok, %{counts: counts}} -> counts
        {:error, _reason} -> %{}
      end
    else
      %{}
    end
  end

  @impl true
  def count_unread_nested_replies_for_post(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_nested_replies_for_post(token, post_id, user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_connection_posts(current_user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_connection_posts(token, current_user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_group_posts(current_user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_group_posts(token, current_user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_discover_posts(current_user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      user_id = if current_user, do: current_user.id, else: nil

      case Client.count_discover_posts(token, user_id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_discover_posts(current_user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_discover_posts(token, current_user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_replies_for_post(post_id, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_replies_for_post(token, post_id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_top_level_replies(post_id, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_top_level_replies(token, post_id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_child_replies(parent_reply_id, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_child_replies(token, parent_reply_id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_user_bookmarks(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_user_bookmarks(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def list_posts(user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_posts(token, user.id, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_replies(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_replies(token, post.id, options) do
        {:ok, %{replies: replies_data}} -> Enum.map(replies_data, &deserialize_reply/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_shared_posts(user_id, current_user_id, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_shared_posts(token, user_id, current_user_id, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_public_posts(_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_public_posts(token, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_public_replies(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_public_replies(token, post.id, options) do
        {:ok, %{replies: replies_data}} -> Enum.map(replies_data, &deserialize_reply/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_user_bookmarks(user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_user_bookmarks(token, user.id, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_bookmark_categories(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_bookmark_categories(token, user.id) do
        {:ok, %{categories: categories_data}} ->
          Enum.map(categories_data, &deserialize_bookmark_category/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  defp deserialize_bookmark_category(nil), do: nil

  defp deserialize_bookmark_category(data) when is_map(data) do
    %Mosslet.Timeline.BookmarkCategory{
      id: data["id"],
      name: data["name"],
      user_id: data["user_id"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  @impl true
  def mark_replies_read_for_post(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_replies_read_for_post(token, post_id, user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      Cache.queue_for_sync("reply", "mark_read_for_post", %{
        post_id: post_id,
        user_id: user_id
      })

      0
    end
  end

  @impl true
  def mark_all_replies_read_for_user(user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_all_replies_read_for_user(token, user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      Cache.queue_for_sync("reply", "mark_all_read", %{user_id: user_id})
      0
    end
  end

  @impl true
  def mark_nested_replies_read_for_parent(parent_reply_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_nested_replies_read_for_parent(token, parent_reply_id, user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      Cache.queue_for_sync("reply", "mark_nested_read", %{
        parent_reply_id: parent_reply_id,
        user_id: user_id
      })

      0
    end
  end

  @impl true
  def create_bookmark_category(attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_bookmark_category(token, attrs) do
        {:ok, %{category: category_data}} ->
          {:ok, deserialize_bookmark_category(category_data)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot create bookmark category"}
    end
  end

  @impl true
  def update_bookmark_category(category, attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.update_bookmark_category(token, category.id, attrs) do
        {:ok, %{category: category_data}} ->
          {:ok, deserialize_bookmark_category(category_data)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot update bookmark category"}
    end
  end

  @impl true
  def delete_bookmark_category(category) do
    token = get_token()

    if Sync.online?() && token do
      case Client.delete_bookmark_category(token, category.id) do
        {:ok, _} -> {:ok, category}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot delete bookmark category"}
    end
  end

  @impl true
  def get_post_with_preloads(id) do
    get_post(id)
  end

  @impl true
  def get_post_with_preloads!(id) do
    get_post!(id)
  end

  @impl true
  def get_reply_with_preloads(id) do
    get_reply(id)
  end

  @impl true
  def get_reply_with_preloads!(id) do
    get_reply!(id)
  end

  @impl true
  def get_user_post(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post(token, id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_user_post_receipt(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_receipt(token, id) do
        {:ok, %{receipt: receipt_data}} -> deserialize_user_post_receipt(receipt_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_bookmark(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_bookmark(token, id) do
        {:ok, %{bookmark: bookmark_data}} -> deserialize_bookmark(bookmark_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_bookmark!(id) do
    case get_bookmark(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.Bookmark
      bookmark -> bookmark
    end
  end

  @impl true
  def get_bookmark_by_post_and_user(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_bookmark_by_post_and_user(token, post_id, user_id) do
        {:ok, %{bookmark: bookmark_data}} -> deserialize_bookmark(bookmark_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_bookmark_category(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_bookmark_category(token, id) do
        {:ok, %{category: category_data}} -> deserialize_bookmark_category(category_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_bookmark_category!(id) do
    case get_bookmark_category(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.BookmarkCategory
      category -> category
    end
  end

  @impl true
  def user_has_bookmarked?(user_id, post_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.user_has_bookmarked?(token, user_id, post_id) do
        {:ok, %{bookmarked: bookmarked}} -> bookmarked
        {:error, _reason} -> false
      end
    else
      false
    end
  end

  @impl true
  def preload_post(post, _preloads), do: post

  @impl true
  def preload_reply(reply, _preloads), do: reply

  @impl true
  def execute_query(_query), do: []

  @impl true
  def execute_count(_query), do: 0

  @impl true
  def execute_one(_query), do: nil

  @impl true
  def execute_exists?(_query), do: false

  @impl true
  def transaction(fun), do: {:ok, fun.()}

  @impl true
  def filter_timeline_posts(_current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.filter_timeline_posts(token, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_group_posts(group, _user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_group_posts(token, group.id, options) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_nested_replies(parent_reply_id, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_nested_replies(token, parent_reply_id, options) do
        {:ok, %{replies: replies_data}} -> Enum.map(replies_data, &deserialize_reply/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_user_replies(user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_user_replies(token, user.id, options) do
        {:ok, %{replies: replies_data}} -> Enum.map(replies_data, &deserialize_reply/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def mark_post_as_read(user_post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_post_as_read(token, user_post_id, user_id) do
        {:ok, %{receipt: receipt_data}} -> {:ok, deserialize_user_post_receipt(receipt_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("receipt", "mark_read", %{
        user_post_id: user_post_id,
        user_id: user_id
      })

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def create_bookmark(attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_bookmark(token, attrs) do
        {:ok, %{bookmark: bookmark_data}} -> {:ok, deserialize_bookmark(bookmark_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot create bookmark"}
    end
  end

  @impl true
  def delete_bookmark(bookmark) do
    token = get_token()

    if Sync.online?() && token do
      case Client.delete_bookmark(token, bookmark.id) do
        {:ok, _} -> {:ok, bookmark}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot delete bookmark"}
    end
  end

  @impl true
  def create_post(attrs, _opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_post(token, attrs) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("post", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_post(post, attrs, _opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.update_post(token, post.id, attrs) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("post", "update", Map.put(attrs, :id, post.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_post(post) do
    token = get_token()

    if Sync.online?() && token do
      case Client.delete_post(token, post.id) do
        {:ok, _} -> {:ok, post}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("post", "delete", %{id: post.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def create_reply(attrs, _opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_reply(token, attrs) do
        {:ok, %{reply: reply_data}} -> {:ok, deserialize_reply(reply_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("reply", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_reply(reply, attrs, _opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.update_reply(token, reply.id, attrs) do
        {:ok, %{reply: reply_data}} -> {:ok, deserialize_reply(reply_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("reply", "update", Map.put(attrs, :id, reply.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_reply(reply) do
    token = get_token()

    if Sync.online?() && token do
      case Client.delete_reply(token, reply.id) do
        {:ok, _} -> {:ok, reply}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("reply", "delete", %{id: reply.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def create_user_post(attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_user_post(token, attrs) do
        {:ok, %{user_post: user_post_data}} -> {:ok, deserialize_user_post(user_post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot create user_post"}
    end
  end

  @impl true
  def delete_user_post(user_post) do
    token = get_token()

    if Sync.online?() && token do
      case Client.delete_user_post(token, user_post.id) do
        {:ok, _} -> {:ok, user_post}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot delete user_post"}
    end
  end

  @impl true
  def create_user_post_receipt(attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_user_post_receipt(token, attrs) do
        {:ok, %{receipt: receipt_data}} -> {:ok, deserialize_user_post_receipt(receipt_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot create receipt"}
    end
  end

  @impl true
  def update_user_post_receipt(receipt, attrs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.update_user_post_receipt(token, receipt.id, attrs) do
        {:ok, %{receipt: receipt_data}} -> {:ok, deserialize_user_post_receipt(receipt_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot update receipt"}
    end
  end

  # =============================================================================
  # Bluesky Sync Operations
  # =============================================================================

  @impl true
  def post_exists_by_external_uri?(uri, bluesky_account_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.post_exists_by_external_uri?(token, uri, bluesky_account_id) do
        {:ok, %{exists: exists}} -> exists
        {:error, _reason} -> false
      end
    else
      false
    end
  end

  @impl true
  def get_post_by_external_uri(uri, bluesky_account_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_post_by_external_uri(token, uri, bluesky_account_id) do
        {:ok, %{post: post_data}} when not is_nil(post_data) -> deserialize_post(post_data)
        {:ok, %{post: nil}} -> nil
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def mark_bluesky_link_verified(post) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_bluesky_link_verified(token, post.id) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, Ecto.Changeset.change(post) |> Ecto.Changeset.add_error(:base, "#{reason}")}
      end
    else
      {:error, Ecto.Changeset.change(post) |> Ecto.Changeset.add_error(:base, "Offline - operation requires network")}
    end
  end

  @impl true
  def mark_bluesky_link_unverified(post) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_bluesky_link_unverified(token, post.id) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, Ecto.Changeset.change(post) |> Ecto.Changeset.add_error(:base, "#{reason}")}
      end
    else
      {:error, Ecto.Changeset.change(post) |> Ecto.Changeset.add_error(:base, "Offline - operation requires network")}
    end
  end

  @impl true
  def remove_shared_user_and_add_to_removed(post, user_to_remove, user_removing) do
    token = get_token()

    if Sync.online?() && token do
      case Client.remove_shared_user_from_post(token, post.id, user_to_remove.id, user_removing.id) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - operation requires network"}
    end
  end

  @impl true
  def create_bluesky_import_post(attrs, opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.create_bluesky_import_post(token, attrs, opts) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot create bluesky import post"}
    end
  end

  @impl true
  def get_unexported_public_posts(user_id, limit \\ 10) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_unexported_public_posts(token, user_id, limit) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data || [], &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def get_post_for_export(post_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_post_for_export(token, post_id) do
        {:ok, %{post: post_data}} -> deserialize_post(post_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def mark_post_as_synced_to_bluesky(post, uri, cid) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_post_as_synced_to_bluesky(token, post.id, uri, cid) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot mark post as synced to Bluesky"}
    end
  end

  @impl true
  def clear_bluesky_sync_info(post) do
    token = get_token()

    if Sync.online?() && token do
      case Client.clear_bluesky_sync_info(token, post.id) do
        {:ok, %{post: post_data}} -> {:ok, deserialize_post(post_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot clear Bluesky sync info"}
    end
  end

  @impl true
  def get_reply_for_export(reply_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_reply_for_export(token, reply_id) do
        {:ok, %{reply: reply_data}} -> deserialize_reply(reply_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def mark_reply_as_synced_to_bluesky(reply, uri, cid, reply_ref) do
    token = get_token()

    if Sync.online?() && token do
      case Client.mark_reply_as_synced_to_bluesky(token, reply.id, uri, cid, reply_ref) do
        {:ok, %{reply: reply_data}} -> {:ok, deserialize_reply(reply_data)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot mark reply as synced to Bluesky"}
    end
  end

  @impl true
  def decrypt_reply_body(_reply, _user, _key) do
    {:error, "Not supported in native adapter - decryption happens on server"}
  end

  # =============================================================================
  # Timeline Listing Functions (called by context after caching logic)
  # =============================================================================

  @impl true
  def fetch_connection_posts(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_connection_posts(token, current_user.id, options) do
        {:ok, %{posts: posts_data}} ->
          posts_data = posts_data || []
          cache_posts_for_tab("connections", current_user.id, posts_data)
          Enum.map(posts_data, &deserialize_post/1)

        {:error, _reason} ->
          get_cached_posts_for_tab("connections", current_user.id)
      end
    else
      get_cached_posts_for_tab("connections", current_user.id)
    end
  end

  @impl true
  def fetch_discover_posts(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      user_id = if current_user, do: current_user.id, else: nil

      case Client.fetch_discover_posts(token, user_id, options) do
        {:ok, %{posts: posts_data}} ->
          posts_data = posts_data || []
          if current_user, do: cache_posts_for_tab("discover", current_user.id, posts_data)
          Enum.map(posts_data, &deserialize_post/1)

        {:error, _reason} ->
          if current_user, do: get_cached_posts_for_tab("discover", current_user.id), else: []
      end
    else
      if current_user, do: get_cached_posts_for_tab("discover", current_user.id), else: []
    end
  end

  @impl true
  def fetch_user_own_posts(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_user_own_posts(token, current_user.id, options) do
        {:ok, %{posts: posts_data}} ->
          posts_data = posts_data || []
          cache_posts_for_tab("home", current_user.id, posts_data)
          Enum.map(posts_data, &deserialize_post/1)

        {:error, _reason} ->
          get_cached_posts_for_tab("home", current_user.id)
      end
    else
      get_cached_posts_for_tab("home", current_user.id)
    end
  end

  @impl true
  def fetch_home_timeline(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_home_timeline(token, current_user.id, options) do
        {:ok, %{posts: posts_data}} ->
          posts_data = posts_data || []
          cache_posts_for_tab("home_timeline", current_user.id, posts_data)
          Enum.map(posts_data, &deserialize_post/1)

        {:error, _reason} ->
          get_cached_posts_for_tab("home_timeline", current_user.id)
      end
    else
      get_cached_posts_for_tab("home_timeline", current_user.id)
    end
  end

  @impl true
  def fetch_group_posts(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_group_posts(token, current_user.id, options) do
        {:ok, %{posts: posts_data}} ->
          posts_data = posts_data || []
          cache_posts_for_tab("groups", current_user.id, posts_data)
          Enum.map(posts_data, &deserialize_post/1)

        {:error, _reason} ->
          get_cached_posts_for_tab("groups", current_user.id)
      end
    else
      get_cached_posts_for_tab("groups", current_user.id)
    end
  end

  # =============================================================================
  # Profile Listing Functions
  # =============================================================================

  @impl true
  def list_public_profile_posts(user, viewer, hidden_post_ids, options) do
    token = get_token()

    if Sync.online?() && token do
      viewer_id = if viewer, do: viewer.id, else: nil

      case Client.list_public_profile_posts(token, user.id, viewer_id, hidden_post_ids, options) do
        {:ok, %{posts: posts_data}} ->
          Enum.map(posts_data || [], &deserialize_post/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  @impl true
  def list_profile_posts_visible_to(profile_user, viewer, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_profile_posts_visible_to(token, profile_user.id, viewer.id, options) do
        {:ok, %{posts: posts_data}} ->
          Enum.map(posts_data || [], &deserialize_post/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  @impl true
  def count_profile_posts_visible_to(profile_user, viewer) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_profile_posts_visible_to(token, profile_user.id, viewer.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def list_user_group_posts(group, user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_user_group_posts(token, group.id, user.id) do
        {:ok, %{posts: posts_data}} ->
          Enum.map(posts_data || [], &deserialize_post/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  @impl true
  def list_own_connection_posts(user, opts) do
    token = get_token()

    if Sync.online?() && token do
      case Client.list_own_connection_posts(token, user.id, opts) do
        {:ok, %{posts: posts_data}} ->
          Enum.map(posts_data || [], &deserialize_post/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  # =============================================================================
  # Home Timeline Count Functions
  # =============================================================================

  @impl true
  def count_home_timeline(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_home_timeline(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_unread_home_timeline(user, filter_prefs) do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_unread_home_timeline(token, user.id, filter_prefs) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  # =============================================================================
  # Utility Listing Functions
  # =============================================================================

  @impl true
  def first_reply(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.first_reply(token, post.id, options) do
        {:ok, %{reply: reply_data}} -> deserialize_reply(reply_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def first_public_reply(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.first_public_reply(token, post.id, options) do
        {:ok, %{reply: reply_data}} -> deserialize_reply(reply_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def unread_posts(current_user, _options \\ %{}) do
    token = get_token()

    if Sync.online?() && token do
      case Client.unread_posts(token, current_user.id) do
        {:ok, %{posts: posts_data}} ->
          Enum.map(posts_data || [], &deserialize_post/1)

        {:error, _reason} ->
          []
      end
    else
      []
    end
  end

  defp get_cached_posts_for_tab(tab, user_id) do
    case Cache.get_cached_item("timeline_#{tab}", user_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        data
        |> Jason.decode!()
        |> Enum.map(&deserialize_post/1)

      _ ->
        []
    end
  end

  defp cache_posts_for_tab(tab, user_id, posts_data) do
    Cache.cache_item("timeline_#{tab}", user_id, Jason.encode!(posts_data))
  end

  defp deserialize_bookmark(nil), do: nil

  defp deserialize_bookmark(data) when is_map(data) do
    %Mosslet.Timeline.Bookmark{
      id: data["id"],
      user_id: data["user_id"],
      post_id: data["post_id"],
      category_id: data["category_id"],
      notes: data["notes"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp get_cached_post(id) do
    case Cache.get_cached_item("post", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        data
        |> Jason.decode!()
        |> deserialize_post()

      _ ->
        nil
    end
  end

  defp deserialize_post(nil), do: nil

  defp deserialize_post(data) when is_map(data) do
    %Mosslet.Timeline.Post{
      id: data["id"],
      body: data["body"],
      username: data["username"],
      visibility: parse_atom(data["visibility"]),
      user_id: data["user_id"],
      group_id: data["group_id"],
      image_urls: data["image_urls"],
      source: parse_atom(data["source"]),
      external_uri: data["external_uri"],
      external_cid: data["external_cid"],
      external_reply_root_uri: data["external_reply_root_uri"],
      external_reply_root_cid: data["external_reply_root_cid"],
      external_reply_parent_uri: data["external_reply_parent_uri"],
      external_reply_parent_cid: data["external_reply_parent_cid"],
      bluesky_account_id: data["bluesky_account_id"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_reply(nil), do: nil

  defp deserialize_reply(data) when is_map(data) do
    %Mosslet.Timeline.Reply{
      id: data["id"],
      body: data["body"],
      username: data["username"],
      visibility: parse_atom(data["visibility"]),
      user_id: data["user_id"],
      post_id: data["post_id"],
      parent_reply_id: data["parent_reply_id"],
      source: parse_atom(data["source"]),
      external_uri: data["external_uri"],
      external_cid: data["external_cid"],
      external_reply_root_uri: data["external_reply_root_uri"],
      external_reply_root_cid: data["external_reply_root_cid"],
      external_reply_parent_uri: data["external_reply_parent_uri"],
      external_reply_parent_cid: data["external_reply_parent_cid"],
      bluesky_account_id: data["bluesky_account_id"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_user_post(nil), do: nil

  defp deserialize_user_post(data) when is_map(data) do
    %Mosslet.Timeline.UserPost{
      id: data["id"],
      user_id: data["user_id"],
      post_id: data["post_id"],
      key: data["key"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_user_post_receipt(nil), do: nil

  defp deserialize_user_post_receipt(data) when is_map(data) do
    %Mosslet.Timeline.UserPostReceipt{
      id: data["id"],
      user_id: data["user_id"],
      user_post_id: data["user_post_id"],
      is_read?: data["is_read"],
      read_at: parse_datetime(data["read_at"]),
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp parse_atom(nil), do: nil
  defp parse_atom(value) when is_atom(value), do: value
  defp parse_atom(value) when is_binary(value), do: String.to_existing_atom(value)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(value), do: value

  @impl true
  def repo_all(_query), do: []

  @impl true
  def repo_all(_query, _opts), do: []

  @impl true
  def repo_one(_query), do: nil

  @impl true
  def repo_one(_query, _opts), do: nil

  @impl true
  def repo_one!(_query), do: raise(Ecto.NoResultsError, queryable: nil)

  @impl true
  def repo_one!(_query, _opts), do: raise(Ecto.NoResultsError, queryable: nil)

  @impl true
  def repo_aggregate(_query, _aggregate, _field), do: 0

  @impl true
  def repo_aggregate(_query, _aggregate, _field, _opts), do: 0

  @impl true
  def repo_exists?(_query), do: false

  @impl true
  def repo_preload(struct_or_structs, _preloads), do: struct_or_structs

  @impl true
  def repo_preload(struct_or_structs, _preloads, _opts), do: struct_or_structs

  @impl true
  def repo_insert(_changeset), do: {:error, "Not supported in native adapter - use API"}

  @impl true
  def repo_insert!(_changeset), do: raise("Not supported in native adapter - use API")

  @impl true
  def repo_update(_changeset), do: {:error, "Not supported in native adapter - use API"}

  @impl true
  def repo_update!(_changeset), do: raise("Not supported in native adapter - use API")

  @impl true
  def repo_delete(_struct), do: {:error, "Not supported in native adapter - use API"}

  @impl true
  def repo_delete!(_struct), do: raise("Not supported in native adapter - use API")

  @impl true
  def repo_delete_all(_query), do: {0, nil}

  @impl true
  def repo_update_all(_query, _updates), do: {0, nil}

  @impl true
  def repo_transaction(fun), do: {:ok, fun.()}

  @impl true
  def repo_get(_schema, _id), do: nil

  @impl true
  def repo_get!(_schema, _id), do: raise(Ecto.NoResultsError, queryable: nil)

  @impl true
  def repo_get_by(_schema, _clauses), do: nil

  @impl true
  def repo_get_by!(_schema, _clauses), do: raise(Ecto.NoResultsError, queryable: nil)
end
