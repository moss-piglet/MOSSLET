defmodule Mosslet.Messages.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific message operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Messages.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Messages.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Messages`)
  - Adapters handle data access (database vs API)
  """

  alias Mosslet.Messages.Message

  @callback list_messages(conversation_id :: String.t()) :: [Message.t()]

  @callback get_message!(conversation_id :: String.t(), id :: String.t()) :: Message.t()

  @callback get_last_message!(conversation_id :: String.t()) :: Message.t()

  @callback create_message(conversation_id :: String.t(), attrs :: map()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}

  @callback update_message(message :: Message.t(), attrs :: map()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_message(message :: Message.t()) ::
              {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
end
