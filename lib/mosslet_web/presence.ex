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

  @presence_topic "proxy:online_users"

  def init(_opts) do
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      # user can be populated here from the database here we populate
      {key,
       %{
         metas: [meta | metas],
         id: meta.id,
         live_view_name: meta.live_view_name,
         user: %{id: meta.user_id},
         joined_at: meta.joined_at,
         cache_optimization: meta.cache_optimization
       }}
    end
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{id: user_id, user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:join, user_data}}

      case presence.live_view_name do
        "timeline" ->
          # broadcast to timeline_cache for invalidation/refresh
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "timeline_cache_presence",
            {:user_joined_timeline, user_id}
          )

          Phoenix.PubSub.broadcast(Mosslet.PubSub, topic, msg)

        _rest ->
          Phoenix.PubSub.broadcast(Mosslet.PubSub, topic, msg)
      end
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.broadcast(Mosslet.PubSub, topic, msg)
    end

    {:ok, state}
  end

  @doc """
  Track a user's presence on the timeline page for cache optimization.

  PRIVACY: Only stores user_id for performance optimization.
  No usernames, no public visibility.
  """
  def track_activity(_live_view_pid, params) do
    track(self(), @presence_topic, params.user_id, params)
  end

  def list_online_users(),
    do: list(@presence_topic) |> Enum.map(fn {_id, presence} -> presence end)

  def subscribe(),
    do: Phoenix.PubSub.subscribe(Mosslet.PubSub, @presence_topic)

  @doc """
  Get active user IDs for cache subscription optimization.

  PRIVACY: Only returns user IDs for backend cache optimization.
  No usernames or metadata exposed.
  """
  def get_active_timeline_user_ids do
    @presence_topic
    |> list()
    |> Map.keys()
  end

  @doc """
  Get count of active users (for monitoring, no privacy concerns).
  """
  def active_timeline_user_count do
    @presence_topic
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
    @presence_topic
    |> list()
    |> Map.has_key?(user_id)
  end

  @doc """
  Check if a specific user is active (for cache decisions).

  PRIVACY: Internal use only for cache optimization and status.
  """
  def user_active_on_timeline?(user_id) do
    @presence_topic
    |> list()
    |> Map.has_key?(user_id)
  end
end
