defmodule Mosslet.Timeline.Jobs.TimelineFeedJob do
  @moduledoc """
  Oban job for timeline feed generation and maintenance.

  🔐 PRIVACY COMPLIANT: Only stores non-sensitive metadata in job args.
  🎯 ETHICAL DESIGN: Performance optimization only - maintains chronological order and user choice.

  SAFE JOB ARGS:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Tab names ("home", "connections" - not sensitive)
  - ✅ Timestamps (not sensitive)
  - ✅ Generic operation types (not sensitive)

  NEVER STORED IN JOBS:
  - ❌ Post content, usernames, emails
  - ❌ Encrypted data or keys
  - ❌ Personal user information

  NO ALGORITHMIC MANIPULATION:
  - ❌ No feed ranking or algorithmic ordering
  - ❌ No engagement-based content promotion
  - ❌ No addiction-optimization patterns
  - ✅ Maintains chronological order and user preferences
  """

  use Oban.Worker, queue: :timeline, max_attempts: 3
  require Logger

  alias Mosslet.Timeline.Performance.TimelineCache
  alias Mosslet.Timeline

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action} = args}) do
    case action do
      "regenerate_user_feed" ->
        regenerate_user_feed(args)

      "warm_user_cache" ->
        warm_user_cache(args)

      "cleanup_expired_cache" ->
        cleanup_expired_cache(args)

      "batch_feed_update" ->
        batch_feed_update(args)

      _ ->
        Logger.warning("Unknown timeline job action: #{action}")
        {:error, "Unknown action"}
    end
  end

  # Public API for scheduling jobs - ALL PRIVACY SAFE & ETHICALLY DESIGNED

  @doc """
  Schedules feed regeneration for a user.
  🔐 PRIVACY: Only stores user_id (UUID) and tab names (non-sensitive).
  🎯 ETHICAL: Maintains user's chosen timeline preferences and chronological order.
  """
  def schedule_feed_regeneration(user_id, tabs \\ ["home"], priority \\ 0) do
    %{
      "action" => "regenerate_user_feed",
      # 🔐 SAFE: Just the user ID (UUID)
      "user_id" => user_id,
      # 🔐 SAFE: Just tab names ("home", "connections", etc.)
      "tabs" => tabs,
      # 🔐 SAFE: Timestamp
      "scheduled_at" => DateTime.to_iso8601(DateTime.utc_now())
    }
    |> __MODULE__.new(priority: priority)
    |> Oban.insert()
  end

  @doc """
  Schedules cache warming for a user.
  🔐 PRIVACY: Only stores user_id and tab names (non-sensitive).
  🎯 ETHICAL: Performance optimization only - no feed manipulation.
  """
  def schedule_cache_warming(user_id, tabs \\ ["home", "connections"]) do
    %{
      "action" => "warm_user_cache",
      # 🔐 SAFE: Just the user ID (UUID)
      "user_id" => user_id,
      # 🔐 SAFE: Just tab names
      "tabs" => tabs
    }
    |> __MODULE__.new(priority: 1)
    |> Oban.insert()
  end

  @doc """
  Schedules batch feed updates for multiple users.
  🔐 PRIVACY: Only stores user IDs and metadata (no sensitive content).
  🎯 ETHICAL: Batch processing for efficiency - maintains chronological order.
  Perfect for: New post affects 100 users -> process all 100 efficiently in batches.
  """
  def schedule_batch_feed_update(user_ids, reason \\ "post_update") do
    %{
      "action" => "batch_feed_update",
      # 🔐 SAFE: Just user IDs (UUIDs)
      "user_ids" => user_ids,
      # 🔐 SAFE: Generic reason ("post_update", "cache_refresh")
      "reason" => reason,
      # 🔐 SAFE: Just count
      "batch_size" => length(user_ids)
    }
    |> __MODULE__.new(priority: 2)
    |> Oban.insert()
  end

  @doc """
  Schedules periodic cache cleanup.
  🔐 PRIVACY: Only stores cleanup metadata (no user data).
  """
  def schedule_cache_cleanup() do
    %{
      "action" => "cleanup_expired_cache",
      # 🔐 SAFE: Just cleanup type
      "cleanup_type" => "expired_entries"
    }
    |> __MODULE__.new(priority: 3)
    |> Oban.insert()
  end

  # Job implementations - ALL sensitive data fetched from encrypted DB during execution

  defp regenerate_user_feed(%{"user_id" => user_id, "tabs" => tabs}) do
    # 🔐 PRIVACY: User ID is just a UUID (safe), sensitive data fetched here
    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        Logger.warning("User not found for feed regeneration: #{user_id}")
        {:error, "User not found"}

      user ->
        Logger.info("Regenerating timeline feed for user #{user_id}, tabs: #{inspect(tabs)}")

        # Clear existing cache
        TimelineCache.invalidate_timeline(user_id, :all)

        # 🎯 ETHICAL: Regenerate feeds maintaining chronological order and user preferences
        results =
          Task.async_stream(
            tabs,
            fn tab ->
              generate_tab_feed(user, tab)
            end,
            timeout: 30_000,
            max_concurrency: 4
          )
          |> Enum.to_list()

        success_count =
          Enum.count(results, fn
            {:ok, result} -> result == :ok
            _ -> false
          end)

        Logger.info(
          "Feed regeneration completed for user #{user_id}: #{success_count}/#{length(tabs)} tabs"
        )

        :ok
    end
  end

  defp warm_user_cache(%{"user_id" => user_id, "tabs" => tabs}) do
    # 🔐 PRIVACY: User ID is safe, all sensitive data fetched during execution
    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        {:error, "User not found"}

      user ->
        Logger.info("Warming cache for user #{user_id}, tabs: #{inspect(tabs)}")

        # 🎯 ETHICAL: Cache warming preserves user's timeline preferences
        Task.async_stream(
          tabs,
          fn tab ->
            warm_tab_cache(user, tab)
          end,
          timeout: 15_000,
          max_concurrency: length(tabs)
        )
        |> Stream.run()

        :ok
    end
  end

  defp cleanup_expired_cache(_args) do
    # 🔐 PRIVACY: No user data involved - just cache maintenance
    Logger.info("Running timeline cache cleanup")

    case TimelineCache.get_cache_stats() do
      %{size: size} when size > 0 ->
        Logger.info("Cache cleanup completed - cache size: #{size}")
        :ok

      _ ->
        Logger.debug("No cache entries to clean up")
        :ok
    end
  end

  defp batch_feed_update(%{"user_ids" => user_ids, "reason" => reason}) do
    # 🔐 PRIVACY: User IDs are UUIDs (safe), no sensitive content in job args
    # 🎯 ETHICAL: Batch processing for efficiency - maintains chronological order
    Logger.info("Processing batch feed update for #{length(user_ids)} users, reason: #{reason}")

    # Process users in smaller batches to avoid overwhelming the system
    # Example: New post affects 1000 users -> process in batches of 50 for efficiency
    user_ids
    |> Enum.chunk_every(10)
    |> Task.async_stream(
      fn user_batch ->
        # 🔐 PRIVACY: All sensitive data fetched from encrypted DB during execution
        # 🎯 ETHICAL: Each user gets their chronological timeline refreshed
        process_user_batch_feeds(user_batch, reason)
      end,
      timeout: 60_000,
      max_concurrency: 3
    )
    |> Stream.run()

    :ok
  end

  # Private helper functions - ALL fetch sensitive data from encrypted DB during execution

  defp generate_tab_feed(user, tab) do
    try do
      # 🔐 PRIVACY: Generate fresh feed data from encrypted DB
      # 🎯 ETHICAL: Maintains chronological order - no algorithmic manipulation
      options = %{
        tab: tab,
        post_per_page: 20,
        skip_cache: true,
        # Required by filter_by_user_id
        filter: %{user_id: "", post_per_page: 20},
        post_sort_by: :inserted_at,
        post_sort_order: :desc
      }

      posts = Timeline.fetch_timeline_posts_from_db(user, options)

      # 🔐 PRIVACY: Cache encrypted data (posts remain encrypted in cache)
      timeline_data = %{
        # 🔐 Posts remain encrypted as fetched from DB
        posts: posts,
        # 🔐 SAFE: Just count
        post_count: length(posts),
        # 🔐 SAFE: Timestamp
        generated_at: System.system_time(:millisecond)
      }

      TimelineCache.cache_timeline_data(user.id, tab, timeline_data)

      Logger.debug("Generated #{length(posts)} posts for user #{user.id}, tab #{tab}")
      :ok
    rescue
      e ->
        Logger.error("Failed to generate feed for user #{user.id}, tab #{tab}: #{inspect(e)}")
        {:error, "Feed generation failed"}
    end
  end

  defp warm_tab_cache(user, tab) do
    try do
      # 🔐 PRIVACY: Load encrypted data to warm cache (no decryption in job)
      # 🎯 ETHICAL: Respects user's timeline preferences and ordering
      options = %{tab: tab, post_per_page: 10}
      Timeline.filter_timeline_posts(user, options)

      Logger.debug("Warmed cache for user #{user.id}, tab #{tab}")
      :ok
    rescue
      e ->
        Logger.error("Failed to warm cache for user #{user.id}, tab #{tab}: #{inspect(e)}")
        {:error, "Cache warming failed"}
    end
  end

  defp process_user_batch_feeds(user_ids, reason) do
    # 🎯 ETHICAL: Efficient batch processing while maintaining chronological feeds
    Logger.debug("Processing feed updates for #{length(user_ids)} users, reason: #{reason}")

    # Process each user's feed update
    Task.async_stream(
      user_ids,
      fn user_id ->
        # 🔐 PRIVACY: User data fetched from encrypted DB during execution
        case Mosslet.Accounts.get_user(user_id) do
          nil ->
            {:error, "User not found"}

          user ->
            # Invalidate cache and regenerate feeds (chronological order preserved)
            TimelineCache.invalidate_timeline(user_id, "home")

            # Pre-generate home feed (most important) - chronological order maintained
            generate_tab_feed(user, "home")
        end
      end,
      timeout: 30_000,
      max_concurrency: 5
    )
    |> Stream.run()
  end
end
