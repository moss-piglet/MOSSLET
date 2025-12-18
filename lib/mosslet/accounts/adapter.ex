defmodule Mosslet.Accounts.Adapter do
  @moduledoc """
  Behaviour defining the interface for platform-specific account operations.

  This enables the same context API to work across web (direct Repo access)
  and native (API + cache) platforms.

  ## Implementation

  Web adapter (`Mosslet.Accounts.Adapters.Web`):
  - Direct Postgres access via `Mosslet.Repo`
  - Uses `Fly.Repo.transaction_on_primary/1` for writes

  Native adapter (`Mosslet.Accounts.Adapters.Native`):
  - HTTP API calls to cloud server via `Mosslet.API.Client`
  - Local SQLite cache via `Mosslet.Cache`
  - Offline fallback to cached data
  """

  alias Mosslet.Accounts.{User, UserConnection, Connection}

  @doc """
  Authenticates a user by email and password.
  Returns the user struct if credentials are valid, nil otherwise.
  """
  @callback get_user_by_email_and_password(email :: String.t(), password :: String.t()) ::
              User.t() | nil

  @doc """
  Registers a new user with the given changeset and connection attributes.
  """
  @callback register_user(changeset :: Ecto.Changeset.t(), connection_attrs :: map()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Gets a user by ID.
  """
  @callback get_user(id :: String.t()) :: User.t() | nil

  @doc """
  Gets a user by ID, raises if not found.
  """
  @callback get_user!(id :: String.t()) :: User.t()

  @doc """
  Gets a user by email.
  """
  @callback get_user_by_email(email :: String.t()) :: User.t() | nil

  @doc """
  Gets a user by username.
  """
  @callback get_user_by_username(username :: String.t()) :: User.t() | nil

  @doc """
  Gets a user by session token.
  """
  @callback get_user_by_session_token(token :: binary()) :: User.t() | nil

  @doc """
  Generates a new session token for the user.
  """
  @callback generate_user_session_token(user :: User.t()) :: binary()

  @doc """
  Deletes a session token.
  """
  @callback delete_user_session_token(token :: binary()) :: :ok

  @doc """
  Gets a user with all preloads (connection, user_connections).
  """
  @callback get_user_with_preloads(id :: String.t()) :: User.t() | nil

  @doc """
  Gets a user from their profile slug (username).
  """
  @callback get_user_from_profile_slug(slug :: String.t()) :: User.t() | nil

  @doc """
  Gets a user from their profile slug, raises if not found.
  """
  @callback get_user_from_profile_slug!(slug :: String.t()) :: User.t()

  @doc """
  Confirms a user by token.
  """
  @callback confirm_user(token :: String.t()) :: {:ok, User.t()} | :error

  @doc """
  Gets a connection by ID.
  """
  @callback get_connection(id :: String.t()) :: Connection.t() | nil

  @doc """
  Gets a connection by ID, raises if not found.
  """
  @callback get_connection!(id :: String.t()) :: Connection.t()

  @doc """
  Gets a user connection by ID.
  """
  @callback get_user_connection(id :: String.t()) :: UserConnection.t() | nil

  @doc """
  Gets a user connection by ID, raises if not found.
  """
  @callback get_user_connection!(id :: String.t()) :: UserConnection.t()

  @doc """
  Creates a user connection.
  """
  @callback create_user_connection(attrs :: map(), opts :: keyword()) ::
              {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a user connection.
  """
  @callback update_user_connection(
              user_connection :: UserConnection.t(),
              attrs :: map(),
              opts :: keyword()
            ) ::
              {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Deletes a user connection.
  """
  @callback delete_user_connection(user_connection :: UserConnection.t()) ::
              {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Confirms a user connection (bidirectional).
  """
  @callback confirm_user_connection(
              user_connection :: UserConnection.t(),
              attrs :: map(),
              opts :: keyword()
            ) ::
              {:ok, UserConnection.t(), UserConnection.t()} | {:error, any()}

  @doc """
  Filters user connections based on filter criteria.
  """
  @callback filter_user_connections(filter :: map(), user :: User.t()) :: [UserConnection.t()]

  @doc """
  Lists user connections for sync (native apps).
  """
  @callback list_user_connections_for_sync(user :: User.t(), opts :: keyword()) ::
              [UserConnection.t()]

  @doc """
  Preloads the connection association for a user.
  """
  @callback preload_connection(user :: User.t()) :: User.t()

  @doc """
  Checks if there's any user connection (pending or confirmed) between two users.
  """
  @callback has_user_connection?(user :: User.t(), current_user :: User.t()) :: boolean()

  @doc """
  Checks if there's a confirmed user connection between a user and a user ID.
  """
  @callback has_confirmed_user_connection?(user :: User.t(), current_user_id :: String.t()) ::
              boolean()

  @doc """
  Checks if a user has any confirmed connections.
  """
  @callback has_any_user_connections?(user :: User.t() | nil) :: boolean() | nil

  @doc """
  Returns pending user connection arrivals for the user.
  """
  @callback filter_user_arrivals(filter :: map(), user :: User.t()) :: [UserConnection.t()]

  @doc """
  Gets the count of pending user connection arrivals.
  """
  @callback arrivals_count(user :: User.t()) :: non_neg_integer()

  @doc """
  Lists pending user connection arrivals with pagination.
  """
  @callback list_user_arrivals_connections(user :: User.t(), options :: map()) ::
              [UserConnection.t()]

  @doc """
  Deletes both user connections between two users (bidirectional unfriend).
  """
  @callback delete_both_user_connections(user_connection :: UserConnection.t()) ::
              {:ok, [UserConnection.t()]} | {:error, any()}

  @doc """
  Gets all user connections for a user (both confirmed and pending).
  """
  @callback get_all_user_connections(id :: String.t()) :: [UserConnection.t()]

  @doc """
  Gets all confirmed user connections for a user.
  """
  @callback get_all_confirmed_user_connections(id :: String.t()) :: [UserConnection.t()]

  @doc """
  Searches user connections by label hash.
  """
  @callback search_user_connections(user :: User.t(), search_query :: String.t()) ::
              [UserConnection.t()]
end
