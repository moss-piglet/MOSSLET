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
  Confirms a user without checking any tokens. Used
  in tests.
  """
  @callback confirm_user!(user :: User.t()) :: User.t()

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

  @doc """
  Gets a user by username, excluding current user and users with pending connections.
  Used for sending connection requests.
  """
  @callback get_user_by_username_for_connection(user :: User.t(), username :: String.t()) ::
              User.t() | nil

  @doc """
  Gets a user by email, excluding current user and users with pending connections.
  Used for sending connection requests.
  """
  @callback get_user_by_email_for_connection(user :: User.t(), email :: String.t()) ::
              User.t() | nil

  @doc """
  Gets both user connections between two users (bidirectional).
  """
  @callback get_both_user_connections_between_users!(
              user_id :: String.t(),
              reverse_user_id :: String.t()
            ) :: [UserConnection.t()]

  @doc """
  Gets the user connection between two users where the first user is the owner.
  """
  @callback get_user_connection_between_users(
              user_id :: String.t(),
              current_user_id :: String.t()
            ) :: UserConnection.t() | nil

  @doc """
  Gets the user connection between two users, raises if not found.
  """
  @callback get_user_connection_between_users!(
              user_id :: String.t(),
              current_user_id :: String.t()
            ) :: UserConnection.t()

  @doc """
  Updates the label on a user connection.
  """
  @callback update_user_connection_label(
              user_connection :: UserConnection.t(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates the zen (mute) status on a user connection.
  """
  @callback update_user_connection_zen(
              user_connection :: UserConnection.t(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates the photos permission on a user connection.
  """
  @callback update_user_connection_photos(
              user_connection :: UserConnection.t(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, UserConnection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates user profile on their connection.
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  """
  @callback update_user_profile(
              user :: User.t(),
              conn :: Connection.t(),
              changeset :: Ecto.Changeset.t()
            ) ::
              {:ok, Connection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates user name (on both user and connection).
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  Takes the user changeset and connection attributes already computed by the context.
  Returns {:ok, user, connection} or {:error, changeset}.
  """
  @callback update_user_name(
              user :: User.t(),
              conn :: Connection.t(),
              user_changeset :: Ecto.Changeset.t(),
              c_attrs :: map()
            ) ::
              {:ok, User.t(), Connection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates user username (on both user and connection).
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  Takes the user changeset and connection attributes already computed by the context.
  Returns {:ok, user, connection} or {:error, changeset}.
  """
  @callback update_user_username(
              user :: User.t(),
              conn :: Connection.t(),
              user_changeset :: Ecto.Changeset.t(),
              c_attrs :: map()
            ) ::
              {:ok, User.t(), Connection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates user visibility setting.
  """
  @callback update_user_visibility(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates user password.
  """
  @callback update_user_password(
              user :: User.t(),
              changeset :: Ecto.Changeset.t()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Resets user password using a token.
  """
  @callback reset_user_password(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates user avatar.
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  Takes the user, connection, user changeset and connection attributes already computed by the context.
  Returns {:ok, user, connection} or {:error, changeset}.
  """
  @callback update_user_avatar(
              user :: User.t(),
              conn :: Connection.t(),
              user_changeset :: Ecto.Changeset.t(),
              c_attrs :: map(),
              opts :: keyword()
            ) ::
              {:ok, User.t(), Connection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Blocks a user.
  Thin wrapper - only handles Repo transaction, returns whether it was an update.
  Returns {:ok, block, was_update?} or {:error, reason}.
  """
  @callback block_user(
              blocker :: User.t(),
              blocked_user :: User.t(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, any(), boolean()} | {:error, any()}

  @doc """
  Unblocks a user.
  """
  @callback unblock_user(blocker :: User.t(), blocked_user :: User.t()) ::
              {:ok, any()} | {:error, atom() | any()}

  @doc """
  Checks if a user has blocked another user.
  """
  @callback user_blocked?(blocker :: User.t(), blocked_user :: User.t()) :: boolean()

  @doc """
  Lists all users blocked by a user.
  """
  @callback list_blocked_users(user :: User.t()) :: [any()]

  @doc """
  Gets a specific user block if it exists.
  """
  @callback get_user_block(blocker :: User.t(), blocked_user_id :: String.t()) :: any() | nil

  @doc """
  Deletes a user account.
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  Takes the already-built changeset with password validation.
  """
  @callback delete_user_account(
              user :: User.t(),
              password :: String.t(),
              changeset :: Ecto.Changeset.t()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Delivers password reset instructions via email.
  """
  @callback deliver_user_reset_password_instructions(user_token :: UserToken.t()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Gets a user by reset password token.
  """
  @callback get_user_by_reset_password_token(token :: String.t()) :: User.t() | nil

  @doc """
  Inserts a user confirmation token.
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  """
  @callback insert_user_confirmation_token(user_token :: any()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Gets a user from a shared item by username.
  """
  @callback get_shared_user_by_username(user_id :: String.t(), username :: String.t()) ::
              User.t() | nil

  @doc """
  Gets a user connection for a user group relationship.
  """
  @callback get_user_connection_for_user_group(
              user_id :: String.t(),
              current_user_id :: String.t()
            ) :: UserConnection.t() | nil

  @doc """
  Gets a user connection for reply shared users.
  """
  @callback get_user_connection_for_reply_shared_users(
              reply_user_id :: String.t(),
              current_user_id :: String.t()
            ) :: UserConnection.t() | nil

  @doc """
  Gets the current user's connection to another user (where current user owns the connection).
  """
  @callback get_current_user_connection_between_users!(
              user_id :: String.t(),
              current_user_id :: String.t()
            ) :: UserConnection.t()

  @doc """
  Validates if a user is part of a connection.
  """
  @callback validate_users_in_connection(
              user_connection_id :: String.t(),
              current_user_id :: String.t()
            ) :: boolean()

  @doc """
  Gets a user connection from a shared item context.
  """
  @callback get_user_connection_from_shared_item(item :: any(), current_user :: User.t()) ::
              UserConnection.t() | nil

  @doc """
  Gets the permissions the post author has granted to the viewer.
  """
  @callback get_post_author_permissions_for_viewer(item :: any(), current_user :: User.t()) ::
              UserConnection.t() | nil

  @doc """
  Gets the user from a post.
  """
  @callback get_user_from_post(post :: any()) :: User.t() | nil

  @doc """
  Gets the user from an item.
  """
  @callback get_user_from_item(item :: any()) :: User.t() | nil

  @doc """
  Gets the user from an item, raises if not found.
  """
  @callback get_user_from_item!(item :: any()) :: User.t()

  @doc """
  Gets the connection from an item.
  """
  @callback get_connection_from_item(item :: any(), current_user :: User.t()) ::
              Connection.t() | nil

  @doc """
  Lists all users (admin function).
  """
  @callback list_all_users() :: [User.t()]

  @doc """
  Counts all users.
  """
  @callback count_all_users() :: non_neg_integer()

  @doc """
  Lists all confirmed users.
  """
  @callback list_all_confirmed_users() :: [User.t()]

  @doc """
  Counts all confirmed users.
  """
  @callback count_all_confirmed_users() :: non_neg_integer()

  @doc """
  Creates a user profile on their connection.
  """
  @callback create_user_profile(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, Connection.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes a user profile.
  """
  @callback delete_user_profile(changeset :: Ecto.Changeset.t()) ::
              {:ok, Connection.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates user onboarding settings.
  """
  @callback update_user_onboarding(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates user onboarding profile (name and marketing notifications).
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  Takes the user changeset and connection attributes already computed by the context.
  Returns {:ok, user, connection} or {:error, changeset}.
  """
  @callback update_user_onboarding_profile(
              user :: User.t(),
              conn :: Connection.t(),
              user_changeset :: Ecto.Changeset.t(),
              c_attrs :: map()
            ) ::
              {:ok, User.t(), Connection.t()} | {:error, Ecto.Changeset.t() | String.t()}

  @doc """
  Updates user notifications settings.
  """
  @callback update_user_notifications(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates the user's AI tokens.
  """
  @callback update_user_tokens(user :: User.t(), attrs :: map()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates when a user last received an email notification.
  """
  @callback update_user_email_notification_received_at(
              user :: User.t(),
              timestamp :: DateTime.t()
            ) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates when a user last received a reply notification.
  """
  @callback update_user_reply_notification_received_at(
              user :: User.t(),
              timestamp :: DateTime.t()
            ) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates when a user last viewed their replies.
  """
  @callback update_user_replies_seen_at(user :: User.t(), timestamp :: DateTime.t()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Emulates email change without actually changing (validates).
  """
  @callback apply_user_email(
              user :: User.t(),
              password :: String.t(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Checks if user can change their email.
  """
  @callback check_if_can_change_user_email(
              user :: User.t(),
              password :: String.t(),
              attrs :: map()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates the user email using a verification token.
  """
  @callback update_user_email(
              user :: User.t(),
              decrypted_email :: String.t(),
              token :: String.t(),
              key :: binary()
            ) :: :ok | :error

  @doc """
  Inserts a user email change token.
  Thin wrapper - only handles Repo transaction, business logic stays in context.
  """
  @callback insert_user_email_change_token(user_token :: any()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Suspends a user account (admin function).
  """
  @callback suspend_user(user :: User.t(), admin_user :: User.t()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t() | :unauthorized}

  @doc """
  Creates a visibility group for a user.
  """
  @callback create_visibility_group(user :: User.t(), group_attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t() | any()}

  @doc """
  Updates a visibility group for a user.
  """
  @callback update_visibility_group(
              user :: User.t(),
              group_id :: String.t(),
              group_attrs :: map(),
              opts :: keyword()
            ) :: {:ok, User.t()} | {:error, Ecto.Changeset.t() | any()}

  @doc """
  Deletes a visibility group from a user.
  """
  @callback delete_visibility_group(user :: User.t(), group_id :: String.t()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t() | any()}

  @doc """
  Gets all visibility groups with connection details.
  """
  @callback get_user_visibility_groups_with_connections(user :: User.t()) :: [map()]

  @doc """
  Deletes user data (not the account).
  """
  @callback delete_user_data(
              user :: User.t(),
              password :: String.t(),
              key :: binary(),
              attrs :: map(),
              opts :: keyword()
            ) :: {:ok, nil} | {:error, Ecto.Changeset.t()}

  # ============================================================================
  # TOTP / 2FA Functions
  # ============================================================================

  @doc """
  Checks if two-factor authentication is enabled for the user.
  """
  @callback two_factor_auth_enabled?(user :: User.t()) :: boolean()

  @doc """
  Gets the UserTOTP entry for a user, if any.
  """
  @callback get_user_totp(user :: User.t()) :: any() | nil

  @doc """
  Returns an Ecto.Changeset for changing user TOTP settings.
  """
  @callback change_user_totp(totp :: any(), attrs :: map()) :: Ecto.Changeset.t()

  @doc """
  Creates or updates the TOTP configuration for a user.
  The secret is validated against the provided OTP code.
  """
  @callback upsert_user_totp(totp :: any(), attrs :: map()) ::
              {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Regenerates backup codes for the user's TOTP configuration.
  """
  @callback regenerate_user_totp_backup_codes(totp :: any()) ::
              {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Deletes the TOTP configuration for a user.
  """
  @callback delete_user_totp(user_totp :: any()) :: {:ok, any()} | {:error, Ecto.Changeset.t()}

  @doc """
  Validates a TOTP code for a user.
  Returns :valid_totp, {:valid_backup_code, remaining_count}, or :invalid.
  """
  @callback validate_user_totp(user :: User.t(), code :: String.t()) ::
              :valid_totp | {:valid_backup_code, non_neg_integer()} | :invalid

  @doc """
  Gets all user connections from a shared item.
  """
  @callback get_all_user_connections_from_shared_item(item :: any(), current_user :: User.t()) ::
              [UserConnection.t()]

  @doc """
  Updates a user's forgot password flag.
  """
  @callback update_user_forgot_password(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a user's Oban reset token ID.
  """
  @callback update_user_oban_reset_token_id(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | {:error, Ecto.Changeset.t()}

  @doc """
  Updates a user's admin status.
  """
  @callback update_user_admin(user :: User.t(), attrs :: map(), opts :: keyword()) ::
              {:ok, User.t()} | nil

  @doc """
  Updates when a user last signed in with IP address.
  """
  @callback update_last_signed_in_info(user :: User.t(), ip :: String.t(), key :: binary()) ::
              {:ok, User.t()} | {:error, any()}

  @doc """
  Preloads user's organization data.
  """
  @callback preload_org_data(user :: User.t(), current_org_slug :: String.t() | nil) :: User.t()

  @doc """
  Preloads associations on a user connection.
  """
  @callback preload_user_connection(user_connection :: UserConnection.t(), preloads :: list()) ::
              UserConnection.t()

  @doc """
  Preloads associations on a connection.
  """
  @callback preload_connection_assocs(connection :: Connection.t(), preloads :: list()) ::
              Connection.t()

  # ============================================================================
  # Delete User Data Functions (thin wrappers for delete_user_data orchestration)
  # ============================================================================

  @doc """
  Deletes all user connections for a user.
  """
  @callback delete_all_user_connections(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all groups for a user.
  """
  @callback delete_all_groups(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all memories for a user.
  """
  @callback delete_all_memories(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all posts for a user.
  """
  @callback delete_all_posts(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all user_memories for a user connection.
  """
  @callback delete_all_user_memories(uconn :: UserConnection.t()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Deletes all user_posts for a user connection.
  """
  @callback delete_all_user_posts(uconn :: UserConnection.t()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Deletes all remarks for a user.
  """
  @callback delete_all_remarks(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all replies for a user.
  """
  @callback delete_all_replies(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all bookmarks for a user.
  """
  @callback delete_all_bookmarks(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Deletes all journals (entries and books) for a user.
  """
  @callback delete_all_journals(user_id :: String.t()) ::
              {:ok, integer()} | {:error, any()}

  @doc """
  Cleans up shared_users embeds from posts when a connection is deleted.
  """
  @callback cleanup_shared_users_from_posts(
              uconn_user_id :: String.t(),
              uconn_reverse_user_id :: String.t()
            ) :: {:ok, :cleaned}

  @doc """
  Cleans up shared_users embeds from memories when a connection is deleted.
  """
  @callback cleanup_shared_users_from_memories(
              uconn_user_id :: String.t(),
              uconn_reverse_user_id :: String.t()
            ) :: {:ok, :cleaned}

  @doc """
  Gets all memories for a user (for extracting URLs before deletion).
  """
  @callback get_all_memories_for_user(user_id :: String.t()) :: [any()]

  @doc """
  Gets all posts for a user with replies preloaded (for extracting URLs before deletion).
  """
  @callback get_all_posts_for_user(user_id :: String.t()) :: [any()]

  @doc """
  Gets all replies for a user with post preloaded (for extracting URLs before deletion).
  """
  @callback get_all_replies_for_user(user_id :: String.t()) :: [any()]
end
