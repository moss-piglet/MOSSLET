defmodule Mosslet.Accounts.Status do
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

  @doc """
  Updates a user's status and status message.

  Follows the dual-update pattern:
  1. Updates user.status_message (encrypted with user_key)
  2. Updates connection.status_message (encrypted with conn_key)
  3. Broadcasts update to connections via PubSub
  """
  def update_user_status(user, attrs, opts \\ []) do
    case Repo.transaction_on_primary(fn ->
           # Update user record (personal status)
           case user
                |> User.status_changeset(attrs, opts)
                |> Repo.update() do
             {:ok, updated_user} ->
               # Update connection record (shared status) if connection_map was set
               if updated_user.connection_map do
                 update_connection_status(updated_user, updated_user.connection_map)
               end

               # Update activity timestamp
               update_user_activity(updated_user)

               # Broadcast status change to connections
               broadcast_status_update(updated_user)

               {:ok, updated_user}

             {:error, changeset} ->
               {:error, changeset}
           end
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
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
           case user
                |> User.status_visibility_changeset(attrs, opts)
                |> Repo.update() do
             {:ok, updated_user} ->
               # Update connection record (shared status visibility) if connection_map was set
               if updated_user.connection_map do
                 IO.inspect(updated_user.connection_map, label: "DEBUG: Connection map to save")
                 result = update_connection_status_visibility(updated_user, updated_user.connection_map)
                 IO.inspect(result, label: "DEBUG: Connection update result")
               else
                 IO.inspect("DEBUG: No connection_map found on updated_user")
               end

               # Broadcast status visibility change to connections
               broadcast_status_visibility_update(updated_user)

               {:ok, updated_user}

             {:error, changeset} ->
               {:error, changeset}
           end
         end) do
      {:ok, {:ok, user}} -> {:ok, user}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
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
    case Accounts.get_user_connection_between_users(viewing_user, user) do
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

  defp update_connection_status(user, connection_map) do
    if user.connection do
      case Repo.transaction_on_primary(fn ->
             user.connection
             |> Connection.update_status_changeset(%{
               status: connection_map[:c_status],
               status_message: connection_map[:c_status_message],
               status_message_hash: connection_map[:c_status_message_hash],
               status_updated_at: connection_map[:c_status_updated_at]
             })
             |> Repo.update()
           end) do
        {:ok, {:ok, _connection}} -> :ok
        _ -> :error
      end
    end
  end

  defp update_user_activity(user) do
    case Repo.transaction_on_primary(fn ->
           user
           |> User.activity_changeset(%{last_activity_at: NaiveDateTime.utc_now()})
           |> Repo.update()
         end) do
      {:ok, {:ok, _user}} -> :ok
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
    case Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(
           user_connection.key,
           viewing_user,
           session_key
         ) do
      {:ok, conn_key} ->
        case Mosslet.Encrypted.Utils.decrypt(%{key: conn_key, payload: encrypted_message}) do
          {:ok, decrypted_message} -> decrypted_message
          _ -> "Unable to decrypt status"
        end

      _ ->
        "Unable to decrypt status"
    end
  end

  defp broadcast_status_update(user) do
    # Broadcast to user's connections that their status changed
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "user_status:#{user.id}",
      {:status_updated, user.id, user.status, user.status_updated_at}
    )

    # Broadcast to connections topic for real-time updates
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "connections",
      {:user_status_changed, user.id, user.status}
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
        # Full status access - decrypt everything
        get_decrypted_status_with_message(target_user, viewing_user, session_key)

      {:ok, :presence_only} ->
        # Only online/offline, no status message
        %{
          status: get_presence_status(target_user),
          status_message: nil,
          updated_at: target_user.status_updated_at,
          online: is_user_online?(target_user)
        }

      {:error, :private} ->
        # No status visibility
        %{status: :offline, status_message: nil, updated_at: nil, online: false}
    end
  end

  @doc """
  Determines if viewing_user can see target_user's status based on privacy settings.
  Follows the same granular privacy pattern as posts.
  """
  def can_view_user_status?(target_user, viewing_user, session_key) do
    # Check user.visibility hierarchy first
    case {target_user.visibility, target_user.status_visibility || :nobody} do
      # Private users: only nobody or connections allowed
      {:private, :nobody} ->
        {:error, :private}

      {:private, :connections} ->
        check_connection_status_access(target_user, viewing_user)

      # Connections users: can share with connections, groups, users (but not public)
      {:connections, :nobody} ->
        {:error, :private}

      {:connections, :connections} ->
        check_connection_status_access(target_user, viewing_user)

      {:connections, :specific_groups} ->
        check_specific_groups_status_access(target_user, viewing_user, session_key)

      {:connections, :specific_users} ->
        check_specific_users_status_access(target_user, viewing_user, session_key)

      # Public users: can use any status visibility including public
      {:public, :nobody} ->
        {:error, :private}

      {:public, :connections} ->
        check_connection_status_access(target_user, viewing_user)

      {:public, :specific_groups} ->
        check_specific_groups_status_access(target_user, viewing_user, session_key)

      {:public, :specific_users} ->
        check_specific_users_status_access(target_user, viewing_user, session_key)

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
    if Accounts.has_user_connection?(target_user.id, viewing_user.id) do
      {:ok, :full_access}
    else
      {:error, :private}
    end
  end

  defp check_specific_groups_status_access(target_user, viewing_user, session_key) do
    # Check if viewing_user is in any of target_user's status-visible groups
    if user_in_status_visible_groups?(target_user, viewing_user, session_key) do
      {:ok, :full_access}
    else
      # Fall back to presence-only if they have presence access
      check_presence_only_access(target_user, viewing_user, session_key)
    end
  end

  defp check_specific_users_status_access(target_user, viewing_user, session_key) do
    # Check if viewing_user is explicitly in target_user's status-visible users list
    if user_in_status_visible_users?(target_user, viewing_user, session_key) do
      {:ok, :full_access}
    else
      # Fall back to presence-only if they have presence access
      check_presence_only_access(target_user, viewing_user, session_key)
    end
  end

  defp check_presence_only_access(target_user, viewing_user, session_key) do
    if target_user.show_online_presence do
      # Check if user can see presence (different from status message)
      if user_can_see_presence?(target_user, viewing_user, session_key) do
        {:ok, :presence_only}
      else
        {:error, :private}
      end
    else
      {:error, :private}
    end
  end

  defp user_in_status_visible_groups?(target_user, viewing_user, session_key) do
    # Get user_connection between them to access group memberships
    case Accounts.get_user_connection_between_users(viewing_user, target_user) do
      nil ->
        false

      user_connection ->
        # Check if viewing_user is in any of target_user's status-visible visibility groups
        target_user.visibility_groups
        |> Enum.any?(fn group ->
          # Decrypt group's connection_ids and check if user_connection.id is in there
          group_connection_ids = decrypt_group_connection_ids(group, target_user, session_key)
          user_connection.id in (group_connection_ids || [])
        end)
    end
  end

  defp user_in_status_visible_users?(target_user, viewing_user, session_key) do
    # Decrypt target_user's status_visible_to_users list and check if viewing_user.id is in it
    status_visible_users = decrypt_status_visible_users(target_user, session_key)
    viewing_user.id in (status_visible_users || [])
  end

  defp user_can_see_presence?(target_user, viewing_user, session_key) do
    # Similar logic but for presence visibility controls
    case {target_user.presence_visible_to_groups, target_user.presence_visible_to_users} do
      {[], []} ->
        # If no specific groups/users set, fall back to connection access
        Accounts.has_user_connection?(target_user.id, viewing_user.id)

      _ ->
        # Check specific presence groups/users
        user_in_presence_visible_groups?(target_user, viewing_user, session_key) or
          user_in_presence_visible_users?(target_user, viewing_user, session_key)
    end
  end

  defp user_in_presence_visible_groups?(target_user, viewing_user, session_key) do
    # Similar to status groups but for presence
    case Accounts.get_user_connection_between_users(viewing_user, target_user) do
      nil ->
        false

      user_connection ->
        presence_group_ids = decrypt_presence_visible_groups(target_user, session_key)

        target_user.visibility_groups
        |> Enum.any?(fn group ->
          group.id in (presence_group_ids || []) and
            user_connection.id in (decrypt_group_connection_ids(group, target_user, session_key) ||
                                     [])
        end)
    end
  end

  defp user_in_presence_visible_users?(target_user, viewing_user, session_key) do
    # Check if viewing_user is in target_user's presence-visible users list
    presence_visible_users = decrypt_presence_visible_users(target_user, session_key)
    viewing_user.id in (presence_visible_users || [])
  end

  defp get_decrypted_status_with_message(target_user, viewing_user, session_key) do
    # Get decrypted status message via connection
    case Accounts.get_user_connection_between_users(viewing_user, target_user) do
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

  defp get_presence_status(user) do
    # Get basic presence status (online/offline/away/etc.) without message
    if is_user_online?(user) do
      user.status || :calm
    else
      :offline
    end
  end

  defp is_user_online?(user) do
    # Check if user is currently online via Presence
    MossletWeb.Presence.user_active_on_timeline?(user.id)
  end

  defp update_connection_status_visibility(user, connection_map) do
    if user.connection do
      case Repo.transaction_on_primary(fn ->
             # Ensure connection is loaded
             user = user |> Repo.preload(:connection)
             # Map the c_ prefixed keys to the expected field names
             mapped_attrs = %{
               status_visibility: connection_map[:c_status_visibility],
               status_visible_to_groups: connection_map[:c_status_visible_to_groups],
               status_visible_to_users: connection_map[:c_status_visible_to_users],
               show_online_presence: connection_map[:c_show_online_presence],
               presence_visible_to_groups: connection_map[:c_presence_visible_to_groups],
               presence_visible_to_users: connection_map[:c_presence_visible_to_users]
             }
             IO.inspect(mapped_attrs, label: "DEBUG: Mapped connection attrs")
             
             user.connection
             |> Connection.update_status_visibility_changeset(mapped_attrs)
             |> Repo.update()
           end) do
        {:ok, {:ok, _connection}} -> :ok
        _ -> :error
      end
    end
  end

  defp broadcast_status_visibility_update(user) do
    # Broadcast to connections that user's status visibility changed
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "user_status_visibility:#{user.id}",
      {:status_visibility_updated, user.id, user.status_visibility}
    )
  end

  # Decryption helper functions
  defp decrypt_status_visible_users(user, session_key) do
    # Decrypt user.status_visible_to_users list
    case user.status_visible_to_users do
      encrypted_list when is_list(encrypted_list) and length(encrypted_list) > 0 ->
        Enum.map(encrypted_list, fn encrypted_user_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                 encrypted_user_id,
                 user,
                 session_key
               ) do
            {:ok, user_id} -> user_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp decrypt_presence_visible_groups(user, session_key) do
    # Similar for presence groups
    case user.presence_visible_to_groups do
      encrypted_list when is_list(encrypted_list) and length(encrypted_list) > 0 ->
        Enum.map(encrypted_list, fn encrypted_group_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                 encrypted_group_id,
                 user,
                 session_key
               ) do
            {:ok, group_id} -> group_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp decrypt_presence_visible_users(user, session_key) do
    # Similar for presence users
    case user.presence_visible_to_users do
      encrypted_list when is_list(encrypted_list) and length(encrypted_list) > 0 ->
        Enum.map(encrypted_list, fn encrypted_user_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                 encrypted_user_id,
                 user,
                 session_key
               ) do
            {:ok, user_id} -> user_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp decrypt_group_connection_ids(group, user, session_key) do
    # Decrypt visibility group's connection_ids list
    case group.connection_ids do
      encrypted_list when is_list(encrypted_list) and length(encrypted_list) > 0 ->
        Enum.map(encrypted_list, fn encrypted_connection_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
                 encrypted_connection_id,
                 user,
                 session_key
               ) do
            {:ok, connection_id} -> connection_id
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end
end
