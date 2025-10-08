defmodule Mosslet.Timeline.Navigation do
  @moduledoc """
  Handles different timeline views and filtering.

  Provides tab-specific timeline data with caching and performance optimization.
  Integrates with existing post_key encryption architecture.
  """

  import Ecto.Query, warn: false
  alias Mosslet.{Accounts, Timeline, Groups, Repo}
  alias Mosslet.Timeline.{Post, UserTimelinePreference, TimelineViewCache}

  @default_tabs ["home", "connections", "groups", "bookmarks", "discover"]

  @doc """
  Gets timeline data for a specific tab with caching.
  """
  def get_timeline_data(user, tab, options \\ %{}) do
    # Check cache first
    case get_valid_timeline_cache(user.id, tab) do
      nil ->
        # Cache miss - fetch fresh data
        data = fetch_timeline_data(user, tab, options)

        # Cache the results
        if data[:posts] do
          post_count = length(data[:posts])
          last_post_at = if post_count > 0, do: List.first(data[:posts]).inserted_at, else: nil

          upsert_timeline_cache(user.id, tab, post_count, last_post_at)
        end

        data

      cached_data ->
        # Cache hit - return cached counts, fetch posts if needed
        %{
          posts: fetch_timeline_posts(user, tab, options),
          post_count: cached_data[:post_count],
          last_post_at: cached_data[:last_post_at],
          cached: true
        }
    end
  end

  @doc """
  Gets post counts for all timeline tabs efficiently.
  """
  def get_timeline_counts(user) do
    # Try to get from cache first
    cached_counts =
      for tab <- @default_tabs, into: %{} do
        count =
          case get_valid_timeline_cache(user.id, tab) do
            nil -> get_fresh_tab_count(user, tab)
            cached -> cached[:post_count] || 0
          end

        {String.to_existing_atom(tab), count}
      end

    cached_counts
  end

  @doc """
  Gets or creates user timeline preferences.
  """
  def get_user_preferences(user) do
    case Repo.get_by(UserTimelinePreference, user_id: user.id) do
      nil -> create_default_preferences(user)
      preferences -> preferences
    end
  end

  @doc """
  Updates user timeline preferences.
  """
  def update_user_preferences(user, attrs, opts \\ []) do
    preferences = get_user_preferences(user)

    case Repo.transaction_on_primary(fn ->
           preferences
           |> UserTimelinePreference.changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_preferences}} -> {:ok, updated_preferences}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Creates or updates cache entry for a user's timeline tab.
  """
  def upsert_timeline_cache(user_id, tab_name, post_count, last_post_at, cache_data \\ nil) do
    # Cache for 15 minutes
    cache_expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), 15, :minute)

    attrs = %{
      user_id: user_id,
      tab_name: tab_name,
      post_count: post_count,
      last_post_at: last_post_at,
      cache_expires_at: cache_expires_at,
      cache_data: cache_data && Jason.encode!(cache_data)
    }

    case Repo.transaction_on_primary(fn ->
           case Repo.get_by(TimelineViewCache, user_id: user_id, tab_name: tab_name) do
             nil ->
               # Create new cache entry
               %TimelineViewCache{}
               |> TimelineViewCache.changeset(attrs)
               |> Repo.insert()

             existing_cache ->
               # Update existing cache
               existing_cache
               |> TimelineViewCache.changeset(attrs)
               |> Repo.update()
           end
         end) do
      {:ok, {:ok, cache}} -> {:ok, cache}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Gets cached data for a user's timeline tab.
  Returns nil if cache is expired.
  """
  def get_valid_timeline_cache(user_id, tab_name) do
    now = NaiveDateTime.utc_now()

    case Repo.get_by(TimelineViewCache, user_id: user_id, tab_name: tab_name) do
      nil ->
        nil

      cache ->
        if cache.cache_expires_at && NaiveDateTime.compare(cache.cache_expires_at, now) == :gt do
          # Cache is still valid
          cache_data =
            if cache.cache_data do
              case Jason.decode(cache.cache_data) do
                {:ok, data} -> data
                _ -> nil
              end
            else
              nil
            end

          %{
            post_count: cache.post_count,
            last_post_at: cache.last_post_at,
            cache_data: cache_data
          }
        else
          # Cache expired
          nil
        end
    end
  end

  @doc """
  Invalidates cache for a specific user and tab.
  """
  def invalidate_timeline_cache(user_id, tab_name) do
    case Repo.transaction_on_primary(fn ->
           from(c in TimelineViewCache,
             where: c.user_id == ^user_id and c.tab_name == ^tab_name
           )
           |> Repo.delete_all()
         end) do
      {:ok, {count, _}} when count > 0 -> :ok
      _ -> :ok
    end
  end

  @doc """
  Cleans up expired cache entries.
  Should be called by background job.
  """
  def cleanup_expired_timeline_cache() do
    now = NaiveDateTime.utc_now()

    case Repo.transaction_on_primary(fn ->
           from(c in TimelineViewCache,
             where: not is_nil(c.cache_expires_at) and c.cache_expires_at <= ^now
           )
           |> Repo.delete_all()
         end) do
      {:ok, {count, _}} -> {:ok, count}
      error -> error
    end
  end

  # Private functions

  defp fetch_timeline_data(user, tab, options) do
    case tab do
      "home" -> get_home_timeline(user, options)
      "connections" -> get_connections_timeline(user, options)
      "groups" -> get_groups_timeline(user, options)
      "bookmarks" -> get_bookmarks_timeline(user, options)
      "discover" -> get_discover_timeline(user, options)
      _ -> get_home_timeline(user, options)
    end
  end

  defp fetch_timeline_posts(user, tab, options) do
    data = fetch_timeline_data(user, tab, options)
    data[:posts] || []
  end

  defp get_fresh_tab_count(user, tab) do
    case tab do
      "home" -> Timeline.timeline_post_count(user, %{filter: %{user_id: "", post_per_page: 25}})
      "connections" -> count_connections_posts(user)
      "groups" -> count_groups_posts(user)
      "bookmarks" -> Timeline.count_user_bookmarks(user)
      # Always fresh/dynamic
      "discover" -> 0
      _ -> 0
    end
  end

  defp get_home_timeline(user, options) do
    # Your existing timeline logic - all posts user has access to
    posts = Timeline.filter_timeline_posts(user, options)
    count = Timeline.timeline_post_count(user, options)

    %{posts: posts, post_count: count, tab: "home"}
  end

  defp get_connections_timeline(user, options) do
    # Only posts from direct connections
    posts = Timeline.filter_timeline_posts(user, Map.put(options, :connections_only, true))
    count = count_connections_posts(user)

    %{posts: posts, post_count: count, tab: "connections"}
  end

  defp get_groups_timeline(user, options) do
    # Only posts from groups user belongs to
    posts = Timeline.filter_timeline_posts(user, Map.put(options, :groups_only, true))
    count = count_groups_posts(user)

    %{posts: posts, post_count: count, tab: "groups"}
  end

  defp get_bookmarks_timeline(user, options) do
    # User's bookmarked posts
    bookmarked_posts = Timeline.list_user_bookmarks(user, options)
    # Convert bookmarks to posts structure
    posts = Enum.map(bookmarked_posts, & &1.post)
    count = Timeline.count_user_bookmarks(user)

    %{posts: posts, post_count: count, tab: "bookmarks"}
  end

  defp get_discover_timeline(user, options) do
    # Public posts, trending content, suggested connections
    posts = Timeline.filter_timeline_posts(user, Map.put(options, :discover_mode, true))

    %{posts: posts, post_count: length(posts), tab: "discover"}
  end

  defp count_connections_posts(user) do
    # Count posts from confirmed connections only
    from(p in Post,
      inner_join: up in Timeline.UserPost,
      on: up.post_id == p.id,
      inner_join: uc in Accounts.UserConnection,
      on: uc.reverse_user_id == p.user_id and uc.user_id == ^user.id,
      where: up.user_id == ^user.id and not is_nil(uc.confirmed_at),
      select: count(p.id)
    )
    |> Repo.one() || 0
  end

  defp count_groups_posts(user) do
    # Count posts from groups user belongs to
    from(p in Post,
      inner_join: ug in Groups.UserGroup,
      on: ug.group_id == p.group_id,
      where: ug.user_id == ^user.id and not is_nil(ug.confirmed_at),
      select: count(p.id)
    )
    |> Repo.one() || 0
  end

  defp create_default_preferences(user) do
    case Repo.transaction_on_primary(fn ->
           %UserTimelinePreference{}
           |> UserTimelinePreference.changeset(%{user_id: user.id})
           |> Repo.insert()
         end) do
      {:ok, {:ok, preferences}} -> preferences
      _ -> nil
    end
  end

  # defp maybe_hide_reposts(query, hide_reposts) do
  #   if hide_reposts do
  #     from(p in query, where: p.repost == false)
  #   else
  #     query
  #   end
  # end

  # defp maybe_hide_mature_content(query, hide_mature) do
  #   if hide_mature do
  #     from(p in query, where: p.mature_content == false)
  #   else
  #     query
  #   end
  # end

  # defp apply_mute_keyword_filters(query, _user, _preferences) do
  #   # For now, just return the query
  #   # TODO: Implement keyword filtering when mute_keywords is used
  #   # Would need to decrypt keywords and filter post content
  #   query
  # end

  @doc """
  Invalidates timeline cache when new posts are created.
  """
  def invalidate_timeline_cache_for_user(user_id, affecting_tabs \\ @default_tabs) do
    for tab <- affecting_tabs do
      invalidate_timeline_cache(user_id, tab)
    end

    :ok
  end
end
