defmodule Mosslet.Timeline.Adapters.Web do
  @moduledoc """
  Web adapter for timeline operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Timeline.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{UserConnection, UserBlock}
  alias Mosslet.Repo
  alias Mosslet.Timeline.{Post, Reply, UserPost, UserPostReceipt, Bookmark}

  @impl true
  def get_post(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Post, id)
      |> Repo.preload([
        :user_posts,
        :replies,
        :group,
        :user,
        :replies,
        :user_group,
        :user_post_receipts
      ])
    end
  end

  @impl true
  def get_post!(id) do
    Repo.get!(Post, id)
    |> Repo.preload([:user_posts, :user, :user_post_receipts])
  end

  @impl true
  def get_reply(id) do
    Repo.get(Reply, id)
  end

  @impl true
  def get_reply!(id) do
    Repo.get!(Reply, id)
    |> Repo.preload([:user, :post, :parent_reply, :child_replies])
  end

  @impl true
  def get_user_post!(id) do
    Repo.get!(UserPost, id)
    |> Repo.preload([:user, :post, :user_post_receipt])
  end

  @impl true
  def get_user_post_receipt!(id) do
    Repo.get!(UserPostReceipt, id)
    |> Repo.preload([:user, :user_post])
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    Repo.one!(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    Repo.one(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  @impl true
  def get_all_posts(user) do
    from(p in Post,
      where: p.user_id == ^user.id
    )
    |> Repo.all()
  end

  @impl true
  def get_all_shared_posts(user_id) do
    Repo.all(
      from p in Post,
        where: p.user_id == ^user_id,
        where: p.visibility == :connections,
        preload: [:user_posts]
    )
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
  def preload_group(post) do
    post |> Repo.preload([:group])
  end

  @impl true
  def count_all_posts do
    from(p in Post)
    |> Repo.aggregate(:count)
  end

  @impl true
  def post_count(user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and p.visibility != :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  defp filter_by_user_id(query, %{filter: %{user_id: ""}}), do: query

  defp filter_by_user_id(query, %{filter: %{user_id: user_id}}) do
    query
    |> where([p, up], p.user_id == ^user_id)
  end

  defp filter_by_user_id(query, _options), do: query

  @impl true
  def shared_between_users_post_count(user_id, current_user_id) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:inner, [p, up], up2 in UserPost, on: up2.post_id == p.id)
      |> where([p, up, up2], up.user_id == ^user_id and up2.user_id == ^current_user_id)
      |> where([p, up, up2], p.visibility == :connections)
      |> where([p, up, up2], is_nil(p.group_id))

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def timeline_post_count(current_user, options) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> where([p, up], up.user_id == ^current_user.id)
      |> where([p], p.visibility in [:private, :connections, :specific_groups, :specific_users])
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def reply_count(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> filter_by_user_id(options)
      |> where(
        [r, p],
        r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  defp user_connection_subquery(current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id)
    |> select([uc], uc.reverse_user_id)
  end

  @impl true
  def public_reply_count(post, options) do
    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> where([r, p], r.visibility == :public and p.visibility == :public)
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def group_post_count(group) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.group_id == ^group.id,
        where: p.visibility == :connections
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def public_post_count_filtered(_user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def public_post_count(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^user.id and p.visibility == :public
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_user_own_posts(user, filter_prefs) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and p.user_id == ^user.id,
        distinct: p.id
      )
      |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: user.id})

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_user_group_posts(user, filter_prefs) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and p.visibility == :specific_groups
      )
      |> apply_database_filters(%{filter_prefs: filter_prefs})

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_user_connection_posts(current_user, filter_prefs) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      0
    else
      query =
        from(p in Post,
          inner_join: up in UserPost,
          on: up.post_id == p.id,
          where: up.user_id == ^current_user.id,
          where: p.user_id in ^connection_user_ids and p.user_id != ^current_user.id,
          where: p.visibility in [:connections, :specific_users],
          distinct: p.id
        )
        |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: current_user.id})

      count = Repo.aggregate(query, :count, :id)

      case count do
        nil -> 0
        count -> count
      end
    end
  end

  @impl true
  def count_unread_user_own_posts(user, filter_prefs) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        inner_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id,
        where: up.user_id == ^user.id and p.user_id == ^user.id,
        where: upr.user_id == ^user.id,
        where: not upr.is_read? and is_nil(upr.read_at)
      )
      |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: user.id})

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_unread_bookmarked_posts(user, filter_prefs) do
    query =
      from(p in Post,
        inner_join: b in Bookmark,
        on: b.post_id == p.id,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        inner_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id,
        where: b.user_id == ^user.id,
        where: up.user_id == ^user.id,
        where: upr.user_id == ^user.id,
        where: not upr.is_read? and is_nil(upr.read_at)
      )
      |> apply_bookmark_unread_database_filters(%{
        filter_prefs: filter_prefs,
        current_user_id: user.id
      })

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_unread_posts_for_user(user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:inner, [p, up], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> where([p], p.visibility in [:private, :connections, :specific_groups, :specific_users])
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def count_unread_replies_for_user(user) do
    direct_to_posts = count_unread_direct_replies_for_user(user)
    to_user_replies = count_unread_replies_to_user_replies(user)
    direct_to_posts + to_user_replies
  end

  defp count_unread_direct_replies_for_user(user) do
    Reply
    |> join(:inner, [r], p in Post, on: r.post_id == p.id)
    |> where([r, p], p.user_id == ^user.id)
    |> where([r, p], r.user_id != ^user.id)
    |> where([r, p], is_nil(r.read_at))
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def count_unread_replies_to_user_replies(user) do
    Reply
    |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
    |> where([r, parent], parent.user_id == ^user.id)
    |> where([r, parent], r.user_id != ^user.id)
    |> where([r, parent], is_nil(r.read_at))
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def count_unread_replies_by_post(user) do
    direct_replies = count_unread_direct_replies_by_post(user)
    nested_replies = count_unread_replies_to_user_replies_by_post(user)
    merge_reply_counts(direct_replies, nested_replies)
  end

  defp count_unread_direct_replies_by_post(user) do
    Reply
    |> join(:inner, [r], p in Post, on: r.post_id == p.id)
    |> where([r, p], p.user_id == ^user.id)
    |> where([r, p], r.user_id != ^user.id)
    |> where([r, p], is_nil(r.read_at))
    |> where([r, p], is_nil(r.parent_reply_id))
    |> group_by([r, p], r.post_id)
    |> select([r, p], {r.post_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  defp merge_reply_counts(map1, map2) do
    Map.merge(map1, map2, fn _key, v1, v2 -> v1 + v2 end)
  end

  @impl true
  def count_unread_nested_replies_by_parent(user) do
    Reply
    |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
    |> where([r, parent], parent.user_id == ^user.id)
    |> where([r, parent], r.user_id != ^user.id)
    |> where([r, parent], is_nil(r.read_at))
    |> group_by([r, parent], r.parent_reply_id)
    |> select([r, parent], {r.parent_reply_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @impl true
  def count_unread_replies_to_user_replies_by_post(user) do
    Reply
    |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
    |> where([r, parent], parent.user_id == ^user.id)
    |> where([r, parent], r.user_id != ^user.id)
    |> where([r, parent], is_nil(r.read_at))
    |> group_by([r, parent], r.post_id)
    |> select([r, parent], {r.post_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @impl true
  def count_unread_nested_replies_for_post(post_id, user_id) do
    Reply
    |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
    |> where([r, parent], r.post_id == ^post_id)
    |> where([r, parent], parent.user_id == ^user_id)
    |> where([r, parent], r.user_id != ^user_id)
    |> where([r, parent], is_nil(r.read_at))
    |> Repo.aggregate(:count, :id)
  end

  @impl true
  def count_unread_connection_posts(current_user, filter_prefs) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      0
    else
      query =
        from(p in Post,
          inner_join: up in UserPost,
          on: up.post_id == p.id,
          inner_join: upr in UserPostReceipt,
          on: upr.user_post_id == up.id,
          where: up.user_id == ^current_user.id,
          where: p.user_id in ^connection_user_ids and p.user_id != ^current_user.id,
          where: p.visibility in [:connections, :specific_users],
          where: upr.user_id == ^current_user.id,
          where: not upr.is_read? and is_nil(upr.read_at)
        )
        |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: current_user.id})

      count = Repo.aggregate(query, :count, :id)

      case count do
        nil -> 0
        count -> count
      end
    end
  end

  @impl true
  def count_unread_group_posts(current_user, filter_prefs) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:inner, [p, up], upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id
      )
      |> where([p, up], up.user_id == ^current_user.id)
      |> where([p], p.visibility == :specific_groups)
      |> where([p], p.user_id != ^current_user.id)
      |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
      |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: current_user.id})

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def count_discover_posts(current_user, filter_prefs) do
    options =
      if current_user do
        %{filter_prefs: filter_prefs, current_user_id: current_user.id}
      else
        %{filter_prefs: filter_prefs}
      end

    author_filter = filter_prefs[:author_filter] || :all

    connection_user_ids =
      if current_user && author_filter == :connections do
        Accounts.get_all_confirmed_user_connections(current_user.id)
        |> Enum.map(& &1.reverse_user_id)
        |> Enum.uniq()
      else
        []
      end

    base_query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public,
        distinct: p.id
      )
      |> apply_database_filters(options)

    query =
      case {current_user, author_filter} do
        {nil, _} ->
          base_query

        {user, :mine} ->
          base_query |> where([p], p.user_id == ^user.id)

        {_user, :connections} ->
          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def count_unread_discover_posts(current_user, filter_prefs) do
    author_filter = filter_prefs[:author_filter] || :all

    connection_user_ids =
      if author_filter == :connections do
        Accounts.get_all_confirmed_user_connections(current_user.id)
        |> Enum.map(& &1.reverse_user_id)
        |> Enum.uniq()
      else
        []
      end

    base_query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        inner_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id,
        where: p.visibility == :public,
        where: not upr.is_read?
      )
      |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: current_user.id})

    query =
      case author_filter do
        :mine ->
          base_query |> where([p], p.user_id == ^current_user.id)

        :connections ->
          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def count_replies_for_post(post_id, options) do
    query =
      from(r in Reply,
        where: r.post_id == ^post_id,
        select: count(r.id)
      )

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.one(filtered_query) || 0
  end

  @impl true
  def count_top_level_replies(post_id, options) do
    query =
      from(r in Reply,
        where: r.post_id == ^post_id and is_nil(r.parent_reply_id),
        select: count(r.id)
      )

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.one(filtered_query) || 0
  end

  @impl true
  def count_child_replies(parent_reply_id, options) do
    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_reply_id,
        select: count(r.id)
      )

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.one(filtered_query) || 0
  end

  @impl true
  def count_user_bookmarks(user, filter_prefs) do
    bookmark_post_ids =
      from(b in Bookmark,
        where: b.user_id == ^user.id,
        select: b.post_id
      )

    base_query =
      from(p in Post,
        where: p.id in subquery(bookmark_post_ids)
      )
      |> apply_database_filters(%{filter_prefs: filter_prefs, current_user_id: user.id})

    author_filter = filter_prefs[:author_filter] || :all

    query =
      case author_filter do
        :mine ->
          base_query |> where([p], p.user_id == ^user.id)

        :connections ->
          connection_user_ids =
            Accounts.get_all_confirmed_user_connections(user.id)
            |> Enum.map(& &1.reverse_user_id)
            |> Enum.uniq()

          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    Repo.aggregate(query, :count, :id) || 0
  end

  defp filter_by_blocked_users_replies(query, current_user_id) when is_binary(current_user_id) do
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :replies_only],
        select: ub.blocked_id
      )

    blocked_me_subquery =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id and ub.block_type in [:full, :replies_only],
        select: ub.blocker_id
      )

    query
    |> where([r], r.user_id not in subquery(blocked_by_me_subquery))
    |> where([r], r.user_id not in subquery(blocked_me_subquery))
  end

  defp filter_by_blocked_users_replies(query, _current_user_id), do: query

  defp apply_database_filters(query, options) do
    case options do
      %{filter_prefs: filter_prefs, current_user_id: current_user_id}
      when is_map(filter_prefs) and is_binary(current_user_id) ->
        query
        |> filter_by_muted_keywords(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users(filter_prefs[:muted_users] || [])
        |> filter_by_reposts(filter_prefs[:hide_reposts] || false)
        |> filter_by_blocked_users_posts(current_user_id)

      %{filter_prefs: filter_prefs} when is_map(filter_prefs) ->
        query
        |> filter_by_muted_keywords(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users(filter_prefs[:muted_users] || [])
        |> filter_by_reposts(filter_prefs[:hide_reposts] || false)

      %{current_user_id: current_user_id} when is_binary(current_user_id) ->
        query
        |> filter_by_blocked_users_posts(current_user_id)

      _ ->
        query
    end
  end

  defp apply_bookmark_unread_database_filters(query, options) do
    case options do
      %{filter_prefs: filter_prefs, current_user_id: current_user_id}
      when is_map(filter_prefs) and is_binary(current_user_id) ->
        query
        |> filter_by_muted_keywords_bookmark(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_bookmark(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_bookmark(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_bookmark(filter_prefs[:hide_reposts] || false)
        |> filter_by_blocked_users_bookmarks(current_user_id)
        |> filter_by_author_bookmark(filter_prefs[:author_filter] || :all, current_user_id)

      %{filter_prefs: filter_prefs} when is_map(filter_prefs) ->
        query
        |> filter_by_muted_keywords_bookmark(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_bookmark(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_bookmark(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_bookmark(filter_prefs[:hide_reposts] || false)

      %{current_user_id: current_user_id} when is_binary(current_user_id) ->
        query
        |> filter_by_blocked_users_bookmarks(current_user_id)

      _ ->
        query
    end
  end

  defp filter_by_muted_keywords(query, muted_keywords)
       when is_list(muted_keywords) and muted_keywords != [] do
    Enum.reduce(muted_keywords, query, fn muted_keyword, acc_query ->
      muted_hash = String.downcase(muted_keyword)

      where(
        acc_query,
        [p, up],
        is_nil(p.content_warning_category_hash) or
          p.content_warning_category_hash != ^muted_hash
      )
    end)
  end

  defp filter_by_muted_keywords(query, _muted_keywords), do: query

  defp filter_by_content_warnings(query, %{}), do: query

  defp filter_by_content_warnings(query, cw_settings) do
    hide_all = Map.get(cw_settings || %{}, :hide_all, false)
    hide_mature = Map.get(cw_settings || %{}, :hide_mature, false)

    cond do
      hide_all ->
        query
        |> where([p, up], not p.content_warning? or is_nil(p.content_warning?))
        |> where([p, up], not p.mature_content or is_nil(p.mature_content))

      hide_mature ->
        query
        |> where([p, up], not p.mature_content or is_nil(p.mature_content))

      true ->
        query
    end
  end

  defp filter_by_muted_users(query, muted_users)
       when is_list(muted_users) and muted_users != [] do
    user_ids = extract_user_ids_from_muted_users(muted_users)

    case user_ids do
      [] -> query
      ids when is_list(ids) -> where(query, [p, up], p.user_id not in ^ids)
    end
  end

  defp filter_by_muted_users(query, _muted_users), do: query

  defp extract_user_ids_from_muted_users(muted_users) when is_list(muted_users) do
    muted_users
    |> Enum.map(fn
      %{user_id: user_id} when is_binary(user_id) -> user_id
      %{"user_id" => user_id} when is_binary(user_id) -> user_id
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp filter_by_reposts(query, false), do: query
  defp filter_by_reposts(query, true), do: where(query, [p], is_nil(p.original_post_id))

  defp filter_by_blocked_users_posts(query, current_user_id) when is_binary(current_user_id) do
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocked_id
      )

    blocked_me_subquery =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocker_id
      )

    query
    |> where([p, up], p.user_id not in subquery(blocked_by_me_subquery))
    |> where([p, up], p.user_id not in subquery(blocked_me_subquery))
  end

  defp filter_by_muted_keywords_bookmark(query, muted_keywords)
       when is_list(muted_keywords) and muted_keywords != [] do
    Enum.reduce(muted_keywords, query, fn muted_keyword, acc_query ->
      muted_hash = String.downcase(muted_keyword)

      where(
        acc_query,
        [p, b, up, upr],
        is_nil(p.content_warning_category_hash) or
          p.content_warning_category_hash != ^muted_hash
      )
    end)
  end

  defp filter_by_muted_keywords_bookmark(query, _muted_keywords), do: query

  defp filter_by_content_warnings_bookmark(query, cw_settings) do
    hide_all = Map.get(cw_settings || %{}, :hide_all, false)
    hide_mature = Map.get(cw_settings || %{}, :hide_mature, false)

    cond do
      hide_all ->
        query
        |> where([p, b, up, upr], not p.content_warning? or is_nil(p.content_warning?))
        |> where([p, b, up, upr], not p.mature_content or is_nil(p.mature_content))

      hide_mature ->
        query
        |> where([p, b, up, upr], not p.mature_content or is_nil(p.mature_content))

      true ->
        query
    end
  end

  defp filter_by_muted_users_bookmark(query, muted_users)
       when is_list(muted_users) and muted_users != [] do
    user_ids = extract_user_ids_from_muted_users(muted_users)

    case user_ids do
      [] -> query
      ids when is_list(ids) -> where(query, [p, b, up, upr], p.user_id not in ^ids)
    end
  end

  defp filter_by_muted_users_bookmark(query, _muted_users), do: query

  defp filter_by_reposts_bookmark(query, true) do
    where(query, [p, b, up, upr], not p.repost or is_nil(p.repost))
  end

  defp filter_by_reposts_bookmark(query, _hide_reposts), do: query

  defp filter_by_blocked_users_bookmarks(query, current_user_id)
       when is_binary(current_user_id) do
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocked_id
      )

    blocked_me_subquery =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocker_id
      )

    query
    |> where([p, b, up, upr], p.user_id not in subquery(blocked_by_me_subquery))
    |> where([p, b, up, upr], p.user_id not in subquery(blocked_me_subquery))
  end

  defp filter_by_author_bookmark(query, :all, _current_user_id), do: query

  defp filter_by_author_bookmark(query, :mine, current_user_id) do
    where(query, [p, b, up, upr], p.user_id == ^current_user_id)
  end

  defp filter_by_author_bookmark(query, :connections, current_user_id) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user_id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      where(query, [p, b, up, upr], false)
    else
      where(query, [p, b, up, upr], p.user_id in ^connection_user_ids)
    end
  end

  defp filter_by_author_bookmark(query, _, _current_user_id), do: query

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
  def list_replies(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    Reply
    |> join(:inner, [r], p in assoc(r, :post))
    |> where([r, p], r.post_id == ^post.id)
    |> where(
      [r, p],
      r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
    )
    |> reply_sort(options)
    |> paginate(options)
    |> preload([:user, :post])
    |> Repo.all()
  end

  @impl true
  def list_shared_posts(user_id, current_user_id, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:inner, [p, up], up2 in UserPost, on: up2.post_id == p.id)
    |> where([p, up, up2], up.user_id == ^user_id and up2.user_id == ^current_user_id)
    |> where([p, up, up2], p.user_id == ^user_id or p.user_id == ^current_user_id)
    |> where([p, up, up2], p.visibility == :connections)
    |> sort(options)
    |> paginate(options)
    |> preload([:user_posts, :group, :user_group, :replies])
    |> Repo.all()
  end

  @impl true
  def list_public_posts(_user, options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: p.visibility == :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def list_public_replies(post, options) do
    from(r in Reply,
      inner_join: p in Post,
      on: p.id == r.post_id,
      where: r.post_id == ^post.id,
      where: r.visibility == :public,
      order_by: [desc: r.inserted_at],
      preload: [:user, :post]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def list_user_bookmarks(user, options) do
    query =
      from b in Bookmark,
        inner_join: p in Post,
        on: b.post_id == p.id,
        where: b.user_id == ^user.id,
        order_by: [desc: b.inserted_at],
        preload: [:category, post: [:user_posts, :replies, :user_post_receipts]],
        select: b

    query =
      case options[:category_id] do
        nil -> query
        category_id -> where(query, [b], b.category_id == ^category_id)
      end

    query = apply_bookmark_database_filters(query, options)
    query = paginate_bookmarks(query, options)

    query
    |> Repo.all()
    |> Enum.map(fn bookmark -> bookmark.post end)
    |> Enum.filter(&(&1 != nil))
  end

  @impl true
  def list_bookmark_categories(user) do
    from(bc in Mosslet.Timeline.BookmarkCategory,
      where: bc.user_id == ^user.id,
      order_by: [asc: bc.name]
    )
    |> Repo.all()
  end

  defp apply_bookmark_database_filters(query, options) do
    case options do
      %{filter_prefs: filter_prefs, current_user_id: current_user_id}
      when is_map(filter_prefs) and is_binary(current_user_id) ->
        query
        |> filter_by_muted_keywords_simple_bookmark(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_simple_bookmark(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_simple_bookmark(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_simple_bookmark(filter_prefs[:hide_reposts] || false)
        |> filter_by_blocked_users_simple_bookmarks(current_user_id)
        |> filter_by_author_simple_bookmark(filter_prefs[:author_filter] || :all, current_user_id)

      %{filter_prefs: filter_prefs} when is_map(filter_prefs) ->
        query
        |> filter_by_muted_keywords_simple_bookmark(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_simple_bookmark(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_simple_bookmark(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_simple_bookmark(filter_prefs[:hide_reposts] || false)

      %{current_user_id: current_user_id} when is_binary(current_user_id) ->
        query
        |> filter_by_blocked_users_simple_bookmarks(current_user_id)

      _ ->
        query
    end
  end

  defp filter_by_muted_keywords_simple_bookmark(query, muted_keywords)
       when is_list(muted_keywords) and muted_keywords != [] do
    Enum.reduce(muted_keywords, query, fn muted_keyword, acc_query ->
      muted_hash = String.downcase(muted_keyword)

      where(
        acc_query,
        [b, p],
        is_nil(p.content_warning_category_hash) or
          p.content_warning_category_hash != ^muted_hash
      )
    end)
  end

  defp filter_by_muted_keywords_simple_bookmark(query, _muted_keywords), do: query

  defp filter_by_content_warnings_simple_bookmark(query, cw_settings) do
    hide_all = Map.get(cw_settings || %{}, :hide_all, false)
    hide_mature = Map.get(cw_settings || %{}, :hide_mature, false)

    cond do
      hide_all ->
        query
        |> where([b, p], not p.content_warning? or is_nil(p.content_warning?))
        |> where([b, p], not p.mature_content or is_nil(p.mature_content))

      hide_mature ->
        query
        |> where([b, p], not p.mature_content or is_nil(p.mature_content))

      true ->
        query
    end
  end

  defp filter_by_muted_users_simple_bookmark(query, muted_users)
       when is_list(muted_users) and muted_users != [] do
    user_ids = extract_user_ids_from_muted_users(muted_users)

    case user_ids do
      [] -> query
      ids when is_list(ids) -> where(query, [b, p], p.user_id not in ^ids)
    end
  end

  defp filter_by_muted_users_simple_bookmark(query, _muted_users), do: query

  defp filter_by_reposts_simple_bookmark(query, true) do
    where(query, [b, p], not p.repost or is_nil(p.repost))
  end

  defp filter_by_reposts_simple_bookmark(query, _hide_reposts), do: query

  defp filter_by_blocked_users_simple_bookmarks(query, current_user_id)
       when is_binary(current_user_id) do
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocked_id
      )

    blocked_me_subquery =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocker_id
      )

    query
    |> where([b, p], p.user_id not in subquery(blocked_by_me_subquery))
    |> where([b, p], p.user_id not in subquery(blocked_me_subquery))
  end

  defp filter_by_blocked_users_simple_bookmarks(query, _current_user_id), do: query

  defp filter_by_author_simple_bookmark(query, :all, _current_user_id), do: query

  defp filter_by_author_simple_bookmark(query, :mine, current_user_id) do
    where(query, [b, p], p.user_id == ^current_user_id)
  end

  defp filter_by_author_simple_bookmark(query, :connections, current_user_id) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user_id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      where(query, [b, p], false)
    else
      where(query, [b, p], p.user_id in ^connection_user_ids)
    end
  end

  defp filter_by_author_simple_bookmark(query, _, _current_user_id), do: query

  defp paginate_bookmarks(query, opts) do
    page = opts[:post_page] || 1
    per_page = opts[:post_per_page] || 20

    query
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, [{^sort_order, ^sort_by}])
  end

  defp sort(query, %{post_sort_by: sort_by, post_sort_order: sort_order}) do
    order_by(query, [{^sort_order, ^sort_by}])
  end

  defp sort(query, _options), do: query

  defp reply_sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, [{^sort_order, ^sort_by}])
  end

  defp reply_sort(query, _options), do: order_by(query, desc: :inserted_at)

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset_val = max((page - 1) * per_page, 0)
    query |> limit(^per_page) |> offset(^offset_val)
  end

  defp paginate(query, %{post_page: page, post_per_page: per_page}) do
    offset_val = max((page - 1) * per_page, 0)
    query |> limit(^per_page) |> offset(^offset_val)
  end

  defp paginate(query, _options), do: query

  @impl true
  def mark_replies_read_for_post(post_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    direct_count = mark_direct_replies_read_for_post(post_id, user_id, now)
    nested_count = mark_nested_replies_read_for_post(post_id, user_id, now)

    direct_count + nested_count
  end

  defp mark_direct_replies_read_for_post(post_id, user_id, now) do
    query =
      Reply
      |> join(:inner, [r], p in Post, on: r.post_id == p.id)
      |> where([r, p], r.post_id == ^post_id)
      |> where([r, p], p.user_id == ^user_id)
      |> where([r, p], r.user_id != ^user_id)
      |> where([r, p], is_nil(r.read_at))
      |> where([r, p], is_nil(r.parent_reply_id))

    {count, _} =
      Repo.transaction_on_primary(fn -> Repo.update_all(query, set: [read_at: now]) end)
      |> unwrap_transaction!()

    count
  end

  defp mark_nested_replies_read_for_post(post_id, user_id, now) do
    query =
      Reply
      |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
      |> where([r, parent], r.post_id == ^post_id)
      |> where([r, parent], parent.user_id == ^user_id)
      |> where([r, parent], r.user_id != ^user_id)
      |> where([r, parent], is_nil(r.read_at))

    {count, _} =
      Repo.transaction_on_primary(fn -> Repo.update_all(query, set: [read_at: now]) end)
      |> unwrap_transaction!()

    count
  end

  @impl true
  def mark_all_replies_read_for_user(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    direct_query =
      Reply
      |> join(:inner, [r], p in Post, on: r.post_id == p.id)
      |> where([r, p], p.user_id == ^user_id)
      |> where([r, p], r.user_id != ^user_id)
      |> where([r, p], is_nil(r.read_at))

    {direct_count, _} =
      Repo.transaction_on_primary(fn ->
        Repo.update_all(direct_query, set: [read_at: now])
      end)
      |> unwrap_transaction!()

    nested_query =
      Reply
      |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
      |> where([r, parent], parent.user_id == ^user_id)
      |> where([r, parent], r.user_id != ^user_id)
      |> where([r, parent], is_nil(r.read_at))

    {nested_count, _} =
      Repo.transaction_on_primary(fn ->
        Repo.update_all(nested_query, set: [read_at: now])
      end)
      |> unwrap_transaction!()

    direct_count + nested_count
  end

  @impl true
  def mark_nested_replies_read_for_parent(parent_reply_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      Reply
      |> join(:inner, [r], parent in Reply, on: r.parent_reply_id == parent.id)
      |> where([r, parent], r.parent_reply_id == ^parent_reply_id)
      |> where([r, parent], parent.user_id == ^user_id)
      |> where([r, parent], r.user_id != ^user_id)
      |> where([r, parent], is_nil(r.read_at))

    {count, _} =
      Repo.transaction_on_primary(fn -> Repo.update_all(query, set: [read_at: now]) end)
      |> unwrap_transaction!()

    count
  end

  @impl true
  def create_bookmark_category(attrs) do
    %Mosslet.Timeline.BookmarkCategory{}
    |> Mosslet.Timeline.BookmarkCategory.changeset(attrs)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def update_bookmark_category(category, attrs) do
    category
    |> Mosslet.Timeline.BookmarkCategory.changeset(attrs)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.update(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def delete_bookmark_category(category) do
    Repo.transaction_on_primary(fn -> Repo.delete(category) end)
    |> unwrap_transaction()
  end

  @impl true
  def get_post_with_preloads(id) do
    Repo.get(Post, id)
    |> Repo.preload([
      :user_posts,
      :replies,
      :group,
      :user,
      :user_group,
      :user_post_receipts
    ])
  end

  @impl true
  def get_post_with_preloads!(id) do
    Repo.get!(Post, id)
    |> Repo.preload([
      :user_posts,
      :replies,
      :group,
      :user,
      :user_group,
      :user_post_receipts
    ])
  end

  @impl true
  def get_reply_with_preloads(id) do
    Repo.get(Reply, id)
    |> Repo.preload([:user, :post, :parent_reply, :child_replies])
  end

  @impl true
  def get_reply_with_preloads!(id) do
    Repo.get!(Reply, id)
    |> Repo.preload([:user, :post, :parent_reply, :child_replies])
  end

  @impl true
  def get_user_post(id) do
    Repo.get(UserPost, id)
    |> Repo.preload([:user, :post, :user_post_receipt])
  end

  @impl true
  def get_user_post_receipt(id) do
    Repo.get(UserPostReceipt, id)
    |> Repo.preload([:user, :user_post])
  end

  @impl true
  def get_bookmark(id) do
    Repo.get(Bookmark, id)
    |> Repo.preload([:post, :category])
  end

  @impl true
  def get_bookmark!(id) do
    Repo.get!(Bookmark, id)
    |> Repo.preload([:post, :category])
  end

  @impl true
  def get_bookmark_by_post_and_user(post_id, user_id) do
    Repo.get_by(Bookmark, post_id: post_id, user_id: user_id)
    |> Repo.preload([:post, :category])
  end

  @impl true
  def get_bookmark_category(id) do
    Repo.get(Mosslet.Timeline.BookmarkCategory, id)
  end

  @impl true
  def get_bookmark_category!(id) do
    Repo.get!(Mosslet.Timeline.BookmarkCategory, id)
  end

  @impl true
  def user_has_bookmarked?(user_id, post_id) do
    Repo.exists?(from b in Bookmark, where: b.user_id == ^user_id and b.post_id == ^post_id)
  end

  @impl true
  def preload_post(post, preloads) do
    Repo.preload(post, preloads)
  end

  @impl true
  def preload_reply(reply, preloads) do
    Repo.preload(reply, preloads)
  end

  @impl true
  def execute_query(query), do: Repo.all(query)

  @impl true
  def execute_count(query), do: Repo.aggregate(query, :count, :id) || 0

  @impl true
  def execute_one(query), do: Repo.one(query)

  @impl true
  def execute_exists?(query), do: Repo.exists?(query)

  @impl true
  def transaction(fun), do: Repo.transaction_on_primary(fun)

  @impl true
  def filter_timeline_posts(current_user, options) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^current_user.id,
        where:
          p.visibility in [:private, :connections, :specific_groups, :specific_users] or
            (p.visibility == :public and p.user_id in ^connection_user_ids),
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :group, :user_group, :replies, :user_post_receipts]
      )
      |> filter_by_user_id(options)
      |> apply_database_filters(%{
        filter_prefs: options[:filter_prefs] || %{},
        current_user_id: current_user.id
      })
      |> sort(options)
      |> paginate(options)

    Repo.all(query)
  end

  @impl true
  def list_group_posts(group, _user, options) do
    query =
      from(p in Post,
        where: p.group_id == ^group.id,
        where: p.visibility == :specific_groups,
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :group, :user_group, :replies, :user_post_receipts]
      )
      |> sort(options)
      |> paginate(options)

    Repo.all(query)
  end

  @impl true
  def list_nested_replies(parent_reply_id, options) do
    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_reply_id,
        order_by: [asc: r.inserted_at],
        preload: [:user, :post]
      )
      |> paginate(options)

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.all(filtered_query)
  end

  @impl true
  def list_user_replies(user, options) do
    query =
      from(r in Reply,
        where: r.user_id == ^user.id,
        order_by: [desc: r.inserted_at],
        preload: [:user, :post]
      )
      |> paginate(options)

    Repo.all(query)
  end

  @impl true
  def mark_post_as_read(user_post_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.get_by(UserPostReceipt, user_post_id: user_post_id, user_id: user_id) do
      nil ->
        %UserPostReceipt{}
        |> UserPostReceipt.changeset(%{
          user_post_id: user_post_id,
          user_id: user_id,
          is_read?: true,
          read_at: now
        })
        |> then(fn changeset ->
          Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
          |> unwrap_transaction()
        end)

      receipt ->
        receipt
        |> UserPostReceipt.changeset(%{is_read?: true, read_at: now})
        |> then(fn changeset ->
          Repo.transaction_on_primary(fn -> Repo.update(changeset) end)
          |> unwrap_transaction()
        end)
    end
  end

  @impl true
  def create_bookmark(attrs) do
    %Bookmark{}
    |> Bookmark.changeset(attrs)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def delete_bookmark(bookmark) do
    Repo.transaction_on_primary(fn -> Repo.delete(bookmark) end)
    |> unwrap_transaction()
  end

  @impl true
  def create_post(attrs, opts) do
    %Post{}
    |> Post.changeset(attrs, opts)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def update_post(post, attrs, opts) do
    post
    |> Post.changeset(attrs, opts)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.update(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def delete_post(post) do
    Repo.transaction_on_primary(fn -> Repo.delete(post) end)
    |> unwrap_transaction()
  end

  @impl true
  def create_reply(attrs, opts) do
    %Reply{}
    |> Reply.changeset(attrs, opts)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def update_reply(reply, attrs, opts) do
    reply
    |> Reply.changeset(attrs, opts)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.update(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def delete_reply(reply) do
    Repo.transaction_on_primary(fn -> Repo.delete(reply) end)
    |> unwrap_transaction()
  end

  @impl true
  def create_user_post(attrs) do
    %UserPost{}
    |> UserPost.changeset(attrs, [])
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def delete_user_post(user_post) do
    Repo.transaction_on_primary(fn -> Repo.delete(user_post) end)
    |> unwrap_transaction()
  end

  @impl true
  def create_user_post_receipt(attrs) do
    %UserPostReceipt{}
    |> UserPostReceipt.changeset(attrs)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.insert(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def update_user_post_receipt(receipt, attrs) do
    receipt
    |> UserPostReceipt.changeset(attrs)
    |> then(fn changeset ->
      Repo.transaction_on_primary(fn -> Repo.update(changeset) end)
      |> unwrap_transaction()
    end)
  end

  @impl true
  def repo_all(query), do: Repo.all(query)

  @impl true
  def repo_all(query, opts), do: Repo.all(query, opts)

  @impl true
  def repo_one(query), do: Repo.one(query)

  @impl true
  def repo_one(query, opts), do: Repo.one(query, opts)

  @impl true
  def repo_one!(query), do: Repo.one!(query)

  @impl true
  def repo_one!(query, opts), do: Repo.one!(query, opts)

  @impl true
  def repo_aggregate(query, aggregate, field), do: Repo.aggregate(query, aggregate, field)

  @impl true
  def repo_aggregate(query, aggregate, field, opts),
    do: Repo.aggregate(query, aggregate, field, opts)

  @impl true
  def repo_exists?(query), do: Repo.exists?(query)

  @impl true
  def repo_preload(struct_or_structs, preloads), do: Repo.preload(struct_or_structs, preloads)

  @impl true
  def repo_preload(struct_or_structs, preloads, opts),
    do: Repo.preload(struct_or_structs, preloads, opts)

  @impl true
  def repo_insert(changeset),
    do: Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) |> unwrap_transaction()

  @impl true
  def repo_insert!(changeset),
    do: Repo.transaction_on_primary(fn -> Repo.insert!(changeset) end) |> unwrap_transaction!()

  @impl true
  def repo_update(changeset),
    do: Repo.transaction_on_primary(fn -> Repo.update(changeset) end) |> unwrap_transaction()

  @impl true
  def repo_update!(changeset),
    do: Repo.transaction_on_primary(fn -> Repo.update!(changeset) end) |> unwrap_transaction!()

  @impl true
  def repo_delete(struct),
    do: Repo.transaction_on_primary(fn -> Repo.delete(struct) end) |> unwrap_transaction()

  @impl true
  def repo_delete!(struct),
    do: Repo.transaction_on_primary(fn -> Repo.delete!(struct) end) |> unwrap_transaction!()

  @impl true
  def repo_delete_all(query),
    do: Repo.transaction_on_primary(fn -> Repo.delete_all(query) end) |> unwrap_transaction!()

  @impl true
  def repo_update_all(query, updates),
    do:
      Repo.transaction_on_primary(fn -> Repo.update_all(query, updates) end)
      |> unwrap_transaction!()

  @impl true
  def repo_transaction(fun), do: Repo.transaction_on_primary(fun)

  @impl true
  def repo_get(schema, id), do: Repo.get(schema, id)

  @impl true
  def repo_get!(schema, id), do: Repo.get!(schema, id)

  @impl true
  def repo_get_by(schema, clauses), do: Repo.get_by(schema, clauses)

  @impl true
  def repo_get_by!(schema, clauses), do: Repo.get_by!(schema, clauses)

  # =============================================================================
  # Timeline Listing Functions (called by context after caching logic)
  # =============================================================================

  @impl true
  def fetch_connection_posts(current_user, options) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      []
    else
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:left, [p, up], upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id
      )
      |> where([p, up], up.user_id == ^current_user.id)
      |> where([p, up], p.user_id in ^connection_user_ids and p.user_id != ^current_user.id)
      |> where([p], p.visibility in [:connections, :specific_users])
      |> apply_database_filters(options)
      |> preload([:user_posts, :user, :replies, :user_post_receipts])
      |> order_by([p, up, upr],
        asc: coalesce(upr.is_read?, true),
        desc: p.inserted_at
      )
      |> paginate(options)
      |> Repo.all()
      |> add_nested_replies_to_posts(options)
    end
  end

  @impl true
  def fetch_discover_posts(current_user, options) do
    if current_user do
      author_filter = get_in(options, [:filter_prefs, :author_filter]) || :all

      connection_user_ids =
        if author_filter == :connections do
          Accounts.get_all_confirmed_user_connections(current_user.id)
          |> Enum.map(& &1.reverse_user_id)
          |> Enum.uniq()
        else
          []
        end

      public_post_ids =
        from(p in Post,
          inner_join: up in UserPost,
          on: up.post_id == p.id,
          where: p.visibility == :public,
          select: p.id
        )

      base_query =
        from(p in Post,
          left_join: up in UserPost,
          on: up.post_id == p.id and up.user_id == ^current_user.id,
          left_join: upr in UserPostReceipt,
          on: upr.user_post_id == up.id and upr.user_id == ^current_user.id,
          where: p.id in subquery(public_post_ids),
          order_by: [
            asc: coalesce(upr.is_read?, true),
            desc: p.inserted_at
          ],
          preload: [:user_posts, :replies, :user_post_receipts]
        )

      query =
        case author_filter do
          :mine ->
            base_query |> where([p], p.user_id == ^current_user.id)

          :connections ->
            if Enum.empty?(connection_user_ids) do
              base_query |> where([p], false)
            else
              base_query |> where([p], p.user_id in ^connection_user_ids)
            end

          _ ->
            base_query
        end

      query
      |> apply_database_filters(options)
      |> paginate(options)
      |> Repo.all()
      |> add_nested_replies_to_posts(options)
    else
      public_post_ids =
        from(p in Post,
          inner_join: up in UserPost,
          on: up.post_id == p.id,
          where: p.visibility == :public,
          select: p.id
        )

      from(p in Post,
        where: p.id in subquery(public_post_ids),
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :replies]
      )
      |> paginate(options)
      |> Repo.all()
    end
  end

  @impl true
  def fetch_user_own_posts(current_user, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:left, [p, up], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up], up.user_id == ^current_user.id and p.user_id == ^current_user.id)
    |> where(
      [p],
      p.visibility in [:private, :connections, :public, :specific_groups, :specific_users]
    )
    |> apply_database_filters(options)
    |> preload([:user_posts, :user, :replies, :user_post_receipts])
    |> order_by([p, up, upr],
      asc: coalesce(upr.is_read?, true),
      desc: p.inserted_at
    )
    |> paginate(options)
    |> Repo.all()
    |> add_nested_replies_to_posts(options)
  end

  @impl true
  def fetch_home_timeline(current_user, options) do
    author_filter = get_in(options, [:filter_prefs, :author_filter]) || :all

    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    base_query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:left, [p, up], upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id
      )
      |> where([p, up], up.user_id == ^current_user.id)
      |> where(
        [p],
        p.visibility in [:private, :connections, :public, :specific_groups, :specific_users]
      )
      |> preload([:user_posts, :user, :replies, :user_post_receipts, :group, :user_group])

    query =
      case author_filter do
        :mine ->
          base_query |> where([p], p.user_id == ^current_user.id)

        :connections ->
          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    query
    |> apply_database_filters(options)
    |> order_by([p, up, upr],
      asc: coalesce(upr.is_read?, true),
      desc: p.inserted_at
    )
    |> paginate(options)
    |> Repo.all()
    |> add_nested_replies_to_posts(options)
  end

  @impl true
  def fetch_group_posts(current_user, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:left, [p, up], upr in UserPostReceipt,
      on: upr.user_post_id == up.id and upr.user_id == ^current_user.id
    )
    |> where([p, up], up.user_id == ^current_user.id)
    |> where([p], p.visibility == :specific_groups)
    |> where([p], p.user_id != ^current_user.id)
    |> apply_database_filters(options)
    |> preload([:user_posts, :user, :replies, :user_post_receipts])
    |> order_by([p, up, upr],
      asc: coalesce(upr.is_read?, true),
      desc: p.inserted_at
    )
    |> paginate(options)
    |> Repo.all()
    |> add_nested_replies_to_posts(options)
  end

  # =============================================================================
  # Profile Listing Functions
  # =============================================================================

  @impl true
  def list_public_profile_posts(user, _viewer, hidden_post_ids, options) do
    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.visibility == :public,
      where: p.user_id == ^user.id,
      where: p.id not in ^hidden_post_ids,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :user, :replies]
    )
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def list_profile_posts_visible_to(profile_user, viewer, options) do
    is_connection =
      Repo.exists?(
        from(uc in UserConnection,
          where:
            uc.user_id == ^viewer.id and uc.reverse_user_id == ^profile_user.id and
              not is_nil(uc.confirmed_at)
        )
      )

    if is_connection do
      from(p in Post,
        join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^profile_user.id,
        where: p.visibility in [:public, :connections],
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :user, :replies]
      )
      |> paginate(options)
      |> Repo.all()
    else
      from(p in Post,
        join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^profile_user.id,
        where: p.visibility == :public,
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :user, :replies]
      )
      |> paginate(options)
      |> Repo.all()
    end
  end

  @impl true
  def count_profile_posts_visible_to(profile_user, viewer) do
    is_connection =
      Repo.exists?(
        from(uc in UserConnection,
          where:
            uc.user_id == ^viewer.id and uc.reverse_user_id == ^profile_user.id and
              not is_nil(uc.confirmed_at)
        )
      )

    viewer_is_profile_user = viewer.id == profile_user.id

    cond do
      viewer_is_profile_user ->
        from(p in Post,
          join: up in UserPost,
          on: up.post_id == p.id,
          where: p.user_id == ^profile_user.id
        )
        |> Repo.aggregate(:count)

      is_connection ->
        from(p in Post,
          join: up in UserPost,
          on: up.post_id == p.id,
          where: p.user_id == ^profile_user.id,
          where: p.visibility in [:public, :connections]
        )
        |> Repo.aggregate(:count)

      true ->
        from(p in Post,
          join: up in UserPost,
          on: up.post_id == p.id,
          where: p.user_id == ^profile_user.id,
          where: p.visibility == :public
        )
        |> Repo.aggregate(:count)
    end
  end

  @impl true
  def list_user_group_posts(group, user) do
    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.group_id == ^group.id,
      where: p.user_id == ^user.id,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> Repo.all()
  end

  @impl true
  def list_own_connection_posts(user, opts) do
    limit = opts[:limit] || 20
    offset = opts[:offset] || 0

    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.visibility == :connections and p.user_id == ^user.id,
      where: is_nil(p.group_id),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group]
    )
    |> Repo.all()
  end

  # =============================================================================
  # Home Timeline Count Functions
  # =============================================================================

  @impl true
  def count_home_timeline(user, filter_prefs) do
    author_filter = filter_prefs[:author_filter] || :all

    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    base_query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id,
        where:
          p.visibility in [:private, :connections, :public, :specific_groups, :specific_users]
      )

    query =
      case author_filter do
        :mine ->
          base_query |> where([p], p.user_id == ^user.id)

        :connections ->
          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    apply_count_database_filters(query, %{
      filter_prefs: filter_prefs,
      current_user_id: user.id
    })
    |> Repo.aggregate(:count, :id) || 0
  end

  @impl true
  def count_unread_home_timeline(user, filter_prefs) do
    author_filter = filter_prefs[:author_filter] || :all

    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    base_query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        inner_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^user.id,
        where: up.user_id == ^user.id,
        where:
          p.visibility in [:private, :connections, :public, :specific_groups, :specific_users],
        where: upr.is_read? == false or is_nil(upr.read_at)
      )

    query =
      case author_filter do
        :mine ->
          base_query |> where([p], p.user_id == ^user.id)

        :connections ->
          if Enum.empty?(connection_user_ids) do
            base_query |> where([p], false)
          else
            base_query |> where([p], p.user_id in ^connection_user_ids)
          end

        _ ->
          base_query
      end

    apply_count_database_filters(query, %{
      filter_prefs: filter_prefs,
      current_user_id: user.id
    })
    |> Repo.aggregate(:count, :id) || 0
  end

  # =============================================================================
  # Utility Listing Functions
  # =============================================================================

  @impl true
  def first_reply(post, options) do
    user_connection_query =
      from(uc in UserConnection,
        where: uc.user_id == ^options.current_user_id,
        select: uc.reverse_user_id
      )

    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> where(
      [r, p],
      r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
    )
    |> sort(options)
    |> preload([:user, :post])
    |> limit(1)
    |> Repo.one()
  end

  @impl true
  def first_public_reply(post, options) do
    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> sort(options)
    |> preload([:user, :post])
    |> limit(1)
    |> Repo.one()
  end

  @impl true
  def unread_posts(current_user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:inner, [p, up], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^current_user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> where([p], p.visibility in [:private, :connections, :specific_groups, :specific_users])
    |> order_by([p, up, upr],
      asc: upr.is_read?,
      desc: p.inserted_at,
      asc: upr.read_at
    )
    |> preload([:user_posts, :user, :replies])
    |> Repo.all()
    |> add_nested_replies_to_posts(%{current_user_id: current_user.id})
  end

  # =============================================================================
  # Private Helper Functions
  # =============================================================================

  defp apply_count_database_filters(query, options) do
    case options do
      %{filter_prefs: filter_prefs, current_user_id: current_user_id}
      when is_map(filter_prefs) and is_binary(current_user_id) ->
        query
        |> filter_by_muted_keywords_count(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_count(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_count(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_count(filter_prefs[:hide_reposts] || false)
        |> filter_by_blocked_users_count(current_user_id)

      %{filter_prefs: filter_prefs} when is_map(filter_prefs) ->
        query
        |> filter_by_muted_keywords_count(filter_prefs[:keywords] || [])
        |> filter_by_content_warnings_count(filter_prefs[:content_warnings] || %{})
        |> filter_by_muted_users_count(filter_prefs[:muted_users] || [])
        |> filter_by_reposts_count(filter_prefs[:hide_reposts] || false)

      %{current_user_id: current_user_id} when is_binary(current_user_id) ->
        query
        |> filter_by_blocked_users_count(current_user_id)

      _ ->
        query
    end
  end

  defp filter_by_muted_keywords_count(query, []), do: query

  defp filter_by_muted_keywords_count(query, keywords) when is_list(keywords) do
    keyword_strings =
      keywords
      |> Enum.map(fn
        %{keyword: kw} when is_binary(kw) -> String.downcase(kw)
        %{"keyword" => kw} when is_binary(kw) -> String.downcase(kw)
        kw when is_binary(kw) -> String.downcase(kw)
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Enum.reduce(keyword_strings, query, fn muted_hash, acc_query ->
      where(
        acc_query,
        [p],
        is_nil(p.content_warning_category_hash) or
          p.content_warning_category_hash != ^muted_hash
      )
    end)
  end

  defp filter_by_content_warnings_count(query, %{}), do: query
  defp filter_by_content_warnings_count(query, nil), do: query

  defp filter_by_content_warnings_count(query, content_warnings) when is_map(content_warnings) do
    hidden_warnings =
      content_warnings
      |> Enum.filter(fn {_key, action} -> action == :hide end)
      |> Enum.map(fn {key, _action} -> key end)

    case hidden_warnings do
      [] ->
        query

      warnings ->
        where(query, [p], is_nil(p.content_warning) or p.content_warning not in ^warnings)
    end
  end

  defp filter_by_muted_users_count(query, []), do: query

  defp filter_by_muted_users_count(query, muted_users) when is_list(muted_users) do
    user_ids = extract_user_ids_from_muted_users(muted_users)

    case user_ids do
      [] -> query
      ids when is_list(ids) -> where(query, [p], p.user_id not in ^ids)
    end
  end

  defp filter_by_reposts_count(query, false), do: query
  defp filter_by_reposts_count(query, true), do: where(query, [p], is_nil(p.original_post_id))

  defp filter_by_blocked_users_count(query, current_user_id) do
    blocked_ids =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id,
        select: ub.blocked_id
      )

    blocker_ids =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id,
        select: ub.blocker_id
      )

    query
    |> where([p], p.user_id not in subquery(blocked_ids))
    |> where([p], p.user_id not in subquery(blocker_ids))
  end

  defp add_nested_replies_to_posts(posts, _options) when is_list(posts), do: posts
  defp add_nested_replies_to_posts(post, _options), do: post

  defp unwrap_transaction({:ok, {:ok, result}}), do: {:ok, result}
  defp unwrap_transaction({:ok, {:error, changeset}}), do: {:error, changeset}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp unwrap_transaction!({:ok, result}), do: result
  defp unwrap_transaction!({:error, reason}), do: raise("Transaction failed: #{inspect(reason)}")
end
