defmodule Mosslet.Statuses.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific status operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Statuses.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Statuses.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data

  ## Pattern

  Following the same pattern as other adapters:
  - Business logic stays in the context (`Mosslet.Statuses`)
  - Adapters handle data access (database vs API)
  """

  alias Mosslet.Accounts.{User, Connection}

  @callback update_user_status_multi(
              user_changeset :: Ecto.Changeset.t(),
              connection :: Connection.t(),
              connection_attrs :: map()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback update_user_status_visibility(
              user :: User.t(),
              changeset :: Ecto.Changeset.t()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @callback update_connection_status_visibility(
              connection :: Connection.t(),
              attrs :: map()
            ) :: :ok | :error

  @callback update_user_activity(
              user :: User.t(),
              changeset :: Ecto.Changeset.t()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @callback preload_connection(user :: User.t()) :: User.t()
end
