defmodule MossletWeb.API.ConnectionController do
  @moduledoc """
  API endpoints for user connection (friend) operations.

  Handles creating, updating, and deleting connections between users.
  All encrypted data is passed through as-is - native apps handle
  encryption/decryption locally for zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Accounts

  action_fallback MossletWeb.API.FallbackController

  def index(conn, params) do
    user = conn.assigns.current_user
    filter = parse_filter(params["filter"])

    connections = Accounts.filter_user_connections(filter, user)

    conn
    |> put_status(:ok)
    |> json(%{
      connections: Enum.map(connections, &serialize_user_connection/1),
      synced_at: DateTime.utc_now()
    })
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          conn
          |> put_status(:ok)
          |> json(%{connection: serialize_user_connection(user_connection)})
        end
    end
  end

  def create(conn, %{"connection" => connection_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    attrs = decode_connection_attrs(connection_params)
    opts = [key: session_key, user: user]

    case Accounts.create_user_connection(attrs, opts) do
      {:ok, user_connection} ->
        conn
        |> put_status(:created)
        |> json(%{
          connection: serialize_user_connection(user_connection),
          message: "Connection request sent"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          attrs = decode_connection_attrs(params["connection"] || %{})
          opts = [key: session_key, user: user]

          case Accounts.update_user_connection(user_connection, attrs, opts) do
            {:ok, updated_connection} ->
              conn
              |> put_status(:ok)
              |> json(%{
                connection: serialize_user_connection(updated_connection),
                message: "Connection updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  def update_label(conn, %{"id" => id, "label" => _label} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          attrs = %{
            "label" => decode_binary(params["label"]),
            "label_hash" => decode_binary(params["label_hash"])
          }

          opts = [key: session_key, user: user]

          case Accounts.update_user_connection_label(user_connection, attrs, opts) do
            {:ok, updated_connection} ->
              conn
              |> put_status(:ok)
              |> json(%{
                connection: serialize_user_connection(updated_connection),
                message: "Label updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  def update_label(_conn, _params), do: {:error, :missing_params}

  def update_zen(conn, %{"id" => id, "zen" => zen}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          attrs = %{"zen?" => zen}
          opts = [key: session_key, user: user]

          case Accounts.update_user_connection_zen(user_connection, attrs, opts) do
            {:ok, updated_connection} ->
              conn
              |> put_status(:ok)
              |> json(%{
                connection: serialize_user_connection(updated_connection),
                message: "Zen mode updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  def update_zen(_conn, _params), do: {:error, :missing_params}

  def update_photos(conn, %{"id" => id, "photos" => photos}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          attrs = %{"photos?" => photos}
          opts = [key: session_key, user: user]

          case Accounts.update_user_connection_photos(user_connection, attrs, opts) do
            {:ok, updated_connection} ->
              conn
              |> put_status(:ok)
              |> json(%{
                connection: serialize_user_connection(updated_connection),
                message: "Photo permission updated successfully"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        end
    end
  end

  def update_photos(_conn, _params), do: {:error, :missing_params}

  def confirm(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.reverse_user_id != user.id do
          {:error, :forbidden}
        else
          attrs = decode_connection_attrs(params["connection"] || %{})
          opts = [key: session_key, user: user]

          case Accounts.confirm_user_connection(user_connection, attrs, opts) do
            {:ok, updated_connection, new_connection} ->
              conn
              |> put_status(:ok)
              |> json(%{
                connection: serialize_user_connection(updated_connection),
                reverse_connection: serialize_user_connection(new_connection),
                message: "Connection confirmed"
              })

            {:error, error} ->
              {:error, error}
          end
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id do
          {:error, :forbidden}
        else
          case Accounts.delete_user_connection(user_connection) do
            {:ok, _deleted} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Connection request cancelled"})

            {:error, error} ->
              {:error, error}
          end
        end
    end
  end

  def delete_both(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Accounts.get_user_connection(id) do
      nil ->
        {:error, :not_found}

      user_connection ->
        if user_connection.user_id != user.id && user_connection.reverse_user_id != user.id do
          {:error, :forbidden}
        else
          case Accounts.delete_both_user_connections(user_connection) do
            {:ok, _deleted} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Connection removed"})

            {:error, error} ->
              {:error, error}
          end
        end
    end
  end

  def arrivals(conn, params) do
    user = conn.assigns.current_user
    filter = parse_filter(params["filter"])

    arrivals = Accounts.filter_user_arrivals(filter, user)

    conn
    |> put_status(:ok)
    |> json(%{
      arrivals: Enum.map(arrivals, &serialize_user_connection/1),
      count: Accounts.arrivals_count(user)
    })
  end

  defp serialize_user_connection(nil), do: nil

  defp serialize_user_connection(user_connection) do
    %{
      id: user_connection.id,
      user_id: user_connection.user_id,
      reverse_user_id: user_connection.reverse_user_id,
      connection_id: user_connection.connection_id,
      label: encode_binary(user_connection.label),
      label_hash: encode_binary(user_connection.label_hash),
      key: encode_binary(user_connection.key),
      zen: user_connection.zen?,
      photos: user_connection.photos?,
      confirmed_at: user_connection.confirmed_at,
      inserted_at: user_connection.inserted_at,
      updated_at: user_connection.updated_at,
      connection: serialize_connection(user_connection.connection)
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

  defp decode_connection_attrs(params) when is_map(params) do
    Map.new(params, fn {k, v} ->
      value = if is_binary(v) && String.length(v) > 50, do: decode_binary(v), else: v
      {k, value}
    end)
  end

  defp parse_filter(nil), do: %{}

  defp parse_filter(filter) when is_binary(filter) do
    %{"filter" => filter}
  end

  defp parse_filter(filter) when is_map(filter), do: filter

  # ============================================================================
  # Bulk Delete Operations (for zero-knowledge user data management)
  # ============================================================================

  def delete_all_memories(conn, %{"id" => uconn_id}) do
    user = conn.assigns.current_user

    case Accounts.get_user_connection(uconn_id) do
      nil ->
        {:error, :not_found}

      uconn ->
        if uconn.user_id == user.id do
          case Accounts.bulk_delete_user_connection_memories(uconn) do
            {:ok, :deleted} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "All user memories deleted"})

            {:error, reason} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: inspect(reason)})
          end
        else
          {:error, :unauthorized}
        end
    end
  end

  def delete_all_posts(conn, %{"id" => uconn_id}) do
    user = conn.assigns.current_user

    case Accounts.get_user_connection(uconn_id) do
      nil ->
        {:error, :not_found}

      uconn ->
        if uconn.user_id == user.id do
          case Accounts.bulk_delete_user_connection_posts(uconn) do
            {:ok, :deleted} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "All user posts deleted"})

            {:error, reason} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: inspect(reason)})
          end
        else
          {:error, :unauthorized}
        end
    end
  end
end
