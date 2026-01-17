defmodule Mosslet.Notifications.MentionEmailNotificationsGenServer do
  @moduledoc """
  Rate-limited GenServer for processing @mention email notifications with backpressure.

  🔐 PRIVACY COMPLIANT: Processes data in-memory only.
  - ✅ No sensitive data persisted in GenServer state
  - ✅ Queue contains only metadata (user IDs, group IDs)
  - ✅ All sensitive content (emails) fetched during processing
  - ✅ Zero knowledge maintained - emails are generic with no circle/mention details

  SAFE QUEUE DATA:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ User Group IDs (UUIDs - not sensitive)
  - ✅ Group IDs (UUIDs - not sensitive)

  NEVER IN QUEUE/EMAIL:
  - ❌ Circle names or descriptions
  - ❌ Monikers or usernames
  - ❌ Message content
  - ❌ Any personally identifiable information

  RATE LIMITING:
  - 📧 Max 1 mention email per user per day (calm notifications)
  - ⏱️ 10-second batch delays (natural spacing)
  - 🔄 Automatic backpressure (queue size limits)
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.{Accounts, Mailer, Groups}
  alias Mosslet.Notifications.Email

  @batch_size 5
  @batch_interval_ms 10_000
  @max_queue_size 500
  @rate_limit_per_minute 20

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a mention email notification for processing.

  Only metadata is queued - the email content is generic for privacy.
  """
  def queue_mention_notification(mentioned_user_id, group_id, sender_user_id) do
    notification = %{
      mentioned_user_id: mentioned_user_id,
      group_id: group_id,
      sender_user_id: sender_user_id,
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_notification, notification})
  end

  @doc """
  Queue multiple mention email notifications.
  """
  def queue_mention_notifications(mentions) when is_list(mentions) do
    notifications =
      Enum.map(mentions, fn %{mentioned_user_id: uid, group_id: gid, sender_user_id: sid} ->
        %{
          mentioned_user_id: uid,
          group_id: gid,
          sender_user_id: sid,
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
    results =
      Enum.map(batch, fn notification ->
        case process_mention_notification_safely(notification) do
          :ok -> :success
          {:error, _reason} -> :failure
          :skip -> :success
        end
      end)

    successful = Enum.count(results, &(&1 == :success))
    failed = Enum.count(results, &(&1 == :failure))

    {successful, failed}
  end

  defp process_mention_notification_safely(notification) do
    mentioned_user_id = notification.mentioned_user_id
    group_id = notification.group_id
    sender_user_id = notification.sender_user_id

    with {:ok, mentioned_user} <- get_user(mentioned_user_id),
         {:ok, _sender_user} <- get_user(sender_user_id),
         {:ok, _group} <- get_group(group_id),
         {:ok, true} <- should_send_mention_email?(mentioned_user),
         {:ok, decrypted_email} <- get_user_email(mentioned_user),
         {:ok, _result} <- send_mention_email(decrypted_email, mentioned_user) do
      Logger.info("✅ Mention email sent successfully to user #{mentioned_user_id}")
      :ok
    else
      {:skip, reason} ->
        Logger.debug("⚠️ Skipping mention email for user #{mentioned_user_id}: #{reason}")
        :skip

      {:error, reason} ->
        Logger.error(
          "❌ Failed to process mention email for user #{mentioned_user_id}: #{inspect(reason)}"
        )

        {:error, reason}

      false ->
        :skip

      error ->
        Logger.error("❌ Unexpected error for user #{mentioned_user_id}: #{inspect(error)}")
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  defp get_group(group_id) do
    case Groups.get_group(group_id) do
      nil -> {:error, "Group not found"}
      group -> {:ok, group}
    end
  end

  defp should_send_mention_email?(user) do
    cond do
      not user.email_notifications ->
        {:skip, "email notifications disabled"}

      already_sent_mention_email_today?(user) ->
        {:skip, "already sent mention email today (daily limit)"}

      MossletWeb.Presence.user_active_in_app?(user.id) ->
        {:skip, "user currently active in app"}

      true ->
        {:ok, true}
    end
  end

  defp already_sent_mention_email_today?(user) do
    case user.last_mention_email_received_at do
      nil ->
        false

      last_sent_at ->
        today = Date.utc_today()
        last_sent_date = DateTime.to_date(last_sent_at)
        Date.compare(last_sent_date, today) == :eq
    end
  end

  defp get_user_email(user) do
    case user.email do
      nil -> {:error, "User has no email"}
      email -> {:ok, email}
    end
  end

  defp send_mention_email(decrypted_email, user) do
    circles_url = url(~p"/app/circles")

    email = Email.circle_activity_notification_with_email(decrypted_email, circles_url)

    case Mailer.deliver(email) do
      {:ok, result} ->
        case Accounts.update_user_mention_email_received_at(user) do
          {:ok, _updated_user} ->
            Logger.info("📅 Updated last_mention_email_received_at for user #{user.id}")

          {:error, changeset} ->
            Logger.error(
              "❌ Failed to update mention email timestamp: #{inspect(changeset.errors)}"
            )
        end

        {:ok, result}

      {:error, reason} ->
        {:error, "delivery failed: #{inspect(reason)}"}

      rest ->
        {:error, "delivery failed: #{inspect(rest)}"}
    end
  end
end
