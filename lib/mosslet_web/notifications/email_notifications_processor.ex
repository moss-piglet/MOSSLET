defmodule Mosslet.Notifications.EmailNotificationsProcessor do
  @moduledoc """
  Coordinator for email notifications that now delegates to the Broadway pipeline.

  This processor handles all filtering, offline checking, and coordinates with the
  Broadway-based email processing system for better backpressure and rate limiting.

  🔄 UPDATED: Now uses Broadway for actual email processing
  🔐 PRIVACY: Maintains session-based decryption approach
  📧 RATE LIMITED: 30 emails per minute via Broadway
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Notifications.EmailNotificationsGenServer

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process email notifications for a new post.

  This handles all filtering logic including visibility, offline checking,
  and user preferences before delegating to the Broadway pipeline.
  """
  def process_post_notifications(post, current_user, session_key) do
    GenServer.cast(__MODULE__, {:process_post_notifications, post, current_user, session_key})
  end

  @doc """
  Process email notification for a specific user (legacy method - kept for compatibility).
  """
  def process_email_notification(user_id, post_id, current_user, session_key) do
    GenServer.cast(__MODULE__, {:process_email, user_id, post_id, current_user, session_key})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("EmailNotificationsProcessor GenServer started")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process_post_notifications, post, current_user, session_key}, state) do
    process_post_notifications_with_broadway(post, current_user, session_key)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:process_email, user_id, post_id, current_user, session_key}, state) do
    # For individual emails, we'll push directly to Broadway
    push_single_email_to_broadway(user_id, post_id, current_user, session_key)

    {:noreply, state}
  end

  ## Private Functions

  defp push_single_email_to_broadway(user_id, post_id, current_user, session_key) do
    EmailNotificationsGenServer.queue_email_notification(
      user_id,
      post_id,
      current_user.id,
      session_key
    )
  end

  defp process_post_notifications_with_broadway(post, current_user, session_key) do
    # Get target user IDs based on post visibility
    target_user_ids = get_target_user_ids_for_post(post, current_user)

    if target_user_ids == [] do
      Logger.info("❌ No target users for post #{post.id} with visibility #{post.visibility}")
    else
      # Filter and process each user
      eligible_users = filter_eligible_users(target_user_ids, current_user)

      # 🔄 NEW: Push all eligible users to GenServer for rate-limited processing
      if eligible_users != [] do
        EmailNotificationsGenServer.queue_post_notifications(
          post,
          eligible_users,
          current_user,
          session_key
        )
      end
    end
  end

  defp get_target_user_ids_for_post(post, current_user) do
    case post.visibility do
      :specific_users ->
        Enum.map(post.shared_users, & &1.user_id)

      :connections ->
        Accounts.get_all_confirmed_user_connections(current_user.id)
        |> Enum.map(& &1.reverse_user_id)

      :specific_groups ->
        # For group posts, get users from the shared_users list
        Enum.map(post.shared_users, & &1.user_id)

      _ ->
        # No email notifications for public or private posts
        []
    end
  end

  defp filter_eligible_users(user_ids, current_user) do
    user_ids
    |> Enum.reject(fn user_id ->
      is_online = MossletWeb.Presence.user_active_in_app?(user_id)
      is_creator = user_id == current_user.id

      is_creator || is_online
    end)
  end

  # 🔄 NOTE: The following functions have been moved to EmailNotificationsGenServer
  # for better rate limiting and backpressure control:
  # - process_email_safely/4
  # - get_user_connection/2
  # - get_post/1
  # - should_process_email?/3
  # - already_sent_email_today?/1
  # - get_unread_count_for_connection/1
  # - decrypt_user_email/3
  # - send_email_notification/3
  #
  # These functions are now handled by the GenServer with proper
  # backpressure and rate limiting (30 emails per minute).
end
