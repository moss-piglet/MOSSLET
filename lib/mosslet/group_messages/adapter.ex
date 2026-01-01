defmodule Mosslet.GroupMessages.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific group message operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.GroupMessages.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.GroupMessages.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.GroupMessages`)
  - Adapters handle data access (database vs API)
  - Context orchestrates operations and broadcasts events
  """

  alias Mosslet.Groups.{Group, GroupMessage}

  @callback list_groups() :: [Group.t()]

  @callback get_message!(id :: String.t()) :: GroupMessage.t() | nil

  @callback last_ten_messages_for(group_id :: String.t()) :: [GroupMessage.t()]

  @callback last_user_message_for_group(group_id :: String.t(), user_id :: String.t()) ::
              GroupMessage.t() | nil

  @callback create_message(attrs :: map(), options :: keyword()) ::
              {:ok, GroupMessage.t()} | {:error, Ecto.Changeset.t()}

  @callback update_message(message :: GroupMessage.t(), attrs :: map()) ::
              {:ok, GroupMessage.t()} | {:error, Ecto.Changeset.t()}

  @callback delete_message(message :: GroupMessage.t()) ::
              {:ok, GroupMessage.t()} | {:error, Ecto.Changeset.t()}

  @callback preload_message_sender(message :: GroupMessage.t()) :: GroupMessage.t()

  @callback get_previous_n_messages(
              date :: NaiveDateTime.t() | nil,
              group_id :: String.t(),
              n :: integer()
            ) :: [GroupMessage.t()]

  @callback get_message_count_for_group(group_id :: String.t()) :: non_neg_integer()
end
