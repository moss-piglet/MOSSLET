defmodule Mosslet.Timeline.Adapters.Web do
  @moduledoc """
  Web adapter for timeline operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes. It preserves all
  existing functionality from the original Timeline context.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Timeline.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Accounts
  alias Mosslet.Groups

  alias Mosslet.Timeline.{
    Post,
    Reply,
    UserPost,
    UserPostReceipt,
    Bookmark,
    BookmarkCategory,
    PostHide,
    PostReport,
    UserPostReport,
    UserTimelinePreference,
    Navigation
  }

  alias Mosslet.Accounts.{User, UserConnection, UserBlock}

  @impl true
  def get_post(id) do
    Repo.get(Post, id)
    |> maybe_preload_post()
  end

  @impl true
  def get_post!(id) do
    post =
      Repo.get!(Post, id)
      |> Repo.preload([:user_posts, :user, :user_post_receipts])

    nested_replies = get_nested_replies_for_post(id)
    Map.put(post, :replies, nested_replies)
  end

  @impl true
  def get_post_with_nested_replies(id, options \\ %{}) do
    case Repo.get(Post, id) do
      nil ->
        nil

      post ->
        post =
          Repo.preload(post, [:user_posts, :user, :user_post_receipts, :group, :user_group])

        nested_replies = get_nested_replies_for_post(id, options)
        total_reply_count = count_replies_for_post(id, options)

        post
        |> Map.put(:replies, nested_replies)
        |> Map.put(:total_reply_count, total_reply_count)
    end
  end

  @impl true
  def get_reply(id), do: Repo.get(Reply, id)

  @impl true
  def get_reply!(id),
    do: Repo.get!(Reply, id) |> Repo.preload([:user, :post, :parent_reply, :child_replies])

  @impl true
  def create_post(attrs \\ %{}, opts \\ []) do
    Mosslet.Timeline.create_post(attrs, opts)
  end

  @impl true
  def create_public_post(attrs \\ %{}, opts \\ []) do
    Mosslet.Timeline.create_public_post(attrs, opts)
  end

  @impl true
  def update_post(%Post{} = post, attrs, opts \\ []) do
    Mosslet.Timeline.update_post(post, attrs, opts)
  end

  @impl true
  def update_public_post(%Post{} = post, attrs, opts \\ []) do
    Mosslet.Timeline.update_public_post(post, attrs, opts)
  end

  @impl true
  def delete_post(%Post{} = post, opts \\ []) do
    Mosslet.Timeline.delete_post(post, opts)
  end

  @impl true
  def delete_group_post(%Post{} = post, opts \\ []) do
    Mosslet.Timeline.delete_group_post(post, opts)
  end

  @impl true
  def create_reply(attrs, opts \\ []) do
    Mosslet.Timeline.create_reply(attrs, opts)
  end

  @impl true
  def update_reply(%Reply{} = reply, attrs, opts \\ []) do
    Mosslet.Timeline.update_reply(reply, attrs, opts)
  end

  @impl true
  def delete_reply(%Reply{} = reply, opts \\ []) do
    Mosslet.Timeline.delete_reply(reply, opts)
  end

  @impl true
  def list_posts(user, options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: up.user_id == ^user.id and p.visibility != :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def list_user_posts_for_sync(user, opts \\ []) do
    since = opts[:since]
    limit = opts[:limit] || 50

    query =
      from(up in UserPost,
        join: p in assoc(up, :post),
        where: up.user_id == ^user.id,
        order_by: [desc: p.updated_at],
        limit: ^limit,
        preload: [:post]
      )

    query =
      if since do
        from([up, p] in query, where: p.updated_at > ^since)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def list_user_own_posts(current_user, options) do
    Mosslet.Timeline.list_user_own_posts(current_user, options)
  end

  @impl true
  def list_connection_posts(current_user, options \\ %{}) do
    Mosslet.Timeline.list_connection_posts(current_user, options)
  end

  @impl true
  def list_group_posts(current_user, options \\ %{}) do
    Mosslet.Timeline.list_group_posts(current_user, options)
  end

  @impl true
  def list_discover_posts(current_user \\ nil, options \\ %{}) do
    Mosslet.Timeline.list_discover_posts(current_user, options)
  end

  @impl true
  def filter_timeline_posts(current_user, options) do
    Mosslet.Timeline.filter_timeline_posts(current_user, options)
  end

  @impl true
  def fetch_timeline_posts_from_db(current_user, options) do
    Mosslet.Timeline.fetch_timeline_posts_from_db(current_user, options)
  end

  @impl true
  def list_replies(post, options) do
    Mosslet.Timeline.list_replies(post, options)
  end

  @impl true
  def list_public_replies(post, options) do
    Mosslet.Timeline.list_public_replies(post, options)
  end

  @impl true
  def get_nested_replies_for_post(post_id, options \\ %{}) do
    limit = options[:limit]
    offset = options[:offset] || 0

    top_level_query =
      from(r in Reply,
        where: r.post_id == ^post_id and is_nil(r.parent_reply_id),
        order_by: [asc: r.inserted_at],
        preload: [:user, :parent_reply]
      )

    top_level_query =
      if options[:current_user_id] do
        blocked_ids = get_blocked_user_ids_query(options[:current_user_id])
        from(r in top_level_query, where: r.user_id not in subquery(blocked_ids))
      else
        top_level_query
      end

    top_level_query =
      top_level_query
      |> offset(^offset)

    top_level_query =
      if limit do
        from(r in top_level_query, limit: ^limit)
      else
        top_level_query
      end

    top_level_replies = Repo.all(top_level_query)

    Enum.map(top_level_replies, fn reply ->
      child_replies = get_child_replies_for_reply(reply.id, options)
      Map.put(reply, :child_replies, child_replies)
    end)
  end

  @impl true
  def get_child_replies_for_reply(parent_reply_id, options \\ %{}) do
    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_reply_id,
        order_by: [asc: r.inserted_at],
        preload: [:user, :parent_reply]
      )

    query =
      if options[:current_user_id] do
        blocked_ids = get_blocked_user_ids_query(options[:current_user_id])
        from(r in query, where: r.user_id not in subquery(blocked_ids))
      else
        query
      end

    replies = Repo.all(query)

    Enum.map(replies, fn reply ->
      child_replies = get_child_replies_for_reply(reply.id, options)
      Map.put(reply, :child_replies, child_replies)
    end)
  end

  @impl true
  def inc_favs(%Post{id: id}) do
    Repo.transaction_on_primary(fn ->
      from(p in Post, where: p.id == ^id)
      |> Repo.update_all(inc: [favs_count: 1])
    end)
    |> elem(1)
  end

  @impl true
  def decr_favs(%Post{id: id}) do
    Repo.transaction_on_primary(fn ->
      from(p in Post, where: p.id == ^id and p.favs_count > 0)
      |> Repo.update_all(inc: [favs_count: -1])
    end)
    |> elem(1)
  end

  @impl true
  def inc_reply_favs(%Reply{id: id}) do
    Repo.transaction_on_primary(fn ->
      from(r in Reply, where: r.id == ^id)
      |> Repo.update_all(inc: [favs_count: 1])
    end)
    |> elem(1)
  end

  @impl true
  def decr_reply_favs(%Reply{id: id}) do
    Repo.transaction_on_primary(fn ->
      from(r in Reply, where: r.id == ^id and r.favs_count > 0)
      |> Repo.update_all(inc: [favs_count: -1])
    end)
    |> elem(1)
  end

  @impl true
  def update_post_fav(%Post{} = post, attrs, opts \\ []) do
    Mosslet.Timeline.update_post_fav(post, attrs, opts)
  end

  @impl true
  def update_reply_fav(%Reply{} = reply, attrs, opts \\ []) do
    Mosslet.Timeline.update_reply_fav(reply, attrs, opts)
  end

  @impl true
  def create_bookmark(user, post, attrs \\ %{}) do
    Mosslet.Timeline.create_bookmark(user, post, attrs)
  end

  @impl true
  def update_bookmark(bookmark, attrs, user) do
    Mosslet.Timeline.update_bookmark(bookmark, attrs, user)
  end

  @impl true
  def delete_bookmark(bookmark, user) do
    Mosslet.Timeline.delete_bookmark(bookmark, user)
  end

  @impl true
  def get_bookmark(user, post) do
    Repo.get_by(Bookmark, user_id: user.id, post_id: post.id)
    |> maybe_preload_bookmark()
  end

  @impl true
  def bookmarked?(user, post) do
    Repo.exists?(from(b in Bookmark, where: b.user_id == ^user.id and b.post_id == ^post.id))
  end

  @impl true
  def list_user_bookmarks(user, opts \\ []) do
    Mosslet.Timeline.list_user_bookmarks(user, opts)
  end

  @impl true
  def list_user_bookmark_categories(user) do
    Repo.all(from(c in BookmarkCategory, where: c.user_id == ^user.id, order_by: [asc: c.name]))
  end

  @impl true
  def create_bookmark_category(user, attrs) do
    Mosslet.Timeline.create_bookmark_category(user, attrs)
  end

  @impl true
  def update_bookmark_category(category, attrs) do
    Mosslet.Timeline.update_bookmark_category(category, attrs)
  end

  @impl true
  def delete_bookmark_category(category) do
    Mosslet.Timeline.delete_bookmark_category(category)
  end

  @impl true
  def get_user_bookmark_category(user, category_id) do
    Repo.get_by(BookmarkCategory, id: category_id, user_id: user.id)
  end

  @impl true
  def count_all_posts() do
    from(p in Post)
    |> Repo.aggregate(:count)
  end

  @impl true
  def post_count(user, options) do
    Mosslet.Timeline.post_count(user, options)
  end

  @impl true
  def count_user_own_posts(user, filter_prefs \\ %{}) do
    Mosslet.Timeline.count_user_own_posts(user, filter_prefs)
  end

  @impl true
  def count_user_group_posts(user, filter_prefs \\ %{}) do
    Mosslet.Timeline.count_user_group_posts(user, filter_prefs)
  end

  @impl true
  def count_user_connection_posts(current_user, filter_prefs \\ %{}) do
    Mosslet.Timeline.count_user_connection_posts(current_user, filter_prefs)
  end

  @impl true
  def count_discover_posts(current_user \\ nil, filter_prefs \\ %{}) do
    Mosslet.Timeline.count_discover_posts(current_user, filter_prefs)
  end

  @impl true
  def count_unread_posts_for_user(user) do
    Mosslet.Timeline.count_unread_posts_for_user(user)
  end

  @impl true
  def count_unread_replies_for_user(user) do
    Mosslet.Timeline.count_unread_replies_for_user(user)
  end

  @impl true
  def count_replies_for_post(post_id, options \\ %{}) do
    query =
      from(r in Reply,
        where: r.post_id == ^post_id
      )

    query =
      if options[:current_user_id] do
        blocked_ids = get_blocked_user_ids_query(options[:current_user_id])
        from(r in query, where: r.user_id not in subquery(blocked_ids))
      else
        query
      end

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def count_user_bookmarks(user, filter_prefs \\ %{}) do
    Mosslet.Timeline.count_user_bookmarks(user, filter_prefs)
  end

  @impl true
  def get_timeline_data(user, tab, options \\ %{}) do
    Mosslet.Timeline.get_timeline_data(user, tab, options)
  end

  @impl true
  def get_timeline_counts(user) do
    Mosslet.Timeline.get_timeline_counts(user)
  end

  @impl true
  def get_user_timeline_preference(user) do
    Mosslet.Timeline.get_user_timeline_preference(user)
  end

  @impl true
  def update_user_timeline_preference(user, attrs, opts \\ []) do
    Mosslet.Timeline.update_user_timeline_preference(user, attrs, opts)
  end

  @impl true
  def create_or_update_user_post_receipt(user_post, user, is_read?) do
    Mosslet.Timeline.create_or_update_user_post_receipt(user_post, user, is_read?)
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    Repo.get_by(UserPost, post_id: post_id, user_id: user_id)
    |> maybe_preload_user_post()
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    Repo.get_by!(UserPost, post_id: post_id, user_id: user_id)
    |> Repo.preload([:post, :user])
  end

  @impl true
  def share_post_with_user(post, user_to_share_with, decrypted_post_key, opts \\ []) do
    Mosslet.Timeline.share_post_with_user(post, user_to_share_with, decrypted_post_key, opts)
  end

  @impl true
  def remove_self_from_shared_post(user_post, opts \\ []) do
    Mosslet.Timeline.remove_self_from_shared_post(user_post, opts)
  end

  @impl true
  def delete_user_post(user_post, opts \\ []) do
    Mosslet.Timeline.delete_user_post(user_post, opts)
  end

  @impl true
  def get_blocked_user_ids(user) do
    from(b in UserBlock,
      where: b.blocker_id == ^user.id,
      select: b.blocked_id
    )
    |> Repo.all()
  end

  @impl true
  def hide_post(user, post, attrs \\ %{}) do
    Mosslet.Timeline.hide_post(user, post, attrs)
  end

  @impl true
  def unhide_post(user, post) do
    Mosslet.Timeline.unhide_post(user, post)
  end

  @impl true
  def post_hidden?(user, post) do
    Mosslet.Timeline.post_hidden?(user, post)
  end

  @impl true
  def report_post(reporter, reported_user, post, attrs) do
    Mosslet.Timeline.report_post(reporter, reported_user, post, attrs)
  end

  @impl true
  def mark_top_level_replies_read_for_post(post_id, user_id) do
    Mosslet.Timeline.mark_top_level_replies_read_for_post(post_id, user_id)
    :ok
  end

  @impl true
  def mark_nested_replies_read_for_parent(parent_reply_id, user_id) do
    Mosslet.Timeline.mark_nested_replies_read_for_parent(parent_reply_id, user_id)
    :ok
  end

  @impl true
  def mark_all_replies_read_for_user(user_id) do
    Mosslet.Timeline.mark_all_replies_read_for_user(user_id)
    :ok
  end

  @impl true
  def preload_group(post) do
    Repo.preload(post, [:group])
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
  def inc_reposts(%Post{id: id}) do
    Repo.transaction_on_primary(fn ->
      from(p in Post, where: p.id == ^id)
      |> Repo.update_all(inc: [reposts_count: 1])
    end)
    |> elem(1)
  end

  @impl true
  def create_public_repost(attrs \\ %{}, opts \\ []) do
    Mosslet.Timeline.create_public_repost(attrs, opts)
  end

  @impl true
  def create_repost(attrs \\ %{}, opts \\ []) do
    Mosslet.Timeline.create_repost(attrs, opts)
  end

  @impl true
  def create_targeted_share(attrs \\ %{}, opts \\ []) do
    Mosslet.Timeline.create_targeted_share(attrs, opts)
  end

  @impl true
  def update_post_shared_users(post, attrs, opts \\ []) do
    Mosslet.Timeline.update_post_shared_users(post, attrs, opts)
  end

  @impl true
  def remove_post_shared_user(post, attrs, opts \\ []) do
    Mosslet.Timeline.remove_post_shared_user(post, attrs, opts)
  end

  @impl true
  def get_or_create_user_post_for_public(post, user) do
    Mosslet.Timeline.get_or_create_user_post_for_public(post, user)
  end

  @impl true
  def get_user_post(post, user) do
    Mosslet.Timeline.get_user_post(post, user)
  end

  @impl true
  def change_user_timeline_preference(pref, attrs, opts \\ []) do
    Mosslet.Timeline.change_user_timeline_preference(pref, attrs, opts)
  end

  @impl true
  def invalidate_timeline_cache_for_user(user_id, affecting_tabs \\ nil) do
    Mosslet.Timeline.invalidate_timeline_cache_for_user(user_id, affecting_tabs)
  end

  @impl true
  def get_expired_ephemeral_posts(current_time \\ nil) do
    Mosslet.Timeline.get_expired_ephemeral_posts(current_time)
  end

  @impl true
  def get_user_ephemeral_posts(user) do
    Mosslet.Timeline.get_user_ephemeral_posts(user)
  end

  defp maybe_preload_post(nil), do: nil

  defp maybe_preload_post(post) do
    Repo.preload(post, [:user_posts, :user, :user_post_receipts])
  end

  defp maybe_preload_bookmark(nil), do: nil

  defp maybe_preload_bookmark(bookmark) do
    Repo.preload(bookmark, [:post, :category])
  end

  defp maybe_preload_user_post(nil), do: nil

  defp maybe_preload_user_post(user_post) do
    Repo.preload(user_post, [:post, :user])
  end

  defp get_blocked_user_ids_query(user_id) do
    from(b in UserBlock,
      where: b.blocker_id == ^user_id,
      select: b.blocked_id
    )
  end

  defp filter_by_user_id(query, %{user_id: user_id}) when not is_nil(user_id) do
    from([p, up] in query, where: p.user_id == ^user_id)
  end

  defp filter_by_user_id(query, _options), do: query

  defp sort(query, %{sort_by: :oldest}) do
    from(p in query, order_by: [asc: p.inserted_at])
  end

  defp sort(query, _options) do
    from(p in query, order_by: [desc: p.inserted_at])
  end

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = (page - 1) * per_page
    from(p in query, limit: ^per_page, offset: ^offset)
  end

  defp paginate(query, _options), do: query
end
