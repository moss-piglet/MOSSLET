defmodule Mosslet.Statuses do
  @moduledoc """
  Context for handling user status and presence.

  Follows the dual-update pattern where status is stored in both:
  1. User table (personal, encrypted with user_key)
  2. Connection table (shared, encrypted with conn_key)

  This mirrors the same pattern used for username/email/avatar updates.
  """

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{User, Connection}
  alias Mosslet.Repo

  require Logger

  @doc """
  Updates a user's status and status message.

  Follows the dual-update pattern:
  1. Updates user.status_message (encrypted with user_key)
  2. Updates connection.status_message (encrypted with conn_key)
  3. Broadcasts update to connections via PubSub

  conn = get_connection!(user.connection.id)
    opts = [key: key, user: user]

    changeset =
      user
      |> User.email_changeset(%{email: email}, opts)
      |> User.confirm_changeset()

    c_attrs = changeset.changes.connection_map

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.update(:connection, fn %{user: _user} ->
      Connection.update_email_changeset(conn, %{
        email: c_attrs.c_email,
        email_hash: c_attrs.c_email_hash
      })
    end)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))

  """
  def update_user_status(user, attrs, opts \\ []) do
    conn = Accounts.get_connection!(user.connection.id)

    changeset =
      user
      |> User.status_changeset(attrs, opts)

    c_attrs = changeset.changes.connection_map

    case Ecto.Multi.new()
         |> Ecto.Multi.update(:user, changeset)
         |> Ecto.Multi.update(:update_connection, fn %{user: _user} ->
           Connection.update_status_changeset(conn, %{
             status: c_attrs.c_status,
             status_message: c_attrs.c_status_message,
             status_message_hash: c_attrs.c_status_message_hash,
             status_updated_at: c_attrs.c_status_updated_at
           })
         end)
         |> Repo.transaction_on_primary() do
      # Update activity timestamp
      {:ok, %{update_connection: _connection, user: user}} ->
        user = update_user_activity(user)

        # Broadcast status change using accounts context
        # Delegate to accounts context for broadcasting
        {:ok, user |> Repo.preload(:connection)}
        |> Accounts.broadcast_user_status(:status_updated)

      {:ok, {:ok, {:error, changeset}}} ->
        {:error, changeset}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      {:error, :update_user, changeset, _} ->
        {:error, changeset}

      error ->
        Logger.info("Error updating user status.")
        Logger.info(inspect(error))
        Logger.error(error)
        {:error, "Error updating user status"}
    end
  end

  @doc """
  Updates a user's status visibility controls.

  Follows the dual-update pattern:
  1. Updates user status visibility settings (encrypted with user_key)
  2. Updates connection status visibility settings (encrypted with conn_key)
  3. Respects user.visibility hierarchy (private users can't share status publicly)
  4. Broadcasts visibility change to affected connections
  """
  def update_user_status_visibility(user, attrs, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           # Update user record (personal status visibility settings)
           changeset = user |> User.status_visibility_changeset(attrs, opts)

           case Repo.update(changeset) do
             {:ok, updated_user} ->
               # Update connection record (shared status visibility) if connection_map was set

               if updated_user.connection_map do
                 update_connection_status_visibility(
                   updated_user,
                   updated_user.connection_map
                 )
               end

               # Broadcast status visibility change to connections
               {:ok, updated_user |> Repo.preload(:connection)}
               |> Accounts.broadcast_user_status(:status_visibility_updated)

             {:error, changeset} ->
               {:error, changeset}
           end
         end) do
      {:ok, {:ok, user}} ->
        {:ok, user}

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        Logger.info("Error updating user status visibility.")
        Logger.info(inspect(error))
        Logger.error(error)
        {:error, "Error updating user status visibility"}
    end
  end

  @doc """
  Auto-updates user status based on their activity.
  Called periodically or on user actions.
  """
  def auto_update_status_from_activity(user) do
    if user.auto_status do
      last_activity = user.last_activity_at || user.inserted_at
      new_status = determine_status_from_activity(last_activity)

      if new_status != String.to_existing_atom(user.status) do
        # Only update status enum, not status_message
        update_user_status(user, %{status: new_status}, auto_update: true)
      else
        {:ok, user}
      end
    else
      {:ok, user}
    end
  end

  @doc """
  Updates user activity timestamp.
  Called on posts, likes, replies, etc.
  """
  def track_user_activity(user, activity_type \\ :general) do
    attrs = %{last_activity_at: NaiveDateTime.utc_now()}

    attrs =
      case activity_type do
        :post -> Map.put(attrs, :last_post_at, NaiveDateTime.utc_now())
        _ -> attrs
      end

    case Repo.transaction_on_primary(fn ->
           user
           |> User.activity_changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_user}} ->
        # Check if auto-status should be updated
        auto_update_status_from_activity(updated_user)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      error ->
        error
    end
  end

  @doc """
  Gets the visible status for a user as seen by another user.
  Follows the connection access pattern.
  """
  def get_user_status_for_connection(user, viewing_user, session_key) do
    # FIXED: Pass user IDs, not structs
    case Accounts.get_user_connection_between_users(viewing_user.id, user.id) do
      nil ->
        # No connection - only show basic status if public
        if user.visibility == :public do
          %{status: user.status, status_message: nil, updated_at: user.status_updated_at}
        else
          %{status: :offline, status_message: nil, updated_at: nil}
        end

      user_connection ->
        # Has connection - decrypt shared status from connection
        connection = user.connection

        if connection && connection.status_message do
          decrypted_message =
            decrypt_connection_status_message(
              connection.status_message,
              user_connection,
              viewing_user,
              session_key
            )

          %{
            status: connection.status,
            status_message: decrypted_message,
            updated_at: connection.status_updated_at
          }
        else
          %{
            status: connection.status || :offline,
            status_message: nil,
            updated_at: connection.status_updated_at
          }
        end
    end
  end

  # Private functions

  defp update_user_activity(user) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.activity_changeset(%{
             last_activity_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
           })
           |> Repo.update()
         end) do
      {:ok, {:ok, user}} -> user
      _ -> :error
    end
  end

  defp determine_status_from_activity(last_activity) do
    minutes_ago = NaiveDateTime.diff(NaiveDateTime.utc_now(), last_activity, :second) / 60

    cond do
      # Active in last 5 minutes
      minutes_ago < 5 -> :active
      # Recently active but not posting
      minutes_ago < 30 -> :calm
      # Away for 1-2 hours
      minutes_ago < 120 -> :away
      # Offline for 2+ hours
      true -> :offline
    end
  end

  defp decrypt_connection_status_message(
         encrypted_message,
         user_connection,
         viewing_user,
         session_key
       ) do
    Mosslet.Encrypted.Users.Utils.decrypt_item(
      encrypted_message,
      viewing_user,
      user_connection.key,
      session_key
    )
  end

  # Enhanced Status Visibility Functions

  @doc """
  Enhanced status access with granular privacy controls.
  Replaces get_user_status_for_connection with privacy-aware logic.
  """
  def get_user_status_for_viewer(target_user, viewing_user, session_key) do
    case can_view_user_status?(target_user, viewing_user, session_key) do
      {:ok, :full_access} ->
        get_decrypted_status_with_message(target_user, viewing_user, session_key)

      {:error, :private} ->
        %{status: :offline, status_message: nil, updated_at: nil, online: false}
    end
  end

  @doc """
  Determines if viewing_user can see target_user's status based on privacy settings.
  Follows the same granular privacy pattern as posts.
  """
  def can_view_user_status?(user, current_user, session_key) do
    # Check user.visibility hierarchy first
    case {user.visibility, user.status_visibility || :nobody} do
      # Private users: only nobody or connections allowed
      {:private, :nobody} ->
        {:error, :private}

      {:private, :connections} ->
        check_connection_status_access(user, current_user)

      # Connections users: can share with connections, groups, users (but not public)
      {:connections, :nobody} ->
        {:error, :private}

      {:connections, :connections} ->
        check_connection_status_access(user, current_user)

      {:connections, :specific_groups} ->
        check_specific_groups_status_access(user, current_user, session_key)

      {:connections, :specific_users} ->
        check_specific_users_status_access(user, current_user, session_key)

      # Public users: can use any status visibility including public
      {:public, :nobody} ->
        {:error, :private}

      {:public, :connections} ->
        check_connection_status_access(user, current_user)

      {:public, :specific_groups} ->
        check_specific_groups_status_access(user, current_user, session_key)

      {:public, :specific_users} ->
        check_specific_users_status_access(user, current_user, session_key)

      # Public status for everyone
      {:public, :public} ->
        {:ok, :full_access}

      # Default: no access
      _ ->
        {:error, :private}
    end
  end

  # Private helper functions for granular status access

  defp check_connection_status_access(target_user, viewing_user) do
    # FIXED: Pass User structs, not IDs - the has_user_connection function expects structs
    if Accounts.has_user_connection?(target_user, viewing_user) do
      # we also check if the target_user is allowing people to view their presence
      case target_user.show_online_presence do
        true -> {:ok, :full_access}
        false -> {:error, :private}
      end
    else
      {:error, :private}
    end
  end

  defp check_specific_groups_status_access(target_user, viewing_user, session_key) do
    # Check if viewing_user is in any of target_user's status-visible groups
    if user_in_status_visible_groups?(target_user, viewing_user, session_key) do
      case target_user.show_online_presence do
        true -> {:ok, :full_access}
        false -> {:error, :private}
      end
    else
      {:error, :private}
    end
  end

  defp check_specific_users_status_access(user, current_user, session_key) do
    # Check if current_user is explicitly in user's status-visible users list
    in_specific_users? = user_in_status_visible_users?(user, current_user, session_key)

    if in_specific_users? do
      case user.show_online_presence do
        true -> {:ok, :full_access}
        false -> {:error, :private}
      end
    else
      {:error, :private}
    end
  end

  defp user_in_status_visible_groups?(target_user, viewing_user, session_key) do
    # Get user_connection between them to access group memberships
    # FIXED: Pass user IDs, not structs
    # Get the current user's UserConnection that points to the target user
    # This contains the target user's conn_key encrypted for the current user
    case Accounts.get_user_connection_between_users(target_user.id, viewing_user.id) do
      nil ->
        false

      user_connection ->
        # Check if viewing_user is in any of target_user's connection status_visible_groups list
        status_groups_user_ids =
          decrypt_presence_visible_groups_user_ids(
            target_user,
            viewing_user,
            user_connection,
            session_key
          )

        reverse_connection =
          Accounts.get_user_connection_between_users(viewing_user.id, target_user.id)

        viewing_user.id in [reverse_connection.user_id, reverse_connection.reverse_user_id] &&
          reverse_connection.id in status_groups_user_ids
    end
  end

  defp user_in_status_visible_users?(user, current_user, session_key) do
    if user.connection && user.connection.status_visible_to_users do
      # We need the UserConnection where current_user.id is the user_id
      # This contains the target user's conn_key encrypted for current_user
      # Based on our debugging, this is the reverse direction
      user_connection = Accounts.get_user_connection_between_users(user.id, current_user.id)

      case user_connection do
        nil ->
          false

        uc ->
          # First decrypt the connection key, then decrypt the user IDs
          encrypted_list = user.connection.status_visible_to_users

          decrypted_user_ids =
            encrypted_list
            |> Enum.map(fn encrypted_user_id ->
              case Mosslet.Encrypted.Users.Utils.decrypt_item(
                     encrypted_user_id,
                     current_user,
                     uc.key,
                     session_key
                   ) do
                user_id when is_binary(user_id) ->
                  user_id

                :failed_verification ->
                  nil
              end
            end)
            |> Enum.reject(&is_nil/1)

          current_user.id in decrypted_user_ids
      end
    else
      false
    end
  end

  defp get_decrypted_status_with_message(target_user, viewing_user, session_key) do
    # Get decrypted status message via connection
    case Accounts.get_user_connection_between_users(target_user.id, viewing_user.id) do
      nil ->
        # No connection - show status without message
        %{
          status: target_user.status || :offline,
          status_message: nil,
          updated_at: target_user.status_updated_at,
          online: is_user_online?(target_user)
        }

      user_connection ->
        # Has connection - decrypt shared status from connection
        connection = target_user.connection

        if connection && connection.status_message do
          decrypted_message =
            decrypt_connection_status_message(
              connection.status_message,
              user_connection,
              viewing_user,
              session_key
            )

          %{
            status: connection.status || :offline,
            status_message: decrypted_message,
            updated_at: connection.status_updated_at,
            online: is_user_online?(target_user)
          }
        else
          %{
            status: connection.status || :offline,
            status_message: nil,
            updated_at: connection.status_updated_at,
            online: is_user_online?(target_user)
          }
        end
    end
  end

  defp is_user_online?(user) do
    # Check if user is currently online via Presence
    MossletWeb.Presence.user_active_on_timeline?(user.id)
  end

  defp update_connection_status_visibility(user, connection_map) do
    case Repo.transaction_on_primary(fn ->
           # Map the c_ prefixed keys to the expected field names
           mapped_attrs = %{
             status_visibility: connection_map[:c_status_visibility],
             status_visible_to_groups: connection_map[:c_status_visible_to_groups],
             status_visible_to_users: connection_map[:c_status_visible_to_users],
             status_visible_to_groups_user_ids:
               connection_map[:c_status_visible_to_groups_user_ids],
             show_online_presence: connection_map[:c_show_online_presence],
             presence_visible_to_groups: connection_map[:c_presence_visible_to_groups],
             presence_visible_to_users: connection_map[:c_presence_visible_to_users],
             presence_visible_to_groups_user_ids:
               connection_map[:c_presence_visible_to_groups_user_ids]
           }

           user.connection
           |> Connection.update_status_visibility_changeset(mapped_attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, _connection}} -> :ok
      _ -> :error
    end
  end

  # Status visibility broadcast moved to Mosslet.Accounts context

  # Decryption helper functions
  defp decrypt_presence_visible_groups_user_ids(
         target_user,
         viewing_user,
         user_connection,
         session_key
       ) do
    with encrypted_list when is_list(encrypted_list) and length(encrypted_list) > 0 <-
           target_user.connection.presence_visible_to_groups_user_ids do
      encrypted_list
      |> Enum.map(fn encrypted_group_user_id ->
        case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
               encrypted_group_user_id,
               viewing_user,
               user_connection.key,
               session_key
             ) do
          user_id when is_binary(user_id) -> user_id
          :failed_verification -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end
end
