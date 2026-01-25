defmodule Mosslet.Timeline do
  @moduledoc """
  The Timeline context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Timeline.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Timeline.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Groups
  alias Mosslet.Platform
  alias Mosslet.Repo

  alias Mosslet.Timeline.{
    Post,
    Reply,
    UserPost,
    UserPostReceipt,
    UserTimelinePreference,
    Bookmark,
    BookmarkCategory,
    PostReport,
    UserPostReport,
    PostHide,
    ContentWarningCategory,
    Navigation
  }

  alias Mosslet.Accounts.UserBlock
  alias Mosslet.Timeline.Performance.TimelineCache

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Timeline.Adapters.Web
    end
  end

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
  end

  @doc """
  Counts all posts for admin dashboard.
  """
  def count_all_posts, do: adapter().count_all_posts()

  @doc """
  Gets the total count of a user's Posts. An
  optional filter can be applied.
  """
  def post_count(user, options), do: adapter().post_count(user, options)

  @doc """
  Gets the total count of a user's Posts that have
  been shared with the current_user by another user.
  Does not include group Posts.
  """
  def shared_between_users_post_count(user_id, current_user_id),
    do: adapter().shared_between_users_post_count(user_id, current_user_id)

  @doc """
  Gets the total count of a current_user's posts
  on their timeline page.
  """
  def timeline_post_count(current_user, options),
    do: adapter().timeline_post_count(current_user, options)

  @doc """
  Gets the total count of a post's Replies. An
  optional filter can be applied.

  Subquery on the user_connection to ensure
  only connections are viewing their connections' replies.
  """
  def reply_count(post, options), do: adapter().reply_count(post, options)

  @doc """
  Gets the total count of a public post's public Replies. An
  optional filter can be applied.

  This does not apply a current user check.
  """
  def public_reply_count(post, options), do: adapter().public_reply_count(post, options)

  def preload_group(post), do: adapter().preload_group(post)

  @doc """
  Gets the total count of a group's Posts.
  """
  def group_post_count(group), do: adapter().group_post_count(group)

  @doc """
  Gets the total count of Public Posts. An
  optional filter can be applied.
  """
  def public_post_count_filtered(user, options),
    do: adapter().public_post_count_filtered(user, options)

  @doc """
  Gets the total count of a profile_user's
  Public Posts.
  """
  def public_post_count(user), do: adapter().public_post_count(user)

  @doc """
  Gets the total count of posts created BY the current user (for Home tab).
  This counts only posts where the user is the author, regardless of visibility.
  """
  def count_user_own_posts(user, filter_prefs \\ %{}) do
    adapter().count_user_own_posts(user, filter_prefs)
  end

  @doc """
  Gets the total count of group posts accessible to the current user (for Groups tab).
  This counts posts with group_id that the user has access to.
  """
  def count_user_group_posts(user, filter_prefs \\ %{}) do
    adapter().count_user_group_posts(user, filter_prefs)
  end

  @doc """
  Gets the total count of posts FROM connected users accessible to current user (for Connections tab).
  This matches the filtering logic used in apply_tab_filtering.
  """
  def count_user_connection_posts(current_user, filter_prefs \\ %{}) do
    adapter().count_user_connection_posts(current_user, filter_prefs)
  end

  @doc """
  Gets the count of unread posts created by the current user (for Home tab unread indicator).
  Now applies content filters to ensure unread counts match filtered timeline display.
  """
  def count_unread_user_own_posts(user, filter_prefs \\ %{}) do
    adapter().count_unread_user_own_posts(user, filter_prefs)
  end

  @doc """
  Gets the count of unread bookmarked posts (for Bookmarks tab unread indicator).
  Now applies content filters to ensure unread counts match filtered timeline display.
  """
  def count_unread_bookmarked_posts(user, filter_prefs \\ %{}) do
    adapter().count_unread_bookmarked_posts(user, filter_prefs)
  end

  @doc """
  Returns all post for a user. Used when
  deleting data in settings.
  """
  def get_all_posts(user), do: adapter().get_all_posts(user)

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
    adapter().list_posts(user, options)
  end

  @doc """
  Returns posts for sync with desktop/mobile apps.

  Returns UserPost records with associated posts, including encrypted
  data blobs that native apps decrypt locally.

  ## Options

  - `:since` - Only return posts updated after this timestamp
  - `:limit` - Maximum number of posts to return (default 50)
  """
  def list_user_posts_for_sync(user, opts \\ []),
    do: adapter().list_user_posts_for_sync(user, opts)

  @doc """
  Returns the list of replies for a post.

  Checks the user_connection_query to return only relevantly
  connected replies.
  """
  def list_replies(post, options) do
    adapter().list_replies(post, options)
  end

  @doc """
  Returns the first (latest) reply for a post.
  """
  def first_reply(post, options) do
    adapter().first_reply(post, options)
  end

  @doc """
  Returns the first (latest) public reply for a post.

  This does not apply a current_user check.
  """
  def first_public_reply(post, options) do
    adapter().first_public_reply(post, options)
  end

  @doc """
  Returns a list of posts shared between two users.
  """
  def list_shared_posts(user_id, current_user_id, options) do
    adapter().list_shared_posts(user_id, current_user_id, options)
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
    |> with_any_visibility([:private, :connections, :specific_groups, :specific_users])
    |> apply_database_filters(options)
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
    |> add_nested_replies_to_posts(options)
  end

  @doc """
  Gets the total count of unread posts for a user.
  Uses the same logic as unread_posts/1 but optimized for counting.
  """
  def count_unread_posts_for_user(user) do
    adapter().count_unread_posts_for_user(user)
  end

  @doc """
  Counts replies to the user's own posts that have not been read yet,
  plus replies to the user's own replies (nested replies).
  Used for the in-app notification count on reply buttons.
  """
  def count_unread_replies_for_user(user) do
    adapter().count_unread_replies_for_user(user)
  end

  @doc """
  Returns a map of post_id => unread_reply_count for posts owned by the user.
  Only counts replies from other users that have not been read yet.
  Also includes replies to the user's own replies (nested replies) on any post.
  """
  def count_unread_replies_by_post(user) do
    adapter().count_unread_replies_by_post(user)
  end

  @doc """
  Counts unread replies to the user's own replies (nested replies).
  This notifies users when someone replies to their reply on any post.
  """
  def count_unread_replies_to_user_replies(user) do
    adapter().count_unread_replies_to_user_replies(user)
  end

  @doc """
  Returns a map of parent_reply_id => unread_count for replies to the user's own replies.
  Used to show unread indicators on nested reply toggle buttons.
  """
  def count_unread_nested_replies_by_parent(user) do
    adapter().count_unread_nested_replies_by_parent(user)
  end

  @doc """
  Marks all unread replies to a specific parent reply as read.
  Called when user expands a nested reply thread.
  """
  def mark_nested_replies_read_for_parent(parent_reply_id, user_id) do
    adapter().mark_nested_replies_read_for_parent(parent_reply_id, user_id)
  end

  @doc """
  Returns a map of post_id => unread_nested_reply_count for posts containing
  replies by the user that have been replied to by others.
  """
  def count_unread_replies_to_user_replies_by_post(user) do
    adapter().count_unread_replies_to_user_replies_by_post(user)
  end

  @doc """
  Counts unread nested replies (replies to user's replies) for a specific post.
  Returns the count of unread nested replies on that post.
  """
  def count_unread_nested_replies_for_post(post_id, user_id) do
    adapter().count_unread_nested_replies_for_post(post_id, user_id)
  end

  @doc """
  Marks all unread replies to a specific post as read.
  This includes:
  - Direct replies to posts the user owns
  - Replies to the user's own replies on that post (nested replies)
  Returns the number of replies marked as read.
  """
  def mark_replies_read_for_post(post_id, user_id) do
    adapter().mark_replies_read_for_post(post_id, user_id)
  end

  @doc """
  Marks only top-level (direct) unread replies to a specific post as read.
  Does NOT mark nested replies as read.
  Returns the number of replies marked as read.
  """
  def mark_top_level_replies_read_for_post(post_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    mark_direct_replies_read_for_post(post_id, user_id, now)
  end

  defp mark_direct_replies_read_for_post(post_id, user_id, now) do
    {count, _} =
      Reply
      |> join(:inner, [r], p in Post, on: r.post_id == p.id)
      |> where([r, p], r.post_id == ^post_id)
      |> where([r, p], p.user_id == ^user_id)
      |> where([r, p], r.user_id != ^user_id)
      |> where([r, p], is_nil(r.read_at))
      |> where([r, p], is_nil(r.parent_reply_id))
      |> Repo.update_all(set: [read_at: now])

    count
  end

  @doc """
  Marks all unread replies to all of a user's posts as read,
  plus replies to the user's own replies (nested replies).
  Used when user views their replies/notifications page.
  Returns the number of replies marked as read.
  """
  def mark_all_replies_read_for_user(user_id) do
    adapter().mark_all_replies_read_for_user(user_id)
  end

  @doc """
  Returns a list of posts for the current_user that
  have not been read yet.
  """
  def unread_posts(current_user, options \\ %{}) do
    adapter().unread_posts(current_user, options)
  end

  defp with_any_visibility(query, visibility_list) do
    where(query, [p], p.visibility in ^visibility_list)
  end

  # Filters out posts based on content warning categories that the user has muted.
  # Uses the content_warning_category_hash for efficient database-level filtering.
  defp filter_by_muted_keywords(query, muted_keywords)
       when is_list(muted_keywords) and muted_keywords != [] do
    # For each muted keyword, add a condition to exclude posts with that category hash
    Enum.reduce(muted_keywords, query, fn muted_keyword, acc_query ->
      # Convert to lowercase to match hash storage format
      muted_hash = String.downcase(muted_keyword)

      # Filter out posts where content_warning_category_hash matches this muted keyword
      # Keep posts that either have no content warning OR have a different category
      where(
        acc_query,
        [p],
        is_nil(p.content_warning_category_hash) or
          p.content_warning_category_hash != ^muted_hash
      )
    end)
  end

  defp filter_by_muted_keywords(query, _muted_keywords), do: query

  # Filters out posts based on content warning settings.
  # Hides all content warning posts if hide_all is true.
  defp filter_by_content_warnings(query, cw_settings) do
    hide_all = Map.get(cw_settings || %{}, :hide_all, false)
    hide_mature = Map.get(cw_settings || %{}, :hide_mature, false)

    cond do
      hide_all ->
        # Hide all content warnings AND mature content
        query
        |> where([p], not p.content_warning? or is_nil(p.content_warning?))
        |> where([p], not p.mature_content or is_nil(p.mature_content))

      hide_mature ->
        # Hide only mature content
        query
        |> where([p], not p.mature_content or is_nil(p.mature_content))

      true ->
        # No filtering
        query
    end
  end

  # Filters out posts from muted users.
  # Handles both legacy format (list of user IDs) and hydrated format (list of user objects)
  defp filter_by_muted_users(query, muted_users)
       when is_list(muted_users) and muted_users != [] do
    # Extract user IDs from the muted users list
    user_ids = extract_user_ids_from_muted_users(muted_users)

    case user_ids do
      [] -> query
      ids when is_list(ids) -> where(query, [p], p.user_id not in ^ids)
    end
  end

  defp filter_by_muted_users(query, _muted_users), do: query

  # Helper function to extract user IDs from muted users list
  # Handles both legacy format (strings) and hydrated format (structs)
  defp extract_user_ids_from_muted_users(muted_users) do
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

  # Filters out posts from blocked users.
  # This matches the same pattern as filter_by_muted_users but for UserBlock relationships.
  # Filters out posts from blocked users (2-directional blocking).
  # This is separate from muted_users and respects block_type granularity.
  defp filter_by_blocked_users_posts(query, current_user_id) when is_binary(current_user_id) do
    # Subquery: users blocked by current user (posts + full blocks)
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocked_id
      )

    # Subquery: users who blocked current user (posts + full blocks)
    blocked_me_subquery =
      from(ub in UserBlock,
        where: ub.blocked_id == ^current_user_id and ub.block_type in [:full, :posts_only],
        select: ub.blocker_id
      )

    query
    |> where([p], p.user_id not in subquery(blocked_by_me_subquery))
    |> where([p], p.user_id not in subquery(blocked_me_subquery))
  end

  # Filters out replies from blocked users (2-directional blocking).
  # NOTE: :posts_only blocks should NOT filter replies - only :replies_only and :full blocks
  defp filter_by_blocked_users_replies(query, current_user_id) when is_binary(current_user_id) do
    # Subquery: users blocked by current user (replies + full blocks only)
    # Explicitly exclude :posts_only blocks since they should only block posts, not replies
    blocked_by_me_subquery =
      from(ub in UserBlock,
        where: ub.blocker_id == ^current_user_id and ub.block_type in [:full, :replies_only],
        select: ub.blocked_id
      )

    # Subquery: users who blocked current user (replies + full blocks only)
    # Explicitly exclude :posts_only blocks since they should only block posts, not replies
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

  # Filters out reposted posts if hide_reposts is true.
  defp filter_by_reposts(query, true) do
    where(query, [p], not p.repost or is_nil(p.repost))
  end

  defp filter_by_reposts(query, _hide_reposts), do: query

  # Helper function to extract filter preferences from options and apply all database-level filters.
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

  @doc """
  Returns the list of public posts.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_posts(user, options)
      [%Post{}, ...]

  """
  def list_public_posts(options) do
    adapter().list_public_posts(nil, options)
  end

  @doc """
  Returns posts FROM connected users for the Connections tab.
  This function is specifically designed to match the filtering logic
  used in the timeline and provide consistent results.
  """
  def list_connection_posts(current_user, options \\ %{})

  def list_connection_posts(current_user, options) do
    options_with_filters = ensure_filter_prefs(options, current_user)

    posts =
      if !options_with_filters[:skip_cache] && (options_with_filters[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "connections") do
          {:hit, cached_data} ->
            Logger.debug("Connections timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = adapter().fetch_connection_posts(current_user, options_with_filters)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "connections", timeline_data)
            posts
        end
      else
        adapter().fetch_connection_posts(current_user, options_with_filters)
      end

    posts
  end

  # Helper function to ensure options always include current user's content filter preferences
  defp ensure_filter_prefs(options, current_user) do
    if options[:filter_prefs] do
      # Filter preferences already provided, use them
      options
    else
      # No filter preferences provided, load them from the database
      case get_user_timeline_preference(current_user) do
        nil ->
          # No preferences stored, use empty defaults but include the map structure
          Map.put(options, :filter_prefs, %{
            keywords: [],
            muted_users: [],
            content_warnings: %{hide_all: false, hide_mature: false},
            hide_reposts: false
          })

        prefs ->
          # Use stored preferences (already decrypted by get_user_timeline_preference)
          filter_prefs = %{
            keywords: decrypt_filter_keywords(prefs, current_user),
            muted_users: decrypt_muted_users(prefs, current_user),
            content_warnings: %{
              hide_all: prefs.hide_content_warnings || false,
              hide_mature: prefs.hide_mature_content || false
            },
            hide_reposts: prefs.hide_reposts || false
          }

          Map.put(options, :filter_prefs, filter_prefs)
      end
    end
  end

  # Helper to decrypt filter keywords
  defp decrypt_filter_keywords(prefs, current_user) do
    if prefs.mute_keywords != [] do
      user_key = current_user.key

      if user_key do
        Enum.map(prefs.mute_keywords, fn encrypted_keyword ->
          Mosslet.Encrypted.Users.Utils.decrypt_user_data(
            encrypted_keyword,
            current_user,
            user_key
          )
        end)
        |> Enum.reject(&is_nil/1)
      else
        []
      end
    else
      []
    end
  end

  # Helper to decrypt muted users
  defp decrypt_muted_users(prefs, current_user) do
    if prefs.muted_users != [] do
      user_key = current_user.key

      if user_key do
        Enum.map(prefs.muted_users, fn encrypted_user_id ->
          Mosslet.Encrypted.Users.Utils.decrypt_user_data(
            encrypted_user_id,
            current_user,
            user_key
          )
        end)
        |> Enum.reject(&is_nil/1)
      else
        []
      end
    else
      []
    end
  end

  @doc """
  Gets the count of unread connection posts (for Connections tab unread indicator).
  Now applies content filters to ensure unread counts match filtered timeline display.
  """
  def count_unread_connection_posts(current_user, filter_prefs \\ %{}) do
    adapter().count_unread_connection_posts(current_user, filter_prefs)
  end

  @doc """
  Returns the list of group posts for the current user.
  These are posts with visibility :specific_groups where the user is in the shared_users list.
  """
  def list_group_posts(current_user, options \\ %{}) do
    posts =
      if !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "groups") do
          {:hit, cached_data} ->
            Logger.debug("Groups timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = adapter().fetch_group_posts(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "groups", timeline_data)
            posts
        end
      else
        adapter().fetch_group_posts(current_user, options)
      end

    posts
  end

  @doc """
  Gets the count of unread group posts (for Groups tab unread indicator).
  Now applies content filters to ensure unread counts match filtered timeline display.
  """
  def count_unread_group_posts(current_user, filter_prefs \\ %{}) do
    adapter().count_unread_group_posts(current_user, filter_prefs)
  end

  @doc """
  Lists public posts for discover timeline with simple pagination.
  """
  def list_discover_posts(current_user \\ nil, options \\ %{}) do
    posts =
      if current_user && !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "discover") do
          {:hit, cached_data} ->
            Logger.debug("Discover timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = adapter().fetch_discover_posts(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "discover", timeline_data)
            posts
        end
      else
        adapter().fetch_discover_posts(current_user, options)
      end

    posts
  end

  @doc """
  Counts public posts for discover timeline.
  """
  def count_discover_posts(current_user \\ nil, filter_prefs \\ %{}) do
    adapter().count_discover_posts(current_user, filter_prefs)
  end

  @doc """
  Gets the count of unread discover posts (for Discover tab unread indicator).
  Now applies content filters to ensure unread counts match filtered timeline display.
  """
  def count_unread_discover_posts(current_user, filter_prefs \\ %{}) do
    adapter().count_unread_discover_posts(current_user, filter_prefs)
  end

  @doc """
  Returns posts created BY the current user for the Home tab.
  This function is specifically designed to show only the user's own posts.
  """
  def list_user_own_posts(current_user, options \\ %{})

  def list_user_own_posts(current_user, options) do
    posts =
      if !options[:skip_cache] && (options[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "home") do
          {:hit, cached_data} ->
            Logger.debug("Home timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = adapter().fetch_user_own_posts(current_user, options)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "home", timeline_data)
            posts
        end
      else
        adapter().fetch_user_own_posts(current_user, options)
      end

    posts
  end

  @doc """
  Returns the unified home timeline containing all posts: user's own posts,
  connection posts, and group posts. This consolidates the previous Home,
  Connections, and Groups tabs into a single unified feed.

  Posts are ordered by unread status first (unread before read), then by
  most recent timestamp.

  Supports filtering by source:
  - filter_prefs.author_filter: :all | :mine | :connections

  ## Examples

      iex> list_home_timeline(user, %{})
      [%Post{}, ...]

  """
  def list_home_timeline(current_user, options \\ %{})

  def list_home_timeline(current_user, options) do
    options_with_filters = ensure_filter_prefs(options, current_user)

    posts =
      if !options_with_filters[:skip_cache] && (options_with_filters[:post_page] || 1) == 1 do
        case TimelineCache.get_timeline_data(current_user.id, "home") do
          {:hit, cached_data} ->
            Logger.debug("Home timeline cache hit for user #{current_user.id}")
            cached_data[:posts] || []

          :miss ->
            posts = adapter().fetch_home_timeline(current_user, options_with_filters)

            timeline_data = %{
              posts: posts,
              post_count: length(posts),
              fetched_at: System.system_time(:millisecond)
            }

            TimelineCache.cache_timeline_data(current_user.id, "home", timeline_data)
            posts
        end
      else
        adapter().fetch_home_timeline(current_user, options_with_filters)
      end

    posts
  end

  @doc """
  Counts all posts in the unified home timeline (user's own + connections + groups).
  Supports author_filter in filter_prefs: :all | :mine | :connections
  """
  def count_home_timeline(current_user, filter_prefs \\ %{}) do
    adapter().count_home_timeline(current_user, filter_prefs)
  end

  @doc """
  Counts unread posts in the unified home timeline.
  Supports author_filter in filter_prefs: :all | :mine | :connections
  """
  def count_unread_home_timeline(current_user, filter_prefs \\ %{}) do
    adapter().count_unread_home_timeline(current_user, filter_prefs)
  end

  def list_public_replies(post, options) do
    adapter().list_public_replies(post, options)
  end

  @doc """
  Returns the list of public posts for the
  user profile being viewed.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_public_profile_posts(user, viewer, hidden_post_ids, options)
      [%Post{}, ...]

  """
  def list_public_profile_posts(user, viewer, hidden_post_ids, options) do
    adapter().list_public_profile_posts(user, viewer, hidden_post_ids, options)
  end

  @doc """
  Lists posts for a profile user that are visible to the viewer.

  Visibility rules:
  - If viewer is the profile owner: show all their posts (private, connections, public, etc)
  - If viewer is a connection: show public posts + connections posts + specific_users posts where viewer is included
  - If viewer is not connected: show only public posts

  Options:
  - :post_page - page number for pagination (default: 1)
  - :post_per_page - posts per page (default: 10)
  """
  def list_profile_posts_visible_to(profile_user, viewer, options \\ %{}) do
    adapter().list_profile_posts_visible_to(profile_user, viewer, options)
  end

  def count_profile_posts_visible_to(profile_user, viewer) do
    adapter().count_profile_posts_visible_to(profile_user, viewer)
  end

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

  @doc """
  Lists all posts for a group and user.
  """
  def list_user_group_posts(group, user) do
    adapter().list_user_group_posts(group, user)
  end

  def list_own_connection_posts(user, opts) do
    adapter().list_own_connection_posts(user, opts)
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

    nested_replies = get_nested_replies_for_post(id)
    Map.put(post, :replies, nested_replies)
  end

  @doc """
  Gets a post with nested replies with pagination support.
  Used for "Load more replies" functionality.

  ## Options

    * `:current_user_id` - The current user's ID for block filtering
    * `:limit` - Maximum number of top-level replies to return
    * `:offset` - Number of top-level replies to skip
  """
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

  def get_reply!(id), do: adapter().get_reply!(id)

  def get_reply(id), do: adapter().get_reply(id)

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
  Gets replies for a post with proper nesting structure and block filtering.
  Returns a tree structure with top-level replies and their children.

  ## Options

    * `:current_user_id` - The current user's ID for block filtering
    * `:limit` - Maximum number of top-level replies to return (default: all)
    * `:offset` - Number of top-level replies to skip (default: 0)
  """
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
        filter_by_blocked_users_replies(top_level_query, options[:current_user_id])
      else
        top_level_query
      end

    top_level_query =
      if limit do
        top_level_query
        |> offset(^offset)
        |> limit(^limit)
      else
        top_level_query
      end

    top_level_replies = Repo.all(top_level_query)

    Enum.map(top_level_replies, fn reply ->
      child_replies = get_child_replies_tree(reply.id, options)
      Map.put(reply, :child_replies, child_replies)
    end)
  end

  defp get_child_replies_tree(parent_reply_id, options) do
    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_reply_id,
        order_by: [asc: r.inserted_at],
        preload: [:user, :parent_reply]
      )

    query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.all(query)
    |> Enum.map(fn child ->
      Map.put(child, :child_replies, get_child_replies_tree(child.id, options))
    end)
  end

  @doc """
  Gets child replies for a specific parent reply with pagination.
  Used for "Load more replies" on nested threads.

  ## Options

    * `:current_user_id` - The current user's ID for block filtering
    * `:limit` - Maximum number of replies to return (default: 5)
    * `:offset` - Number of replies to skip (default: 0)
  """
  def get_child_replies_for_reply(parent_reply_id, options \\ %{}) do
    limit = options[:limit] || 5
    offset = options[:offset] || 0

    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_reply_id,
        order_by: [asc: r.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user, :parent_reply]
      )

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    replies = Repo.all(filtered_query)

    Enum.map(replies, fn reply ->
      child_replies = get_all_child_replies_recursive(reply.id, options)
      Map.put(reply, :child_replies, child_replies)
    end)
  end

  defp get_all_child_replies_recursive(parent_id, options) do
    query =
      from(r in Reply,
        where: r.parent_reply_id == ^parent_id,
        order_by: [asc: r.inserted_at],
        preload: [:user, :parent_reply]
      )

    filtered_query =
      if options[:current_user_id] do
        filter_by_blocked_users_replies(query, options[:current_user_id])
      else
        query
      end

    Repo.all(filtered_query)
    |> Enum.map(fn child ->
      Map.put(child, :child_replies, get_all_child_replies_recursive(child.id, options))
    end)
  end

  @doc """
  Counts total replies for a post (all levels).
  """
  def count_replies_for_post(post_id, options \\ %{}) do
    adapter().count_replies_for_post(post_id, options)
  end

  @doc """
  Counts top-level replies for a post (replies without a parent).
  """
  def count_top_level_replies(post_id, options \\ %{}) do
    adapter().count_top_level_replies(post_id, options)
  end

  @doc """
  Counts child replies for a specific parent reply.
  """
  def count_child_replies(parent_reply_id, options \\ %{}) do
    adapter().count_child_replies(parent_reply_id, options)
  end

  @doc """
  Gets the list of user IDs that are blocked by the current user.
  Returns a list of integers for database-level filtering.
  """
  def get_blocked_user_ids(user) do
    from(ub in UserBlock,
      where: ub.blocker_id == ^user.id,
      select: ub.blocked_id
    )
    |> Repo.all()
  end

  # Helper function to add nested replies to a list of posts with block filtering
  # Defaults to loading 5 top-level replies per post for performance
  # Also adds total_reply_count for "Load more" functionality
  defp add_nested_replies_to_posts(posts, options) when is_list(posts) do
    reply_options = Map.put_new(options, :limit, 5)

    Enum.map(posts, fn post ->
      nested_replies = get_nested_replies_for_post(post.id, reply_options)
      total_reply_count = count_replies_for_post(post.id, options)

      post
      |> Map.put(:replies, nested_replies)
      |> Map.put(:total_reply_count, total_reply_count)
    end)
  end

  def get_post(id), do: adapter().get_post(id)

  def get_post_with_preloads(id), do: adapter().get_post_with_preloads(id)

  def get_user_post!(id), do: adapter().get_user_post!(id)

  def get_user_post_receipt!(id), do: adapter().get_user_post_receipt!(id)

  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    adapter().get_user_post_by_post_id_and_user_id!(post_id, user_id)
  end

  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    adapter().get_user_post_by_post_id_and_user_id(post_id, user_id)
  end

  def get_all_shared_posts(user_id), do: adapter().get_all_shared_posts(user_id)

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
    |> with_any_visibility([:private, :connections, :specific_groups, :specific_users])
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

    conn = Accounts.get_connection_from_item(post, user)

    {:ok, post}
    |> broadcast_admin(:post_created)

    {:ok, conn,
     post |> Repo.preload([:user_posts, :group, :user_group, :replies, :user_post_receipts])}
    |> broadcast(:post_created)
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
          |> Ecto.Multi.run(:process_url_preview_image, fn _repo, %{insert_post: post} ->
            process_url_preview_image_after_insert(post, p_attrs.temp_key)
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
        |> schedule_ephemeral_deletion_if_needed()
        |> broadcast_admin(:post_created)

        {:ok, conn,
         post |> Repo.preload([:user_posts, :group, :user_group, :replies, :user_post_receipts])}
        |> schedule_ephemeral_deletion_for_group_post()
        |> broadcast(:post_created)
      else
        case create_new_post(post, user, p_attrs, attrs) do
          # we create user_posts for everyone being shared with
          {:ok, %{insert_post: post, insert_user_post: _user_post_conn}} ->
            create_shared_user_posts(post, attrs, p_attrs, user)

            {:ok, post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])}
            |> schedule_ephemeral_deletion_if_needed()
            |> broadcast_admin(:post_created)

          {:error, :insert_post, changeset, _changes_so_far} ->
            {:error, changeset}

          {:error, _failed_op, changeset, _changes_so_far} ->
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
    |> Ecto.Multi.run(:process_url_preview_image, fn _repo, %{insert_post: post} ->
      process_url_preview_image_after_insert(post, p_attrs.temp_key)
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
    |> Ecto.Multi.insert(:inser_user_post_receipt, fn %{insert_user_post: user_post} ->
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

  defp process_url_preview_image_after_insert(post, post_key) do
    if post.url_preview && is_map(post.url_preview) && map_size(post.url_preview) > 0 do
      decrypted_preview =
        post.url_preview
        |> Enum.map(fn {key, value} ->
          decrypted_value =
            if is_binary(value) do
              case Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: value}) do
                {:ok, value} -> value
                _rest -> nil
              end
            else
              value
            end

          {key, decrypted_value}
        end)
        |> Enum.into(%{})

      original_image_url = decrypted_preview["original_image_url"]

      if original_image_url && original_image_url != "" do
        url_hash =
          :crypto.hash(:sha3_512, "#{original_image_url}-#{post.id}")
          |> Base.encode16(case: :lower)

        case Mosslet.Extensions.URLPreviewImageProxy.fetch_and_store_preview_image(
               original_image_url,
               url_hash,
               post_key,
               post.id
             ) do
          {:ok, tigris_presigned_url} ->
            updated_preview =
              decrypted_preview
              |> Map.put("image", tigris_presigned_url)
              |> Map.put("image_hash", url_hash)
              |> Map.delete("original_image_url")

            encrypted_preview =
              updated_preview
              |> Enum.map(fn {key, value} ->
                encrypted_value =
                  if is_binary(value) do
                    Mosslet.Encrypted.Utils.encrypt(%{key: post_key, payload: value})
                  else
                    value
                  end

                {key, encrypted_value}
              end)
              |> Enum.into(%{})

            post
            |> Ecto.Changeset.change(%{url_preview: encrypted_preview})
            |> Repo.update()

          {:error, _reason} ->
            updated_preview =
              decrypted_preview
              |> Map.put("image", nil)
              |> Map.delete("original_image_url")

            encrypted_preview =
              updated_preview
              |> Enum.map(fn {key, value} ->
                encrypted_value =
                  if is_binary(value) do
                    Mosslet.Encrypted.Utils.encrypt(%{key: post_key, payload: value})
                  else
                    value
                  end

                {key, encrypted_value}
              end)
              |> Enum.into(%{})

            post
            |> Ecto.Changeset.change(%{url_preview: encrypted_preview})
            |> Repo.update()
        end
      else
        {:ok, post}
      end
    else
      {:ok, post}
    end
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
          {:ok, %{insert_post: post, insert_user_post: _user_post}} ->
            # For public posts, we also need to create receipts for other users
            # But we don't need to create additional UserPost records
            post_with_associations =
              post |> Repo.preload([:user_posts, :replies, :user_post_receipts])

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

        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Ecto.Multi.insert(:insert_user_post_receipt, fn %{insert_user_post: user_post} ->
            UserPostReceipt.changeset(
              %UserPostReceipt{},
              %{
                user_id: user.id,
                user_post_id: user_post.id,
                is_read?: false,
                read_at: nil
              }
            )
            |> Ecto.Changeset.put_assoc(:user, user)
            |> Ecto.Changeset.put_assoc(:user_post, user_post)
          end)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies, :user_post_receipts])}
      |> broadcast(:post_reposted)
    else
      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies, :user_post_receipts])}
      |> broadcast(:post_reposted)
    end
  end

  @doc """
  Creates a targeted share - shares a post only with specifically selected connections.

  Unlike create_repost which broadcasts to all connections, this sends to selected users only.
  This promotes intentional, thoughtful sharing over viral broadcast patterns.
  """
  def create_targeted_share(attrs \\ %{}, opts \\ []) do
    post = Post.repost_changeset(%Post{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = post.changes.user_post_map

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
             visibility: :connections
           )
           |> Ecto.Changeset.put_assoc(:post, post)
           |> Ecto.Changeset.put_assoc(:user, user)
         end)
         |> Ecto.Multi.insert(:insert_user_post_receipt_creator, fn %{insert_user_post: user_post} ->
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
        create_targeted_share_user_posts(post, attrs, p_attrs, user)

      {:error, :insert_post, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_user_post, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error creating targeted share")
        Logger.debug("Error creating targeted share: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  defp create_targeted_share_user_posts(post, attrs, p_attrs, current_user) do
    if attrs.shared_users && !Enum.empty?(attrs.shared_users) do
      share_note = Map.get(attrs, :share_note) || Map.get(attrs, "share_note")

      for su <- attrs.shared_users do
        user = Mosslet.Accounts.get_user!(su.user_id || su[:user_id] || su["user_id"])

        user_post =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: p_attrs.temp_key,
              post_id: post.id,
              user_id: user.id,
              share_note: share_note
            },
            user: user,
            visibility: :connections,
            post_key: p_attrs.temp_key
          )

        {:ok, %{insert_user_post: _user_post}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post)
          |> Ecto.Multi.insert(:insert_user_post_receipt, fn %{insert_user_post: user_post} ->
            UserPostReceipt.changeset(
              %UserPostReceipt{},
              %{
                user_id: user.id,
                user_post_id: user_post.id,
                is_read?: false,
                read_at: nil
              }
            )
            |> Ecto.Changeset.put_assoc(:user, user)
            |> Ecto.Changeset.put_assoc(:user_post, user_post)
          end)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(post, current_user)

      {:ok, conn, post |> Repo.preload([:user_posts, :replies, :user_post_receipts])}
      |> broadcast(:post_shared)
    else
      {:error, "No recipients selected"}
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

        # FIXED: Add nested replies structure like get_post! does to maintain consistency
        post_with_preloads =
          post
          |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])

        nested_replies = get_nested_replies_for_post(post.id)
        post_with_nested_replies = Map.put(post_with_preloads, :replies, nested_replies)

        {:ok, conn, post_with_nested_replies}
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
          "There was an error update_post_shared_users/3 in Mosslet.Timeline #{inspect(changeset)}"
        )

        Logger.debug(inspect(changeset))
        {:error, changeset}
    end
  end

  def update_post_shared_users_without_validation(%Post{} = post, attrs, opts \\ []) do
    original_shared_user_ids = Enum.map(post.shared_users || [], & &1.user_id)
    new_shared_user_ids = Enum.map(attrs[:shared_users] || [], & &1[:user_id])
    added_user_ids = new_shared_user_ids -- original_shared_user_ids

    case Repo.transaction_on_primary(fn ->
           Post.change_post_remove_shared_user_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_post}} ->
        conn = Accounts.get_connection_from_item(updated_post, opts[:user])

        updated_post =
          updated_post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])

        Enum.each(added_user_ids, fn user_id ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{user_id}",
            {:post_created, updated_post}
          )
        end)

        Logger.debug(
          "Broadcasting :post_shared_users_added to conn_posts:#{updated_post.user_id}"
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_posts:#{updated_post.user_id}",
          {:post_shared_users_added, updated_post}
        )

        {:ok, conn, updated_post}

      {:ok, {:error, changeset}} ->
        Logger.error(
          "There was an error update_post_shared_users_without_validation/3 in Mosslet.Timeline #{inspect(changeset)}"
        )

        Logger.debug(inspect(changeset))
        {:error, changeset}
    end
  end

  def remove_post_shared_user(%Post{} = post, attrs, opts \\ []) do
    original_shared_user_ids = Enum.map(post.shared_users || [], & &1.user_id)
    new_shared_user_ids = Enum.map(attrs[:shared_users] || [], & &1[:user_id])
    removed_user_ids = original_shared_user_ids -- new_shared_user_ids

    case Repo.transaction_on_primary(fn ->
           Post.change_post_remove_shared_user_changeset(post, attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_post}} ->
        conn = Accounts.get_connection_from_item(updated_post, opts[:user])

        updated_post =
          updated_post |> Repo.preload([:user_posts, :user, :replies, :user_post_receipts])

        # broadcast to each removed user
        Enum.each(removed_user_ids, fn user_id ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_posts:#{user_id}",
            {:post_updated_user_removed, updated_post}
          )
        end)

        Logger.debug(
          "Broadcasting :post_shared_users_removed to conn_posts:#{updated_post.user_id}"
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_posts:#{updated_post.user_id}",
          {:post_shared_users_removed, updated_post}
        )

        {:ok, conn, updated_post}

      {:ok, {:error, changeset}} ->
        Logger.error(
          "There was an error remove_post_shared_user/3 in Mosslet.Timeline #{inspect(changeset)}"
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

    attrs = calculate_thread_depth(attrs)

    case Repo.transaction_on_primary(fn ->
           Reply.changeset(%Reply{}, attrs, opts)
           |> Repo.insert()
         end) do
      {:ok, {:ok, reply}} ->
        reply = reply |> Repo.preload([:user, :post, :parent_reply])
        conn = Accounts.get_connection_from_item(reply.post, user)

        update_post_last_reply_at(reply.post)

        maybe_queue_reply_notification(reply, user, opts[:key])
        maybe_enqueue_bluesky_reply_export(reply, user)

        {:ok, conn, reply}
        |> broadcast_reply(:reply_created)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  defp update_post_last_reply_at(post) do
    Repo.transaction_on_primary(fn ->
      from(p in Post, where: p.id == ^post.id)
      |> Repo.update_all(set: [last_reply_at: DateTime.utc_now()])
    end)
  end

  defp maybe_queue_reply_notification(reply, replier, session_key) do
    post_owner_id = reply.post.user_id

    if post_owner_id != replier.id && session_key do
      case GenServer.whereis(Mosslet.Notifications.ReplyNotificationsGenServer) do
        pid when is_pid(pid) ->
          Mosslet.Notifications.ReplyNotificationsGenServer.queue_reply_notification(
            post_owner_id,
            reply.id,
            replier.id,
            session_key
          )

        nil ->
          :ok
      end
    end
  end

  defp maybe_enqueue_bluesky_reply_export(reply, user) do
    post = reply.post

    if post.external_uri && post.external_cid do
      case Mosslet.Bluesky.get_account_for_user(user) do
        %{export_enabled: true} = account ->
          Mosslet.Bluesky.Workers.ExportSyncWorker.enqueue_single_reply_export(
            reply.id,
            account.id
          )

        _ ->
          :ok
      end
    else
      :ok
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

  @doc """
  Gets or creates a UserPost record for public posts when users interact with them.
  This allows any user to track read/unread status for public posts without pre-creating
  massive amounts of UserPost records for all users.
  """
  def get_or_create_user_post_for_public(post, user) do
    case get_user_post(post, user) do
      nil when post.visibility == :public ->
        # Create UserPost on-demand for public posts
        create_user_post_for_public_interaction(post, user)

      nil ->
        # Post is not public and user doesn't have access
        {:error, :no_access}

      existing_user_post ->
        # UserPost already exists
        {:ok, existing_user_post}
    end
  end

  defp create_user_post_for_public_interaction(post, user) do
    # Use the same key structure as the original post creator
    # For public posts, we can derive the key from the post itself
    original_user_post = get_public_user_post(post)

    if original_user_post do
      user_post_changeset =
        UserPost.changeset(
          %UserPost{},
          %{
            # Reuse the same key as the original post for public posts
            key: Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(original_user_post.key),
            user_id: user.id,
            post_id: post.id
          },
          user: user,
          visibility: :public
        )
        |> Ecto.Changeset.put_assoc(:post, post)
        |> Ecto.Changeset.put_assoc(:user, user)

      case Repo.transaction_on_primary(fn -> Repo.insert(user_post_changeset) end) do
        {:ok, {:ok, user_post}} ->
          preloaded_user_post = Repo.preload(user_post, [:post, :user, :user_post_receipt])
          {:ok, preloaded_user_post}

        {:ok, {:error, changeset}} ->
          {:error, changeset}

        error ->
          error
      end
    else
      {:error, :invalid_public_post}
    end
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

      # BEFORE deleting, get all reposts to broadcast individual deletions
      reposts_query =
        from(p in Post,
          where: p.original_post_id == ^post.id,
          preload: [:user_posts, :group, :user_group, :original_post]
        )

      reposts = Repo.all(reposts_query)

      query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

      post =
        Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

      case Repo.transaction_on_primary(fn ->
             Repo.delete_all(query)
           end) do
        {:ok, {:error, changeset}} ->
          {:error, changeset}

        {:ok, {_count, _posts}} ->
          Enum.each(reposts, fn repost ->
            repost_user = Accounts.get_user!(repost.user_id)
            repost_conn = Accounts.get_connection_from_item(repost, repost_user)

            cleanup_preview_image(repost.id)

            {:ok, repost_conn, repost}
            |> broadcast(:repost_deleted)
          end)

          cleanup_preview_image(post.id)
          maybe_delete_from_bluesky(post)

          {:ok, conn, post}
          |> broadcast(:post_deleted)

        rest ->
          Logger.warning("Error deleting post")
          Logger.debug("Error deleting post: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      # Handle deleting an ephemeral post from a job
      if opts[:user_id] && opts[:ephemeral] === true do
        user = Accounts.get_user!(opts[:user_id])
        conn = Accounts.get_connection_from_item(post, user)

        # BEFORE deleting, get all reposts to broadcast individual deletions
        reposts_query =
          from(p in Post,
            where: p.original_post_id == ^post.id,
            preload: [:user_posts, :group, :user_group, :original_post]
          )

        reposts = Repo.all(reposts_query)

        query = from(p in Post, where: p.id == ^post.id or p.original_post_id == ^post.id)

        post =
          Repo.preload(post, [:user_posts, :group, :user_group, :original_post])

        case Repo.transaction_on_primary(fn ->
               Repo.delete_all(query)
             end) do
          {:ok, {:error, changeset}} ->
            {:error, changeset}

          {:ok, {_count, _posts}} ->
            Enum.each(reposts, fn repost ->
              repost_user = Accounts.get_user!(repost.user_id)
              repost_conn = Accounts.get_connection_from_item(repost, repost_user)

              cleanup_preview_image(repost.id)

              {:ok, repost_conn, repost}
              |> broadcast(:repost_deleted)
            end)

            cleanup_preview_image(post.id)
            maybe_delete_from_bluesky(post)

            {:ok, conn, post}
            |> broadcast(:post_deleted)

          rest ->
            Logger.warning("Error deleting post")
            Logger.debug("Error deleting post: #{inspect(rest)}")
            {:error, "error"}
        end
      else
        {:error, "You do not have permission to delete this post."}
      end
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
            shared_user.user_id == user.id
          end)

        # convert list from structs to maps, preserving each user's own username
        shared_user_map_list =
          Enum.into(shared_user_structs, [], fn shared_user_struct ->
            Map.from_struct(shared_user_struct)
            |> Map.put(:sender_id, opts[:user].id)
          end)

        # call remove_post_shared_user to update the shared_users list
        remove_post_shared_user(
          post,
          %{
            shared_users: shared_user_map_list
          },
          user: opts[:user]
        )

      rest ->
        Logger.warning("Error deleting user_post")
        Logger.debug("Error deleting user_post: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  @doc """
  Removes the current user from a shared post (user removes themselves).

  This deletes the user's user_post record and removes them from shared_users,
  effectively removing the post from their timeline.

  ## Options
    * `:user` - The current user removing themselves (required)
  """
  def remove_self_from_shared_post(%UserPost{} = user_post, opts \\ []) do
    current_user = opts[:user]

    if user_post.user_id != current_user.id do
      {:error, "You can only remove yourself from posts"}
    else
      delete_user_bookmark_for_post(current_user.id, user_post.post_id)

      case Repo.transaction_on_primary(fn ->
             Repo.delete(user_post)
           end) do
        {:ok, {:error, changeset}} ->
          {:error, changeset}

        {:ok, {:ok, deleted_user_post}} ->
          post = get_post!(deleted_user_post.post_id)

          shared_user_structs =
            Enum.reject(post.shared_users || [], fn shared_user ->
              shared_user.user_id == current_user.id
            end)

          shared_user_map_list =
            Enum.into(shared_user_structs, [], fn shared_user_struct ->
              Map.from_struct(shared_user_struct)
              |> Map.put(:sender_id, post.user_id)
            end)

          remove_post_shared_user_for_self(
            post,
            %{
              shared_users: shared_user_map_list
            },
            user: current_user,
            removed_user: current_user
          )

        rest ->
          Logger.warning("Error removing self from shared post")
          Logger.debug("Error removing self from shared post: #{inspect(rest)}")
          {:error, "error"}
      end
    end
  end

  defp remove_post_shared_user_for_self(%Post{} = post, attrs, opts) do
    removed_user = opts[:removed_user]

    case adapter().remove_shared_user_and_add_to_removed(post, attrs, opts) do
      {:ok, updated_post} ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_posts:#{removed_user.id}",
          {:post_updated_user_removed, updated_post}
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_posts:#{updated_post.user_id}",
          {:post_shared_users_removed, updated_post}
        )

        {:ok, updated_post}

      {:error, changeset} ->
        Logger.error(
          "There was an error remove_post_shared_user_for_self/3 in Mosslet.Timeline #{inspect(changeset)}"
        )

        Logger.debug({inspect(changeset)})
        {:error, changeset}
    end
  end

  @doc """
  Shares an existing post with a single user by creating a user_post record.

  ## Options
    * `:user` - The current user who owns the post (required)
  """
  def share_post_with_user(%Post{} = post, user_to_share_with, decrypted_post_key, opts \\ []) do
    current_user = opts[:user]

    cond do
      post.user_id != current_user.id ->
        {:error, "You can only share your own posts"}

      get_user_post_by_post_id_and_user_id(post.id, user_to_share_with.id) != nil ->
        {:error, :already_shared}

      true ->
        user_post_changeset =
          UserPost.sharing_changeset(
            %UserPost{},
            %{
              key: decrypted_post_key,
              post_id: post.id,
              user_id: user_to_share_with.id
            },
            user: user_to_share_with,
            visibility: post.visibility
          )

        result =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_post, user_post_changeset)
          |> Ecto.Multi.insert(:insert_user_post_receipt, fn %{insert_user_post: user_post} ->
            UserPostReceipt.changeset(
              %UserPostReceipt{},
              %{
                user_id: user_to_share_with.id,
                user_post_id: user_post.id,
                is_read?: false,
                read_at: nil
              }
            )
            |> Ecto.Changeset.put_assoc(:user, user_to_share_with)
            |> Ecto.Changeset.put_assoc(:user_post, user_post)
          end)
          |> Repo.transaction_on_primary()

        case result do
          {:ok, %{insert_user_post: user_post}} ->
            new_shared_user = %Post.SharedUser{
              user_id: user_to_share_with.id,
              color: get_shared_user_color(user_to_share_with, current_user)
            }

            existing_shared_users = post.shared_users || []

            shared_user_map_list =
              (existing_shared_users ++ [new_shared_user])
              |> Enum.map(fn su ->
                Map.from_struct(su)
                |> Map.put(:sender_id, current_user.id)
              end)

            update_post_shared_users_without_validation(
              post,
              %{shared_users: shared_user_map_list},
              user: current_user
            )

            {:ok, user_post}

          {:error, _op, changeset, _changes} ->
            {:error, changeset}
        end
    end
  end

  defp get_shared_user_color(user_to_share_with, current_user) do
    case Accounts.get_user_connection_between_users(user_to_share_with.id, current_user.id) do
      %{color: color} when not is_nil(color) -> color
      _ -> :emerald
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
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "admin:moderation_reports")
    end
  end

  defp broadcast({:ok, conn, post}, event, _user_conn \\ %{}) do
    case post.visibility do
      :public ->
        public_broadcast({:ok, post}, event)

      :private ->
        private_broadcast({:ok, post}, event)

      :connections ->
        connections_broadcast({:ok, conn, post}, event)

      :specific_groups ->
        connections_broadcast({:ok, conn, post}, event)

      :specific_users ->
        connections_broadcast({:ok, conn, post}, event)
    end
  end

  defp broadcast_reply({:ok, conn, reply}, event, _user_conn \\ %{}) do
    case reply.visibility do
      :public -> public_reply_broadcast({:ok, reply}, event)
      :private -> private_reply_broadcast({:ok, reply}, event)
      :connections -> connections_reply_broadcast({:ok, conn, reply}, event)
      :specific_groups -> connections_reply_broadcast({:ok, conn, reply}, event)
      :specific_users -> connections_reply_broadcast({:ok, conn, reply}, event)
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
      cond do
        post.visibility in [:specific_groups, :specific_users] ->
          # For specific_groups and specific_users, broadcast to users in shared_users list AND the sender
          target_user_ids = Enum.map(post.shared_users, & &1.user_id)
          all_recipient_ids = [post.user_id | target_user_ids] |> Enum.uniq()

          Enum.each(all_recipient_ids, fn user_id ->
            Phoenix.PubSub.broadcast(
              Mosslet.PubSub,
              "conn_posts:#{user_id}",
              {event, post}
            )
          end)

        true ->
          all_recipient_ids =
            conn.user_connections
            |> Enum.flat_map(fn uconn -> [uconn.user_id, uconn.reverse_user_id] end)
            |> Enum.uniq()

          Enum.each(all_recipient_ids, fn user_id ->
            Phoenix.PubSub.broadcast(
              Mosslet.PubSub,
              "conn_posts:#{user_id}",
              {event, post}
            )
          end)
      end

      {:ok, post}
    else
      maybe_publish_group_post({event, post})
    end
  end

  defp connections_reply_broadcast({:ok, conn, reply}, event) do
    post = get_post!(reply.post_id)

    # we only broadcast to our connections if it's NOT a group post
    if is_nil(post.group_id) do
      cond do
        post.visibility in [:specific_groups, :specific_users] ->
          # For specific_groups and specific_users, broadcast to users in shared_users list AND the post author
          target_user_ids = Enum.map(post.shared_users, & &1.user_id)
          all_recipient_ids = [post.user_id | target_user_ids] |> Enum.uniq()

          Enum.each(all_recipient_ids, fn user_id ->
            Phoenix.PubSub.broadcast(
              Mosslet.PubSub,
              "conn_replies:#{user_id}",
              {event, post, reply}
            )
          end)

        true ->
          all_recipient_ids =
            conn.user_connections
            |> Enum.flat_map(fn uconn -> [uconn.user_id, uconn.reverse_user_id] end)
            |> Enum.uniq()

          Enum.each(all_recipient_ids, fn user_id ->
            Phoenix.PubSub.broadcast(
              Mosslet.PubSub,
              "conn_replies:#{user_id}",
              {event, post, reply}
            )
          end)
      end

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
    # Get the user_connection if post is a connection's post
    user_connection =
      if user.id != post.user_id && post.visibility != :public,
        do: Accounts.get_user_connection_between_users(post.user_id, user.id)

    attrs =
      if user_connection,
        do: attrs |> Map.put(:user_connection_id, user_connection.id),
        else: attrs

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
    adapter().list_user_bookmarks(user, opts)
  end

  @doc """
  Counts a user's bookmarks.
  """
  def count_user_bookmarks(user, filter_prefs \\ %{}) do
    adapter().count_user_bookmarks(user, filter_prefs)
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
    attrs = Map.put(attrs, :user_id, user.id)
    adapter().create_bookmark_category(attrs)
  end

  @doc """
  Updates a bookmark category.
  """
  def update_bookmark_category(category, attrs) do
    adapter().update_bookmark_category(category, attrs)
  end

  @doc """
  Deletes a bookmark category.
  Note: This will set category_id to nil for existing bookmarks.
  """
  def delete_bookmark_category(category) do
    adapter().delete_bookmark_category(category)
  end

  @doc """
  Gets all bookmark categories for a user.
  """
  def list_user_bookmark_categories(user) do
    adapter().list_bookmark_categories(user)
  end

  @doc """
  Gets a user's bookmark category by ID.
  """
  def get_user_bookmark_category(user, category_id) do
    Repo.get_by(BookmarkCategory, user_id: user.id, id: category_id)
  end

  ## Content Moderation Functions

  @doc """
  Updates a post report status (admin function).
  """
  def update_post_report(report, attrs, admin_user) do
    # Use admin_action_changeset for admin updates to properly track actions
    changeset =
      if Map.has_key?(attrs, "admin_action") or Map.has_key?(attrs, :admin_action) do
        # Add admin_user_id to attrs
        attrs_with_admin = Map.put(attrs, "admin_user_id", admin_user.id)
        PostReport.admin_action_changeset(report, attrs_with_admin)
      else
        # Use regular changeset for simple status updates
        PostReport.changeset(report, attrs)
      end

    case Repo.transaction_on_primary(fn ->
           Repo.update(changeset)
         end) do
      {:ok, {:ok, updated_report}} ->
        # Preload associations before broadcasting for admin dashboard
        updated_report_with_preloads =
          Repo.preload(updated_report, [
            :reporter,
            :reported_user,
            :post,
            :admin_user,
            :user_post_report
          ])

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "admin:moderation_reports",
          {:report_updated, updated_report_with_preloads}
        )

        {:ok, updated_report_with_preloads}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Counts all reports matching the given filters for admin review.
  """
  def count_post_reports(opts \\ []) do
    query = from r in PostReport, select: count(r.id)

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
      case opts[:report_type] do
        nil -> query
        report_type -> where(query, [r], r.report_type == ^report_type)
      end

    Repo.one(query)
  end

  @doc """
  Gets all reports for admin review.
  """
  def list_post_reports(opts \\ []) do
    limit = opts[:limit] || 10
    page = opts[:page] || 1
    offset = (page - 1) * limit

    query =
      from r in PostReport,
        preload: [:reporter, :reported_user, :post, :reply, :user_post_report],
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        offset: ^offset

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
      case opts[:report_type] do
        nil -> query
        report_type -> where(query, [r], r.report_type == ^report_type)
      end

    Repo.all(query)
  end

  @doc """
  Gets a single post report by ID for admin review.
  """
  def get_post_report(id) do
    PostReport
    |> where([r], r.id == ^id)
    |> preload([:reporter, :reported_user, :post])
    |> Repo.one()
  end

  @doc """
  Creates a post report with proper asymmetric encryption for admin review.

  Follows the same pattern as posts:
  1. Generate unique report_key
  2. Encrypt content with report_key
  3. Store report_key encrypted with server public key for admin access

  ## Examples

      iex> report_post(reporter, reported_user, post, %{
      ...>   "reason" => "harassment",
      ...>   "details" => "Threatening language",
      ...>   "report_type" => "harassment",
      ...>   "severity" => "high"
      ...> })
      {:ok, %PostReport{}}
  """
  def report_post(reporter, reported_user, post, attrs) do
    # Generate unique report key for this report context
    report_key = Mosslet.Encrypted.Utils.generate_key()

    attrs =
      attrs
      |> Map.put("reporter_id", reporter.id)
      |> Map.put("reported_user_id", reported_user.id)
      |> Map.put("post_id", post.id)

    case Repo.transaction_on_primary(fn ->
           Ecto.Multi.new()
           |> Ecto.Multi.insert(:insert_report, fn _ ->
             PostReport.changeset(
               %PostReport{},
               attrs,
               report_key: report_key
             )
           end)
           |> Ecto.Multi.insert(:insert_user_post_report, fn %{insert_report: report} ->
             UserPostReport.changeset(
               %UserPostReport{},
               %{"post_report_id" => report.id},
               report_key: report_key
             )
           end)
           |> Repo.transaction()
         end) do
      {:ok, {:ok, %{insert_report: report}}} ->
        # Preload associations before broadcasting for admin dashboard
        report_with_preloads =
          Repo.preload(report, [:reporter, :reported_user, :post, :user_post_report])

        # Broadcast to admin dashboard for real-time updates
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "admin:moderation_reports",
          {:report_created, report_with_preloads}
        )

        # Also broadcast to reporter for confirmation
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "user:#{reporter.id}",
          {:report_submitted, report_with_preloads}
        )

        {:ok, report_with_preloads}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
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
  Gets list of post IDs hidden by a user.
  """
  def list_hidden_post_ids(user) do
    from(h in PostHide,
      where: h.user_id == ^user.id,
      select: h.post_id
    )
    |> Repo.all()
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
  def get_user_timeline_preference(user) do
    Navigation.get_user_preferences(user)
  end

  @doc """
  Updates user timeline preferences.
  """
  def update_user_timeline_preference(user, attrs, opts \\ []) do
    Navigation.update_user_preferences(user, attrs, opts)
  end

  @doc """
  Creates a changeset for UserTimelinePreference.
  """
  def change_user_timeline_preference(
        preferences \\ %UserTimelinePreference{},
        attrs \\ %{},
        opts \\ []
      ) do
    UserTimelinePreference.changeset(preferences, attrs, opts)
  end

  @doc """
  Invalidates timeline cache when posts are created/updated/deleted.
  """
  def invalidate_timeline_cache_for_user(user_id, affecting_tabs \\ nil) do
    Navigation.invalidate_timeline_cache_for_user(user_id, affecting_tabs)
  end

  @doc """
  DEPRECATED: Application-level filtering has been moved to database level for better performance.
  All filtering is now done in queries using apply_database_filters/2.
  """
  def apply_content_filters(posts, _user, _filter_prefs) do
    # Return posts as-is since filtering is now done at database level
    posts
  end

  @doc """
  Checks if the user has active content filters.
  """
  def has_active_filters?(filter_prefs) when is_nil(filter_prefs), do: false

  def has_active_filters?(filter_prefs) do
    keywords_active = (filter_prefs[:keywords] || []) != []
    cw_active = Map.get(filter_prefs[:content_warnings] || %{}, :hide_all, false)
    users_active = (filter_prefs[:muted_users] || []) != []
    reposts_active = Map.get(filter_prefs, :hide_reposts, false)

    keywords_active || cw_active || users_active || reposts_active
  end

  @doc """
  Gets reporter statistics for admin review to detect abuse patterns.
  Updated to use new admin action tracking for more accurate scoring.
  """
  def get_reporter_statistics(reporter_id) do
    one_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -7, :day)

    # Get all reports by this reporter
    total_reports =
      from(r in PostReport, where: r.reporter_id == ^reporter_id)
      |> Repo.aggregate(:count)

    # Get recent reports (last 7 days)
    recent_reports =
      from(r in PostReport,
        where: r.reporter_id == ^reporter_id and r.inserted_at >= ^one_week_ago
      )
      |> Repo.aggregate(:count)

    # Calculate total score impact (includes new admin action scoring)
    total_score_impact =
      from(r in PostReport,
        where: r.reporter_id == ^reporter_id and not is_nil(r.reporter_score_impact),
        select: sum(r.reporter_score_impact)
      )
      |> Repo.one() || 0

    # Get dismissed reports for legacy compatibility
    dismissed_reports =
      from(r in PostReport,
        where: r.reporter_id == ^reporter_id and r.status == :dismissed
      )
      |> Repo.aggregate(:count)

    # Get content deletion successes (high-value reports)
    content_deleted_reports =
      from(r in PostReport,
        where:
          r.reporter_id == ^reporter_id and r.admin_action in [:content_deleted, :user_suspended]
      )
      |> Repo.aggregate(:count)

    # Calculate accuracy rate (considering admin actions)
    legitimate_reports = content_deleted_reports + max(0, total_reports - dismissed_reports)

    accuracy_rate =
      if total_reports > 0 do
        round(legitimate_reports / total_reports * 100)
      else
        100
      end

    # Calculate dismissal rate for legacy compatibility
    dismissal_rate =
      if total_reports > 0 do
        round(dismissed_reports / total_reports * 100)
      else
        0
      end

    # Enhanced flagging logic using score impact
    # Very negative score
    # High dismissal rate (legacy)
    suspicious? =
      (total_score_impact < -10 and total_reports > 5) or
        (dismissal_rate > 70 and total_reports > 5)

    stats = %{
      total_reports: total_reports,
      recent_reports: recent_reports,
      dismissed_reports: dismissed_reports,
      content_deleted_reports: content_deleted_reports,
      total_score_impact: total_score_impact,
      accuracy_rate: accuracy_rate,
      dismissal_rate: dismissal_rate,
      suspicious?: suspicious?
    }

    {:ok, stats}
  end

  @doc """
  Gets statistics for a reported user to help with moderation decisions.
  Updated to use new admin action tracking for more accurate risk assessment.
  """
  def get_reported_user_statistics(reported_user_id) do
    one_week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -7, :day)

    # Get all reports against this user
    total_reports_received =
      from(r in PostReport, where: r.reported_user_id == ^reported_user_id)
      |> Repo.aggregate(:count)

    # Get recent reports against this user (last 7 days)
    recent_reports_received =
      from(r in PostReport,
        where: r.reported_user_id == ^reported_user_id and r.inserted_at >= ^one_week_ago
      )
      |> Repo.aggregate(:count)

    # Calculate total score impact (includes new admin action scoring)
    total_score_impact =
      from(r in PostReport,
        where:
          r.reported_user_id == ^reported_user_id and not is_nil(r.reported_user_score_impact),
        select: sum(r.reported_user_score_impact)
      )
      |> Repo.one() || 0

    # Get content deletions against this user (serious violations)
    content_deleted_against =
      from(r in PostReport,
        where:
          r.reported_user_id == ^reported_user_id and
            r.admin_action in [:content_deleted, :user_suspended]
      )
      |> Repo.aggregate(:count)

    # Get resolved/confirmed violations for legacy compatibility
    confirmed_violations =
      from(r in PostReport,
        where: r.reported_user_id == ^reported_user_id and r.status == :resolved
      )
      |> Repo.aggregate(:count)

    # Get dismissed reports (false accusations)
    dismissed_reports =
      from(r in PostReport,
        where: r.reported_user_id == ^reported_user_id and r.status == :dismissed
      )
      |> Repo.aggregate(:count)

    # Calculate violation rate (confirmed violations / total reports)
    violation_rate =
      if total_reports_received > 0 do
        round(confirmed_violations / total_reports_received * 100)
      else
        0
      end

    # Calculate content deletion rate (more serious metric)
    content_deletion_rate =
      if total_reports_received > 0 do
        round(content_deleted_against / total_reports_received * 100)
      else
        0
      end

    # Enhanced risk assessment using score impact and content deletions
    # Very negative score
    # High deletion rate
    # Legacy high violation rate
    high_risk? =
      (total_score_impact < -15 and total_reports_received > 3) or
        (content_deletion_rate > 30 and total_reports_received > 2) or
        (violation_rate > 40 and total_reports_received > 3)

    stats = %{
      total_reports_received: total_reports_received,
      recent_reports_received: recent_reports_received,
      confirmed_violations: confirmed_violations,
      content_deleted_against: content_deleted_against,
      dismissed_reports: dismissed_reports,
      total_score_impact: total_score_impact,
      violation_rate: violation_rate,
      content_deletion_rate: content_deletion_rate,
      high_risk?: high_risk?
    }

    {:ok, stats}
  end

  # Ephemeral Post Management Functions
  # These functions support the EphemeralPostCleanupJob

  @doc """
  Get all expired ephemeral posts that need to be deleted.
  Returns posts where is_ephemeral = true and expires_at < current time.
  """
  def get_expired_ephemeral_posts(current_time \\ nil) do
    current_time = current_time || NaiveDateTime.utc_now()

    from(p in Post,
      where: p.is_ephemeral == true,
      where: not is_nil(p.expires_at),
      where: p.expires_at < ^current_time,
      order_by: [asc: p.expires_at]
    )
    |> Repo.all()
  end

  @doc """
  Get all ephemeral posts for a specific user.
  Used for user account cleanup.
  """
  def get_user_ephemeral_posts(user) do
    from(p in Post,
      where: p.user_id == ^user.id,
      where: p.is_ephemeral == true
    )
    |> Repo.all()
  end

  @doc """
  Delete all bookmarks for a specific post.
  Used during ephemeral post cleanup.
  """
  def delete_post_bookmarks(post_id) do
    Repo.transaction_on_primary(fn ->
      from(b in Bookmark,
        where: b.post_id == ^post_id
      )
      |> Repo.delete_all()
    end)
  end

  defp delete_user_bookmark_for_post(user_id, post_id) do
    Repo.transaction_on_primary(fn ->
      from(b in Bookmark,
        where: b.user_id == ^user_id and b.post_id == ^post_id
      )
      |> Repo.delete_all()
    end)
  end

  # Helper function to schedule ephemeral post deletion
  # Integrates with Oban to automatically delete ephemeral posts when they expire
  defp schedule_ephemeral_deletion_if_needed({:ok, post}) do
    if post.is_ephemeral && post.expires_at do
      # Schedule the post for automatic deletion at its expiration time
      case Mosslet.Timeline.Jobs.EphemeralPostCleanupJob.schedule_post_expiration(
             post.id,
             post.expires_at,
             post.user_id
           ) do
        {:ok, _job} ->
          Logger.info("Scheduled ephemeral post #{post.id} for deletion at #{post.expires_at}")

        {:error, reason} ->
          Logger.error(
            "Failed to schedule ephemeral post deletion for #{post.id}: #{inspect(reason)}"
          )
      end
    end

    {:ok, post}
  end

  # Helper function for group posts which return {:ok, conn, post}
  defp schedule_ephemeral_deletion_for_group_post({:ok, conn, post}) do
    {:ok, updated_post} = schedule_ephemeral_deletion_if_needed({:ok, post})
    {:ok, conn, updated_post}
  end

  defp cleanup_preview_image(post_id) do
    Mosslet.Timeline.Jobs.PreviewImageCleanupJob.schedule_cleanup(post_id)
  end

  defp maybe_delete_from_bluesky(%Post{} = post) do
    cond do
      post.bluesky_account_id && post.external_uri ->
        case Mosslet.Bluesky.get_account_for_user(post.user_id) do
          %{id: account_id, auto_delete_from_bsky: true}
          when account_id == post.bluesky_account_id ->
            Mosslet.Bluesky.Workers.DeleteSyncWorker.enqueue_delete_by_uri(
              post.external_uri,
              account_id
            )

          _ ->
            :ok
        end

      post.external_uri && post.source == :mosslet ->
        case Mosslet.Bluesky.get_account_for_user(post.user_id) do
          %{id: account_id, auto_delete_from_bsky: true} ->
            Mosslet.Bluesky.Workers.DeleteSyncWorker.enqueue_delete_by_uri(
              post.external_uri,
              account_id
            )

          _ ->
            :ok
        end

      true ->
        :ok
    end
  end

  # =============================================================================
  # Bluesky Sync Functions
  # =============================================================================

  @doc """
  Checks if a post with the given external URI already exists for a Bluesky account.
  Used to prevent duplicate imports.
  """
  def post_exists_by_external_uri?(uri, bluesky_account_id) do
    adapter().post_exists_by_external_uri?(uri, bluesky_account_id)
  end

  @doc """
  Gets a post by its external URI (e.g., Bluesky AT URI).
  Returns nil if not found.
  """
  def get_post_by_external_uri(uri, bluesky_account_id) do
    adapter().get_post_by_external_uri(uri, bluesky_account_id)
  end

  @doc """
  Creates a post imported from Bluesky.
  Uses the bluesky_import_changeset to properly set source and external references.
  """
  def create_bluesky_import_post(attrs, opts) do
    adapter().create_bluesky_import_post(attrs, opts)
  end

  @doc """
  Gets public posts from a user that haven't been synced to Bluesky yet.
  """
  def get_unexported_public_posts(user_id, limit \\ 10) do
    adapter().get_unexported_public_posts(user_id, limit)
  end

  @doc """
  Gets a post for export to Bluesky.
  Returns nil if the post is not exportable (not public, not from mosslet, etc).
  """
  def get_post_for_export(post_id) do
    adapter().get_post_for_export(post_id)
  end

  @doc """
  Marks a post as synced to Bluesky by storing the AT URI and CID.
  """
  def mark_post_as_synced_to_bluesky(post, uri, cid) do
    adapter().mark_post_as_synced_to_bluesky(post, uri, cid)
  end

  @doc """
  Clears Bluesky sync info from a post (after deletion from Bluesky).
  Keeps the post on Mosslet but removes the Bluesky reference.
  """
  def clear_bluesky_sync_info(post) do
    adapter().clear_bluesky_sync_info(post)
  end

  @doc """
  Marks a post's Bluesky link as unverified (deleted from Bluesky).
  Keeps the external_uri intact but hides the badge in the UI.
  """
  def mark_bluesky_link_unverified(post) do
    adapter().mark_bluesky_link_unverified(post)
  end

  @doc """
  Marks a post's Bluesky link as verified (exists on Bluesky).
  """
  def mark_bluesky_link_verified(post) do
    adapter().mark_bluesky_link_verified(post)
  end

  @doc """
  Decrypts a post body for export to Bluesky.
  """
  def decrypt_post_body(post, user, key) do
    case get_user_post_key_for_export(post, user, key) do
      {:ok, post_key} ->
        Mosslet.Encrypted.Utils.decrypt(%{key: post_key, payload: post.body})

      _ ->
        {:error, :decryption_failed}
    end
  end

  defp get_user_post_key_for_export(post, user, key) do
    user_post = Enum.find(post.user_posts, &(&1.user_id == user.id))

    if user_post do
      case post.visibility do
        :public ->
          {:ok, Mosslet.Encrypted.Users.Utils.decrypt_public_item_key(user_post.key)}

        _ ->
          Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user_post.key, user, key)
      end
    else
      {:error, :no_user_post}
    end
  end

  @doc """
  Gets a reply for export to Bluesky.
  Only returns public replies that haven't been synced yet.
  """
  def get_reply_for_export(reply_id) do
    adapter().get_reply_for_export(reply_id)
  end

  @doc """
  Marks a reply as synced to Bluesky with its URI, CID, and reply references.
  """
  def mark_reply_as_synced_to_bluesky(reply, uri, cid, reply_ref) do
    adapter().mark_reply_as_synced_to_bluesky(reply, uri, cid, reply_ref)
  end

  @doc """
  Decrypts a reply body for export to Bluesky.
  """
  def decrypt_reply_body(reply, user, key) do
    adapter().decrypt_reply_body(reply, user, key)
  end
end
