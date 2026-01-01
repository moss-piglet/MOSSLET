defmodule Mosslet.Statuses do
  @moduledoc """
  Context for handling user status and presence.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Statuses.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Statuses.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.

  Follows the dual-update pattern where status is stored in both:
  1. User table (personal, encrypted with user_key)
  2. Connection table (shared, encrypted with conn_key)

  This mirrors the same pattern used for username/email/avatar updates.
  """

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Platform

  require Logger

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Mosslet.Statuses.Adapters.Native
    else
      Mosslet.Statuses.Adapters.Web
    end
  end

  @doc """
  Updates a user's status and status message.

  Follows the dual-update pattern:
  1. Updates user.status_message (encrypted with user_key)
  2. Updates connection.status_message (encrypted with conn_key)
  3. Broadcasts update to connections via PubSub
  """
  def update_user_status(user, attrs, opts \\ []) do
    conn = Accounts.get_connection!(user.connection.id)

    changeset =
      user
      |> User.status_changeset(attrs, opts)

    c_attrs = changeset.changes.connection_map

    case adapter().update_user_status_multi(changeset, conn, c_attrs) do
      {:ok, user} ->
        {:ok, user}
        |> Accounts.broadcast_user_status(:status_updated)

      {:error, changeset} ->
        {:error, changeset}
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
    changeset = user |> User.status_visibility_changeset(attrs, opts)

    case adapter().update_user_status_visibility(user, changeset) do
      {:ok, updated_user} ->
        {:ok, updated_user}
        |> Accounts.broadcast_user_status(:status_visibility_updated)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Auto-updates user status based on presence and activity.
  Uses Phoenix Presence for online/offline detection and activity timestamps for engagement level.
  Preserves existing status message when auto-updating status.
  """
  def auto_update_status_from_activity(user) do
    if user.auto_status do
      new_status = determine_status_from_presence_and_activity(user)

      if new_status != user.status do
        attrs = %{status: new_status}
        update_user_status(user, attrs, auto_update: true)
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
    attrs = %{}

    attrs =
      case activity_type do
        :post ->
          Map.put(attrs, :last_post_at, NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second))

        :interaction ->
          Map.put(
            attrs,
            :last_activity_at,
            NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
          )

        _ ->
          attrs
      end

    changeset = user |> User.activity_changeset(attrs)

    case adapter().update_user_activity(user, changeset) do
      {:ok, updated_user} ->
        auto_update_status_from_activity(updated_user)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets the visible status for a user as seen by another user.
  Follows the connection access pattern.
  """
  def get_user_status_for_connection(user, viewing_user, session_key) do
    case Accounts.get_user_connection_between_users(viewing_user.id, user.id) do
      nil ->
        if user.visibility == :public do
          %{status: user.status, status_message: nil, updated_at: user.status_updated_at}
        else
          %{status: :offline, status_message: nil, updated_at: nil}
        end

      user_connection ->
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

  defp determine_status_from_presence_and_activity(user) do
    if user.status == :busy do
      :busy
    else
      if MossletWeb.Presence.user_active_in_app?(user.id) do
        minutes_since_activity = get_minutes_since_last_activity(user)

        cond do
          minutes_since_activity < 2 -> :active
          minutes_since_activity < 10 -> :calm
          true -> :away
        end
      else
        :offline
      end
    end
  end

  defp get_minutes_since_last_activity(user) do
    last_activity =
      case {user.last_activity_at, user.last_post_at} do
        {nil, nil} ->
          user.inserted_at

        {activity_at, nil} ->
          activity_at

        {nil, post_at} ->
          post_at

        {activity_at, post_at} ->
          if NaiveDateTime.compare(activity_at, post_at) == :gt do
            activity_at
          else
            post_at
          end
      end

    NaiveDateTime.diff(NaiveDateTime.utc_now(), last_activity, :second) / 60
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
    case {user.visibility, user.status_visibility || :nobody} do
      {:private, :nobody} ->
        {:error, :private}

      {:private, :connections} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_connection_status_access(user, current_user)
        end

      {:connections, :nobody} ->
        {:error, :private}

      {:connections, :connections} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_connection_status_access(user, current_user)
        end

      {:connections, :specific_groups} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_specific_groups_status_access(user, current_user, session_key)
        end

      {:connections, :specific_users} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_specific_users_status_access(user, current_user, session_key)
        end

      {:public, :nobody} ->
        {:error, :private}

      {:public, :connections} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_connection_status_access(user, current_user)
        end

      {:public, :specific_groups} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_specific_groups_status_access(user, current_user, session_key)
        end

      {:public, :specific_users} ->
        if user.id == current_user.id do
          {:ok, :full_access}
        else
          check_specific_users_status_access(user, current_user, session_key)
        end

      {:public, :public} ->
        {:ok, :full_access}

      _ ->
        {:error, :private}
    end
  end

  # Private helper functions for granular status access

  defp check_connection_status_access(target_user, viewing_user) do
    if Accounts.has_user_connection?(target_user, viewing_user) do
      case target_user.show_online_presence do
        true -> {:ok, :full_access}
        false -> {:error, :private}
      end
    else
      {:error, :private}
    end
  end

  defp check_specific_groups_status_access(target_user, viewing_user, session_key) do
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
    case Accounts.get_user_connection_between_users(target_user.id, viewing_user.id) do
      nil ->
        false

      user_connection ->
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
      user_connection = Accounts.get_user_connection_between_users(user.id, current_user.id)

      case user_connection do
        nil ->
          false

        uc ->
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
    case Accounts.get_user_connection_between_users(target_user.id, viewing_user.id) do
      nil ->
        %{
          status: target_user.status || :offline,
          status_message: nil,
          updated_at: target_user.status_updated_at,
          online: is_user_online?(target_user)
        }

      user_connection ->
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
    MossletWeb.Presence.user_active_on_timeline?(user.id)
  end

  defp decrypt_presence_visible_groups_user_ids(
         target_user,
         viewing_user,
         user_connection,
         session_key
       ) do
    with encrypted_list when is_list(encrypted_list) and encrypted_list != [] <-
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
