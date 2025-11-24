defmodule Mosslet.Timeline.Performance.TimelineCache do
  @moduledoc """
  High-performance ETS-based caching for timeline data.

  Separate from existing avatar cache to avoid conflicts.
  Caches encrypted timeline data and metadata without compromising security.
  Integrates with PubSub for real-time cache invalidation.
  """

  use GenServer
  require Logger

  @table_name :mosslet_timeline_cache
  # 5 minutes in milliseconds
  @cache_ttl 300_000

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Cache timeline data for a user's specific tab.
  Stores encrypted data safely.
  """
  def cache_timeline_data(user_id, tab, data) do
    key = "timeline:#{user_id}:#{tab}"
    expires_at = System.system_time(:millisecond) + @cache_ttl

    cache_entry = %{
      data: data,
      expires_at: expires_at,
      cached_at: System.system_time(:millisecond)
    }

    :ets.insert(@table_name, {key, cache_entry})

    :ok
  end

  @doc """
  Get cached timeline data if still valid.
  Returns {:hit, data} or :miss
  """
  def get_timeline_data(user_id, tab) do
    key = "timeline:#{user_id}:#{tab}"
    now = System.system_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, %{expires_at: expires_at} = entry}] when expires_at > now ->
        {:hit, entry.data}

      [{^key, _expired}] ->
        :ets.delete(@table_name, key)
        :miss

      [] ->
        :miss
    end
  end

  @doc """
  Cache individual post data (encrypted).
  Useful for frequently accessed posts.
  """
  def cache_post_data(post_id, encrypted_data, metadata \\ %{}) do
    key = "post:#{post_id}"
    expires_at = System.system_time(:millisecond) + @cache_ttl

    cache_entry = %{
      encrypted_data: encrypted_data,
      metadata: metadata,
      expires_at: expires_at
    }

    :ets.insert(@table_name, {key, cache_entry})
    :ok
  end

  @doc """
  Get cached post data if valid.
  """
  def get_post_data(post_id) do
    key = "post:#{post_id}"
    now = System.system_time(:millisecond)

    case :ets.lookup(@table_name, key) do
      [{^key, %{expires_at: expires_at} = entry}] when expires_at > now ->
        {:hit, entry}

      [{^key, _expired}] ->
        :ets.delete(@table_name, key)
        :miss

      [] ->
        :miss
    end
  end

  @doc """
  Invalidate timeline cache for user (all tabs or specific tab).
  """
  def invalidate_timeline(user_id, tab \\ :all) do
    if tab == :all do
      # Invalidate all tabs for user
      pattern = "timeline:#{user_id}:"
      invalidate_keys_with_prefix(pattern)
    else
      # Invalidate specific tab
      key = "timeline:#{user_id}:#{tab}"
      :ets.delete(@table_name, key)
    end
  end

  @doc """
  Invalidate cached post data.
  """
  def invalidate_post(post_id) do
    key = "post:#{post_id}"
    :ets.delete(@table_name, key)
  end

  @doc """
  Get cache statistics for monitoring.
  """
  def get_cache_stats() do
    info = :ets.info(@table_name)

    %{
      size: info[:size] || 0,
      memory: info[:memory] || 0,
      table_name: @table_name,
      ttl_seconds: div(@cache_ttl, 1000)
    }
  end

  ## GenServer Implementation

  def init(_opts) do
    # Create separate ETS table for timeline caching (won't conflict with avatar cache)
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ])

    # Subscribe to timeline events for cache invalidation
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "posts")
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "replies")
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "timeline_cache")

    # Subscribe to user-specific events for targeted invalidation
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "users")

    # Subscribe to Presence events for privacy-first active user tracking
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "timeline_cache_presence")

    # Subscribe to recently active users' private post and reply topics for cache invalidation
    subscribe_to_active_users_private_topics()
    subscribe_to_active_users_reply_topics()

    # Subscribe to all user-specific private post topics for cache invalidation
    # We'll dynamically subscribe to "priv_posts:#{user_id}" when users are active
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "private_posts_cache")

    Logger.info("Timeline cache started with table: #{table}")

    # Schedule periodic cleanup
    schedule_cleanup()

    {:ok, %{table: table}}
  end

  # Handle post updates - invalidate specific post and related timelines
  def handle_info({:post_updated, post}, state) do
    # Invalidate specific post cache
    invalidate_post(post.id)

    # Invalidate timeline caches for affected users
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle post deletion - immediate cache removal
  def handle_info({:post_deleted, post}, state) do
    # Remove from all caches immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle likes/favs - invalidate post cache AND timeline cache for updated counts
  def handle_info({:post_updated_fav, post}, state) do
    # Invalidate post cache so new like count shows immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle reposts - invalidate post cache AND timeline cache for updated counts
  def handle_info({:post_reposted, post}, state) do
    # Invalidate post cache so new repost count shows immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle bookmark changes
  def handle_info({:bookmark_created, bookmark}, state) do
    # Invalidate bookmarks timeline for user
    invalidate_timeline(bookmark.user_id, "bookmarks")

    {:noreply, state}
  end

  def handle_info({:bookmark_deleted, bookmark}, state) do
    # Invalidate bookmarks timeline for user
    invalidate_timeline(bookmark.user_id, "bookmarks")

    {:noreply, state}
  end

  # Handle reply creation - invalidate timelines since reply counts changed
  def handle_info({:reply_created, post, _reply}, state) do
    # Invalidate post cache and timelines so new reply count shows immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle reply updates
  def handle_info({:reply_updated, post, _reply}, state) do
    # Invalidate post cache so changes show immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle reply deletion
  def handle_info({:reply_deleted, post, _reply}, state) do
    # Invalidate post cache and timelines so updated reply count shows immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle reply favorites
  def handle_info({:reply_updated_fav, post, _reply}, state) do
    # Invalidate post cache so reply changes show immediately
    invalidate_post(post.id)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Periodic cleanup of expired entries
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    expired_count = cleanup_expired_entries(now)

    if expired_count > 0 do
      Logger.info("Cleaned up #{expired_count} expired timeline cache entries")
    end

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, state}
  end

  # Handle private post events - these come on user-specific topics
  def handle_info({:post_created, post}, state) when is_map(post) do
    # This handles both public posts (from "posts" topic) and private posts (from "priv_posts:user_id" topics)
    invalidate_timelines_for_post(post)

    {:noreply, state}
  end

  # Handle user joining timeline (via Presence) - subscribe to their topics
  def handle_info({:user_joined_timeline, user_id}, state) do
    # Subscribe to their private posts
    private_topic = "priv_posts:#{user_id}"
    Phoenix.PubSub.subscribe(Mosslet.PubSub, private_topic)

    # Subscribe to their connections posts
    connections_topic = "conn_posts:#{user_id}"
    Phoenix.PubSub.subscribe(Mosslet.PubSub, connections_topic)

    # Subscribe to their reply topics
    private_reply_topic = "priv_replies:#{user_id}"
    Phoenix.PubSub.subscribe(Mosslet.PubSub, private_reply_topic)

    connections_reply_topic = "conn_replies:#{user_id}"
    Phoenix.PubSub.subscribe(Mosslet.PubSub, connections_reply_topic)

    Logger.info("Timeline cache now tracking active user for cache optimization")

    {:noreply, state}
  end

  # Catch-all for unknown events
  def handle_info(msg, state) do
    Logger.debug("Timeline cache received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end

  ## Private Functions

  # Subscribe to private post topics for recently active users
  # PRIVACY: Uses Presence-based activity tracking (privacy-first)
  defp subscribe_to_active_users_private_topics() do
    # Get users active on timeline (privacy-first approach via Presence)
    active_user_ids = MossletWeb.Presence.get_active_timeline_user_ids()

    # Also include recently posted users for better cache coverage
    recently_active_users = Mosslet.Timeline.get_recently_active_users(60, 30)
    recently_active_user_ids = Enum.map(recently_active_users, & &1.id)

    # Combine both for optimal cache subscriptions
    all_active_user_ids = (active_user_ids ++ recently_active_user_ids) |> Enum.uniq()

    Enum.each(all_active_user_ids, fn user_id ->
      # Subscribe to private posts
      private_topic = "priv_posts:#{user_id}"
      Phoenix.PubSub.subscribe(Mosslet.PubSub, private_topic)

      # Subscribe to connections posts
      connections_topic = "conn_posts:#{user_id}"
      Phoenix.PubSub.subscribe(Mosslet.PubSub, connections_topic)
    end)

    Logger.info(
      "Timeline cache subscribed to #{length(all_active_user_ids)} active users' private and connections post topics (presence + recent activity)"
    )
  end

  # Subscribe to reply topics for recently active users
  defp subscribe_to_active_users_reply_topics() do
    # Get recently active users (those who posted in the last hour)
    recently_active_users = Mosslet.Timeline.get_recently_active_users(60, 50)

    Enum.each(recently_active_users, fn user ->
      # Subscribe to private replies
      private_reply_topic = "priv_replies:#{user.id}"
      Phoenix.PubSub.subscribe(Mosslet.PubSub, private_reply_topic)

      # Subscribe to connections replies
      connections_reply_topic = "conn_replies:#{user.id}"
      Phoenix.PubSub.subscribe(Mosslet.PubSub, connections_reply_topic)
    end)

    Logger.info(
      "Timeline cache subscribed to #{length(recently_active_users)} active users' reply topics"
    )
  end

  defp invalidate_timelines_for_post(post) do
    cond do
      post.visibility === :public ->
        # Invalidate discover timelines (public posts affect discover feed)
        invalidate_keys_with_prefix("timeline:")

      post.visibility in [:connections, :specific_users] ->
        # Invalidate home/connections timelines for connected users
        connected_user_ids = get_connected_user_ids(post.user_id)

        for user_id <- [post.user_id | connected_user_ids] do
          invalidate_timeline(user_id, "home")
          invalidate_timeline(user_id, "connections")
        end

      post.visibility === :specific_groups ->
        # Invalidate home/connections timelines for connected users
        connected_user_ids = get_connected_user_ids(post.user_id)

        for user_id <- [post.user_id | connected_user_ids] do
          invalidate_timeline(user_id, "home")
          invalidate_timeline(user_id, "groups")
        end

      post.visibility === :private ->
        # Only invalidate creator's timelines
        invalidate_timeline(post.user_id, "home")

      true ->
        # Handle other visibility types
        invalidate_timeline(post.user_id, "home")
    end
  end

  defp invalidate_keys_with_prefix(prefix) do
    # Find all keys that start with prefix and delete them
    :ets.foldl(
      fn {key, _value}, acc when is_binary(key) ->
        if String.starts_with?(key, prefix) do
          :ets.delete(@table_name, key)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
  end

  defp get_connected_user_ids(user_id) do
    # Get confirmed connections for cache invalidation
    Mosslet.Accounts.get_all_confirmed_user_connections(user_id)
    |> Enum.map(& &1.reverse_user_id)
  end

  defp schedule_cleanup() do
    # Clean up expired entries every 10 minutes
    Process.send_after(self(), :cleanup, 600_000)
  end

  defp cleanup_expired_entries(now) do
    :ets.foldl(
      fn {key, %{expires_at: expires_at}}, acc ->
        if expires_at <= now do
          :ets.delete(@table_name, key)
          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
  end
end
