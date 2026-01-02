defmodule Mosslet.Logs.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific log operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Logs.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`

  Native adapter (`Mosslet.Logs.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Logs are server-side only, native adapter mostly no-ops or delegates

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Logs`)
  - Adapters handle data access (database vs API)

  Note: Logs are primarily a server-side concern for audit/analytics.
  Native apps send log events to the server via API.
  """

  alias Mosslet.Logs.Log

  @callback get(id :: binary()) :: Log.t() | nil

  @callback create(attrs :: map()) :: {:ok, Log.t()} | {:error, Ecto.Changeset.t()}

  @callback exists?(params :: keyword() | map()) :: boolean()

  @callback get_last_log_of_user(user_id :: binary()) :: Log.t() | nil

  @callback delete_logs_older_than(days :: pos_integer()) :: {non_neg_integer(), nil | [any()]}

  @callback delete_sensitive_logs() :: {non_neg_integer(), nil | [any()]}

  @callback delete_user_logs(user_id :: binary()) :: {non_neg_integer(), nil | [any()]}
end
