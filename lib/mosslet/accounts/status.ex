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
end
