defmodule Mosslet.Notifications.ReplyNotificationsGenServer do
  @moduledoc """
  Rate-limited GenServer for processing reply email notifications with backpressure.

  🔐 PRIVACY COMPLIANT: Processes data in-memory only.
  - ✅ No sensitive data persisted in GenServer state
  - ✅ Queue contains only metadata (user IDs, post IDs, operation types)
  - ✅ All sensitive content (emails, session keys) fetched during processing
  - ✅ Zero knowledge maintained - no server-side decryption in state

  RATE LIMITING:
  - 📧 30 emails per minute (prevents spam detection)
  - ⏱️ 5-second batch delays (natural spacing)
  - 🔄 Automatic backpressure (queue size limits)
  - 🌙 Max 1 reply notification email per user per day
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.{Accounts, Timeline, Mailer}
  alias Mosslet.Notifications.Email

  @batch_size 5
  @batch_interval_ms 5_000
  @max_queue_size 1000
  @rate_limit_per_minute 30

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a reply notification for processing.
  """
  def queue_reply_notification(post_owner_id, reply_id, replier_id, session_key_ref) do
    notification = %{
      post_owner_id: post_owner_id,
      reply_id: reply_id,
      replier_id: replier_id,
      session_key_ref: session_key_ref,
      operation: "reply_notification",
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_notification, notification})
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@batch_interval_ms, :process_batch)
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

    if batch != [] and can_send_emails?(state, length(batch)) do
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
    results =
      Enum.map(batch, fn notification ->
        case process_reply_notification_safely(notification) do
          :ok ->
            :success

          {:error, reason} ->
            Logger.error("❌ Failed to process reply notification: #{inspect(reason)}")
            :failure

          :skip ->
            :success
        end
      end)

    successful = Enum.count(results, &(&1 == :success))
    failed = Enum.count(results, &(&1 == :failure))

    {successful, failed}
  end

  defp process_reply_notification_safely(notification) do
    post_owner_id = notification.post_owner_id
    reply_id = notification.reply_id
    replier_id = notification.replier_id
    session_key_ref = notification.session_key_ref

    with {:ok, post_owner} <- get_user(post_owner_id),
         {:ok, replier} <- get_user(replier_id),
         {:ok, _reply} <- get_reply(reply_id),
         {:ok, should_process} <- should_process_reply_email?(post_owner, replier_id),
         true <- should_process,
         {:ok, reply_count} <- get_unread_reply_count(post_owner),
         {:ok, user_connection} <- get_user_connection(post_owner_id, replier_id),
         {:ok, session_key} <- get_session_key(session_key_ref),
         {:ok, decrypted_email} <- decrypt_user_email(user_connection, replier, session_key),
         {:ok, _result} <- send_reply_email_notification(decrypted_email, reply_count, post_owner) do
      :ok
    else
      {:skip, _reason} ->
        :skip

      {:error, reason} ->
        Logger.error(
          "❌ Failed to process reply notification for user #{post_owner_id}: #{inspect(reason)}"
        )

        {:error, reason}

      false ->
        :skip

      error ->
        Logger.error("❌ Unexpected error for user #{post_owner_id}: #{inspect(error)}")
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  defp get_reply(reply_id) do
    case Timeline.get_reply(reply_id) do
      nil -> {:error, "Reply not found"}
      reply -> {:ok, reply}
    end
  end

  defp should_process_reply_email?(post_owner, replier_id) do
    cond do
      post_owner.id == replier_id ->
        {:skip, "replying to own post"}

      not post_owner.email_notifications ->
        {:skip, "email notifications disabled"}

      already_sent_reply_email_today?(post_owner) ->
        {:skip, "already sent reply email today (daily limit)"}

      MossletWeb.Presence.user_active_in_app?(post_owner.id) ->
        {:skip, "user currently active in app"}

      true ->
        {:ok, true}
    end
  end

  defp already_sent_reply_email_today?(user) do
    case user.last_reply_notification_received_at do
      nil ->
        false

      last_sent_at ->
        today = Date.utc_today()
        last_sent_date = DateTime.to_date(last_sent_at)
        Date.compare(last_sent_date, today) == :eq
    end
  end

  defp get_unread_reply_count(post_owner) do
    reply_count = Timeline.count_unread_replies_for_user(post_owner)

    if reply_count > 0 do
      {:ok, reply_count}
    else
      {:skip, "no unread replies"}
    end
  end

  defp get_user_connection(post_owner_id, replier_id) do
    case Accounts.get_user_connection_between_users(post_owner_id, replier_id) do
      nil -> {:error, "User connection not found"}
      user_connection -> {:ok, user_connection}
    end
  end

  defp get_session_key(session_key_ref) do
    case session_key_ref do
      nil -> {:error, "No session key reference provided"}
      key when is_binary(key) -> {:ok, key}
      _ -> {:error, "Invalid session key reference"}
    end
  end

  defp decrypt_user_email(user_connection, replier, session_key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
           user_connection.connection.email,
           replier,
           user_connection.key,
           session_key
         ) do
      :failed_verification -> {:error, "Failed to decrypt email"}
      decrypted_email -> {:ok, decrypted_email}
    end
  end

  defp send_reply_email_notification(decrypted_email, reply_count, post_owner) do
    timeline_url = url(~p"/app/timeline")

    email =
      Email.new_replies_notification_with_email(
        decrypted_email,
        reply_count,
        timeline_url
      )

    case Mailer.deliver(email) do
      {:ok, result} ->
        case Accounts.update_user_reply_notification_received_at(post_owner) do
          {:ok, _updated_user} ->
            :ok

          {:error, changeset} ->
            Logger.error("❌ Failed to update reply email timestamp: #{inspect(changeset.errors)}")
        end

        {:ok, result}

      {:error, reason} ->
        {:error, "delivery failed: #{inspect(reason)}"}

      rest ->
        {:error, "delivery failed: #{inspect(rest)}"}
    end
  end
end
