defmodule Mosslet.Conversations do
  @moduledoc """
  The Conversations context for end-to-end encrypted direct messaging.

  Messages are encrypted client-side using libsodium (NaCl) before being
  sent to the server. The server stores only encrypted blobs and never
  has access to plaintext message content.

  ## Encryption Architecture

  Each conversation has a unique symmetric key (`conversation_key`).
  This key is encrypted per-participant using their public key and stored
  in `user_conversations.key`. Messages are encrypted with the conversation_key
  using secretbox (XSalsa20-Poly1305).

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Conversations.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Conversations.Adapters.Native`
  """

  alias Mosslet.Conversations.{Conversation, Message}
  alias Mosslet.Platform

  require Logger

  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.Conversations.Adapters.Web
    end
  end

  def list_conversations(user), do: adapter().list_conversations(user)

  def get_conversation!(id), do: adapter().get_conversation!(id)

  def get_conversation_for_connection(user_connection_id) do
    adapter().get_conversation_for_connection(user_connection_id)
  end

  def get_or_create_conversation(user_connection_id, user_conversation_attrs_list) do
    adapter().get_or_create_conversation(user_connection_id, user_conversation_attrs_list)
  end

  def get_user_conversation(conversation_id, user_id) do
    adapter().get_user_conversation(conversation_id, user_id)
  end

  def get_message(id), do: adapter().get_message(id)

  def list_messages(conversation_id, opts \\ []) do
    adapter().list_messages(conversation_id, opts)
  end

  def create_message(attrs) do
    adapter().create_message(attrs)
  end

  def update_message(%Message{} = message, attrs) do
    adapter().update_message(message, attrs)
  end

  def delete_message(%Message{} = message) do
    adapter().delete_message(message)
  end

  def mark_conversation_read(conversation_id, user_id) do
    adapter().mark_conversation_read(conversation_id, user_id)
  end

  def archive_conversation(conversation_id, user_id) do
    adapter().archive_conversation(conversation_id, user_id)
  end

  def unarchive_conversation(conversation_id, user_id) do
    adapter().unarchive_conversation(conversation_id, user_id)
  end

  def delete_conversation(%Conversation{} = conversation) do
    adapter().delete_conversation(conversation)
  end

  def count_unread_messages(user_id) do
    adapter().count_unread_messages(user_id)
  end

  def get_last_message(conversation_id) do
    adapter().get_last_message(conversation_id)
  end

  def list_archived_conversations(user) do
    adapter().list_archived_conversations(user)
  end

  def get_user_connection_for_conversation(conversation_id, user_id) do
    adapter().get_user_connection_for_conversation(conversation_id, user_id)
  end

  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def change_conversation(%Conversation{} = conversation, attrs \\ %{}) do
    Conversation.changeset(conversation, attrs)
  end

  def toggle_reaction(message_id, user_id, emoji) do
    adapter().toggle_reaction(message_id, user_id, emoji)
  end

  def list_reactions(message_id) do
    adapter().list_reactions(message_id)
  end

  def subscribe_to_conversation(conversation_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conversation:#{conversation_id}")
  end

  def subscribe_to_user(user_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "user_conversations:#{user_id}")
  end

  def broadcast_new_message(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:new_message, message}
    )
  end

  def broadcast_message_updated(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:message_updated, message}
    )
  end

  def broadcast_message_deleted(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:message_deleted, message}
    )
  end

  def broadcast_conversation_updated(user_id, conversation_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "user_conversations:#{user_id}",
      {:conversation_updated, conversation_id}
    )
  end

  def broadcast_conversation_deleted(conversation_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:conversation_deleted, conversation_id}
    )
  end

  def broadcast_typing(conversation_id, user_id, typing?) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:typing, user_id, typing?}
    )
  end

  def broadcast_reaction_updated(conversation_id, message_id) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "conversation:#{conversation_id}",
      {:reaction_updated, message_id}
    )
  end
end
