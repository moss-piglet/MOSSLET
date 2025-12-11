defmodule Mosslet.Timeline.Jobs.EphemeralPostCleanupJob do
  @moduledoc """
  Oban job for ephemeral post deletion and cleanup.

  🔐 PRIVACY COMPLIANT: Only stores non-sensitive metadata in job args.
  🎯 ETHICAL DESIGN: Respects user privacy choices for temporary content.

  SAFE JOB ARGS:
  - ✅ Post IDs (UUIDs - not sensitive)
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Expiration timestamps (not sensitive)
  - ✅ Cleanup types (not sensitive)

  NEVER STORED IN JOBS:
  - ❌ Post content, usernames, emails
  - ❌ Encrypted data or keys
  - ❌ Personal user information

  USER AGENCY FIRST:
  - ✅ Honors user's ephemeral post choices
  - ✅ Automatically cleans up expired content
  - ✅ Protects user privacy by removing temporary data
  - ✅ Maintains data integrity during cleanup
  """

  use Oban.Worker, queue: :ephemeral_cleanup, max_attempts: 3
  require Logger

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Performance.TimelineCache

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => action} = args}) do
    case action do
      "delete_expired_post" ->
        delete_expired_post(args)

      "cleanup_expired_posts" ->
        cleanup_expired_posts(args)

      "cleanup_user_ephemeral_posts" ->
        cleanup_user_ephemeral_posts(args)

      _ ->
        Logger.warning("Unknown ephemeral cleanup action: #{action}")
        {:error, "Unknown action"}
    end
  end

  # Public API for scheduling ephemeral post jobs

  @doc """
  Schedules deletion of a specific ephemeral post at its expiration time.
  🔐 PRIVACY: Only stores post_id (UUID) and expiration timestamp (non-sensitive).
  🎯 ETHICAL: Honors user's choice for temporary content.

  Called when an ephemeral post is created to schedule its automatic deletion.
  """
  def schedule_post_expiration(post_id, expires_at, user_id) do
    # Calculate delay until expiration
    now = DateTime.utc_now()
    expires_at_utc = DateTime.from_naive!(expires_at, "Etc/UTC")

    delay_seconds = DateTime.diff(expires_at_utc, now, :second)

    # Don't schedule if already expired
    if delay_seconds > 0 do
      %{
        "action" => "delete_expired_post",
        # 🔐 SAFE: Just the post ID (UUID)
        "post_id" => post_id,
        # 🔐 SAFE: Just the user ID (UUID)
        "user_id" => user_id,
        # 🔐 SAFE: Expiration timestamp
        "expires_at" => DateTime.to_iso8601(expires_at_utc)
      }
      |> __MODULE__.new(scheduled_at: expires_at_utc)
      |> Oban.insert()
    else
      # Post is already expired, delete immediately
      schedule_immediate_deletion(post_id, user_id)
    end
  end

  @doc """
  Schedules immediate deletion of an expired ephemeral post.
  🔐 PRIVACY: Only stores post_id and user_id (UUIDs - non-sensitive).
  """
  def schedule_immediate_deletion(post_id, user_id) do
    %{
      "action" => "delete_expired_post",
      # 🔐 SAFE: Just the post ID (UUID)
      "post_id" => post_id,
      # 🔐 SAFE: Just the user ID (UUID)
      "user_id" => user_id,
      # 🔐 SAFE: Current timestamp
      "expires_at" => DateTime.to_iso8601(DateTime.utc_now())
    }
    |> __MODULE__.new(priority: 1)
    |> Oban.insert()
  end

  @doc """
  Schedules bulk cleanup of expired ephemeral posts.
  🔐 PRIVACY: No sensitive data in job args.

  Should be called periodically (every hour) to catch any missed expirations.
  """
  def schedule_bulk_cleanup() do
    %{
      "action" => "cleanup_expired_posts",
      # 🔐 SAFE: Just cleanup type
      "cleanup_type" => "bulk_expired",
      # 🔐 SAFE: Timestamp
      "cleanup_time" => DateTime.to_iso8601(DateTime.utc_now())
    }
    |> __MODULE__.new(priority: 2)
    |> Oban.insert()
  end

  @doc """
  Schedules cleanup of all ephemeral posts for a specific user.
  🔐 PRIVACY: Only stores user_id (UUID - non-sensitive).

  Used when a user account is deleted or suspended.
  """
  def schedule_user_ephemeral_cleanup(user_id, reason \\ "user_cleanup") do
    %{
      "action" => "cleanup_user_ephemeral_posts",
      # 🔐 SAFE: Just the user ID (UUID)
      "user_id" => user_id,
      # 🔐 SAFE: Generic reason
      "reason" => reason
    }
    |> __MODULE__.new(priority: 1)
    |> Oban.insert()
  end

  # Job implementations - All sensitive data fetched from encrypted DB during execution

  defp delete_expired_post(%{"post_id" => post_id, "user_id" => user_id}) do
    # 🔐 PRIVACY: Post ID is just a UUID (safe), post content fetched from encrypted DB
    Logger.info("Deleting expired ephemeral post: #{post_id}")

    case Timeline.get_post(post_id) do
      nil ->
        Logger.info("Post #{post_id} already deleted or not found")
        :ok

      post ->
        # Verify this is actually an ephemeral post that should be deleted
        if post.is_ephemeral && post.expires_at do
          now = NaiveDateTime.utc_now()

          case NaiveDateTime.compare(post.expires_at, now) do
            :lt ->
              # Post is expired, safe to delete
              perform_post_deletion(post, user_id)

            _ ->
              Logger.warning("Attempted to delete non-expired ephemeral post: #{post_id}")
              {:error, "Post not yet expired"}
          end
        else
          Logger.warning("Attempted to delete non-ephemeral post: #{post_id}")
          {:error, "Post is not ephemeral"}
        end
    end
  end

  defp cleanup_expired_posts(%{"cleanup_type" => cleanup_type}) do
    # 🔐 PRIVACY: No user data in job args - fetch from encrypted DB during execution
    Logger.info("Running bulk ephemeral post cleanup: #{cleanup_type}")

    # Find all expired ephemeral posts
    now = NaiveDateTime.utc_now()
    expired_posts = Timeline.get_expired_ephemeral_posts(now)

    if expired_posts != [] do
      Logger.info("Found #{length(expired_posts)} expired ephemeral posts to delete")

      # Process in batches to avoid overwhelming the system
      expired_posts
      |> Enum.chunk_every(10)
      |> Task.async_stream(
        fn post_batch ->
          delete_post_batch(post_batch)
        end,
        timeout: 30_000,
        max_concurrency: 3
      )
      |> Stream.run()

      Logger.info("Bulk ephemeral post cleanup completed")
    else
      Logger.debug("No expired ephemeral posts found")
    end

    :ok
  end

  defp cleanup_user_ephemeral_posts(%{"user_id" => user_id, "reason" => reason}) do
    # 🔐 PRIVACY: User ID is UUID (safe), user data fetched from encrypted DB
    Logger.info("Cleaning up ephemeral posts for user #{user_id}, reason: #{reason}")

    case Mosslet.Accounts.get_user(user_id) do
      nil ->
        Logger.warning("User not found for ephemeral cleanup: #{user_id}")
        {:error, "User not found"}

      user ->
        # Get all ephemeral posts for this user
        ephemeral_posts = Timeline.get_user_ephemeral_posts(user)

        if ephemeral_posts != [] do
          Logger.info("Deleting #{length(ephemeral_posts)} ephemeral posts for user #{user_id}")

          # Delete all ephemeral posts for this user
          Task.async_stream(
            ephemeral_posts,
            fn post ->
              perform_post_deletion(post, user_id)
            end,
            timeout: 15_000,
            max_concurrency: 5
          )
          |> Stream.run()

          Logger.info("User ephemeral post cleanup completed for #{user_id}")
        else
          Logger.debug("No ephemeral posts found for user #{user_id}")
        end

        :ok
    end
  end

  # Helper functions for post deletion

  defp perform_post_deletion(post, user_id) do
    # 🔐 PRIVACY: Proper deletion through Timeline context (maintains encryption patterns)
    # 🎯 ETHICAL: Clean deletion that respects user privacy
    case Timeline.delete_post(post, user_id: user_id, ephemeral: true) do
      {:ok, _deleted_post} ->
        # Invalidate cache for affected users
        TimelineCache.invalidate_timeline(user_id, :all)

        # Clean up related data (replies, bookmarks, etc.)
        cleanup_related_data(post)

        Logger.info("Successfully deleted ephemeral post: #{post.id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete ephemeral post #{post.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp delete_post_batch(posts) do
    Logger.debug("Deleting batch of #{length(posts)} expired ephemeral posts")

    Task.async_stream(
      posts,
      fn post ->
        perform_post_deletion(post, post.user_id)
      end,
      timeout: 10_000,
      max_concurrency: 5
    )
    |> Stream.run()
  end

  defp cleanup_related_data(post) do
    # Clean up bookmarks of this ephemeral post
    # This is ethical - bookmarks of ephemeral content should also be cleaned up
    Timeline.delete_post_bookmarks(post.id)

    # Note: Replies are handled by cascade delete in the database
    # Note: Cache invalidation already handled in perform_post_deletion

    Logger.debug("Cleaned up related data for ephemeral post: #{post.id}")
  end
end
