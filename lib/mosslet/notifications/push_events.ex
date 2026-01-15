defmodule Mosslet.Notifications.PushEvents do
  @moduledoc """
  Helper module to trigger push notifications from application events.

  🔐 ZERO-KNOWLEDGE: Only passes user IDs and resource IDs.
  Push payloads contain generic content, device fetches/decrypts actual content.

  ## Usage

  Call these functions after successful database operations:

      # After creating a post for connections
      PushEvents.notify_new_post(post, recipient_ids)

      # After creating a reply
      PushEvents.notify_new_reply(reply, post_owner_id)

      # After a connection request
      PushEvents.notify_connection_request(connection, target_user_id)
  """

  alias Mosslet.Notifications.PushNotificationsGenServer, as: PushQueue

  @doc """
  Notifies recipients about a new post.
  Called after creating a post visible to connections/groups.
  """
  def notify_new_post(post, recipient_user_ids) when is_list(recipient_user_ids) do
    metadata = %{post_id: post.id}
    PushQueue.queue_notification_for_many(recipient_user_ids, :new_post, metadata)
  end

  @doc """
  Notifies the post owner about a new reply.
  """
  def notify_new_reply(reply, post_owner_id) do
    metadata = %{reply_id: reply.id, post_id: reply.post_id}
    PushQueue.queue_notification(post_owner_id, :new_reply, metadata)
  end

  @doc """
  Notifies a user about a nested reply to their reply.
  """
  def notify_nested_reply(reply, parent_reply_owner_id) do
    metadata = %{
      reply_id: reply.id,
      parent_reply_id: reply.parent_reply_id,
      post_id: reply.post_id
    }

    PushQueue.queue_notification(parent_reply_owner_id, :new_reply, metadata)
  end

  @doc """
  Notifies a user about a connection request.
  """
  def notify_connection_request(user_connection, target_user_id) do
    metadata = %{connection_id: user_connection.id}
    PushQueue.queue_notification(target_user_id, :connection_request, metadata)
  end

  @doc """
  Notifies a user that their connection request was accepted.
  """
  def notify_connection_accepted(user_connection, requester_user_id) do
    metadata = %{connection_id: user_connection.id}
    PushQueue.queue_notification(requester_user_id, :connection_accepted, metadata)
  end

  @doc """
  Notifies group members about a new group message.
  Excludes the sender from notifications.
  """
  def notify_group_message(message, group_member_ids, sender_id) do
    recipient_ids = Enum.reject(group_member_ids, &(&1 == sender_id))
    metadata = %{message_id: message.id, group_id: message.group_id}
    PushQueue.queue_notification_for_many(recipient_ids, :group_message, metadata)
  end

  @doc """
  Notifies a user about a group invitation.
  """
  def notify_group_invite(user_group, invitee_user_id) do
    metadata = %{user_group_id: user_group.id, group_id: user_group.group_id}
    PushQueue.queue_notification(invitee_user_id, :group_invite, metadata)
  end

  @doc """
  Notifies a user about a direct message (legacy).
  """
  def notify_direct_message(message, recipient_user_id) do
    metadata = %{message_id: message.id, conversation_id: message.conversation_id}
    PushQueue.queue_notification(recipient_user_id, :new_message, metadata)
  end
end
