defmodule MossletWeb.Presence do
  @moduledoc """
  Privacy-first Phoenix Presence implementation for tracking user activity.

  PRIVACY DESIGN:
  - Default: Only tracks anonymous activity (no usernames or identifying info)
  - Used primarily for performance optimization (cache subscriptions)
  - Privacy by default: No user-visible presence indicators
  - Minimal metadata collection
  - Automatic cleanup when users leave

  FUTURE EXPANSION (Phase 5):
  - Users can opt-in to visible presence indicators in settings
  - When enabled, presence can show "Online" status to connections
  - Always respects user privacy preferences
  - Granular control: show to all connections vs specific groups

  Current uses:
  - Timeline cache optimization (subscribe to active users' topics)
  - Performance improvements based on activity patterns

  Future uses (opt-in only):
  - "Online now" indicators for connections who allow it
  - Activity status messages ("Working", "Away", custom with emoji)
  - Typing indicators in conversations
  """

  use Phoenix.Presence,
    otp_app: :mosslet,
    pubsub_server: Mosslet.PubSub

  require Logger

  @timeline_topic "timeline:activity"
  @connections_topic "connections:activity"

  @doc """
  Track a user's presence on the connections page for cache optimization.

  PRIVACY: Only stores user_id for performance optimization.
  No usernames, no public visibility.
  """
  def track_connections_activity(pid, user_id) do
    # Only store minimal data needed for cache optimization
    presence_meta = %{
      joined_at: System.system_time(:second),
      # No username, no identifying info - just for cache management
      cache_optimization: true
    }

    case track(pid, @connections_topic, user_id, presence_meta) do
      {:ok, _ref} ->
        Logger.debug("Connections activity tracked for cache optimization")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to track connections activity: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Track a user's presence on the timeline page for cache optimization.

  PRIVACY: Only stores user_id for performance optimization.
  No usernames, no public visibility.
  """
  def track_timeline_activity(pid, user_id) do
    # Only store minimal data needed for cache optimization
    presence_meta = %{
      joined_at: System.system_time(:second),
      # No username, no identifying info - just for cache management
      cache_optimization: true
    }

    case track(pid, @timeline_topic, user_id, presence_meta) do
      {:ok, _ref} ->
        Logger.debug("Timeline activity tracked for cache optimization")

        # Notify timeline cache about new active user
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "timeline_cache_presence",
          {:user_joined_timeline, user_id}
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to track timeline activity: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get active user IDs for cache subscription optimization.

  PRIVACY: Only returns user IDs for backend cache optimization.
  No usernames or metadata exposed.
  """
  def get_active_timeline_user_ids do
    @timeline_topic
    |> list()
    |> Map.keys()
  end

  @doc """
  Get count of active users (for monitoring, no privacy concerns).
  """
  def active_timeline_user_count do
    @timeline_topic
    |> list()
    |> map_size()
  end

  @doc """
  Check if a specific user is active on timeline OR connections (for auto-status).

  PRIVACY: Internal use only for auto-status optimization and status.
  """
  def user_active_in_app?(user_id) do
    user_active_on_timeline?(user_id) || user_active_on_connections?(user_id)
  end

  @doc """
  Check if a specific user is active on connections page.

  PRIVACY: Internal use only for cache optimization and status.
  """
  def user_active_on_connections?(user_id) do
    @connections_topic
    |> list()
    |> Map.has_key?(user_id)
  end

  @doc """
  Check if a specific user is active (for cache decisions).

  PRIVACY: Internal use only for cache optimization and status.
  """
  def user_active_on_timeline?(user_id) do
    @timeline_topic
    |> list()
    |> Map.has_key?(user_id)
  end
end
