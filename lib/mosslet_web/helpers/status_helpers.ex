defmodule MossletWeb.Helpers.StatusHelpers do
  @moduledoc """
  Consolidated helper functions for handling user status and status messages
  across the application. This module provides a consistent interface for
  decrypting and displaying status messages while respecting privacy settings.
  """

  alias Mosslet.Accounts
  alias Mosslet.Statuses
  alias Mosslet.Encrypted

  @doc """
  Gets the decrypted status message for any user, handling both current user
  and connected user scenarios with proper encryption key management.

  ## Parameters
  - `user` - The user whose status message to retrieve
  - `current_user` - The viewing user (for permission checks)
  - `session_key` - The session encryption key

  ## Returns
  - A string status message or `nil` if no message exists or cannot be decrypted

  ## Examples
      iex> get_user_status_message(user, current_user, session_key)
      "I'm focusing on deep work today"

      iex> get_user_status_message(user, user, session_key)
      "My personal status message"
  """
  def get_user_status_message(user, current_user, session_key) do
    cond do
      # Case 1: Current user's own status -> decrypt with user_key
      user.id == current_user.id ->
        get_current_user_status_message(user, session_key)

      # Case 2: Connected user's status -> use Status module with proper privacy handling
      true ->
        get_connected_user_status_message(user, current_user, session_key)
    end
  end

  @doc """
  Gets the current user's own status message, decrypted with their user_key.
  Provides consistent fallback behavior based on their status type.

  ## Parameters
  - `user` - The current user
  - `session_key` - The session encryption key

  ## Returns
  - A string status message or fallback message based on user status
  """
  def get_current_user_status_message(user, session_key) do
    if user.status_message do
      case Encrypted.Users.Utils.decrypt_user_data(user.status_message, user, session_key) do
        decrypted_message when is_binary(decrypted_message) and decrypted_message != "" ->
          decrypted_message

        :failed_verification ->
          get_status_fallback_message(user.status)
      end
    else
      get_status_fallback_message(user.status)
    end
  end

  @doc """
  Gets a connected user's status message, respecting privacy settings and
  using the proper encryption keys through the Status module.

  ## Parameters
  - `target_user` - The user whose status message to retrieve
  - `current_user` - The viewing user
  - `session_key` - The session encryption key

  ## Returns
  - A string status message or `nil` if not accessible
  """
  def get_connected_user_status_message(target_user, current_user, session_key) do
    case Statuses.get_user_status_for_viewer(target_user, current_user, session_key) do
      %{status_message: status_message}
      when is_binary(status_message) and status_message != "" ->
        status_message

      _result ->
        nil
    end
  end

  @doc """
  Gets the status message for a connection card display, handling the
  connection structure and extracting the proper user information.

  ## Parameters
  - `connection` - The user connection struct
  - `current_user` - The viewing user
  - `session_key` - The session encryption key

  ## Returns
  - A string status message or `nil` if not accessible
  """
  def get_connection_status_message(connection, current_user, session_key) do
    case connection.connection do
      %{user_id: connected_user_id} ->
        case Accounts.get_user_with_preloads(connected_user_id) do
          %{} = connected_user ->
            get_user_status_message(connected_user, current_user, session_key)

          nil ->
            nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Gets the status (not message) for a connected user, handling privacy settings.

  ## Parameters
  - `connection` - The user connection struct
  - `current_user` - The viewing user
  - `session_key` - The session encryption key

  ## Returns
  - A string representation of the status or `nil` if not accessible
  """
  def get_connection_user_status(connection, current_user, session_key) do
    case connection.connection do
      %{user_id: connected_user_id} ->
        case Accounts.get_user_with_preloads(connected_user_id) do
          %{} = connected_user ->
            case Statuses.can_view_user_status?(
                   connected_user,
                   current_user,
                   session_key
                 ) do
              {:ok, :full_access} -> to_string(connected_user.status || "offline")
              {:error, :private} -> nil
            end

          nil ->
            nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Provides consistent fallback messages based on user status when no custom
  status message is available or decryption fails.

  ## Parameters
  - `status` - The user's status atom

  ## Returns
  - A string fallback message appropriate for the status
  """
  def get_status_fallback_message(status) do
    case status do
      :calm -> "Mindfully connected"
      :active -> "Active and engaged"
      :busy -> "Focused and productive"
      :away -> "Away for a while"
      :offline -> "Taking a peaceful break"
      _ -> "Mindfully connected"
    end
  end

  @doc """
  Checks if a user has a custom status message (not just the fallback).

  ## Parameters
  - `user` - The user to check
  - `current_user` - The viewing user (for permission checks)
  - `session_key` - The session encryption key

  ## Returns
  - `true` if user has a custom status message, `false` otherwise
  """
  def has_custom_status_message?(user, current_user, session_key) do
    status_message = get_user_status_message(user, current_user, session_key)
    fallback_message = get_status_fallback_message(user.status)

    status_message != nil and status_message != fallback_message
  end

  @doc """
  Gets both status and status message for a user in a single call,
  optimized for components that need both pieces of information.

  ## Parameters
  - `user` - The user whose status info to retrieve
  - `current_user` - The viewing user
  - `session_key` - The session encryption key

  ## Returns
  - A map with `:status` and `:status_message` keys, or `nil` values if not accessible
  """
  def get_user_status_info(user, current_user, session_key) do
    cond do
      user.id == current_user.id ->
        %{
          status: to_string(user.status || "offline"),
          status_message: get_current_user_status_message(user, session_key)
        }

      true ->
        case Statuses.get_user_status_for_viewer(user, current_user, session_key) do
          %{status: status, status_message: status_message} ->
            %{
              status: to_string(status || "offline"),
              status_message: status_message
            }

          _rest ->
            %{status: nil, status_message: nil}
        end
    end
  end

  def can_view_status?(user, current_user, session_key) do
    case Statuses.can_view_user_status?(user, current_user, session_key) do
      {:error, :private} -> false
      _rest -> true
    end
  end
end
