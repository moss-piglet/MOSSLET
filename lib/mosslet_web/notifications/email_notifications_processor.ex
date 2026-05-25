defmodule Mosslet.Notifications.EmailNotificationsProcessor do
  @moduledoc """
  Coordinator for email notifications that delegates to the GenServer pipeline.

  This module handles filtering logic (visibility, offline, preferences) and
  decrypts recipient emails at the call site (while the sender's session key
  is still available in the LiveView process). Only metadata + pre-decrypted
  emails are queued to the GenServer for rate-limited sending.

  SECURITY: The session key never leaves the calling process. Email decryption
  happens synchronously in the caller, and the GenServer queue receives only
  pre-decrypted emails (transient in-memory data).
  """

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils
  alias Mosslet.Notifications.EmailNotificationsGenServer

  @doc """
  Process email notifications for a new post.

  Decrypts recipient emails immediately (while the session key is available),
  then queues only metadata + pre-decrypted emails to the GenServer.
  The session key never enters the GenServer queue.

  This runs synchronously in the caller's process — the session key stays
  in the LiveView process and is discarded after this function returns.
  """
  def process_post_notifications(post, current_user, session_key) do
    target_user_ids = get_target_user_ids_for_post(post, current_user)

    if target_user_ids != [] do
      eligible_users = filter_eligible_users(target_user_ids, current_user)

      if eligible_users != [] do
        # Decrypt recipient emails NOW while session key is available.
        # Only users whose email we can successfully decrypt get queued.
        notifications_with_emails =
          eligible_users
          |> Enum.map(fn target_user_id ->
            case decrypt_recipient_email(target_user_id, current_user, session_key) do
              {:ok, email} ->
                {target_user_id, email}

              {:error, reason} ->
                Logger.warning(
                  "Skipping email notification for user #{target_user_id}: #{inspect(reason)}"
                )

                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        if notifications_with_emails != [] do
          EmailNotificationsGenServer.queue_post_notifications(
            post,
            notifications_with_emails,
            current_user
          )
        end
      end
    end
  end

  @doc """
  Decrypt a recipient's email using the sender's session key and their connection.

  Returns `{:ok, email}` or `{:error, reason}`.
  Used by both post and reply notification flows.
  """
  def decrypt_recipient_email(target_user_id, sender_user, session_key) do
    case Accounts.get_user_connection_between_users(target_user_id, sender_user.id) do
      nil ->
        {:error, :no_connection}

      user_connection ->
        case EncryptedUtils.decrypt_user_item(
               user_connection.connection.email,
               sender_user,
               user_connection.key,
               session_key
             ) do
          :failed_verification -> {:error, :decrypt_failed}
          email when is_binary(email) -> {:ok, email}
          _ -> {:error, :decrypt_failed}
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
        Enum.map(post.shared_users, & &1.user_id)

      _ ->
        []
    end
  end

  defp filter_eligible_users(user_ids, current_user) do
    Enum.reject(user_ids, fn user_id ->
      MossletWeb.Presence.user_active_in_app?(user_id) || user_id == current_user.id
    end)
  end
end
