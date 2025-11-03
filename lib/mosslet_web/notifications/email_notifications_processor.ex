defmodule Mosslet.Notifications.EmailNotificationsProcessor do
  @moduledoc """
  GenServer that processes email notifications in a privacy-preserving way.

  This processor handles all filtering, offline checking, decryption of user emails
  and sends notifications within the session context, avoiding the security issue
  of storing decrypted data in Oban jobs.
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.{Accounts, Timeline, Mailer}
  alias Mosslet.Notifications.Email

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process email notifications for a new post.

  This handles all filtering logic including visibility, offline checking,
  and user preferences before sending notifications.
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
    Task.Supervisor.start_child(Mosslet.BackgroundTask, fn ->
      process_post_notifications_safely(post, current_user, session_key)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:process_email, user_id, post_id, current_user, session_key}, state) do
    Task.Supervisor.start_child(Mosslet.BackgroundTask, fn ->
      process_email_safely(user_id, post_id, current_user, session_key)
    end)

    {:noreply, state}
  end

  ## Private Functions

  defp process_post_notifications_safely(post, current_user, session_key) do
    Logger.info(
      "🔍 Starting email notification processing for post #{post.id} from user #{current_user.id}"
    )

    Logger.info("🔍 Post visibility: #{post.visibility}")

    # Get target user IDs based on post visibility
    target_user_ids = get_target_user_ids_for_post(post, current_user)

    Logger.info("🔍 Target user IDs found: #{inspect(target_user_ids)}")

    if target_user_ids == [] do
      Logger.info("❌ No target users for post #{post.id} with visibility #{post.visibility}")
    else
      Logger.info("✅ Processing email notifications for #{length(target_user_ids)} users")

      # Filter and process each user
      eligible_users = filter_eligible_users(target_user_ids, current_user)
      Logger.info("🔍 Eligible users after filtering: #{inspect(eligible_users)}")

      eligible_users
      |> Enum.each(fn user_id ->
        Logger.info("🔍 Processing individual email for user #{user_id}")
        process_email_safely(user_id, post.id, current_user, session_key)
      end)

      Logger.info("✅ Completed processing all email notifications")
    end
  end

  defp get_target_user_ids_for_post(post, current_user) do
    case post.visibility do
      :specific_users ->
        Logger.info("Post visibility: specific_users")
        target_user_ids = Enum.map(post.shared_users, & &1.user_id)
        Logger.info("Target user IDs: #{inspect(target_user_ids)}")
        target_user_ids

      :connections ->
        Logger.info("Post visibility: connections")

        connection_user_ids =
          Accounts.get_all_confirmed_user_connections(current_user.id)
          |> Enum.map(& &1.reverse_user_id)

        Logger.info("Connection user IDs: #{inspect(connection_user_ids)}")
        connection_user_ids

      :specific_groups ->
        Logger.info("Post visibility: specific_groups")
        # For group posts, get users from the shared_users list
        target_user_ids = Enum.map(post.shared_users, & &1.user_id)
        Logger.info("Group target user IDs: #{inspect(target_user_ids)}")
        target_user_ids

      _ ->
        Logger.info("Post visibility #{post.visibility} - no email notifications")
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

  defp process_email_safely(user_id, post_id, current_user, session_key) do
    with {:ok, target_user_connection} <- get_user_connection(user_id, current_user),
         {:ok, post} <- get_post(post_id),
         {:ok, should_process} <-
           should_process_email?(target_user_connection, post, current_user),
         true <- should_process,
         {:ok, unread_count} <- get_unread_count_for_connection(target_user_connection),
         {:ok, decrypted_email} <-
           decrypt_user_email(target_user_connection, current_user, session_key),
         {:ok, _result} <-
           send_email_notification(decrypted_email, unread_count, target_user_connection) do
    else
      {:skip, reason} ->
        Logger.info("⚠️ Skipping email notification for user #{user_id}: #{reason}")

      {:error, reason} ->
        Logger.error(
          "❌ Failed to process email notification for user #{user_id}: #{inspect(reason)}"
        )

      false ->
        Logger.info("⚠️ Email notification not needed for user #{user_id}")

      error ->
        Logger.error("❌ Unexpected error for user #{user_id}: #{inspect(error)}")
    end
  end

  defp get_user_connection(user_id, current_user) do
    # We want to get the user connection from the target user's perspective
    # where they have a connection TO the current_user (post creator)
    case Accounts.get_user_connection_between_users(user_id, current_user.id) do
      nil -> {:error, "User connection not found"}
      user_connection -> {:ok, user_connection}
    end
  end

  defp get_post(post_id) do
    case Timeline.get_post(post_id) do
      nil -> {:error, "Post not found"}
      post -> {:ok, post}
    end
  end

  defp should_process_email?(user_connection, post, _current_user) do
    # Get the actual user from the connection
    target_user = Accounts.get_user!(user_connection.reverse_user_id)

    cond do
      target_user.id == post.user_id ->
        {:skip, "post creator"}

      not target_user.is_subscribed_to_email_notifications ->
        {:skip, "email notifications disabled"}

      true ->
        {:ok, true}
    end
  end

  defp get_unread_count_for_connection(user_connection) do
    target_user = Accounts.get_user!(user_connection.reverse_user_id)
    unread_count = Timeline.count_unread_posts_for_user(target_user)

    if unread_count > 0 do
      {:ok, unread_count}
    else
      {:skip, "no unread posts"}
    end
  end

  defp decrypt_user_email(user_connection, current_user, session_key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
           user_connection.connection.email,
           current_user,
           user_connection.key,
           session_key
         ) do
      :failed_verification -> :failed_verification
      decrypted_email -> {:ok, decrypted_email}
    end
  end

  defp send_email_notification(decrypted_email, unread_count, _user_connection) do
    timeline_url = ~p"/app/timeline"

    email =
      Email.unread_posts_notification_with_email(
        decrypted_email,
        unread_count,
        timeline_url
      )

    case Mailer.deliver(email) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "delivery failed: #{inspect(reason)}"}

      rest ->
        {:error, "delievery failed: #{inspect(rest)}"}
    end
  end
end
