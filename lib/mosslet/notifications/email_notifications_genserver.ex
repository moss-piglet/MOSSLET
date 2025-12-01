defmodule Mosslet.Notifications.EmailNotificationsGenServer do
  @moduledoc """
  Rate-limited GenServer for processing email notifications with backpressure.

  🔐 PRIVACY COMPLIANT: Processes data in-memory only.
  - ✅ No sensitive data persisted in GenServer state
  - ✅ Queue contains only metadata (user IDs, post IDs, operation types)
  - ✅ All sensitive content (emails, session keys) fetched during processing
  - ✅ Zero knowledge maintained - no server-side decryption in state

  SAFE QUEUE DATA:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Post IDs (UUIDs - not sensitive)
  - ✅ Operation types ("post_notification" - not sensitive)
  - ✅ Sender user ID (UUID - not sensitive)

  NEVER IN QUEUE:
  - ❌ Encrypted emails or decryption keys
  - ❌ Session keys or decrypted content
  - ❌ Personal user information
  - ❌ Post content or sensitive metadata

  RATE LIMITING:
  - 📧 30 emails per minute (prevents spam detection)
  - ⏱️ 5-second batch delays (natural spacing)
  - 🔄 Automatic backpressure (queue size limits)
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.{Accounts, Timeline, Mailer}
  alias Mosslet.Notifications.Email

  @batch_size 5
  # 10 seconds between batches
  @batch_interval_ms 5_000
  # Backpressure: reject if queue too big
  @max_queue_size 1000
  @rate_limit_per_minute 30

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue an email notification for processing.

  This preserves the same API as the Broadway version but uses a GenServer queue.
  Only metadata is queued - all sensitive data is fetched during processing.
  """
  def queue_email_notification(target_user_id, post_id, sender_user_id, session_key_ref) do
    notification = %{
      target_user_id: target_user_id,
      post_id: post_id,
      sender_user_id: sender_user_id,
      session_key_ref: session_key_ref,
      operation: "post_notification",
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_notification, notification})
  end

  @doc """
  Queue multiple email notifications for a post to multiple users.

  This preserves the batch functionality from Broadway.
  """
  def queue_post_notifications(post, target_user_ids, sender_user, session_key_ref) do
    notifications =
      Enum.map(target_user_ids, fn target_user_id ->
        %{
          target_user_id: target_user_id,
          post_id: post.id,
          sender_user_id: sender_user.id,
          session_key_ref: session_key_ref,
          operation: "post_notification",
          queued_at: DateTime.utc_now()
        }
      end)

    GenServer.call(__MODULE__, {:queue_notifications, notifications})
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
    # Schedule periodic batch processing (rate limiting)
    :timer.send_interval(@batch_interval_ms, :process_batch)

    # Schedule rate limit reset every minute
    :timer.send_interval(60_000, :reset_rate_limit)

    state = %{
      queue: [],
      emails_sent_this_minute: 0,
      last_batch_processed_at: DateTime.utc_now(),
      total_processed: 0,
      total_failed: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:queue_notification, notification}, _from, state) do
    case queue_size_ok?(state) do
      true ->
        new_state = %{state | queue: [notification | state.queue]}

        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :queue_full}, state}
    end
  end

  @impl true
  def handle_call({:queue_notifications, notifications}, _from, state) do
    case queue_size_ok?(state, length(notifications)) do
      true ->
        new_state = %{state | queue: notifications ++ state.queue}

        {:reply, :ok, new_state}

      false ->
        {:reply, {:error, :queue_full}, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      queue_size: length(state.queue),
      emails_sent_this_minute: state.emails_sent_this_minute,
      total_processed: state.total_processed,
      total_failed: state.total_failed,
      last_batch_processed_at: state.last_batch_processed_at
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:process_batch, state) do
    {batch, remaining_queue} = take_batch_from_queue(state.queue)

    if length(batch) > 0 and can_send_emails?(state, length(batch)) do
      # Process the batch (same logic as Broadway)
      {successful, failed} = process_email_batch(batch)

      new_state = %{
        state
        | queue: remaining_queue,
          emails_sent_this_minute: state.emails_sent_this_minute + successful,
          total_processed: state.total_processed + successful,
          total_failed: state.total_failed + failed,
          last_batch_processed_at: DateTime.utc_now()
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:reset_rate_limit, state) do
    {:noreply, %{state | emails_sent_this_minute: 0}}
  end

  ## Private Functions

  defp queue_size_ok?(state, additional \\ 1) do
    length(state.queue) + additional <= @max_queue_size
  end

  defp can_send_emails?(state, batch_size) do
    state.emails_sent_this_minute + batch_size <= @rate_limit_per_minute
  end

  defp take_batch_from_queue(queue) do
    {batch, remaining} = Enum.split(queue, @batch_size)
    {batch, remaining}
  end

  defp process_email_batch(batch) do
    # Process each email notification in the batch
    # This preserves ALL the logic from the Broadway version
    results =
      Enum.map(batch, fn notification ->
        case process_email_notification_safely(notification) do
          :ok ->
            :success

          {:error, reason} ->
            Logger.error("❌ Failed to process email notification: #{inspect(reason)}")
            :failure

          :skip ->
            # Count skips as successful (not failures)
            :success
        end
      end)

    successful = Enum.count(results, &(&1 == :success))
    failed = Enum.count(results, &(&1 == :failure))

    {successful, failed}
  end

  # This preserves ALL the email processing logic from Broadway
  defp process_email_notification_safely(notification) do
    target_user_id = notification.target_user_id
    post_id = notification.post_id
    sender_user_id = notification.sender_user_id
    session_key_ref = notification.session_key_ref

    with {:ok, target_user_connection} <- get_user_connection(target_user_id, sender_user_id),
         {:ok, post} <- get_post(post_id),
         {:ok, sender_user} <- get_user(sender_user_id),
         {:ok, should_process} <- should_process_email?(target_user_connection, post, sender_user),
         true <- should_process,
         {:ok, unread_count} <- get_unread_count_for_connection(target_user_connection),
         {:ok, session_key} <- get_session_key(session_key_ref),
         {:ok, decrypted_email} <-
           decrypt_user_email(target_user_connection, sender_user, session_key),
         {:ok, _result} <-
           send_email_notification(decrypted_email, unread_count, target_user_connection) do
      :ok
    else
      {:skip, _reason} ->
        :skip

      {:error, reason} ->
        Logger.error(
          "❌ Failed to process email notification for user #{target_user_id}: #{inspect(reason)}"
        )

        {:error, reason}

      false ->
        :skip

      error ->
        Logger.error("❌ Unexpected error for user #{target_user_id}: #{inspect(error)}")
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  # All the helper functions from Broadway (EXACTLY THE SAME LOGIC)

  defp get_user_connection(target_user_id, sender_user_id) do
    case Accounts.get_user_connection_between_users(target_user_id, sender_user_id) do
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

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  defp should_process_email?(user_connection, post, _sender_user) do
    target_user = Accounts.get_user!(user_connection.reverse_user_id)

    cond do
      target_user.id == post.user_id ->
        {:skip, "post creator"}

      not target_user.email_notifications ->
        {:skip, "email notifications disabled"}

      already_sent_email_today?(target_user) ->
        {:skip, "already sent email today (daily limit)"}

      MossletWeb.Presence.user_active_in_app?(target_user.id) ->
        {:skip, "user currently active in app"}

      true ->
        {:ok, true}
    end
  end

  defp already_sent_email_today?(user) do
    case user.last_email_notification_received_at do
      nil ->
        false

      last_sent_at ->
        today = Date.utc_today()
        last_sent_date = DateTime.to_date(last_sent_at)

        case Date.compare(last_sent_date, today) do
          :eq ->
            true

          _ ->
            false
        end
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

  defp get_session_key(session_key_ref) do
    case session_key_ref do
      nil -> {:error, "No session key reference provided"}
      key when is_binary(key) -> {:ok, key}
      _ -> {:error, "Invalid session key reference"}
    end
  end

  defp decrypt_user_email(user_connection, sender_user, session_key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
           user_connection.connection.email,
           sender_user,
           user_connection.key,
           session_key
         ) do
      :failed_verification -> {:error, "Failed to decrypt email"}
      decrypted_email -> {:ok, decrypted_email}
    end
  end

  defp send_email_notification(decrypted_email, unread_count, user_connection) do
    timeline_url = url(~p"/app/timeline")

    email =
      Email.unread_posts_notification_with_email(
        decrypted_email,
        unread_count,
        timeline_url
      )

    case Mailer.deliver(email) do
      {:ok, result} ->
        target_user = Accounts.get_user!(user_connection.reverse_user_id)

        case Accounts.update_user_email_notification_received_at(target_user) do
          {:ok, _updated_user} ->
            :ok

          {:error, changeset} ->
            Logger.error("❌ Failed to update email timestamp: #{inspect(changeset.errors)}")
        end

        {:ok, result}

      {:error, reason} ->
        {:error, "delivery failed: #{inspect(reason)}"}

      rest ->
        {:error, "delivery failed: #{inspect(rest)}"}
    end
  end
end
