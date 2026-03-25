defmodule Mosslet.Conversations.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific conversation operations.

  Web adapter (`Mosslet.Conversations.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Conversations.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data
  """

  alias Mosslet.Conversations.{Conversation, Message, UserConversation}
  alias Mosslet.Accounts.User

  @callback list_conversations(user :: User.t()) :: [map()]

  @callback get_conversation!(id :: binary()) :: Conversation.t()

  @callback get_conversation_for_connection(user_connection_id :: binary()) ::
              Conversation.t() | nil

  @callback get_or_create_conversation(
              user_connection_id :: binary(),
              user_conversation_attrs_list :: [map()]
            ) ::
              {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()}

  @callback get_user_conversation(conversation_id :: binary(), user_id :: binary()) ::
              UserConversation.t() | nil

  @callback list_messages(conversation_id :: binary(), opts :: keyword()) :: [Message.t()]

  @callback create_message(attrs :: map()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}

  @callback update_message(message :: Message.t(), attrs :: map()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_message(message :: Message.t()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}

  @callback mark_conversation_read(conversation_id :: binary(), user_id :: binary()) ::
              {:ok, UserConversation.t()} | {:error, term()}

  @callback archive_conversation(conversation_id :: binary(), user_id :: binary()) ::
              {:ok, UserConversation.t()} | {:error, term()}

  @callback unarchive_conversation(conversation_id :: binary(), user_id :: binary()) ::
              {:ok, UserConversation.t()} | {:error, term()}

  @callback delete_conversation(conversation :: Conversation.t()) ::
              {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()}

  @callback count_unread_messages(user_id :: binary()) :: integer()

  @callback get_last_message(conversation_id :: binary()) :: Message.t() | nil

  @callback list_archived_conversations(user :: User.t()) :: [map()]

  @callback get_user_connection_for_conversation(conversation_id :: binary(), user_id :: binary()) ::
              UserConversation.t() | nil
end
