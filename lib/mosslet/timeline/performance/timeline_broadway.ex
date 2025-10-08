defmodule Mosslet.Timeline.Performance.TimelineBroadway do
  @moduledoc """
  High-throughput Broadway pipeline for timeline processing.

  🔐 PRIVACY COMPLIANT: Broadway processes data in-memory only.
  - ✅ No sensitive data persisted in Broadway state
  - ✅ Messages contain only metadata (user IDs, post IDs, operation types)
  - ✅ All sensitive content fetched from encrypted DB during processing
  - ✅ Zero knowledge maintained - no server-side decryption

  SAFE MESSAGE DATA:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Post IDs (UUIDs - not sensitive)
  - ✅ Operation types ("regenerate", "warm_cache" - not sensitive)
  - ✅ Tab names ("home", "connections" - not sensitive)

  NEVER IN MESSAGES:
  - ❌ Post content, usernames, emails
  - ❌ Encrypted data or decryption keys
  - ❌ Personal user information
  """

  use Broadway
  require Logger

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Performance.TimelineCache
  alias Broadway.Message

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {Broadway.DummyProducer, opts[:producer_opts] || []},
        concurrency: opts[:producer_stages] || 1
      ],
      processors: [
        default: [
          concurrency: opts[:processor_stages] || 5,
          max_demand: opts[:max_demand] || 10
        ]
      ],
      batchers: [
        timeline_feeds: [
          concurrency: opts[:batcher_stages] || 3,
          batch_size: opts[:batch_size] || 20,
          batch_timeout: opts[:batch_timeout] || 5_000
        ],
        cache_updates: [
          concurrency: 2,
          batch_size: 50,
          batch_timeout: 2_000
        ]
      ]
    )
  end

  def handle_message(:default, message, _context) do
    # 🔐 PRIVACY: Message data contains only metadata, no sensitive content
    case Jason.decode(message.data) do
      {:ok, %{"type" => "timeline_update", "data" => data}} ->
        # 🔐 SAFE: data contains only user_id, operation type, tab names
        process_timeline_update(data)

        # Route to appropriate batcher
        case data["operation"] do
          "feed_generation" ->
            message |> Message.put_batcher(:timeline_feeds)

          "cache_invalidation" ->
            message |> Message.put_batcher(:cache_updates)

          _ ->
            message
        end

      {:ok, %{"type" => "post_processing", "data" => data}} ->
        # 🔐 SAFE: data contains only post_id and affected user_ids (UUIDs)
        process_post_update(data)
        message |> Message.put_batcher(:timeline_feeds)

      {:error, _} ->
        Logger.warning("Failed to decode Broadway message: #{inspect(message.data)}")
        Message.failed(message, "Invalid JSON")

      _ ->
        Logger.debug("Unknown message type in Broadway: #{inspect(message.data)}")
        message
    end
  end

  def handle_batch(:timeline_feeds, messages, _batch_info, _context) do
    Logger.info("Processing batch of #{length(messages)} timeline feed updates")

    # Process timeline feeds in batch for efficiency
    messages
    |> Enum.group_by(fn message ->
      case Jason.decode(message.data) do
        {:ok, %{"data" => %{"user_id" => user_id}}} -> user_id
        _ -> :unknown
      end
    end)
    |> Enum.map(fn {user_id, user_messages} ->
      if user_id != :unknown do
        process_user_timeline_batch(user_id, user_messages)
      end

      # Mark all messages as successful
      user_messages
    end)
    |> List.flatten()
  end

  def handle_batch(:cache_updates, messages, _batch_info, _context) do
    Logger.info("Processing batch of #{length(messages)} cache updates")

    # Process cache invalidations in batch
    cache_operations =
      Enum.map(messages, fn message ->
        case Jason.decode(message.data) do
          {:ok, %{"data" => %{"operation" => "invalidate", "keys" => keys}}} ->
            Enum.each(keys, fn key ->
              case String.split(key, ":") do
                ["timeline", user_id, tab] ->
                  TimelineCache.invalidate_timeline(user_id, tab)

                ["post", post_id] ->
                  TimelineCache.invalidate_post(post_id)

                _ ->
                  :ok
              end
            end)

          _ ->
            :ok
        end
      end)

    Logger.debug("Completed #{length(cache_operations)} cache operations")
    messages
  end

  # Process timeline update for a single user
  defp process_timeline_update(data) do
    # 🔐 PRIVACY: data contains only user_id (UUID) and operation type
    user_id = data["user_id"]
    operation = data["operation"]

    case operation do
      "regenerate_feed" ->
        # 🔐 PRIVACY: Sensitive data fetched from encrypted DB during execution
        regenerate_user_timeline_feed(user_id)

      "warm_cache" ->
        # 🔐 PRIVACY: Cache warming fetches encrypted data during execution
        warm_user_timeline_cache(user_id)

      "optimize_feed" ->
        # 🔐 PRIVACY: Feed optimization works with metadata only
        optimize_user_feed(user_id)

      _ ->
        Logger.debug("Unknown timeline operation: #{operation}")
    end
  end

  # Process post update that affects multiple users
  defp process_post_update(data) do
    # 🔐 PRIVACY: data contains only post_id (UUID) and affected user_ids (UUIDs)
    post_id = data["post_id"]
    affected_users = data["affected_users"] || []

    # Process feed updates for all affected users concurrently
    # 🔐 PRIVACY: All sensitive post content fetched from encrypted DB during execution
    Task.async_stream(
      affected_users,
      fn user_id ->
        update_user_feed_for_post(user_id, post_id)
      end,
      timeout: :infinity,
      max_concurrency: 10
    )
    |> Stream.run()
  end

  # Process batch of timeline updates for a specific user
  defp process_user_timeline_batch(user_id, messages) do
    Logger.debug("Processing #{length(messages)} timeline updates for user #{user_id}")

    # Get user for processing
    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        Logger.warning("User not found for timeline batch: #{user_id}")

      user ->
        # Process all timeline operations for this user
        operations = extract_operations_from_messages(messages)
        process_user_operations(user, operations)
    end
  end

  # Extract operations from Broadway messages
  defp extract_operations_from_messages(messages) do
    Enum.map(messages, fn message ->
      case Jason.decode(message.data) do
        {:ok, %{"data" => data}} -> data
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  # Process multiple operations for a user efficiently
  defp process_user_operations(user, operations) do
    # Group operations by type for batch processing
    grouped_ops = Enum.group_by(operations, & &1["operation"])

    # Process each operation type
    Enum.each(grouped_ops, fn {op_type, ops} ->
      case op_type do
        "regenerate_feed" ->
          # Regenerate all requested timeline tabs
          tabs = Enum.flat_map(ops, &(&1["tabs"] || ["home"]))
          regenerate_multiple_feeds(user, Enum.uniq(tabs))

        "cache_warm" ->
          # Warm cache for multiple tabs
          tabs = Enum.flat_map(ops, &(&1["tabs"] || []))
          warm_multiple_tabs(user, Enum.uniq(tabs))

        _ ->
          Logger.debug("Unknown batch operation: #{op_type}")
      end
    end)
  end

  # Generate fresh timeline feed for user
  defp regenerate_user_timeline_feed(user_id) do
    # 🔐 PRIVACY: User fetched from encrypted DB, no sensitive data in Broadway state
    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        Logger.warning("User not found for feed regeneration: #{user_id}")

      user ->
        Logger.debug("Regenerating timeline feed for user #{user_id}")

        # Clear cache first
        TimelineCache.invalidate_timeline(user_id, :all)

        # Pre-generate feeds for all tabs
        tabs = ["home", "connections", "groups", "bookmarks"]

        Task.async_stream(
          tabs,
          fn tab ->
            # 🔐 PRIVACY: Timeline data fetched from encrypted DB during execution
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

            Timeline.fetch_timeline_posts_from_db(user, options)
          end,
          timeout: 30_000,
          max_concurrency: 4
        )
        |> Stream.run()

        Logger.debug("Completed feed regeneration for user #{user_id}")
    end
  end

  # Pre-warm cache for user's timeline
  defp warm_user_timeline_cache(user_id) do
    # 🔐 PRIVACY: User data fetched from encrypted DB, cache stores encrypted posts
    # 🎯 ETHICAL: Performance optimization only - maintains user's chosen timeline order
    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        :ok

      user ->
        Logger.debug("Warming timeline cache for user #{user_id}")

        # Warm cache for high-traffic tabs
        priority_tabs = ["home", "connections", "groups"]

        Task.async_stream(
          priority_tabs,
          fn tab ->
            # 🔐 PRIVACY: Cache warming stores encrypted posts (no decryption)
            # 🎯 ETHICAL: Preserves chronological order and user preferences
            options = %{tab: tab, post_per_page: 10}
            Timeline.filter_timeline_posts(user, options)
          end,
          timeout: 15_000,
          max_concurrency: 2
        )
        |> Stream.run()

        :ok
    end
  end

  # Optimize user's feed (future: ML-based ranking, relevance scoring)
  defp optimize_user_feed(user_id) do
    # Placeholder for advanced feed optimization
    # Could include ML-based post ranking, engagement prediction, etc.
    Logger.debug("Feed optimization placeholder for user #{user_id}")
    :ok
  end

  # Update specific user's feed when a post changes
  defp update_user_feed_for_post(user_id, post_id) do
    Logger.debug("Updating feed for user #{user_id} after post #{post_id} change")

    # Invalidate relevant caches
    TimelineCache.invalidate_timeline(user_id, "home")

    # Could pre-compute new feed position for this post
    # This is where you'd implement feed algorithm optimizations
    :ok
  end

  # Batch operations for efficiency
  defp regenerate_multiple_feeds(user, tabs) do
    Logger.debug("Regenerating feeds for user #{user.id}, tabs: #{inspect(tabs)}")

    Task.async_stream(
      tabs,
      fn tab ->
        options = %{
          tab: tab,
          post_per_page: 20,
          skip_cache: true,
          # Required by filter_by_user_id
          filter: %{user_id: "", post_per_page: 20},
          post_sort_by: :inserted_at,
          post_sort_order: :desc
        }

        Timeline.fetch_timeline_posts_from_db(user, options)
      end,
      timeout: 30_000,
      max_concurrency: length(tabs)
    )
    |> Stream.run()
  end

  defp warm_multiple_tabs(user, tabs) do
    Logger.debug("Warming cache for user #{user.id}, tabs: #{inspect(tabs)}")

    Task.async_stream(
      tabs,
      fn tab ->
        options = %{tab: tab, post_per_page: 10}
        Timeline.filter_timeline_posts(user, options)
      end,
      timeout: 15_000,
      max_concurrency: length(tabs)
    )
    |> Stream.run()
  end
end
