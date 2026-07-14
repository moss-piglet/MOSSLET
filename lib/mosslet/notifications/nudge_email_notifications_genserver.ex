defmodule Mosslet.Notifications.NudgeEmailNotificationsGenServer do
  @moduledoc """
  Rate-limited GenServer for the calm offline "thinking of you" nudge email
  fallback (EPIC #377, task #399).

  A nudge is realtime + in-app when the recipient is present. When they're not,
  we fall back to a single, calm, GENERIC email — never the sender's name (that
  would break zero-knowledge, and an email can't run the client-side decrypt
  hook), never any content (a nudge has none).

  🔐 PRIVACY COMPLIANT:
  - ✅ Queue contains only the recipient user id (a UUID — not sensitive)
  - ✅ Duplicate recipients within a batch window collapse to one email
  - ✅ Recipient email is Cloak-decrypted at rest server-side (same as the
       mention notifier) — no session key is ever involved
  - ✅ Email is generic: no sender name, no content

  RATE LIMITING:
  - 📧 Max 1 nudge email per recipient per day (calm)
  - ⏱️ 10-second batch delays (natural spacing)
  - 🔕 Skipped entirely if the recipient is active in-app or opted out
  """

  use GenServer
  use MossletWeb, :verified_routes
  require Logger

  alias Mosslet.{Accounts, Mailer}
  alias Mosslet.Notifications.Email

  @batch_size 10
  @batch_interval_ms 10_000
  @max_queue_size 500
  @rate_limit_per_minute 30

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a nudge email for a recipient. Only the recipient user id is stored.
  Duplicate recipients in the same window collapse to a single email.
  """
  def queue_nudge_notification(to_user_id) when is_binary(to_user_id) do
    GenServer.call(__MODULE__, {:queue_notification, to_user_id})
  end

  @doc "Current queue status (monitoring)."
  def get_status, do: GenServer.call(__MODULE__, :get_status)

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
  def handle_call({:queue_notification, to_user_id}, _from, state) do
    cond do
      to_user_id in state.queue ->
        # Collapse: this recipient already has a pending nudge email.
        {:reply, :ok, state}

      length(state.queue) + 1 > @max_queue_size ->
        {:reply, {:error, :queue_full}, state}

      true ->
        {:reply, :ok, %{state | queue: [to_user_id | state.queue]}}
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
    {batch, remaining_queue} = Enum.split(state.queue, @batch_size)

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

  defp can_send_emails?(state, batch_size) do
    state.emails_sent_this_minute + batch_size <= @rate_limit_per_minute
  end

  defp process_email_batch(batch) do
    results =
      Enum.map(batch, fn to_user_id ->
        case process_nudge_notification_safely(to_user_id) do
          :ok -> :success
          :skip -> :success
          {:error, _reason} -> :failure
        end
      end)

    {Enum.count(results, &(&1 == :success)), Enum.count(results, &(&1 == :failure))}
  end

  defp process_nudge_notification_safely(to_user_id) do
    with {:ok, user} <- get_user(to_user_id),
         {:ok, true} <- should_send_nudge_email?(user),
         {:ok, email} <- get_user_email(user),
         {:ok, _result} <- send_nudge_email(email, user) do
      :ok
    else
      {:skip, reason} ->
        Logger.debug("⚠️ Skipping nudge email for user #{to_user_id}: #{reason}")
        :skip

      {:error, reason} ->
        Logger.error("❌ Failed to process nudge email for user #{to_user_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      user -> {:ok, user}
    end
  end

  defp should_send_nudge_email?(user) do
    cond do
      not user.nudges_enabled ->
        {:skip, "nudges disabled"}

      not user.email_notifications ->
        {:skip, "email notifications disabled"}

      already_sent_nudge_email_today?(user) ->
        {:skip, "already sent nudge email today (daily limit)"}

      MossletWeb.Presence.user_active_in_app?(user.id) ->
        {:skip, "user currently active in app"}

      true ->
        {:ok, true}
    end
  end

  defp already_sent_nudge_email_today?(user) do
    case user.last_nudge_email_received_at do
      nil ->
        false

      last_sent_at ->
        Date.compare(DateTime.to_date(last_sent_at), Date.utc_today()) == :eq
    end
  end

  defp get_user_email(user) do
    case user.email do
      nil -> {:error, "User has no email"}
      email -> {:ok, email}
    end
  end

  defp send_nudge_email(decrypted_email, user) do
    dashboard_url = url(~p"/app")
    email = Email.nudge_notification(decrypted_email, dashboard_url)

    case Mailer.deliver(email) do
      {:ok, result} ->
        case Accounts.update_user_nudge_email_received_at(user) do
          {:ok, _updated_user} ->
            :ok

          {:error, changeset} ->
            Logger.error("❌ Failed to update nudge email timestamp: #{inspect(changeset.errors)}")
        end

        {:ok, result}

      {:error, reason} ->
        {:error, "delivery failed: #{inspect(reason)}"}

      rest ->
        {:error, "delivery failed: #{inspect(rest)}"}
    end
  end
end
