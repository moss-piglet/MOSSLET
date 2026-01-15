defmodule Mosslet.Notifications.PushNotificationsGenServer do
  @moduledoc """
  Rate-limited GenServer for processing push notifications with backpressure.

  🔐 ZERO-KNOWLEDGE ARCHITECTURE:
  - Queue contains only metadata (user IDs, resource IDs, notification types)
  - Push payloads contain ONLY generic content + metadata IDs
  - NO sensitive content (usernames, post content, etc.) ever leaves this server
  - Device fetches & decrypts actual content locally

  SAFE QUEUE DATA:
  - ✅ User IDs (UUIDs - not sensitive)
  - ✅ Resource IDs (post_id, reply_id, etc. - not sensitive)
  - ✅ Notification types (:new_post, :new_reply, etc. - not sensitive)

  NEVER IN QUEUE OR PUSH:
  - ❌ Usernames or display names
  - ❌ Post content or messages
  - ❌ Any encrypted/decrypted personal data

  RATE LIMITING:
  - 📱 100 pushes per minute (APNs/FCM have higher limits, but we batch)
  - ⏱️ 1-second batch delays (fast delivery)
  - 🔄 Automatic backpressure (queue size limits)
  """

  use GenServer
  require Logger

  alias Mosslet.Notifications.Push

  @batch_size 20
  @batch_interval_ms 1_000
  @max_queue_size 5000
  @rate_limit_per_minute 100

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a push notification for a user.

  ## Examples

      queue_notification(user_id, :new_post, %{post_id: post.id})
      queue_notification(user_id, :new_reply, %{reply_id: reply.id, post_id: post.id})
      queue_notification(user_id, :connection_request, %{connection_id: conn.id})
  """
  def queue_notification(user_id, type, metadata \\ %{}) do
    notification = %{
      user_id: user_id,
      type: type,
      metadata: metadata,
      queued_at: DateTime.utc_now()
    }

    GenServer.call(__MODULE__, {:queue_notification, notification})
  end

  @doc """
  Queue notifications for multiple users at once.
  """
  def queue_notification_for_many(user_ids, type, metadata \\ %{}) do
    Enum.each(user_ids, fn user_id ->
      queue_notification(user_id, type, metadata)
    end)
  end

  @doc """
  Get current queue status for monitoring.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @impl true
  def init(_opts) do
    :timer.send_interval(@batch_interval_ms, :process_batch)
    :timer.send_interval(60_000, :reset_rate_limit)

    state = %{
      queue: [],
      pushes_sent_this_minute: 0,
      last_batch_processed_at: DateTime.utc_now(),
      total_processed: 0,
      total_failed: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:queue_notification, notification}, _from, state) do
    if queue_size_ok?(state) do
      new_state = %{state | queue: [notification | state.queue]}
      {:reply, :ok, new_state}
    else
      Logger.warning("Push notification queue full, rejecting notification")
      {:reply, {:error, :queue_full}, state}
    end
  end

  def handle_call(:get_status, _from, state) do
    status = %{
      queue_size: length(state.queue),
      pushes_sent_this_minute: state.pushes_sent_this_minute,
      last_batch_processed_at: state.last_batch_processed_at,
      total_processed: state.total_processed,
      total_failed: state.total_failed
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:process_batch, state) do
    if state.pushes_sent_this_minute < @rate_limit_per_minute and length(state.queue) > 0 do
      {batch, remaining} = Enum.split(state.queue, @batch_size)

      {processed, failed} = process_batch(Enum.reverse(batch))

      new_state = %{
        state
        | queue: remaining,
          pushes_sent_this_minute: state.pushes_sent_this_minute + processed,
          last_batch_processed_at: DateTime.utc_now(),
          total_processed: state.total_processed + processed,
          total_failed: state.total_failed + failed
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info(:reset_rate_limit, state) do
    {:noreply, %{state | pushes_sent_this_minute: 0}}
  end

  defp queue_size_ok?(state), do: length(state.queue) < @max_queue_size

  defp process_batch(notifications) do
    results =
      Enum.map(notifications, fn notification ->
        try do
          results =
            Push.send_notification(notification.user_id, notification.type, notification.metadata)

          success_count = Enum.count(results, &match?({:ok, _}, &1))
          error_count = Enum.count(results, &match?({:error, _}, &1))
          {success_count, error_count}
        rescue
          e ->
            Logger.error("Push notification failed: #{inspect(e)}")
            {0, 1}
        end
      end)

    processed = Enum.sum(Enum.map(results, fn {s, _} -> s end))
    failed = Enum.sum(Enum.map(results, fn {_, f} -> f end))
    {processed, failed}
  end
end
