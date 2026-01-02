defmodule Mosslet.Conversations.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific conversation operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Conversations.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Conversations.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Conversations`)
  - Adapters handle data access (database vs API)

  Note: Conversations is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """

  alias Mosslet.Conversations.Conversation
  alias Mosslet.Accounts.User

  @callback load_conversations(user :: User.t()) :: [Conversation.t()]

  @callback get_conversation!(id :: binary(), user :: User.t()) :: Conversation.t()

  @callback total_conversation_tokens(conversation :: Conversation.t(), user :: User.t()) ::
              integer() | nil

  @callback create_conversation(attrs :: map()) ::
              {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()}

  @callback update_conversation(
              conversation :: Conversation.t(),
              attrs :: map(),
              user :: User.t()
            ) ::
              {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | nil

  @callback delete_conversation(conversation :: Conversation.t(), user :: User.t()) ::
              {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | nil
end
