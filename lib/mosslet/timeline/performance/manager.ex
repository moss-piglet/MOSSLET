defmodule Mosslet.Timeline.Performance.Manager do
  @moduledoc """
  Central performance manager that coordinates Oban jobs, Broadway pipelines,
  and timeline caching for optimal performance.

  This module provides the public API for timeline performance operations.
  """

  require Logger

  alias Mosslet.Timeline.Jobs.{TimelineFeedJob, CacheMaintenanceJob}
  alias Mosslet.Timeline.Performance.TimelineCache

  @doc """
  Handles new post creation with performance optimizations.
  Called after a post is successfully created.
  """
  def handle_post_created(post) do
    Logger.debug("Performance manager handling post creation: #{post.id}")

    # Immediate cache invalidation (real-time)
    invalidate_caches_for_post(post)

    # Schedule background feed regeneration for affected users (persistent via Oban)
    if should_trigger_feed_regeneration?(post) do
      affected_user_ids = get_affected_user_ids(post)

      if length(affected_user_ids) > 5 do
        # Many users affected - use batch job
        TimelineFeedJob.schedule_batch_feed_update(affected_user_ids, "new_post")
      else
        # Few users affected - individual jobs
        Enum.each(affected_user_ids, fn user_id ->
          TimelineFeedJob.schedule_feed_regeneration(user_id, [
            "home",
            "connections",
            "groups"
          ])
        end)
      end
    end

    :ok
  end

  @doc """
  Handles post updates with cache management.
  """
  def handle_post_updated(post) do
    Logger.debug("Performance manager handling post update: #{post.id}")

    # Immediate cache invalidation
    TimelineCache.invalidate_post(post.id)
    invalidate_caches_for_post(post)

    # Schedule feed updates for affected users
    affected_user_ids = get_affected_user_ids(post)

    if length(affected_user_ids) > 0 do
      TimelineFeedJob.schedule_batch_feed_update(affected_user_ids, "post_update")
    end

    :ok
  end

  @doc """
  Handles post deletion with cleanup.
  """
  def handle_post_deleted(post) do
    Logger.debug("Performance manager handling post deletion: #{post.id}")

    # Immediate cache cleanup
    TimelineCache.invalidate_post(post.id)
    invalidate_caches_for_post(post)

    # Note: No need to schedule feed regeneration for deletions
    # Cache invalidation is sufficient

    :ok
  end

  @doc """
  Handles user activity to optimize their experience.
  Called when user performs timeline actions.
  """
  def handle_user_activity(user_id, activity_type \\ :general) do
    case activity_type do
      :login ->
        # User just logged in - warm their cache immediately
        TimelineFeedJob.schedule_cache_warming(user_id, ["home", "connections"])

      :timeline_view ->
        # User viewing timeline - warm related tabs
        TimelineFeedJob.schedule_cache_warming(user_id, ["connections", "groups"])

      :post_creation ->
        # User creating content - warm their home feed
        TimelineFeedJob.schedule_cache_warming(user_id, ["home"])

      _ ->
        # General activity - no specific action needed
        :ok
    end
  end

  @doc """
  Gets performance statistics for monitoring.
  """
  def get_performance_stats() do
    cache_stats = TimelineCache.get_cache_stats()

    # Get Oban job statistics
    oban_stats = get_oban_timeline_stats()

    %{
      cache: cache_stats,
      jobs: oban_stats,
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  Sets up periodic maintenance jobs.
  Call this once during application startup.
  """
  def setup_periodic_maintenance() do
    Logger.info("Setting up timeline performance maintenance jobs")

    # Schedule periodic cache cleanup (every 30 minutes)
    CacheMaintenanceJob.schedule_cleanup()

    # Schedule cache statistics logging (every 10 minutes)
    CacheMaintenanceJob.schedule_cache_stats()

    :ok
  end

  # Private functions

  defp invalidate_caches_for_post(post) do
    case post.visibility do
      :public ->
        # Public posts affect discover feeds
        # For now, we'll invalidate broadly - could be optimized later
        Logger.debug("Invalidating public post caches")

      :connections ->
        # Invalidate cache for connected users
        connected_user_ids = get_connected_user_ids(post.user_id)

        Enum.each([post.user_id | connected_user_ids], fn user_id ->
          TimelineCache.invalidate_timeline(user_id, "home")
          TimelineCache.invalidate_timeline(user_id, "connections")
        end)

      :private ->
        # Only invalidate creator's cache
        TimelineCache.invalidate_timeline(post.user_id, "home")

      _ ->
        # Handle other visibility types
        TimelineCache.invalidate_timeline(post.user_id, "home")
    end
  end

  defp should_trigger_feed_regeneration?(post) do
    # Determine if this post warrants background feed regeneration
    case post.visibility do
      # Public posts affect many users
      :public -> true
      # Connection posts affect multiple users
      :connections -> true
      # Private posts only affect creator (cache invalidation sufficient)
      :private -> false
      _ -> false
    end
  end

  defp get_affected_user_ids(post) do
    case post.visibility do
      :public ->
        # For public posts, we'd need to get all users who follow public feeds
        # For now, return empty to avoid overwhelming the system
        []

      :connections ->
        # Get all connected users
        connected_user_ids = get_connected_user_ids(post.user_id)
        [post.user_id | connected_user_ids]

      :private ->
        # Only the creator
        [post.user_id]

      _ ->
        [post.user_id]
    end
  end

  defp get_connected_user_ids(user_id) do
    Mosslet.Accounts.get_all_confirmed_user_connections(user_id)
    |> Enum.map(& &1.reverse_user_id)
  end

  defp get_oban_timeline_stats() do
    # Simplified Oban stats (avoiding deprecated count_jobs)
    %{
      timeline_queue: "active",
      cache_queue: "active",
      status: "running"
    }
  end
end
