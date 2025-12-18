defmodule MossletWeb.API.UserController do
  @moduledoc """
  API endpoints for user account operations.

  Handles profile updates, password changes, name/username updates, etc.
  All encrypted data is passed through as-is - native apps handle
  encryption/decryption locally for zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Accounts

  action_fallback MossletWeb.API.FallbackController

  def update_name(conn, %{"name" => _name} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "name" => params["name"],
      "connection_map" => decode_connection_map(params["connection_map"])
    }

    case Accounts.update_user_name(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Name updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_name(_conn, _params), do: {:error, :missing_params}

  def update_username(conn, %{"username" => _username} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "username" => params["username"],
      "connection_map" => decode_connection_map(params["connection_map"])
    }

    case Accounts.update_user_username(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Username updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_username(_conn, _params), do: {:error, :missing_params}

  def update_profile(conn, %{"profile" => profile_params} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "id" => user.connection.id,
      "profile" => profile_params
    }

    opts = [
      key: session_key,
      user: user,
      update_profile: true,
      encrypt: params["encrypt"] == true
    ]

    case Accounts.update_user_profile(user, attrs, opts) do
      {:ok, updated_conn} ->
        conn
        |> put_status(:ok)
        |> json(%{
          connection: serialize_connection(updated_conn),
          message: "Profile updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_profile(_conn, _params), do: {:error, :missing_params}

  def update_visibility(conn, %{"visibility" => visibility}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{"visibility" => visibility}

    case Accounts.update_user_visibility(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Visibility updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_visibility(_conn, _params), do: {:error, :missing_params}

  def update_password(
        conn,
        %{"current_password" => current_password, "password" => _password} = params
      ) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "password" => params["password"],
      "password_confirmation" => params["password_confirmation"]
    }

    case Accounts.update_user_password(user, current_password, attrs, key: session_key) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Password updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_password(_conn, _params), do: {:error, :missing_params}

  def update_avatar(conn, %{"avatar_url" => avatar_url} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{avatar_url: decode_binary(avatar_url)}
    opts = [key: session_key, user: user, delete_avatar: params["delete_avatar"] == true]

    case Accounts.update_user_avatar(user, attrs, opts) do
      {:ok, updated_user, updated_conn} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          connection: serialize_connection(updated_conn),
          message: "Avatar updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_avatar(_conn, _params), do: {:error, :missing_params}

  def update_notifications(conn, %{"notifications" => notifications}) do
    user = conn.assigns.current_user

    attrs = %{"notifications?" => notifications}

    case Accounts.update_user_notifications(user, attrs) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Notification settings updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_notifications(_conn, _params), do: {:error, :missing_params}

  def update_onboarding(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.update_user_onboarding(user, params, key: session_key) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Onboarding updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_data(conn, %{"current_password" => password, "data" => data}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{"data" => data}

    case Accounts.delete_user_data(user, password, session_key, attrs) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Selected data deleted successfully"})

      {:ok, nil} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "No data selected for deletion"})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} when is_binary(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def delete_data(_conn, _params), do: {:error, :missing_params}

  def block_user(conn, %{"user_id" => blocked_user_id} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user(blocked_user_id) do
      nil ->
        {:error, :not_found}

      blocked_user ->
        attrs = %{
          "reason" => params["reason"],
          "note" => params["note"]
        }

        opts = [key: session_key, user: user]

        case Accounts.block_user(user, blocked_user, attrs, opts) do
          {:ok, block} ->
            conn
            |> put_status(:created)
            |> json(%{
              block: serialize_user_block(block),
              message: "User blocked successfully"
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def block_user(_conn, _params), do: {:error, :missing_params}

  def unblock_user(conn, %{"user_id" => blocked_user_id}) do
    user = conn.assigns.current_user

    case Accounts.get_user(blocked_user_id) do
      nil ->
        {:error, :not_found}

      blocked_user ->
        case Accounts.unblock_user(user, blocked_user) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{message: "User unblocked successfully"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: inspect(reason)})
        end
    end
  end

  def unblock_user(_conn, _params), do: {:error, :missing_params}

  def list_blocked(conn, _params) do
    user = conn.assigns.current_user

    blocks = Accounts.list_blocked_users(user)

    conn
    |> put_status(:ok)
    |> json(%{
      blocks: Enum.map(blocks, &serialize_user_block/1)
    })
  end

  def create_profile(conn, %{"profile" => profile_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    opts = [key: session_key, user: user]

    case Accounts.create_user_profile(user, profile_params, opts) do
      {:ok, updated_conn} ->
        conn
        |> put_status(:created)
        |> json(%{
          connection: serialize_connection(updated_conn),
          message: "Profile created successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_profile(_conn, _params), do: {:error, :missing_params}

  def delete_profile(conn, _params) do
    user = conn.assigns.current_user

    connection = user.connection

    if connection && connection.profile do
      case Accounts.delete_user_profile(user, connection) do
        {:ok, _} ->
          conn
          |> put_status(:ok)
          |> json(%{message: "Profile deleted successfully"})

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      conn
      |> put_status(:ok)
      |> json(%{message: "No profile to delete"})
    end
  end

  def reset_password(
        conn,
        %{"current_password" => _current_password, "password" => _password} = params
      ) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "password" => params["password"],
      "password_confirmation" => params["password_confirmation"]
    }

    opts = [key: session_key]

    case Accounts.reset_user_password(user, attrs, opts) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Password reset successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def reset_password(_conn, _params), do: {:error, :missing_params}

  def update_onboarding_profile(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "name" => params["name"],
      "connection_map" => decode_connection_map(params["connection_map"])
    }

    case Accounts.update_user_onboarding_profile(user, attrs, key: session_key, user: user) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          connection: serialize_connection(updated_user.connection),
          message: "Onboarding profile updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_email_notification_received_at(conn, %{"timestamp" => timestamp}) do
    user = conn.assigns.current_user

    parsed_timestamp = parse_timestamp(timestamp)

    case Accounts.update_user_email_notification_received_at(user, parsed_timestamp) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Email notification timestamp updated"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_email_notification_received_at(_conn, _params), do: {:error, :missing_params}

  def update_reply_notification_received_at(conn, %{"timestamp" => timestamp}) do
    user = conn.assigns.current_user

    parsed_timestamp = parse_timestamp(timestamp)

    case Accounts.update_user_reply_notification_received_at(user, parsed_timestamp) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Reply notification timestamp updated"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_reply_notification_received_at(_conn, _params), do: {:error, :missing_params}

  def update_replies_seen_at(conn, %{"timestamp" => timestamp}) do
    user = conn.assigns.current_user

    parsed_timestamp = parse_timestamp(timestamp)

    case Accounts.update_user_replies_seen_at(user, parsed_timestamp) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Replies seen timestamp updated"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_replies_seen_at(_conn, _params), do: {:error, :missing_params}

  def update_tokens(conn, params) do
    user = conn.assigns.current_user

    attrs = %{
      "tokens" => params["tokens"]
    }

    case Accounts.update_user_tokens(user, attrs) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "User tokens updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_visibility_group(conn, %{"group" => group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = decode_visibility_group_params(group_params)
    opts = [key: session_key, user: user]

    case Accounts.create_visibility_group(user, attrs, opts) do
      {:ok, updated_user} ->
        conn
        |> put_status(:created)
        |> json(%{
          user: serialize_user(updated_user),
          visibility_groups: serialize_visibility_groups(updated_user.visibility_groups),
          message: "Visibility group created successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_visibility_group(_conn, _params), do: {:error, :missing_params}

  def update_visibility_group(conn, %{"id" => group_id, "group" => group_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = decode_visibility_group_params(group_params)
    opts = [key: session_key, user: user]

    case Accounts.update_visibility_group(user, group_id, attrs, opts) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          visibility_groups: serialize_visibility_groups(updated_user.visibility_groups),
          message: "Visibility group updated successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_visibility_group(_conn, _params), do: {:error, :missing_params}

  def delete_visibility_group(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    case Accounts.delete_visibility_group(user, group_id) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          visibility_groups: serialize_visibility_groups(updated_user.visibility_groups),
          message: "Visibility group deleted successfully"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_visibility_group(_conn, _params), do: {:error, :missing_params}

  def update_forgot_password(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "forgot_password?" => params["forgot_password"]
    }

    opts = [key: session_key, user: user]

    case Accounts.update_user_forgot_password(user, attrs, opts) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Forgot password status updated"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_oban_reset_token_id(conn, params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = %{
      "oban_reset_token_id" => params["oban_reset_token_id"]
    }

    opts = [key: session_key, user: user]

    case Accounts.update_user_oban_reset_token_id(user, attrs, opts) do
      {:ok, updated_user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          user: serialize_user(updated_user),
          message: "Oban reset token ID updated"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()

  defp serialize_visibility_groups(nil), do: []

  defp serialize_visibility_groups(groups) when is_list(groups) do
    Enum.map(groups, &serialize_visibility_group/1)
  end

  defp serialize_visibility_group(group) do
    %{
      id: group.id,
      name: encode_binary(group.name),
      name_hash: encode_binary(group.name_hash),
      user_ids: group.user_ids
    }
  end

  defp decode_visibility_group_params(params) when is_map(params) do
    %{
      "name" => decode_binary(params["name"]),
      "name_hash" => decode_binary(params["name_hash"]),
      "user_ids" => params["user_ids"] || []
    }
  end

  defp decode_visibility_group_params(_), do: %{}

  defp serialize_user_block(nil), do: nil

  defp serialize_user_block(block) do
    %{
      id: block.id,
      blocker_id: block.blocker_id,
      blocked_id: block.blocked_id,
      reason: block.reason,
      inserted_at: block.inserted_at
    }
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      email_hash: encode_binary(user.email_hash),
      username_hash: encode_binary(user.username_hash),
      visibility: user.visibility,
      is_confirmed: not is_nil(user.confirmed_at),
      is_onboarded: user.is_onboarded?,
      notifications: user.notifications?,
      updated_at: user.updated_at
    }
  end

  defp serialize_connection(nil), do: nil

  defp serialize_connection(connection) do
    %{
      id: connection.id,
      user_id: connection.user_id,
      email: encode_binary(connection.email),
      username: encode_binary(connection.username),
      name: encode_binary(connection.name),
      avatar_url: encode_binary(connection.avatar_url),
      updated_at: connection.updated_at
    }
  end

  defp encode_binary(nil), do: nil
  defp encode_binary(data) when is_binary(data), do: Base.encode64(data)

  defp decode_binary(nil), do: nil

  defp decode_binary(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> decoded
      :error -> data
    end
  end

  defp decode_connection_map(nil), do: %{}

  defp decode_connection_map(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      key = if is_binary(k), do: String.to_existing_atom(k), else: k
      {key, decode_binary(v)}
    end)
  rescue
    _ -> %{}
  end
end
