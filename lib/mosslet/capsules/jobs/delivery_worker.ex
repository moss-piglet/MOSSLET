defmodule Mosslet.Capsules.Jobs.DeliveryWorker do
  @moduledoc """
  Daily, calm delivery of time-capsule letters.

  Runs once per day (cluster-wide, via the global Oban peer). For every
  capsule whose `deliver_on` date has arrived (and which hasn't yet been
  announced), it:

    1. Marks the capsule `notified_at` (idempotency — never re-announces).
    2. Sends ONE quiet "a letter is waiting" email per user (batched across
       all of that user's freshly-arrived capsules).

  This rides entirely on the plaintext `deliver_on` metadata. The worker never
  touches — and could not read — the encrypted letter content.

  Calm ethos (mirrors `EmailNotificationsGenServer`): we suppress the email
  when the user is currently active in the app, and we respect the user's
  `email_notifications` preference. The primary, gentlest surfacing is the
  dashboard affordance — the email is just a soft nudge home.
  """
  use Oban.Worker, queue: :email_notifications, max_attempts: 3, priority: 3
  use MossletWeb, :verified_routes

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserNotifier
  alias Mosslet.Capsules
  alias Mosslet.Mailer
  alias Mosslet.Notifications.Email

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "deliver_due"}}) do
    Capsules.list_due_for_delivery()
    |> Enum.group_by(& &1.user_id)
    |> Enum.each(&deliver_for_user/1)

    :ok
  end

  def perform(%Oban.Job{}), do: :ok

  defp deliver_for_user({user_id, capsules}) do
    # Always mark as notified first so we never re-announce, regardless of
    # whether an email actually goes out.
    Enum.each(capsules, &Capsules.mark_notified/1)

    case fetch_user(user_id) do
      nil -> :ok
      user -> maybe_notify(user, length(capsules))
    end
  rescue
    error ->
      Logger.error("Capsule delivery failed for user #{user_id}: #{inspect(error)}")
      :ok
  end

  defp maybe_notify(user, count) do
    cond do
      not UserNotifier.can_receive_mail?(user) ->
        :ok

      not user.email_notifications ->
        :ok

      MossletWeb.Presence.user_active_in_app?(user.id) ->
        # They're already here — no need for a nudge home. The dashboard shows it.
        :ok

      true ->
        send_capsule_email(user, count)
    end
  end

  defp send_capsule_email(user, count) do
    email = Email.capsule_ready_notification(user.email, count, url(~p"/app/capsules"))

    case Mailer.deliver(email) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Capsule email failed: #{inspect(reason)}")
    end
  end

  defp fetch_user(user_id) do
    Accounts.get_user!(user_id)
  rescue
    _ -> nil
  end
end
