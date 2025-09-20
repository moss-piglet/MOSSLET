defmodule Mosslet.Timeline.Jobs.CacheMaintenanceJob do
  @moduledoc """
  Oban job for timeline cache maintenance and optimization.

  Handles periodic tasks:
  - Cleanup expired cache entries
  - Optimize cache performance
  - Monitor cache statistics
  - Preemptive cache warming for active users
  """

  use Oban.Worker, queue: :cache_maintenance, max_attempts: 2
  require Logger

  alias Mosslet.Timeline.Performance.TimelineCache
  alias Mosslet.Timeline

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action} = args}) do
    case action do
      "cleanup_expired" ->
        cleanup_expired_entries(args)

      "warm_active_users" ->
        warm_active_users_cache(args)

      "optimize_cache" ->
        optimize_cache_performance(args)

      "cache_stats" ->
        log_cache_statistics(args)

      _ ->
        Logger.warning("Unknown cache maintenance action: #{action}")
        {:error, "Unknown action"}
    end
  end

  # Public API for scheduling maintenance

  @doc """
  Schedules periodic cache cleanup.
  Should be called every 30 minutes via cron.
  """
  def schedule_cleanup() do
    %{
      "action" => "cleanup_expired",
      "cleanup_type" => "expired_entries"
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end

  @doc """
  Schedules cache warming for recently active users.
  Should be called every 15 minutes during peak hours.
  """
  def schedule_active_user_warming() do
    %{
      "action" => "warm_active_users",
      "time_window_minutes" => 30,
      "max_users" => 100
    }
    |> __MODULE__.new(priority: 1)
    |> Oban.insert()
  end

  @doc """
  Schedules cache optimization.
  Should be called every hour during low-traffic periods.
  """
  def schedule_cache_optimization() do
    %{
      "action" => "optimize_cache",
      "optimization_type" => "memory_cleanup"
    }
    |> __MODULE__.new(priority: 2)
    |> Oban.insert()
  end

  @doc """
  Schedules cache statistics logging.
  Should be called every 10 minutes for monitoring.
  """
  def schedule_cache_stats() do
    %{
      "action" => "cache_stats",
      "include_details" => false
    }
    |> __MODULE__.new(priority: 3)
    |> Oban.insert()
  end

  # Job implementations

  defp cleanup_expired_entries(_args) do
    Logger.info("Starting timeline cache cleanup")

    start_time = System.monotonic_time(:millisecond)

    # Get cache stats before cleanup
    %{size: before_size, memory: before_memory} = TimelineCache.get_cache_stats()

    # Trigger cleanup in the cache GenServer
    send(Mosslet.Timeline.Performance.TimelineCache, :cleanup)

    # Wait a moment for cleanup to complete
    Process.sleep(1000)

    # Get stats after cleanup  
    %{size: after_size, memory: after_memory} = TimelineCache.get_cache_stats()

    end_time = System.monotonic_time(:millisecond)
    cleanup_time = end_time - start_time

    cleaned_entries = before_size - after_size
    memory_freed = before_memory - after_memory

    Logger.info(
      "Cache cleanup completed in #{cleanup_time}ms: #{cleaned_entries} entries removed, #{memory_freed} words freed"
    )

    :ok
  end

  defp warm_active_users_cache(%{"time_window_minutes" => window, "max_users" => max_users}) do
    Logger.info("Warming cache for active users (last #{window} minutes, max #{max_users})")

    # Get recently active users from Timeline context (proper separation of concerns)
    active_users = Timeline.get_recently_active_users(window, max_users)

    if length(active_users) > 0 do
      # Warm cache for active users in small batches
      active_users
      |> Enum.chunk_every(10)
      |> Task.async_stream(
        fn user_batch ->
          warm_user_batch_cache(user_batch)
        end,
        timeout: 30_000,
        max_concurrency: 3
      )
      |> Stream.run()

      Logger.info("Cache warming completed for #{length(active_users)} active users")
    else
      Logger.debug("No recently active users found for cache warming")
    end

    :ok
  end

  defp optimize_cache_performance(%{"optimization_type" => opt_type}) do
    Logger.info("Running cache optimization: #{opt_type}")

    case opt_type do
      "memory_cleanup" ->
        # Force garbage collection on the cache process
        Process.send(Mosslet.Timeline.Performance.TimelineCache, :cleanup, [])

        # Log memory usage before/after
        %{memory: before_memory} = TimelineCache.get_cache_stats()

        # Force GC
        :erlang.garbage_collect(Process.whereis(Mosslet.Timeline.Performance.TimelineCache))

        # Wait for cleanup
        Process.sleep(2000)

        %{memory: after_memory} = TimelineCache.get_cache_stats()
        memory_freed = before_memory - after_memory

        Logger.info("Cache optimization completed: #{memory_freed} words freed")

      _ ->
        Logger.debug("Unknown optimization type: #{opt_type}")
    end

    :ok
  end

  defp log_cache_statistics(%{"include_details" => include_details}) do
    stats = TimelineCache.get_cache_stats()

    Logger.info(
      "Timeline Cache Stats: #{stats.size} entries, #{stats.memory} words, TTL: #{stats.ttl_seconds}s"
    )

    if include_details do
      # Log additional details for monitoring
      Logger.info("Cache table: #{stats.table_name}")
    end

    # Could send to external monitoring service here
    # Sentry.capture_message("Timeline cache stats", extra: stats)

    :ok
  end

  # Helper functions

  defp warm_user_batch_cache(users) do
    Logger.debug("Warming cache for #{length(users)} users")

    Task.async_stream(
      users,
      fn user ->
        # Warm home and connections feeds (most commonly accessed)
        priority_tabs = ["home", "connections"]

        Enum.each(priority_tabs, fn tab ->
          try do
            options = %{tab: tab, post_per_page: 10}
            Timeline.filter_timeline_posts(user, options)
          rescue
            e ->
              Logger.debug("Failed to warm cache for user #{user.id}, tab #{tab}: #{inspect(e)}")
          end
        end)
      end,
      timeout: 10_000,
      max_concurrency: 5
    )
    |> Stream.run()
  end
end
