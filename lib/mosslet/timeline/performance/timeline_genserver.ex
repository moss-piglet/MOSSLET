defmodule Mosslet.Timeline.Performance.TimelineGenServer do
  @moduledoc """
  High-performance GenServer for timeline processing with batching and concurrency.

  🔐 PRIVACY COMPLIANT: Processes data in-memory only.
  - ✅ No sensitive data persisted in GenServer state
  - ✅ Queue contains only metadata (user IDs, post IDs, operation types)
  - ✅ All sensitive content fetched from encrypted DB during processing
  - ✅ Zero knowledge maintained - no server-side decryption

  SAFE QUEUE DATA:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Post IDs (UUIDs - not sensitive)
  - ✅ Operation types ("regenerate", "warm_cache" - not sensitive)
  - ✅ Tab names ("home", "connections" - not sensitive)

  NEVER IN QUEUE:
  - ❌ Post content, usernames, emails
  - ❌ Encrypted data or decryption keys
  - ❌ Personal user information

  PROCESSING TYPES:
  - 📊 Timeline feed regeneration (ethical chronological order)
  - 🔥 Cache warming for performance
  - ⚡ Feed optimization (future ML-based ranking)
  """

  use GenServer
  require Logger

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Performance.TimelineCache

  @batch_size 20
  # 5 seconds between batches
  @batch_interval_ms 5_000
  @cache_batch_size 50
  # 2 seconds for cache operations
  @cache_batch_interval_ms 2_000
  # Backpressure: reject if queue too big
  @max_queue_size 5000

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a timeline update operation.

  This preserves the same functionality as Broadway but uses a GenServer queue.
  Only metadata is queued - all sensitive data is fetched during processing.
  """
  def queue_timeline_update(user_id, operation, options \\ %{}) do
    update_request = %{
      type: "timeline_update",
      user_id: user_id,
      operation: operation,
      options: options,
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_update, update_request})
  end

  @doc """
  Queue a post processing operation that affects multiple users.

  This preserves the batch functionality from Broadway.
  """
  def queue_post_update(post_id, affected_user_ids) do
    update_request = %{
      type: "post_processing",
      post_id: post_id,
      affected_users: affected_user_ids,
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_update, update_request})
  end

  @doc """
  Queue multiple timeline operations efficiently.
  """
  def queue_timeline_batch(operations) do
    GenServer.call(__MODULE__, {:queue_batch, operations})
  end

  @doc """
  Get current queue status for monitoring.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic batch processing for timeline feeds
    :timer.send_interval(@batch_interval_ms, :process_timeline_batch)

    # Schedule periodic batch processing for cache updates
    :timer.send_interval(@cache_batch_interval_ms, :process_cache_batch)

    Logger.info(
      "📊 TimelineGenServer started with batching: #{@batch_size} timeline ops, #{@cache_batch_size} cache ops"
    )

    state = %{
      timeline_queue: [],
      cache_queue: [],
      total_processed: 0,
      last_batch_processed_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:queue_update, update_request}, _from, state) do
    case queue_size_ok?(state) do
      true ->
        new_state = route_to_appropriate_queue(update_request, state)
        Logger.debug("📊 Queued #{update_request.type} operation")
        {:reply, :ok, new_state}

      false ->
        Logger.warning("⚠️ Timeline queue full, rejecting operation (backpressure)")
        {:reply, {:error, :queue_full}, state}
    end
  end

  @impl true
  def handle_call({:queue_batch, operations}, _from, state) do
    case queue_size_ok?(state, length(operations)) do
      true ->
        new_state =
          Enum.reduce(operations, state, fn operation, acc_state ->
            route_to_appropriate_queue(operation, acc_state)
          end)

        Logger.info("📊 Queued batch of #{length(operations)} timeline operations")
        {:reply, :ok, new_state}

      false ->
        Logger.warning("⚠️ Timeline queue would overflow, rejecting batch (backpressure)")
        {:reply, {:error, :queue_full}, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      timeline_queue_size: length(state.timeline_queue),
      cache_queue_size: length(state.cache_queue),
      total_queue_size: length(state.timeline_queue) + length(state.cache_queue),
      total_processed: state.total_processed,
      last_batch_processed_at: state.last_batch_processed_at
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:process_timeline_batch, state) do
    {batch, remaining_queue} = take_batch_from_queue(state.timeline_queue, @batch_size)

    if length(batch) > 0 do
      Logger.info("🔄 Processing timeline batch of #{length(batch)} operations")

      # Process the batch (same logic as Broadway)
      processed_count = process_timeline_batch(batch)

      new_state = %{
        state
        | timeline_queue: remaining_queue,
          total_processed: state.total_processed + processed_count,
          last_batch_processed_at: DateTime.utc_now()
      }

      Logger.info("✅ Processed timeline batch: #{processed_count} operations")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:process_cache_batch, state) do
    {batch, remaining_queue} = take_batch_from_queue(state.cache_queue, @cache_batch_size)

    if length(batch) > 0 do
      Logger.debug("🔄 Processing cache batch of #{length(batch)} operations")

      # Process cache operations
      processed_count = process_cache_batch(batch)

      new_state = %{
        state
        | cache_queue: remaining_queue,
          total_processed: state.total_processed + processed_count
      }

      Logger.debug("✅ Processed cache batch: #{processed_count} operations")
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  ## Private Functions

  defp queue_size_ok?(state, additional \\ 1) do
    total_size = length(state.timeline_queue) + length(state.cache_queue)
    total_size + additional <= @max_queue_size
  end

  defp route_to_appropriate_queue(operation, state) do
    case operation do
      %{type: "timeline_update"} ->
        %{state | timeline_queue: [operation | state.timeline_queue]}

      %{type: "post_processing"} ->
        %{state | timeline_queue: [operation | state.timeline_queue]}

      %{operation: "cache_invalidation"} ->
        %{state | cache_queue: [operation | state.cache_queue]}

      %{operation: "invalidate"} ->
        %{state | cache_queue: [operation | state.cache_queue]}

      _ ->
        # Default to timeline queue
        %{state | timeline_queue: [operation | state.timeline_queue]}
    end
  end

  defp take_batch_from_queue(queue, batch_size) do
    {batch, remaining} = Enum.split(queue, batch_size)
    {batch, remaining}
  end

  # Process timeline updates batch (preserves ALL Broadway logic)
  defp process_timeline_batch(batch) do
    # Group operations by user for efficient batch processing
    # This preserves the exact logic from Broadway
    grouped_operations =
      batch
      |> Enum.group_by(fn operation ->
        case operation do
          %{user_id: user_id} -> user_id
          %{affected_users: users} when is_list(users) -> :multi_user
          _ -> :unknown
        end
      end)

    # Process single-user operations
    single_user_count =
      grouped_operations
      |> Enum.filter(fn {user_id, _ops} -> is_binary(user_id) end)
      |> Enum.map(fn {user_id, operations} ->
        process_user_timeline_operations(user_id, operations)
      end)
      |> Enum.sum()

    # Process multi-user operations
    multi_user_count =
      case grouped_operations[:multi_user] do
        nil ->
          0

        multi_ops ->
          Enum.map(multi_ops, &process_post_update_operation/1)
          |> Enum.sum()
      end

    single_user_count + multi_user_count
  end

  # Process cache operations batch
  defp process_cache_batch(batch) do
    cache_operations =
      Enum.map(batch, fn operation ->
        case operation do
          %{operation: "invalidate", keys: keys} ->
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

            1

          _ ->
            Logger.debug("Unknown cache operation: #{inspect(operation)}")
            0
        end
      end)

    Enum.sum(cache_operations)
  end

  # Process timeline operations for a specific user (preserves Broadway logic)
  defp process_user_timeline_operations(user_id, operations) do
    Logger.debug("Processing #{length(operations)} timeline updates for user #{user_id}")

    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        Logger.warning("User not found for timeline operations: #{user_id}")
        0

      user ->
        # Group operations by type for batch processing (same as Broadway)
        grouped_ops = Enum.group_by(operations, fn op -> op.operation end)

        # Process each operation type
        Enum.reduce(grouped_ops, 0, fn {op_type, ops}, acc ->
          processed =
            case op_type do
              "regenerate_feed" ->
                # Regenerate all requested timeline tabs
                tabs =
                  Enum.flat_map(ops, fn op ->
                    Map.get(op.options, "tabs", ["home"])
                  end)

                regenerate_multiple_feeds(user, Enum.uniq(tabs))
                length(ops)

              "warm_cache" ->
                # Warm cache for multiple tabs
                tabs =
                  Enum.flat_map(ops, fn op ->
                    Map.get(op.options, "tabs", [])
                  end)

                warm_multiple_tabs(user, Enum.uniq(tabs))
                length(ops)

              "optimize_feed" ->
                # Optimize user's feed (future: ML-based ranking)
                optimize_user_feed(user.id)
                length(ops)

              _ ->
                Logger.debug("Unknown timeline operation: #{op_type}")
                0
            end

          acc + processed
        end)
    end
  end

  # Process post update that affects multiple users (preserves Broadway logic)
  defp process_post_update_operation(operation) do
    post_id = operation.post_id
    affected_users = operation.affected_users || []

    Logger.debug(
      "Processing post update for post #{post_id}, affecting #{length(affected_users)} users"
    )

    # Process feed updates for all affected users concurrently (same as Broadway)
    Task.async_stream(
      affected_users,
      fn user_id ->
        update_user_feed_for_post(user_id, post_id)
      end,
      timeout: :infinity,
      max_concurrency: 10
    )
    |> Stream.run()

    # Count as 1 operation processed
    1
  end

  # All the helper functions from Broadway (EXACTLY THE SAME LOGIC)

  defp regenerate_multiple_feeds(user, tabs) do
    Logger.debug("Regenerating feeds for user #{user.id}, tabs: #{inspect(tabs)}")

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
      max_concurrency: length(tabs)
    )
    |> Stream.run()
  end

  defp warm_multiple_tabs(user, tabs) do
    Logger.debug("Warming cache for user #{user.id}, tabs: #{inspect(tabs)}")

    Task.async_stream(
      tabs,
      fn tab ->
        # 🔐 PRIVACY: Cache warming stores encrypted posts (no decryption)
        # 🎯 ETHICAL: Preserves chronological order and user preferences
        options = %{tab: tab, post_per_page: 10}
        Timeline.filter_timeline_posts(user, options)
      end,
      timeout: 15_000,
      max_concurrency: length(tabs)
    )
    |> Stream.run()
  end

  defp optimize_user_feed(user_id) do
    # Placeholder for advanced feed optimization
    # Could include ML-based post ranking, engagement prediction, etc.
    Logger.debug("Feed optimization placeholder for user #{user_id}")
    :ok
  end

  defp update_user_feed_for_post(user_id, post_id) do
    Logger.debug("Updating feed for user #{user_id} after post #{post_id} change")

    # Invalidate relevant caches
    TimelineCache.invalidate_timeline(user_id, "home")

    # Could pre-compute new feed position for this post
    # This is where you'd implement feed algorithm optimizations
    :ok
  end
end
