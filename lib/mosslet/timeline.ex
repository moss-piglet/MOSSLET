defmodule Mosslet.Timeline do
  @moduledoc """
  The Timeline context.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{User, UserConnection}
  alias Mosslet.Groups
  alias Mosslet.Repo

  alias Mosslet.Timeline.{
    Post,
    Reply,
    UserPost,
    UserPostReceipt,
    UserTimelinePreferences,
    Bookmark,
    BookmarkCategory,
    PostReport,
    PostHide,
    ContentWarningCategory,
    ContentFilter,
    Navigation
  }

  alias Mosslet.Accounts.UserBlock
  alias Mosslet.Timeline.Performance.TimelineCache

  @doc """
  Gets recently active users for cache warming.
  Returns users who have posted within the specified time window.
  """
  def get_recently_active_users(time_window_minutes \\ 30, max_users \\ 100) do
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -time_window_minutes, :minute)

    from(u in User,
      inner_join: p in Post,
      on: p.user_id == u.id,
      where: p.inserted_at >= ^cutoff,
      group_by: u.id,
      select: u,
      limit: ^max_users,
      order_by: [desc: max(p.inserted_at)]
    )
    |> Repo.all()
  rescue
    e ->
      Logger.error("Failed to get recently active users: #{inspect(e)}")
      []
  end

  @doc """
  Counts all posts for admin dashboard.
  """
  def count_all_posts() do
    from(p in Post)
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets the total count of a user's Posts. An
  optional filter can be applied.
  """
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
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's Posts that have
  been shared with the current_user by another user.
  Does not include group Posts.
  """
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
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a current_user's posts
  on their timeline page.
  """
  def timeline_post_count(current_user, options) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> where([p, up], up.user_id == ^current_user.id)
      |> with_any_visibility([:private, :connections])
      |> filter_by_user_id(options)
      |> preload([:user_posts])

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a post's Replies. An
  optional filter can be applied.

  Subquery on the user_connection to ensure
  only connections are viewing their connections' replies.
  """
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
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a public post's public Replies. An
  optional filter can be applied.

  This does not apply a current user check.
  """
  def public_reply_count(post, options) do
    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> where([r, p], r.visibility == :public and p.visibility == :public)
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  def preload_group(post) do
    post |> Repo.preload([:group])
  end

  # we use this subquery to fetch user connections
  # to check them against a main query
  defp user_connection_subquery(current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id)
    |> select([uc], uc.reverse_user_id)
  end

  @doc """
  Gets the total count of a group's Posts.
  """
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
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of Public Posts. An
  optional filter can be applied.
  """
  def public_post_count(_user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a profile_user's
  Public Posts.
  """
  def public_post_count(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^user.id and p.visibility == :public
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of posts created BY the current user (for Home tab).
  This counts only posts where the user is the author, regardless of visibility.
  """
  def count_user_own_posts(user, filter_prefs \\ %{}) do
    if has_active_filters?(filter_prefs) do
      # When filters are active, get posts and count after filtering
      posts = fetch_user_own_posts_from_db(user, %{})
      filtered_posts = apply_content_filters(posts, user, filter_prefs)
      length(filtered_posts)
    else
      # When no filters, use fast database count
      # FIXED: Count unique posts, not UserPost entries
      query =
        from(p in Post,
          inner_join: up in UserPost,
          on: up.post_id == p.id,
          where: up.user_id == ^user.id and p.user_id == ^user.id,
          distinct: p.id
        )

      count = Repo.aggregate(query, :count, :id)

      case count do
        nil -> 0
        count -> count
      end
    end
  end

  @doc """
  Gets the total count of group posts accessible to the current user (for Groups tab).
  This counts posts with group_id that the user has access to.
  """
  def count_user_group_posts(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and not is_nil(p.group_id)
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of posts FROM connected users accessible to current user (for Connections tab).
  This matches the filtering logic used in apply_tab_filtering.
  """
  def count_user_connection_posts(current_user, filter_prefs \\ %{}) do
    if has_active_filters?(filter_prefs) do
      # When filters are active, get posts and count after filtering
      posts = fetch_connection_posts_from_db(current_user, %{})
      filtered_posts = apply_content_filters(posts, current_user, filter_prefs)
      length(filtered_posts)
    else
      # When no filters, use fast database count
      connection_user_ids =
        Accounts.get_all_confirmed_user_connections(current_user.id)
        |> Enum.map(& &1.reverse_user_id)
        |> Enum.uniq()

      if Enum.empty?(connection_user_ids) do
        0
      else
        # FIXED: Count unique posts, not UserPost entries
        query =
          from(p in Post,
            inner_join: up in UserPost,
            on: up.post_id == p.id,
            where: up.user_id == ^current_user.id,
            where: p.user_id in ^connection_user_ids and p.user_id != ^current_user.id,
            where: p.visibility != :private,
            distinct: p.id
          )

        count = Repo.aggregate(query, :count, :id)

        case count do
          nil -> 0
          count -> count
        end
      end
    end
  end

  @doc """
  Gets the count of unread posts created BY the current user (for Home tab unread indicator).
  """
  def count_unread_user_own_posts(user) do
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

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Gets the count of unread group posts accessible to the current user (for Groups tab unread indicator).
  """
  def count_unread_group_posts(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        inner_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id,
        where: up.user_id == ^user.id and not is_nil(p.group_id),
        where: upr.user_id == ^user.id,
        where: not upr.is_read? and is_nil(upr.read_at)
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Gets the count of unread bookmarked posts (for Bookmarks tab unread indicator).
  """
  def count_unread_bookmarked_posts(user) do
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

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @doc """
  Returns all post for a user. Used when
  deleting data in settings.
  """
  def get_all_posts(user) do
    from(p in Post,
      where: p.user_id == ^user.id
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of non-public posts for
  the user. This includes posts shared
  with user or the user's own uploaded posts.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_posts(user, options)
      [%Post{}, ...]

  """
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

  @doc """
  Returns the list of replies for a post.

  Checks the user_connection_query to return only relevantly
  connected replies.
  """
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

  @doc """
  Returns the first (latest) reply for a post.
  """
  def first_reply(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> where(
      [r, p],
      r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
    )
    |> sort(options)
    |> preload([:user, :post])
    |> Repo.first()
  end

  @doc """
  Returns the first (latest) public reply for a post.

  This does not apply a current_user check.
  """
  def first_public_reply(post, options) do
    Reply
    |> join(:inner, [r], p in Post, on: p.id == r.post_id)
    |> where([r, p], r.post_id == ^post.id)
    |> sort(options)
    |> preload([:user, :post])
    |> Repo.first()
  end

  @doc """
  Returns a list of posts shared between two users.
  """
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

  @doc """
  Returns a list of posts for the current_user's
  timeline. Non public posts. Now with caching support.
  """
  def filter_timeline_posts(current_user, options) do
    tab = options[:tab] || "home"

    # Try cache first (only for non-realtime requests)
    if !options[:skip_cache] do
      case TimelineCache.get_timeline_data(current_user.id, tab) do
        {:hit, cached_data} ->
          Logger.debug("Timeline cache hit for user #{current_user.id}, tab #{tab}")
          cached_data[:posts] || []

        :miss ->
          # Cache miss - fetch fresh data
          posts = fetch_timeline_posts_from_db(current_user, options)

          # Cache the results (cache encrypted posts safely)
          timeline_data = %{
            posts: posts,
            post_count: length(posts),
            fetched_at: System.system_time(:millisecond)
          }

          TimelineCache.cache_timeline_data(current_user.id, tab, timeline_data)
          posts
      end
    else
      # Skip cache for real-time updates
      fetch_timeline_posts_from_db(current_user, options)
    end
  end

  @doc """
  Fetches timeline posts directly from database.
  This is the original filter_timeline_posts logic.
  """
  def fetch_timeline_posts_from_db(current_user, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> where([p, up], up.user_id == ^current_user.id)
    |> join(:left, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> with_any_visibility([:private, :connections])
    |> filter_by_user_id(options)
    |> filter_by_muted_keywords(get_muted_keywords_from_options(options))
    |> preload([:user_posts, :user, :replies, :user_post_receipts])
    |> order_by([p, up, upr],
      # Unread posts first (fals comes before true)
      asc: upr.is_read?,
      # Most recent posts first within each group
      desc: p.inserted_at,
      # Secondary sort on read_at
      asc: upr.read_at
    )
    |> paginate(options)
    |> Repo.all()
    |> add_nested_replies_to_posts()
  end

  @doc """
  Returns a list of posts for the current_user that
  have not been read yet.
  """
  def unread_posts(current_user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:inner, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^current_user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> with_any_visibility([:private, :connections])
    # Unread posts first (false comes before true)
    |> order_by([p, up, upr],
      asc: upr.is_read?,
      # Most recent posts first within each group
      desc: p.inserted_at,
      # Secondary sort on read_at
      asc: upr.read_at
    )
    |> preload([:user_posts, :user, :replies])
    |> Repo.all()
    |> add_nested_replies_to_posts()
  end

  defp with_any_visibility(query, visibility_list) do
    where(query, [p], p.visibility in ^visibility_list)
  end

  @doc """
  Filters out posts based on content warning categories that the user has muted.
  Uses the content_warning_category_hash for efficient database-level filtering.
  For each muted keyword, we add a condition to exclude posts with that category.
  """
  defp filter_by_muted_keywords(query, muted_keywords) when is_list(muted_keywords) and length(muted_keywords) > 0 do
    # For each muted keyword, add a condition to exclude posts with that category hash
    Enum.reduce(muted_keywords, query, fn muted_keyword, acc_query ->
      # Convert to lowercase to match hash storage format
      muted_hash = String.downcase(muted_keyword)
      
      # Filter out posts where content_warning_category_hash matches this muted keyword
      # Keep posts that either have no content warning OR have a different category
      where(acc_query, [p], 
        is_nil(p.content_warning_category_hash) or 
        p.content_warning_category_hash != ^muted_hash
      )
    end)
  end
  
  defp filter_by_muted_keywords(query, _muted_keywords), do: query

  @doc """
  Helper function to extract muted keywords from options.
  """
  defp get_muted_keywords_from_options(options) do
    case options do
      %{filter_prefs: %{keywords: keywords}} when is_list(keywords) -> keywords
      _ -> []
    end
  end

  @doc """
  Returns the list of public posts.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_posts(user, options)
      [%Post{}, ...]

  """
  def list_public_posts(options) do
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

  @doc """
  Returns posts FROM connected users for the Connections tab.
  This function is specifically designed to match the filtering logic
  used in the timeline and provide consistent results.
  """
  def list_connection_posts(current_user, options \\ %{})

  def list_connection_posts(current_user, options) do
    # Try cache first (for first page only)
    posts =
      if !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "connections") do
          {:hit, cached_data} ->
            Logger.debug("Connections timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = fetch_connection_posts_from_db(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "connections", timeline_data)
            posts
        end
      else
        fetch_connection_posts_from_db(current_user, options)
      end

    # Always apply content filters to both cached and fresh data
    apply_content_filters(posts, current_user, options[:filter_prefs] || %{})
  end

  defp fetch_connection_posts_from_db(current_user, options) do
    connection_user_ids =
      Accounts.get_all_confirmed_user_connections(current_user.id)
      |> Enum.map(& &1.reverse_user_id)
      |> Enum.uniq()

    if Enum.empty?(connection_user_ids) do
      []
    else
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      # FIXED: Use LEFT JOIN to include posts without receipts (like Home tab)
      |> join(:left, [p, up], upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id
      )
      |> where([p, up], up.user_id == ^current_user.id)
      |> where([p, up], p.user_id in ^connection_user_ids and p.user_id != ^current_user.id)
      |> where([p], p.visibility != :private)
      |> filter_by_muted_keywords(get_muted_keywords_from_options(options))
      |> preload([:user_posts, :user, :replies, :user_post_receipts])
      |> order_by([p, up, upr],
        # Unread posts first (false comes before true)
        asc: upr.is_read?,
        # Most recent posts first within each group
        desc: p.inserted_at,
        # Secondary sort on read_at
        asc: upr.read_at
      )
      # Uses post_page and post_per_page
      |> paginate(options)
      |> Repo.all()
      |> add_nested_replies_to_posts()
    end
  end

  @doc """
  Counts unread posts FROM connected users for the Connections tab.
  This matches exactly with list_connection_posts/2 but only counts unread ones.
  """
  def count_unread_connection_posts(current_user) do
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
          where: p.visibility != :private,
          where: upr.user_id == ^current_user.id,
          where: not upr.is_read? and is_nil(upr.read_at)
        )

      count = Repo.aggregate(query, :count, :id)

      case count do
        nil -> 0
        count -> count
      end
    end
  end

  @doc """
  Lists public posts for discover timeline with simple pagination.
  """
  def list_discover_posts(current_user \\ nil, options \\ %{}) do
    posts =
      if current_user && !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        # Try cache for first page of discover posts
        case TimelineCache.get_timeline_data(current_user.id, "discover") do
          {:hit, cached_data} ->
            Logger.debug("Discover timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = fetch_discover_posts_from_db(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "discover", timeline_data)
            posts
        end
      else
        fetch_discover_posts_from_db(current_user, options)
      end

    # Always apply content filters to both cached and fresh data
    filtered_posts = apply_content_filters(posts, current_user, options[:filter_prefs] || %{})

    Logger.info(
      "🔄 List discover: #{length(posts)} raw posts -> #{length(filtered_posts)} after filtering"
    )

    filtered_posts
  end

  defp fetch_discover_posts_from_db(current_user, options) do
    if current_user do
      # With user context - show unread posts first
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        left_join: upr in UserPostReceipt,
        on: upr.user_post_id == up.id and upr.user_id == ^current_user.id,
        where: p.visibility == :public,
        order_by: [
          # Unread posts first (false comes before true)
          asc: upr.is_read?,
          # Most recent posts first within each group
          desc: p.inserted_at
        ],
        preload: [:user_posts, :replies, :user_post_receipts]
      )
      # Use consistent pagination helper
      |> filter_by_muted_keywords(get_muted_keywords_from_options(options))
      |> paginate(options)
      |> Repo.all()
      |> add_nested_replies_to_posts()
    else
      # Without user context - just show by date
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public,
        order_by: [desc: p.inserted_at],
        preload: [:user_posts, :replies]
      )
      # Use consistent pagination helper
      |> filter_by_muted_keywords(get_muted_keywords_from_options(options))
      |> paginate(options)
      |> Repo.all()
      |> add_nested_replies_to_posts()
    end
  end

  @doc """
  Counts public posts for discover timeline.
  """
  def count_discover_posts(current_user \\ nil, filter_prefs \\ %{}) do
    if current_user && has_active_filters?(filter_prefs) do
      # CRITICAL FIX: When filters are active, use same logic as list function
      # Get all posts without pagination, then apply same filtering
      posts = fetch_discover_posts_from_db(current_user, %{})

      # Remove duplicates first (same as DISTINCT in database)
      unique_posts = Enum.uniq_by(posts, & &1.id)

      # Then apply content filters
      filtered_posts = apply_content_filters(unique_posts, current_user, filter_prefs)

      Logger.info(
        "🔢 Count with filters: #{length(posts)} raw -> #{length(unique_posts)} unique -> #{length(filtered_posts)} filtered"
      )

      length(filtered_posts)
    else
      # FIXED: Count unique posts, not UserPost entries
      # Use DISTINCT to avoid counting duplicate posts from multiple UserPost entries
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public,
        distinct: p.id
      )
      |> Repo.aggregate(:count, :id)
    end
  end

  @doc """
  Counts unread public posts for discover timeline.
  """
  def count_unread_discover_posts(current_user) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      inner_join: upr in UserPostReceipt,
      on: upr.user_post_id == up.id and upr.user_id == ^current_user.id,
      where: p.visibility == :public,
      where: not upr.is_read?
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Returns posts created BY the current user for the Home tab.
  This function is specifically designed to show only the user's own posts.
  """
  def list_user_own_posts(current_user, options \\ %{})

  def list_user_own_posts(current_user, options) do
    # Try cache first (for first page only)
    posts =
      if !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "home") do
          {:hit, cached_data} ->
            Logger.debug("Home timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = fetch_user_own_posts_from_db(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "home", timeline_data)
            posts
        end
      else
        fetch_user_own_posts_from_db(current_user, options)
      end

    # Always apply content filters to both cached and fresh data
    apply_content_filters(posts, current_user, options[:filter_prefs] || %{})
  end

  defp fetch_user_own_posts_from_db(current_user, options) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> join(:left, [p, up], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up], up.user_id == ^current_user.id and p.user_id == ^current_user.id)
    |> with_any_visibility([:private, :connections, :public])
    |> filter_by_muted_keywords(get_muted_keywords_from_options(options))
    |> preload([:user_posts, :user, :replies, :user_post_receipts])
    |> order_by([p, up, upr],
      # Unread posts first (false comes before true)
      asc: upr.is_read?,
      # Most recent posts first within each group
      desc: p.inserted_at,
      # Secondary sort on read_at
      asc: upr.read_at
    )
    |> paginate(options)
    |> Repo.all()
    |> add_nested_replies_to_posts()
  end

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

  @doc """
  Returns the list of public posts for the
  user profile being viewed.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_profile_posts(user, options)
      [%Post{}, ...]

  """
  def list_public_profile_posts(user, options) do
    from(p in Post,
      inner_join: up in UserPost,
      on: up.post_id == p.id,
      where: p.user_id == ^user.id and p.visibility == :public,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  defp filter_by_user_id(query, %{filter: %{user_id: ""}}), do: query

  defp filter_by_user_id(query, %{filter: %{user_id: user_id}}) do
    query
    |> where([p, up, upr], p.user_id == ^user_id)
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, %{post_sort_by: sort_by, post_sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, _options), do: query

  defp reply_sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp reply_sort(query, _options), do: query

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, %{post_page: page, post_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, _options), do: query

  defp paginate_bookmarks(query, %{post_page: page, post_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate_bookmarks(query, opts) when is_list(opts) do
    # Convert list opts to map for consistency
    options = Enum.into(opts, %{})
    paginate_bookmarks(query, options)
  end

  defp paginate_bookmarks(query, _options), do: query

  @doc """
  Used only in group's show page.
  """
  def list_group_posts(group, options) do
    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      where: p.group_id == ^group.id,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group, :replies]
    )
    |> filter_by_user_id(options)
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Lists all posts for a group and user.
  """
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

  def list_own_connection_posts(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(p in Post,
      join: up in UserPost,
      on: up.post_id == p.id,
      join: u in User,
      on: up.user_id == u.id,
      where: p.visibility == :connections and p.user_id == ^user.id,
      where: is_nil(p.group_id),
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: p.inserted_at],
      preload: [:user_posts, :group, :user_group]
    )
    |> Repo.all()
  end

  def inc_favs(%Post{id: id}) do
    case Repo.transaction_on_primary(fn ->
           from(p in Post, where: p.id == ^id, select: p)
           |> Repo.update_all(inc: [favs_count: 1])
         end) do
      {:ok, {1, [post]}} ->
        {:ok, post |> Repo.preload([:user_posts, :replies])}

      {:ok, {0, []}} ->
        {:error, :post_not_found}

      error ->
        {:error, error}
    end
  end

  def decr_favs(%Post{id: id}) do
    case Repo.transaction_on_primary(fn ->
           from(p in Post, where: p.id == ^id, select: p)
           |> Repo.update_all(inc: [favs_count: -1])
         end) do
      {:ok, {1, [post]}} ->
        {:ok, post |> Repo.preload([:user_posts, :replies])}

      {:ok, {0, []}} ->
        {:error, :post_not_found}

      error ->
        {:error, error}
    end
  end

  def inc_reply_favs(%Reply{id: id}) do
    case Repo.transaction_on_primary(fn ->
           from(r in Reply, where: r.id == ^id, select: r)
           |> Repo.update_all(inc: [favs_count: 1])
         end) do
      {:ok, {1, [reply]}} ->
        {:ok, reply |> Repo.preload([:post, :user])}

      {:ok, {0, []}} ->
        {:error, :reply_not_found}

      error ->
        {:error, error}
    end
  end

  def decr_reply_favs(%Reply{id: id}) do
    case Repo.transaction_on_primary(fn ->
           from(r in Reply, where: r.id == ^id, select: r)
           |> Repo.update_all(inc: [favs_count: -1])
         end) do
      {:ok, {1, [reply]}} ->
        {:ok, reply |> Repo.preload([:post, :user])}

      {:ok, {0, []}} ->
        {:error, :reply_not_found}

      error ->
        {:error, error}
    end
  end

  def inc_reposts(%Post{id: id}) do
    {1, [post]} =
      from(p in Post, where: p.id == ^id, select: p)
      |> Repo.update_all(inc: [reposts_count: 1])

    {:ok, post |> Repo.preload([:user_posts, :replies])}
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(123)
      %Post{}

      iex> get_post!(456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(id) do
    post =
      Repo.get!(Post, id)
      |> Repo.preload([:user_posts, :user, :user_post_receipts])

    # Load nested replies structure
    nested_replies = get_nested_replies_for_post(id)
    Map.put(post, :replies, nested_replies)
  end

  def get_reply!(id),
    do: Repo.get!(Reply, id) |> Repo.preload([:user, :post, :parent_reply, :child_replies])

  # Helper function to calculate thread depth for nested replies
  defp calculate_thread_depth(attrs) do
    case attrs["parent_reply_id"] || attrs[:parent_reply_id] do
      nil ->
        Map.put(attrs, "thread_depth", 0)

      parent_id when is_binary(parent_id) ->
        parent_reply = get_reply!(parent_id)
        Map.put(attrs, "thread_depth", parent_reply.thread_depth + 1)

      _ ->
        attrs
    end
  end

  @doc """
  Gets replies for a post with proper nesting structure.
  Returns a tree structure with top-level replies and their children.
  """
  def get_nested_replies_for_post(post_id) do
    # Get all replies for the post
    replies =
      from(r in Reply,
        where: r.post_id == ^post_id,
        order_by: [asc: r.inserted_at],
        preload: [:user, :parent_reply]
      )
      |> Repo.all()

    # Build nested structure
    build_reply_tree(replies)
  end

  # Helper function to add nested replies to a list of posts
  defp add_nested_replies_to_posts(posts) when is_list(posts) do
    Enum.map(posts, fn post ->
      nested_replies = get_nested_replies_for_post(post.id)
      Map.put(post, :replies, nested_replies)
    end)
  end

  # Helper to build nested reply structure
  defp build_reply_tree(replies) do
    # Group replies by parent_reply_id
    grouped = Enum.group_by(replies, & &1.parent_reply_id)

    # Get top-level replies (no parent)
    top_level = Map.get(grouped, nil, [])

    # Recursively build tree
    Enum.map(top_level, fn reply ->
      Map.put(reply, :child_replies, build_children(reply.id, grouped))
    end)
  end

  defp build_children(parent_id, grouped) do
    children = Map.get(grouped, parent_id, [])

    Enum.map(children, fn child ->
      Map.put(child, :child_replies, build_children(child.id, grouped))
    end)
  end

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

  def get_user_post!(id),
    do: Repo.get!(UserPost, id) |> Repo.preload([:user, :post, :user_post_receipt])

  def get_user_post_receipt!(id),
    do: Repo.get!(UserPostReceipt, id) |> Repo.preload([:user, :user_post])

  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    Repo.one!(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  def get_all_shared_posts(user_id) do
    Repo.all(
      from p in Post,
        where: p.user_id == ^user_id,
        where: p.visibility == :connections,
        preload: [:user_posts]
    )
  end

  def get_all_public_user_posts do
    Repo.all(
      from up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: up.post_id == p.id,
        where: p.visibility == :public,
        preload: [:user, :user_post_receipt, post: :user_posts]
    )
  end

  def get_profile_user_posts(user) do
    Repo.all(
      from up in UserPost,
        inner_join: p in Post,
        on: up.post_id == p.id,
        where: up.post_id == p.id,
        where: p.user_id == ^user.id,
        preload: [:user, :user_post_receipt, post: [:user_posts, :replies, :group, :user_group]]
    )
  end

  @doc """
  Creates or updates a user post receipt.
  """
  def create_or_update_user_post_receipt(user_post, user, is_read?) do
    # First check if a receipt already exists by querying directly
    existing_receipt =
      Repo.get_by(
        UserPostReceipt,
        user_id: user.id,
        user_post_id: user_post.id
      )

    case existing_receipt do
      nil ->
        # No receipt exists, create a new one
        {:ok, dt} = DateTime.now("Etc/UTC")

        receipt_changeset =
          UserPostReceipt.changeset(
            %UserPostReceipt{},
            %{
              user_id: user.id,
              user_post_id: user_post.id,
              is_read?: is_read?,
              read_at: if(is_read?, do: DateTime.to_naive(dt), else: nil)
            }
          )
          |> Ecto.Changeset.put_assoc(:user, user)
          |> Ecto.Changeset.put_assoc(:user_post, user_post)

        case Repo.transaction_on_primary(fn -> Repo.insert(receipt_changeset) end) do
          {:ok, {:ok, receipt}} -> {:ok, receipt}
          {:ok, {:error, changeset}} -> {:error, changeset}
          error -> error
        end

      receipt ->
        # Receipt already exists, update it instead
        {:ok, dt} = DateTime.now("Etc/UTC")

        update_changeset =
          UserPostReceipt.changeset(
            receipt,
            %{
              is_read?: is_read?,
              read_at: if(is_read?, do: DateTime.to_naive(dt), else: nil)
            }
          )

        case Repo.transaction_on_primary(fn -> Repo.update(update_changeset) end) do
          {:ok, {:ok, updated_receipt}} -> {:ok, updated_receipt}
          {:ok, {:error, changeset}} -> {:error, changeset}
          error -> error
        end
    end
  end

  @doc """
  Gets the UserPostReceipt for a post and user.
  Returns nil if no receipt exists.
  """
  def get_user_post_receipt(current_user, post) do
    # First, get the UserPost for this user and post
    user_post = get_user_post(post, current_user)

    if user_post do
      # Then get the receipt for this user_post
      Repo.get_by(UserPostReceipt, user_id: current_user.id, user_post_id: user_post.id)
    else
      nil
    end
  end

  @doc """
  Gets the unread post for the user based on the
  associated post through the user_post.
  """
  def get_unread_post_for_user_and_post(post, current_user) do
    Post
    |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
    |> where([p, up], p.id == ^post.id)
    |> where([p, up], up.user_id == ^current_user.id)
    |> join(:inner, [p, up, upr], upr in UserPostReceipt, on: upr.user_post_id == up.id)
    |> where([p, up, upr], upr.user_id == ^current_user.id)
    |> where([p, up, upr], not upr.is_read? and is_nil(upr.read_at))
    |> with_any_visibility([:private, :connections])
    |> preload([:user_posts, :user, :replies, :group, :user_group])
    |> Repo.one()
  end

  @doc """
  Creates a public post.

  ## Examples

      iex> create_public_post(%{field: value})
      {:ok, %Post{}}

      iex> create_public_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_public_post(attrs \\ %{}, opts \\ []) do
    post = Post.changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    {:ok, %{insert_post: post, insert_user_post: user_post_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_post, post)
      |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
        UserPost.changeset(
          %UserPost{},
          %{
            key: p_attrs.temp_key,
            user_id: user.id,
            post_id: post.id
          },
          user: user,
          visibility: attrs["visibility"]
        )
        |> Ecto.Changeset.put_assoc(:post, post)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Ecto.Multi.insert(:insert_user_post_receipt_creator, fn %{insert_user_post: user_post} ->
        # Create receipt for the post creator (marked as read)
        {:ok, dt} = DateTime.now("Etc/UTC")

        UserPostReceipt.changeset(
          %UserPostReceipt{},
          %{
            user_id: user.id,
            user_post_id: user_post.id,
            is_read?: true,
            read_at: DateTime.to_naive(dt)
          }
        )
        |> Ecto.Changeset.put_assoc(:user, user)
        |> Ecto.Changeset.put_assoc(:user_post, user_post)
      end)
      |> Repo.transaction_on_primary()

    # Create user_post_receipts for other users who can see this public post
    # For public posts, this means all confirmed users in the system
    create_public_post_receipts_for_other_users(post, user_post_conn, user)

    # we do not create multiple user_posts as the post is
    # symmetrically encrypted with the server public key.

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, post}
    |> broadcast_admin(:post_created)

    {:ok, conn, post |> Repo.preload([:user_posts, :group, :user_group, :replies])}
    |> broadcast(:post_created)
  end

  # Helper function to create user_post_receipts for public posts
  # This creates receipts for all confirmed users except the post creator
  defp create_public_post_receipts_for_other_users(post, user_post_conn, creator_user) do
    # Get all confirmed users except the post creator
    # We limit this to prevent performance issues on large platforms
    other_users =
      from(u in Accounts.User,
        where: not is_nil(u.confirmed_at),
        where: u.id != ^creator_user.id,
        # Limit to recent active users to prevent excessive receipt creation
        # Temporarily removing the 30-day filter to ensure all users get receipts
        # where: u.updated_at >= ago(30, "day"),
        # Reasonable limit for public post visibility
        limit: 1000
      )
      |> Repo.all()

    # Create receipts in batches to avoid overwhelming the database
    batch_size = 100

    other_users
    |> Enum.chunk_every(batch_size)
    |> Enum.each(fn user_batch ->
      # Create UserPost entries for each user (they all share the same encrypted key)
      user_posts_data =
        Enum.map(user_batch, fn user ->
          %{
            id: Ecto.UUID.generate(),
            # Same encrypted key as creator
            key: user_post_conn.key,
            user_id: user.id,
            post_id: post.id,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      # Batch insert UserPost entries
      case Repo.insert_all(UserPost, user_posts_data, returning: [:id, :user_id]) do
        {_count, user_posts_inserted} ->
          # Create UserPostReceipt entries for the inserted UserPosts
          receipts_data =
            Enum.map(user_posts_inserted, fn %{id: user_post_id, user_id: user_id} ->
              %{
                id: Ecto.UUID.generate(),
                user_id: user_id,
                user_post_id: user_post_id,
                # Public posts start as read for other users to avoid overwhelming them
                # Users can manually mark posts as unread to prioritize them
                is_read?: true,
                read_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
                updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              }
            end)

          # Batch insert UserPostReceipt entries
          Repo.insert_all(UserPostReceipt, receipts_data)

        _error ->
          Logger.error("Failed to create user_posts for public post #{post.id}")
      end
    end)
  rescue
    error ->
      Logger.error("Error creating public post receipts: #{inspect(error)}")
      # Don't fail the post creation if receipt creation fails
      :ok
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}, opts \\ []) do
    post = Post.changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    if post.changes[:user_post_map] do
      p_attrs = post.changes.user_post_map

      # "groups" is a single group_id from the live_select single mode component
      if (attrs["groups"] && attrs["groups"] != "") || attrs["group_id"] do
        group =
          if attrs["groups"],
            do: Groups.get_group!(attrs["groups"]),
            else: Groups.get_group!(attrs["group_id"])

        user_group = Groups.get_user_group_for_group_and_user(group, user)

        # we also set the shared users to an empty list as the post
        # is only going to be shared with a group

        attrs =
          attrs
          |> Map.put("group_id", group.id)
          |> Map.put("user_group_id", user_group.id)
          |> Map.put("shared_users", [])

        {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_post, fn _post ->
            Post.changeset(%Post{}, attrs, opts)
            |> Ecto.Changeset.put_assoc(:group, group)
            |> Ecto.Changeset.put_assoc(:user_group, user_group)
          end)
          |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
            UserPost.changeset(
              %UserPost{},
              %{
                key: p_attrs.temp_key,
                user_id: user.id,
                post_id: post.id
              },
              user: user,
              visibility: attrs["visibility"]
            )
            |> Ecto.Changeset.put_assoc(:post, post)
            |> Ecto.Changeset.put_assoc(:user, user)
          end)
          |> Repo.transaction_on_primary()

        conn = Accounts.get_connection_from_item(post, user)

        # we create user_posts for everyone being shared with
        # create_shared_user_posts(post, attrs, p_attrs, user)

        {:ok, post}
        |> broadcast_admin(:post_created)

        {:ok, conn, post |> Repo.preload([:user_posts, :group, :user_group, :replies])}
        |> broadcast(:post_created)
      else
        case create_new_post(post, user, p_attrs, attrs) do
          # we create user_posts for everyone being shared with
          {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} ->
            create_shared_user_posts(post, attrs, p_attrs, user)

            {:ok, post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])}
            |> broadcast_admin(:post_created)

          {:error, insert_post: changeset, insert_user_post: _user_post_changeset} ->
            {:error, changeset}
        end
      end
    else
      # there's an error on the post changeset
      # which we've assigned to this post variable
      {:error, post}
    end
  end

  # wrap the create post in a function so that we can
  # match on a case statement for errors
  defp create_new_post(post, user, p_attrs, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_post, post)
    |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
      UserPost.changeset(
        %UserPost{},
        %{
          key: p_attrs.temp_key,
          user_id: user.id,
          post_id: post.id
        },
        user: user,
        visibility: attrs["visibility"]
      )
      |> Ecto.Changeset.put_assoc(:post, post)
      |> Ecto.Changeset.put_assoc(:user, user)
    end)
    |> Ecto.Multi.insert(:inser_user_post_receipt, fn %{insert_user_post: user_post} ->
      # since this is the user who created the post, we mark it as read
      {:ok, dt} = DateTime.now("Etc/UTC")

      UserPostReceipt.changeset(
        %UserPostReceipt{},
        %{
          user_id: user.id,
          user_post_id: user_post.id,
          is_read?: true,
          read_at: DateTime.to_naive(dt)
        }
      )
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Ecto.Changeset.put_assoc(:user_post, user_post)
    end)
    |> Repo.transaction_on_primary()
  end

  defp create_shared_user_posts(post, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet
        # we also add a user_post_receipt to each person a post is shared with
        # (we don't worry about a receipt for someone who created the post)
        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Ecto.Multi.insert(:inser_user_post_receipt, fn %{insert_user_post: user_post} ->
            # For public posts, mark receipts as read to avoid overwhelming users
            # For private/connections posts, mark as unread for notifications
            {is_read, read_at} =
              if attrs["visibility"] == "public" or attrs[:visibility] == :public do
                {true, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)}
              else
                {false, nil}
              end

            UserPostReceipt.changeset(
              %UserPostReceipt{},
              %{
                user_id: user.id,
                user_post_id: user_post.id,
                is_read?: is_read,
                read_at: read_at
              }
            )
            |> Ecto.Changeset.put_assoc(:user, user)
            |> Ecto.Changeset.put_assoc(:user_post, user_post)
          end)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_created)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_created)
    end
  end

  defp update_shared_user_posts(post, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            get_user_post(post, user),
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet

        case Ecto.Multi.new()
             |> Ecto.Multi.update(:update_user_post, user_post)
             |> Repo.transaction_on_primary() do
          {:ok, %{update_user_post: _user_post}} ->
            :ok

          {:error, :update_user_post, changeset, _map} ->
            Logger.warning("Error updating public post")
            Logger.debug("Error updating public post: #{inspect(changeset)}")
            :error

          rest ->
            Logger.warning("Unknown error updating user_post")
            Logger.debug("Unknown error updating user_post: #{inspect(rest)}")
            :error
        end
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_updated)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_updated)
    end
  end

  @doc """
  Creates a repost.

  ## Examples

      iex> create_public_repost(%{field: value})
      {:ok, %Post{}}

      iex> create_public_repost(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_public_repost(attrs \\ %{}, opts \\ []) do
    post = Post.repost_changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_post, post)
      |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
        UserPost.changeset(
          %UserPost{},
          %{
            key: p_attrs.temp_key,
            user_id: user.id,
            post_id: post.id
          },
          user: user,
          visibility: attrs["visibility"] || attrs[:visibility]
        )
        |> Ecto.Changeset.put_assoc(:post, post)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Repo.transaction_on_primary()

    # we do not create multiple user_posts as the post is
    # symmetrically encrypted with the server public key.

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
    |> broadcast(:post_reposted)
  end

  @doc """
  Creates a repost.

  ## Examples

      iex> create_repost(%{field: value})
      {:ok, %Post{}}

      iex> create_repost(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_repost(attrs \\ %{}, opts \\ []) do
    post = Post.repost_changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    case attrs["visibility"] || attrs[:visibility] do
      :public ->
        # For public reposts, only create the Post record, not UserPost records
        # Public posts should reuse the original post's UserPost with public key
        case Ecto.Multi.new()
             |> Ecto.Multi.insert(:insert_post, post)
             |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
               # For public reposts, create a UserPost with the same public key
               UserPost.changeset(
                 %UserPost{},
                 %{
                   # This should be the original public key
                   key: p_attrs.temp_key,
                   user_id: user.id,
                   post_id: post.id
                 },
                 user: user,
                 visibility: :public
               )
               |> Ecto.Changeset.put_assoc(:post, post)
               |> Ecto.Changeset.put_assoc(:user, user)
             end)
             |> Ecto.Multi.insert(:insert_user_post_receipt_creator, fn %{
                                                                          insert_user_post:
                                                                            user_post
                                                                        } ->
               # Create receipt for the repost creator (marked as read)
               {:ok, dt} = DateTime.now("Etc/UTC")

               UserPostReceipt.changeset(
                 %UserPostReceipt{},
                 %{
                   user_id: user.id,
                   user_post_id: user_post.id,
                   is_read?: true,
                   read_at: DateTime.to_naive(dt)
                 }
               )
               |> Ecto.Changeset.put_assoc(:user, user)
               |> Ecto.Changeset.put_assoc(:user_post, user_post)
             end)
             |> Repo.transaction_on_primary() do
          {:ok, %{insert_post: post, insert_user_post: user_post}} ->
            # For public posts, we also need to create receipts for other users
            # But we don't need to create additional UserPost records
            post_with_associations = post |> Repo.preload([:user_posts, :replies])
            create_public_post_receipts_for_other_users(post_with_associations, user_post, user)

            conn = Accounts.get_connection_from_item(post, user)

            {:ok, conn, post_with_associations}
            |> broadcast(:post_reposted)

          {:error, :insert_post, changeset, _map} ->
            {:error, changeset}

          rest ->
            Logger.warning("Error creating public repost")
            Logger.debug("Error creating public repost: #{inspect(rest)}")
            {:error, "error"}
        end

      _ ->
        # For private/connections reposts, create UserPost records as before
        case Ecto.Multi.new()
             |> Ecto.Multi.insert(:insert_post, post)
             |> Ecto.Multi.insert(:insert_user_post, fn %{insert_post: post} ->
               UserPost.changeset(
                 %UserPost{},
                 %{
                   key: p_attrs.temp_key,
                   user_id: user.id,
                   post_id: post.id
                 },
                 user: user,
                 visibility: attrs["visibility"] || attrs[:visibility]
               )
               |> Ecto.Changeset.put_assoc(:post, post)
               |> Ecto.Changeset.put_assoc(:user, user)
             end)
             |> Ecto.Multi.insert(:insert_user_post_receipt_creator, fn %{
                                                                          insert_user_post:
                                                                            user_post
                                                                        } ->
               # Create receipt for the repost creator (marked as read)
               {:ok, dt} = DateTime.now("Etc/UTC")

               UserPostReceipt.changeset(
                 %UserPostReceipt{},
                 %{
                   user_id: user.id,
                   user_post_id: user_post.id,
                   is_read?: true,
                   read_at: DateTime.to_naive(dt)
                 }
               )
               |> Ecto.Changeset.put_assoc(:user, user)
               |> Ecto.Changeset.put_assoc(:user_post, user_post)
             end)
             |> Repo.transaction_on_primary() do
          {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} ->
            # we create user_posts for everyone being shared with
            create_shared_user_reposts(post, attrs, p_attrs, user)

          {:error, :insert_post, changeset, _map} ->
            {:error, changeset}

          {:error, :insert_user_post, changeset, _map} ->
            {:error, changeset}

          {:error, :insert_post, _, :update_user_post, changeset, _map} ->
            {:error, changeset}

          rest ->
            Logger.warning("Error creating repost")
            Logger.debug("Error creating repost: #{inspect(rest)}")
            {:error, "error"}
        end
    end
  end

  defp create_shared_user_reposts(post, attrs, p_attrs, current_user) do
    if attrs.shared_users && !Enum.empty?(attrs.shared_users) do
      for su <- attrs.shared_users do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet
        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_reposted)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
      |> broadcast(:post_reposted)
    end
  end

  @doc """
  Updates a public post.

  ## Examples

      iex> update_public_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_public_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_public_post(%Post{} = post, attrs, opts \\ []) do
    post = Post.changeset(post, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_post, post)
         |> Ecto.Multi.update(:update_user_post, fn %{update_post: post} ->
           UserPost.changeset(
             get_public_user_post(post),
             %{
               key: p_attrs.temp_key,
               user_id: user.id,
               post_id: post.id
             },
             user: user,
             visibility: attrs["visibility"]
           )
           |> Ecto.Changeset.put_assoc(:post, post)
           |> Ecto.Changeset.put_assoc(:user, user)
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_post: post, update_user_post: _user_post_conn}} ->
        # we do not create multiple user_posts as the post is
        # symmetrically encrypted with the server public key.
        conn = Accounts.get_connection_from_item(post, user)

        {:ok, conn, post |> Repo.preload([:user_posts, :replies])}
        |> broadcast(:post_updated)

      {:error, :update_post, changeset, _map} ->
        {:error, changeset}

      {:error, :update_user_post, changeset, _map} ->
        {:error, changeset}

      {:error, :update_post, _, :update_user_post, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating public post")
        Logger.debug("Error updating public post: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs, opts \\ []) do
    post = Post.changeset(post, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    if post.changes[:user_post_map] do
      p_attrs = post.changes.user_post_map

      case Ecto.Multi.new()
           |> Ecto.Multi.update(:update_post, post)
           |> Ecto.Multi.update(:update_user_post, fn %{update_post: post} ->
             UserPost.changeset(
               get_user_post(post, user),
               %{
                 key: p_attrs.temp_key,
                 user_id: user.id,
                 post_id: post.id
               },
               user: user,
               visibility: attrs["visibility"]
             )
             |> Ecto.Changeset.put_assoc(:post, post)
             |> Ecto.Changeset.put_assoc(:user, user)
           end)
           |> Repo.transaction_on_primary() do
        {:ok, %{update_post: post, update_user_post: _user_post_conn}} ->
          # we create user_posts for everyone being shared with
          # this should return {:ok, post} after the broadcast
          update_shared_user_posts(post, attrs, p_attrs, user)

        {:error, :update_post, changeset, _map} ->
          {:error, changeset}

        {:error, :update_user_post, changeset, _map} ->
          {:error, changeset}

        {:error, :update_post, _, :update_user_post, changeset, _map} ->
          {:error, changeset}

        rest ->
          Logger.warning("Error updating post")
          Logger.debug("Error updating post: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      # there's an error on the post changeset
      # which we've assigned to this post variable
      {:error, post}
    end
  end

  def update_user_post_receipt_read(id) do
    user_post_receipt = get_user_post_receipt!(id)
    {:ok, dt} = DateTime.now("Etc/UTC")
    today = DateTime.to_naive(dt)

    case Repo.transaction_on_primary(fn ->
           UserPostReceipt.changeset(user_post_receipt, %{is_read?: true, read_at: today})
           |> Repo.update()
         end) do
      {:ok, {:ok, user_post_receipt}} ->
        user_post_receipt = Repo.preload(user_post_receipt, [:user_post])
        post = get_post!(user_post_receipt.user_post.post_id)

        conn = Accounts.get_connection_from_item(post, user_post_receipt.user)

        # Broadcast the update (this returns {:ok, post} but we ignore it)
        # Note: Broadcast disabled for receipt updates to prevent double updates
        # broadcast({:ok, conn, post}, :post_updated)

        # Return the expected tuple for the LiveView
        {:ok, conn, post}

      rest ->
        Logger.warning("Error updating post read user_post_receipt")
        Logger.debug("Error updating post read user_post_receipt: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_user_post_receipt_unread(id) do
    user_post_receipt = get_user_post_receipt!(id)

    case Repo.transaction_on_primary(fn ->
           UserPostReceipt.changeset(user_post_receipt, %{is_read?: false, read_at: nil})
           |> Repo.update()
         end) do
      {:ok, {:ok, user_post_receipt}} ->
        user_post_receipt = Repo.preload(user_post_receipt, [:user_post])
        post = get_post!(user_post_receipt.user_post.post_id)

        conn = Accounts.get_connection_from_item(post, user_post_receipt.user)

        # Broadcast the update (this returns {:ok, post} but we ignore it)
        # Note: Broadcast disabled for receipt updates to prevent double updates
        # broadcast({:ok, conn, post}, :post_updated)

        # Return the expected tuple for the LiveView
        {:ok, conn, post}

      rest ->
        Logger.warning("Error updating post unread user_post_receipt")
        Logger.debug("Error updating post unread user_post_receipt: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_post_fav(%Post{} = post, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    case Repo.transaction_on_primary(fn ->
           Post.favs_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, post}} ->
        conn = Accounts.get_connection_from_item(post, user)

        {:ok, conn, post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])}
        |> broadcast(:post_updated_fav)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating post fav")
        Logger.debug("Error updating post fav: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_reply_fav(%Reply{} = reply, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    case Repo.transaction_on_primary(fn ->
           Reply.favs_changeset(reply, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, reply}} ->
        conn = Accounts.get_connection_from_item(reply, user)

        {:ok, conn, reply |> Repo.preload([:post, :user])}
        |> broadcast_reply(:reply_updated_fav)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error updating reply fav")
        Logger.debug("Error updating reply fav: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def update_post_repost(%Post{} = post, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    {:ok, {:ok, post}} =
      Repo.transaction_on_primary(fn ->
        Post.change_post_to_repost_changeset(post, attrs, opts)
        |> Repo.update()
      end)

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, conn, post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])}
    |> broadcast(:post_updated)
  end

  def update_post_shared_users(%Post{} = post, attrs, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           Post.change_post_shared_users_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, post}} ->
        conn = Accounts.get_connection_from_item(post, opts[:user])

        {:ok, conn, post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])}
        |> broadcast(:post_updated)

      {:ok, {:error, changeset}} ->
        Logger.error(
          "There was an error update_post_shared_users/3 in Mosslet.Timeline #{changeset}"
        )

        Logger.debug({inspect(changeset)})
        {:error, changeset}
    end
  end

  @doc """
  Creates a %Reply{}.
  """
  def create_reply(attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    # Calculate thread depth for nested replies
    attrs = calculate_thread_depth(attrs)

    case Repo.transaction_on_primary(fn ->
           Reply.changeset(%Reply{}, attrs, opts)
           |> Repo.insert()
         end) do
      {:ok, {:ok, reply}} ->
        reply = reply |> Repo.preload([:user, :post, :parent_reply])
        conn = Accounts.get_connection_from_item(reply.post, user)

        {:ok, conn, reply}
        |> broadcast_reply(:reply_created)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Updates a %Reply{}.
  """
  def update_reply(%Reply{} = reply, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    case Repo.transaction_on_primary(fn ->
           Reply.changeset(reply, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, reply}} ->
        reply = reply |> Repo.preload([:user, :post])
        conn = Accounts.get_connection_from_item(reply.post, user)

        {:ok, conn, reply}
        |> broadcast_reply(:reply_updated)

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a %Reply{}.
  """
  def delete_reply(%Reply{} = reply, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    if (user && user.id == reply.user_id) || user.id == reply.post.user_id do
      {:ok, {:ok, reply}} =
        Repo.transaction_on_primary(fn ->
          Repo.delete(reply)
        end)

      conn = Accounts.get_connection_from_item(reply.post, user)

      {:ok, conn, reply}
      |> broadcast_reply(:reply_deleted)
    else
      {:error, "You do not have permission to delete this reply."}
    end
  end

  ## Get UserPost (user_post)

  # The user_post is always just one
  # and is the first in the list
  def get_public_user_post(post) do
    Enum.at(post.user_posts, 0)
    |> Repo.preload([:post, :user, :user_post_receipt])
  end

  def get_user_post(post, user) do
    Repo.one(from up in UserPost, where: up.post_id == ^post.id and up.user_id == ^user.id)
    |> Repo.preload([:post, :user, :user_post_receipt])
  end

  @doc """
  Deletes a post and any reposts.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post, opts \\ []) do
    if opts[:user] do
      user = Accounts.get_user!(opts[:user].id)
      conn = Accounts.get_connection_from_item(post, user)

      query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

      post =
        Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

      case Repo.transaction_on_primary(fn ->
             Repo.delete_all(query)
           end) do
        {:ok, {:error, changeset}} ->
          {:error, changeset}

        {:ok, {count, _posts}} ->
          if count > 1 do
            {:ok, conn, post}
            |> broadcast(:repost_deleted)
          else
            {:ok, conn, post}
            |> broadcast(:post_deleted)
          end

        rest ->
          Logger.warning("Error deleting post")
          Logger.debug("Error deleting post: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      {:error, "You do not have permission to delete this post."}
    end
  end

  def delete_user_post(%UserPost{} = user_post, opts \\ []) do
    # we get the connection for the user associated with the deleted user_post
    user = Accounts.get_user!(user_post.user_id)

    case Repo.transaction_on_primary(fn ->
           Repo.delete(user_post)
         end) do
      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:ok, {:ok, user_post}} ->
        post = get_post!(user_post.post_id)

        # remove the shared_user
        shared_user_structs =
          Enum.reject(post.shared_users, fn shared_user ->
            shared_user.id === user.id
          end)

        # convert list from structs to maps
        shared_user_map_list =
          Enum.into(shared_user_structs, [], fn shared_user_struct ->
            Map.from_struct(shared_user_struct)
            |> Map.put(:sender_id, opts[:user].id)
            |> Map.put(:username, opts[:shared_username])
          end)

        # call update_post to remove the user_post_map
        update_post_shared_users(
          post,
          %{
            shared_users: shared_user_map_list
          },
          # is the current_user
          user: opts[:user]
        )

      rest ->
        Logger.warning("Error deleting user_post")
        Logger.debug("Error deleting user_post: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def delete_group_post(%Post{} = post, opts \\ []) do
    if post.user_id == opts[:user].id || opts[:user_group].role in [:owner, :admin, :moderator] do
      user =
        if post.user_id == opts[:user].id do
          Accounts.get_user!(opts[:user].id)
        else
          Accounts.get_user!(post.user_id)
        end

      conn = Accounts.get_connection_from_item(post, user)

      query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

      post =
        Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

      {:ok, {count, _posts}} =
        Repo.transaction_on_primary(fn ->
          Repo.delete_all(query)
        end)

      if count > 1 do
        {:ok, conn, post}
        |> broadcast(:repost_deleted)
      else
        {:ok, conn, post}
        |> broadcast(:post_deleted)
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Post{} = post, attrs \\ %{}, opts \\ []) do
    Post.changeset(post, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking reply changes.

  ## Examples

      iex> change_reply(reply)
      %Ecto.Changeset{data: %Reply{}}

  """
  def change_reply(%Reply{} = reply, attrs \\ %{}, opts \\ []) do
    Reply.changeset(reply, attrs, opts)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "posts")
  end

  def reply_subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "replies")
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_posts:#{user.id}")
  end

  def private_reply_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_replies:#{user.id}")
  end

  def connections_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_posts:#{user.id}")
  end

  def connections_reply_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_replies:#{user.id}")
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "admin:posts")
    end
  end

  defp broadcast({:ok, conn, post}, event, _user_conn \\ %{}) do
    case post.visibility do
      :public -> public_broadcast({:ok, post}, event)
      :private -> private_broadcast({:ok, post}, event)
      :connections -> connections_broadcast({:ok, conn, post}, event)
    end
  end

  defp broadcast_reply({:ok, conn, reply}, event, _user_conn \\ %{}) do
    case reply.visibility do
      :public -> public_reply_broadcast({:ok, reply}, event)
      :private -> private_reply_broadcast({:ok, reply}, event)
      :connections -> connections_reply_broadcast({:ok, conn, reply}, event)
    end
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "admin:posts", {event, struct})
    {:ok, struct}
  end

  defp public_broadcast({:ok, post}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "posts", {event, post})
    {:ok, post}
  end

  defp public_reply_broadcast({:ok, reply}, event) do
    post = get_post!(reply.post_id)

    Phoenix.PubSub.broadcast(Mosslet.PubSub, "replies", {event, post, reply})

    {:ok, reply}
  end

  defp private_broadcast({:ok, post}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "priv_posts:#{post.user_id}", {event, post})
    {:ok, post}
  end

  defp private_reply_broadcast({:ok, reply}, event) do
    post = get_post!(reply.post_id)

    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "priv_replies:#{reply.user_id}",
      {event, post, reply}
    )

    {:ok, reply}
  end

  defp connections_broadcast({:ok, conn, post}, event) do
    # we only broadcast to our connections if it's NOT a group post
    if is_nil(post.group_id) do
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(post.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{uconn.reverse_user_id}",
            {event, post}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{uconn.user_id}",
            {event, post}
          )
        end)
      end)

      {:ok, post}
    else
      maybe_publish_group_post({event, post})
    end
  end

  defp connections_reply_broadcast({:ok, conn, reply}, event) do
    post = get_post!(reply.post_id)

    # we only broadcast to our connections if it's NOT a group post
    if is_nil(post.group_id) do
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(post.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_replies:#{uconn.user_id}",
            {event, post, reply}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_replies:#{uconn.reverse_user_id}",
            {event, post, reply}
          )
        end)
      end)

      {:ok, reply}
    else
      maybe_publish_group_post_reply({event, post, reply})
    end
  end

  defp maybe_publish_group_post({event, post}) do
    if not is_nil(post.group_id) do
      publish_group_post({event, post})
    end
  end

  defp maybe_publish_group_post_reply({event, post, reply}) do
    if not is_nil(post.group_id) do
      publish_group_post_reply({event, post, reply})
    end
  end

  ##  Group Post broadcasts

  def publish_group_post({event, post}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{post.group_id}",
      {event, post}
    )

    {:ok, post}
  end

  def publish_group_post_reply({event, post, reply}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{post.group_id}",
      {event, post, reply}
    )

    {:ok, reply}
  end

  ## Bookmark Functions

  @doc """
  Creates a bookmark for a user on a specific post.
  Uses the existing post_key encryption strategy for consistency.

  ## Examples

      iex> create_bookmark(user, post, %{notes: "Great article!"})
      {:ok, %Bookmark{}}

      iex> create_bookmark(user, post, %{notes: "", category_id: category.id})
      {:ok, %Bookmark{}}
  """
  def create_bookmark(user, post, attrs \\ %{}) do
    # Get the post_key using existing mechanism (same as post decryption)
    post_key = MossletWeb.Helpers.get_post_key(post, user)

    if post_key do
      attrs = attrs |> Map.put(:user_id, user.id) |> Map.put(:post_id, post.id)

      case Repo.transaction_on_primary(fn ->
             %Bookmark{}
             |> Bookmark.changeset(attrs, post_key: post_key)
             |> Repo.insert()
           end) do
        {:ok, {:ok, bookmark}} ->
          # Broadcast bookmark creation for real-time updates
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "bookmarks:#{user.id}",
            {:bookmark_created, bookmark}
          )

          {:ok, bookmark}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :no_access_to_post}
    end
  end

  @doc """
  Updates a bookmark's notes or category.
  """
  def update_bookmark(bookmark, attrs, user) do
    # Get the post_key for re-encryption
    post_key = MossletWeb.Helpers.get_post_key(bookmark.post, user)

    if post_key do
      case Repo.transaction_on_primary(fn ->
             bookmark
             |> Bookmark.changeset(attrs, post_key: post_key)
             |> Repo.update()
           end) do
        {:ok, {:ok, updated_bookmark}} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "bookmarks:#{user.id}",
            {:bookmark_updated, updated_bookmark}
          )

          {:ok, updated_bookmark}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :no_access_to_post}
    end
  end

  @doc """
  Deletes a bookmark.
  """
  def delete_bookmark(bookmark, user) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(bookmark)
         end) do
      {:ok, {:ok, deleted_bookmark}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "bookmarks:#{user.id}",
          {:bookmark_deleted, deleted_bookmark}
        )

        {:ok, deleted_bookmark}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Gets a user's bookmark for a specific post.
  """
  def get_bookmark(user, post) do
    Repo.get_by(Bookmark, user_id: user.id, post_id: post.id)
  end

  @doc """
  Checks if a user has bookmarked a specific post.
  """
  def bookmarked?(user, post) do
    query =
      from b in Bookmark,
        where: b.user_id == ^user.id and b.post_id == ^post.id

    Repo.exists?(query)
  end

  @doc """
  Gets all bookmarks for a user with optional category filtering.
  """
  def list_user_bookmarks(user, opts \\ []) do
    query =
      from b in Bookmark,
        where: b.user_id == ^user.id,
        preload: [:category, post: :replies],
        order_by: [desc: b.inserted_at]

    query =
      case opts[:category_id] do
        nil -> query
        category_id -> where(query, [b], b.category_id == ^category_id)
      end

    # Apply consistent pagination using post_page and post_per_page
    query = paginate_bookmarks(query, opts)

    posts =
      query
      |> Repo.all()
      |> Enum.map(fn bookmark -> bookmark.post end)
      |> Enum.filter(&(&1 != nil))

    # Apply content filters to bookmarked posts
    apply_content_filters(posts, user, opts[:filter_prefs] || %{})
  end

  @doc """
  Counts a user's bookmarks.
  """
  def count_user_bookmarks(user, filter_prefs \\ %{}) do
    if has_active_filters?(filter_prefs) do
      # When filters are active, get bookmarked posts and count after filtering
      posts =
        from(b in Bookmark,
          where: b.user_id == ^user.id,
          preload: [post: :replies],
          order_by: [desc: b.inserted_at]
        )
        |> Repo.all()
        |> Enum.map(fn bookmark -> bookmark.post end)
        |> Enum.filter(&(&1 != nil))

      filtered_posts = apply_content_filters(posts, user, filter_prefs)
      length(filtered_posts)
    else
      # When no filters, use fast database count
      # NOTE: Bookmarks are 1:1 with posts, so no need for DISTINCT here
      query = from b in Bookmark, where: b.user_id == ^user.id
      Repo.aggregate(query, :count)
    end
  end

  @doc """
  Decrypts bookmark notes using the same post_key as the associated post.
  """
  def decrypt_bookmark_notes(bookmark, user, _key) do
    if bookmark.notes do
      # Use the SAME decryption flow as post.body
      post_key = MossletWeb.Helpers.get_post_key(bookmark.post, user)

      if post_key do
        case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: bookmark.notes}) do
          {:ok, decrypted_notes} -> decrypted_notes
          _ -> "Unable to decrypt notes"
        end
      else
        "No access to decrypt notes"
      end
    else
      nil
    end
  end

  ## Bookmark Category Functions

  @doc """
  Creates a bookmark category for a user.
  """
  def create_bookmark_category(user, attrs) do
    case Repo.transaction_on_primary(fn ->
           %BookmarkCategory{}
           |> BookmarkCategory.changeset(attrs)
           |> Ecto.Changeset.put_assoc(:user, user)
           |> Repo.insert()
         end) do
      {:ok, {:ok, category}} -> {:ok, category}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Updates a bookmark category.
  """
  def update_bookmark_category(category, attrs) do
    case Repo.transaction_on_primary(fn ->
           category
           |> BookmarkCategory.changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_category}} -> {:ok, updated_category}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Deletes a bookmark category.
  Note: This will set category_id to nil for existing bookmarks.
  """
  def delete_bookmark_category(category) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(category)
         end) do
      {:ok, {:ok, deleted_category}} -> {:ok, deleted_category}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Gets all bookmark categories for a user.
  """
  def list_user_bookmark_categories(user) do
    query =
      from bc in BookmarkCategory,
        where: bc.user_id == ^user.id,
        order_by: [asc: bc.name]

    Repo.all(query)
  end

  @doc """
  Gets a user's bookmark category by ID.
  """
  def get_user_bookmark_category(user, category_id) do
    Repo.get_by(BookmarkCategory, user_id: user.id, id: category_id)
  end

  ## Content Moderation Functions

  @doc """
  Reports a post for harmful content.

  ## Examples

      iex> report_post(reporter, reported_user, post, %{
      ...>   reason: "harassment",
      ...>   details: "Contains threatening language",
      ...>   report_type: :harassment,
      ...>   severity: :high
      ...> })
      {:ok, %PostReport{}}
  """
  def report_post(reporter, reported_user, post, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:reporter_id, reporter.id)
      |> Map.put(:reported_user_id, reported_user.id)
      |> Map.put(:post_id, post.id)

    # Get user key for encryption (simplified - you may need to adjust based on your key management)
    user_key = get_user_encryption_key(reporter)

    case Repo.transaction_on_primary(fn ->
           %PostReport{}
           |> PostReport.changeset(attrs, user: reporter, user_key: user_key)
           |> Repo.insert()
         end) do
      {:ok, {:ok, report}} ->
        # Broadcast to admin moderation system
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "moderation:reports",
          {:report_created, report}
        )

        {:ok, report}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Updates a post report status (admin function).
  """
  def update_post_report(report, attrs, _admin_user) do
    case Repo.transaction_on_primary(fn ->
           report
           |> PostReport.changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_report}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "moderation:reports",
          {:report_updated, updated_report}
        )

        {:ok, updated_report}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Gets all reports for admin review.
  """
  def list_post_reports(opts \\ []) do
    query =
      from r in PostReport,
        preload: [:reporter, :reported_user, :post],
        order_by: [desc: r.inserted_at]

    query =
      case opts[:status] do
        nil -> query
        status -> where(query, [r], r.status == ^status)
      end

    query =
      case opts[:severity] do
        nil -> query
        severity -> where(query, [r], r.severity == ^severity)
      end

    query =
      case opts[:limit] do
        nil -> query
        limit -> limit(query, ^limit)
      end

    Repo.all(query)
  end

  @doc """
  Blocks a user.

  ## Examples

      iex> block_user(blocker, blocked_user, %{
      ...>   reason: "Inappropriate content",
      ...>   block_type: :full
      ...> })
      {:ok, %UserBlock{}}
  """
  def block_user(blocker, blocked_user, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:blocker_id, blocker.id)
      |> Map.put(:blocked_id, blocked_user.id)

    # Get user key for encryption
    user_key = get_user_encryption_key(blocker)

    case Repo.transaction_on_primary(fn ->
           %UserBlock{}
           |> UserBlock.changeset(attrs, user: blocker, user_key: user_key)
           |> Repo.insert()
         end) do
      {:ok, {:ok, block}} ->
        # Broadcast block creation for real-time filtering
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "blocks:#{blocker.id}",
          {:user_blocked, block}
        )

        {:ok, block}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Unblocks a user.
  """
  def unblock_user(blocker, blocked_user) do
    block = Repo.get_by(UserBlock, blocker_id: blocker.id, blocked_id: blocked_user.id)

    if block do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(block)
           end) do
        {:ok, {:ok, deleted_block}} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "blocks:#{blocker.id}",
            {:user_unblocked, deleted_block}
          )

          {:ok, deleted_block}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :not_blocked}
    end
  end

  @doc """
  Checks if a user has blocked another user.
  """
  def user_blocked?(blocker, blocked_user) do
    query =
      from b in UserBlock,
        where: b.blocker_id == ^blocker.id and b.blocked_id == ^blocked_user.id

    Repo.exists?(query)
  end

  @doc """
  Gets all users blocked by a user.
  """
  def list_blocked_users(user) do
    query =
      from b in UserBlock,
        where: b.blocker_id == ^user.id,
        preload: [:blocked],
        order_by: [desc: b.inserted_at]

    Repo.all(query)
  end

  @doc """
  Hides a post from a user's timeline.

  ## Examples

      iex> hide_post(user, post, %{
      ...>   reason: "Not interested",
      ...>   hide_type: :similar_content
      ...> })
      {:ok, %PostHide{}}
  """
  def hide_post(user, post, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:post_id, post.id)

    # Get user key for encryption
    user_key = get_user_encryption_key(user)

    case Repo.transaction_on_primary(fn ->
           %PostHide{}
           |> PostHide.changeset(attrs, user: user, user_key: user_key)
           |> Repo.insert()
         end) do
      {:ok, {:ok, hide}} ->
        # Broadcast hide creation for real-time filtering
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "hides:#{user.id}",
          {:post_hidden, hide}
        )

        {:ok, hide}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Unhides a post.
  """
  def unhide_post(user, post) do
    hide = Repo.get_by(PostHide, user_id: user.id, post_id: post.id)

    if hide do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(hide)
           end) do
        {:ok, {:ok, deleted_hide}} ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "hides:#{user.id}",
            {:post_unhidden, deleted_hide}
          )

          {:ok, deleted_hide}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :not_hidden}
    end
  end

  @doc """
  Checks if a user has hidden a specific post.
  """
  def post_hidden?(user, post) do
    query =
      from h in PostHide,
        where: h.user_id == ^user.id and h.post_id == ^post.id

    Repo.exists?(query)
  end

  @doc """
  Gets all posts hidden by a user.
  """
  def list_hidden_posts(user) do
    query =
      from h in PostHide,
        where: h.user_id == ^user.id,
        preload: [:post],
        order_by: [desc: h.inserted_at]

    Repo.all(query)
  end

  @doc """
  Filters timeline posts to exclude blocked users and hidden posts.
  This should be called in your timeline filtering logic.
  """
  def apply_moderation_filters(query, user) do
    # Exclude posts from blocked users
    blocked_user_ids =
      from(b in UserBlock,
        where: b.blocker_id == ^user.id,
        select: b.blocked_id
      )

    # Exclude hidden posts
    hidden_post_ids =
      from(h in PostHide,
        where: h.user_id == ^user.id,
        select: h.post_id
      )

    query
    |> where([p], p.user_id not in subquery(blocked_user_ids))
    |> where([p], p.id not in subquery(hidden_post_ids))
  end

  # Helper function to get user encryption key (you may need to adjust this)
  defp get_user_encryption_key(user) do
    # This is a simplified version - adjust based on your key management system
    # You may need to decrypt the user's key or generate a temporary key
    case user.key_pair do
      %{"private" => private_key} -> private_key
      _ -> Mosslet.Encrypted.Utils.generate_key()
    end
  end

  ## Content Warning Functions

  @doc """
  Creates a system content warning category (admin function).

  ## Examples

      iex> create_system_content_warning_category(%{
      ...>   name: "Mental Health",
      ...>   description: "Content related to mental health topics",
      ...>   severity_level: :high,
      ...>   color: "red"
      ...> })
      {:ok, %ContentWarningCategory{}}
  """
  def create_system_content_warning_category(attrs) do
    attrs = Map.put(attrs, :is_system_category, true)

    case Repo.transaction_on_primary(fn ->
           %ContentWarningCategory{}
           |> ContentWarningCategory.changeset(attrs)
           |> Repo.insert()
         end) do
      {:ok, {:ok, category}} -> {:ok, category}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Creates a user-specific content warning category.

  ## Examples

      iex> create_user_content_warning_category(user, %{
      ...>   name: "Food",
      ...>   description: "Food content that might be triggering",
      ...>   severity_level: :medium
      ...> })
      {:ok, %ContentWarningCategory{}}
  """
  def create_user_content_warning_category(user, attrs) do
    attrs =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put(:is_system_category, false)

    case Repo.transaction_on_primary(fn ->
           %ContentWarningCategory{}
           |> ContentWarningCategory.changeset(attrs)
           |> Repo.insert()
         end) do
      {:ok, {:ok, category}} -> {:ok, category}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Lists all available content warning categories for a user.
  Includes both system categories and user's custom categories.
  """
  def list_content_warning_categories(user) do
    query =
      from c in ContentWarningCategory,
        where: c.is_system_category == true or c.user_id == ^user.id,
        order_by: [asc: c.is_system_category, asc: c.name]

    Repo.all(query)
  end

  @doc """
  Lists only system content warning categories.
  """
  def list_system_content_warning_categories() do
    query =
      from c in ContentWarningCategory,
        where: c.is_system_category == true,
        order_by: [asc: c.name]

    Repo.all(query)
  end

  @doc """
  Adds a content warning to a post.

  ## Examples

      iex> add_content_warning_to_post(post, user, %{
      ...>   content_warning_category: "Mental Health",
      ...>   content_warning_text: "Discussion of depression and anxiety"
      ...> })
      {:ok, %Post{}}
  """
  def add_content_warning_to_post(post, user, attrs) do
    # Get the post_key for encrypting warning text (same as post body)
    post_key = MossletWeb.Helpers.get_post_key(post, user)

    if post_key do
      warning_attrs = %{
        content_warning_category: attrs[:content_warning_category],
        content_warning: attrs[:content_warning],
        content_warning?: true
      }

      case Repo.transaction_on_primary(fn ->
             # Use a minimal changeset that only updates content warning fields
             post
             |> Ecto.Changeset.cast(warning_attrs, [
               :content_warning_category,
               :content_warning,
               :content_warning?
             ])
             |> encrypt_content_warning_fields(post_key)
             |> Repo.update()
           end) do
        {:ok, {:ok, updated_post}} ->
          # Broadcast content warning added
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "posts",
            {:post_updated, updated_post}
          )

          {:ok, updated_post}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :no_access_to_post}
    end
  end

  # Helper function to encrypt content warning fields
  defp encrypt_content_warning_fields(changeset, post_key) do
    content_warning = Ecto.Changeset.get_field(changeset, :content_warning)
    content_warning_category = Ecto.Changeset.get_field(changeset, :content_warning_category)

    # For content_warning field: First encrypt with enacl (asymmetric), then Cloak handles symmetric encryption at rest
    changeset =
      if content_warning && String.trim(content_warning) != "" do
        try do
          # Get the binary result from enacl encryption (returns binary directly)
          encrypted_warning =
            Mosslet.Encrypted.Utils.encrypt(%{key: post_key, payload: content_warning})

          # Store the enacl-encrypted binary - Cloak will add the second layer automatically
          Ecto.Changeset.put_change(changeset, :content_warning, encrypted_warning)
        rescue
          e ->
            IO.puts("Encryption error: #{inspect(e)}")

            Ecto.Changeset.add_error(
              changeset,
              :content_warning,
              "Failed to encrypt content warning"
            )
        end
      else
        changeset
      end

    if content_warning_category && String.trim(content_warning_category) != "" do
      Ecto.Changeset.put_change(
        changeset,
        :content_warning_hash,
        String.downcase(String.trim(content_warning_category))
      )
    else
      changeset
    end
  end

  @doc """
  Removes a content warning from a post.
  """
  def remove_content_warning_from_post(post, _user) do
    case Repo.transaction_on_primary(fn ->
           post
           |> Post.changeset(%{
             content_warning_category: nil,
             content_warning: nil,
             content_warning?: false
           })
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_post}} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "posts",
          {:post_updated, updated_post}
        )

        {:ok, updated_post}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Checks if a post has a content warning.
  """
  def post_has_content_warning?(post) do
    !!post.content_warning?
  end

  @doc """
  Filters timeline to exclude posts with content warnings (user preference).
  """
  def apply_content_warning_filters(query, _user, opts \\ []) do
    hide_warnings = opts[:hide_content_warnings] || false

    if hide_warnings do
      where(query, [p], p.content_warning? == false)
    else
      query
    end
  end

  @doc """
  Decrypts content warning text using the same post_key as the post body.
  """
  def decrypt_content_warning_text(post, user, _key) do
    if post.content_warning do
      # Use the SAME post_key as post body decryption
      post_key = MossletWeb.Helpers.get_post_key(post, user)

      if post_key do
        case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: post.content_warning}) do
          {:ok, decrypted_text} -> decrypted_text
          _ -> "Unable to decrypt warning text"
        end
      else
        "No access to decrypt warning"
      end
    else
      nil
    end
  end

  @doc """
  Seeds the database with default system content warning categories.
  This should be run once during deployment.
  """
  def seed_system_content_warning_categories() do
    default_categories = [
      %{
        name: "Mental Health",
        description: "Content related to mental health, depression, anxiety, self-harm",
        severity_level: :high,
        color: "red",
        icon: "hero-heart"
      },
      %{
        name: "Violence",
        description: "Content depicting or discussing violence",
        severity_level: :high,
        color: "red",
        icon: "hero-exclamation-triangle"
      },
      %{
        name: "Substance Use",
        description: "Content related to alcohol, drugs, or substance abuse",
        severity_level: :medium,
        color: "orange",
        icon: "hero-beaker"
      },
      %{
        name: "Food & Body Image",
        description: "Content that might trigger eating disorders or body image issues",
        severity_level: :medium,
        color: "yellow",
        icon: "hero-heart"
      },
      %{
        name: "Politics",
        description: "Political content that might be controversial",
        severity_level: :low,
        color: "blue",
        icon: "hero-megaphone"
      },
      %{
        name: "Death & Grief",
        description: "Content discussing death, loss, or grief",
        severity_level: :high,
        color: "purple",
        icon: "hero-heart"
      }
    ]

    Enum.each(default_categories, fn category_attrs ->
      case create_system_content_warning_category(category_attrs) do
        {:ok, _category} ->
          :ok

        {:error, %{errors: errors}} ->
          # Category might already exist
          case Keyword.get(errors, :name_hash) do
            {_, [constraint: :unique, constraint_name: _]} -> :ok
            _ -> Logger.warning("Failed to create category: #{inspect(errors)}")
          end
      end
    end)

    :ok
  end

  ## Timeline Navigation & Preferences

  @doc """
  Gets timeline data for a specific tab with caching.
  """
  def get_timeline_data(user, tab, options \\ %{}) do
    Navigation.get_timeline_data(user, tab, options)
  end

  @doc """
  Gets post counts for all timeline tabs efficiently.
  """
  def get_timeline_counts(user) do
    Navigation.get_timeline_counts(user)
  end

  @doc """
  Gets or creates user timeline preferences.
  """
  def get_user_timeline_preferences(user) do
    Navigation.get_user_preferences(user)
  end

  @doc """
  Updates user timeline preferences.
  """
  def update_user_timeline_preferences(user, attrs, opts \\ []) do
    Navigation.update_user_preferences(user, attrs, opts)
  end

  @doc """
  Creates a changeset for UserTimelinePreferences.
  """
  def change_user_timeline_preferences(
        preferences \\ %UserTimelinePreferences{},
        attrs \\ %{},
        opts \\ []
      ) do
    UserTimelinePreferences.changeset(preferences, attrs, opts)
  end

  @doc """
  Invalidates timeline cache when posts are created/updated/deleted.
  """
  def invalidate_timeline_cache_for_user(user_id, affecting_tabs \\ nil) do
    Navigation.invalidate_timeline_cache_for_user(user_id, affecting_tabs)
  end

  @doc """
  Applies content filters to a list of posts.

  This function accepts already-decrypted filter preferences from the LiveView
  and applies them to the posts list. It's designed to be called at the
  end of Timeline context functions to ensure consistent filtering across
  all timeline tabs and cached/fresh data.
  """
  def apply_content_filters(posts, user, filter_prefs \\ %{}) do
    # Skip filtering if no filter preferences provided or explicitly disabled
    if is_nil(filter_prefs) || filter_prefs[:skip_content_filters] do
      posts
    else
      # Apply filters using the ContentFilter module with already-decrypted prefs
      ContentFilter.filter_timeline_posts(posts, user, filter_prefs)
    end
  end

  @doc """
  Checks if the user has active content filters.
  """
  def has_active_filters?(filter_prefs) when is_nil(filter_prefs), do: false

  def has_active_filters?(filter_prefs) do
    keywords_active = length(filter_prefs[:keywords] || []) > 0
    cw_active = Map.get(filter_prefs[:content_warnings] || %{}, :hide_all, false)
    users_active = length(filter_prefs[:muted_users] || []) > 0
    reposts_active = Map.get(filter_prefs, :hide_reposts, false)

    keywords_active || cw_active || users_active || reposts_active
  end
end
