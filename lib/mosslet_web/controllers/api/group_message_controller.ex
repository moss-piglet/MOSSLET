defmodule MossletWeb.API.GroupMessageController do
  @moduledoc """
  API endpoints for group message operations.

  Handles group chat message CRUD operations.
  All encrypted data is passed through as-is - native apps handle
  encryption/decryption locally for zero-knowledge operation.
  """
  use MossletWeb, :controller

  alias Mosslet.Groups
  alias Mosslet.GroupMessages

  action_fallback MossletWeb.API.FallbackController

  def index(conn, %{"group_id" => group_id} = params) do
    user = conn.assigns.current_user

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if member_of_group?(group, user) do
          messages =
            if params["last_ten"] == "true" do
              GroupMessages.last_ten_messages_for(group_id)
            else
              GroupMessages.last_ten_messages_for(group_id)
            end

          conn
          |> put_status(:ok)
          |> json(%{messages: Enum.map(messages, &serialize_message/1)})
        else
          {:error, :forbidden}
        end
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case GroupMessages.get_message!(id) do
      nil ->
        {:error, :not_found}

      message ->
        group = Groups.get_group!(message.group_id)

        if member_of_group?(group, user) do
          conn
          |> put_status(:ok)
          |> json(%{message: serialize_message(message)})
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"message" => message_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key
    group_id = message_params["group_id"]

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if member_of_group?(group, user) do
          attrs = decode_message_attrs(message_params)
          attrs = Map.put(attrs, "user_id", user.id)
          opts = [key: session_key, user: user]

          case GroupMessages.create_message(attrs, opts) do
            {:ok, message} ->
              conn
              |> put_status(:created)
              |> json(%{
                message: serialize_message(message),
                message_text: "Message sent"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{"id" => id, "message" => message_params}) do
    user = conn.assigns.current_user

    case GroupMessages.get_message!(id) do
      nil ->
        {:error, :not_found}

      message ->
        if message.user_id == user.id do
          attrs = decode_message_attrs(message_params)

          case GroupMessages.update_message(message, attrs) do
            {:ok, updated_message} ->
              conn
              |> put_status(:ok)
              |> json(%{
                message: serialize_message(updated_message),
                message_text: "Message updated"
              })

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case GroupMessages.get_message!(id) do
      nil ->
        {:error, :not_found}

      message ->
        group = Groups.get_group!(message.group_id)
        is_owner = message.user_id == user.id
        is_admin = can_manage_group?(group, user)

        if is_owner || is_admin do
          case GroupMessages.delete_message(message) do
            {:ok, _} ->
              conn
              |> put_status(:ok)
              |> json(%{message: "Message deleted"})

            {:error, error} ->
              {:error, error}
          end
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def last_user_message(conn, %{"group_id" => group_id, "user_id" => user_id}) do
    message = GroupMessages.last_user_message_for_group(group_id, user_id)

    conn
    |> put_status(:ok)
    |> json(%{message: serialize_message(message)})
  end

  def count(conn, %{"group_id" => group_id}) do
    count = GroupMessages.get_message_count_for_group(group_id)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  def previous(conn, %{"group_id" => group_id, "before_id" => before_id} = params) do
    user = conn.assigns.current_user
    n = String.to_integer(params["n"] || "10")

    case Groups.get_group(group_id) do
      nil ->
        {:error, :not_found}

      group ->
        if member_of_group?(group, user) do
          before_message = GroupMessages.get_message!(before_id)

          messages =
            GroupMessages.get_previous_n_messages(before_message.inserted_at, group_id, n)

          conn
          |> put_status(:ok)
          |> json(%{messages: Enum.map(messages, &serialize_message/1)})
        else
          {:error, :forbidden}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def previous(_conn, _params), do: {:error, :missing_params}

  defp member_of_group?(group, user) do
    user_group = Groups.get_user_group_for_group_and_user(group, user)
    user_group != nil && user_group.confirmed_at != nil
  end

  defp can_manage_group?(group, user) do
    user_group = Groups.get_user_group_for_group_and_user(group, user)
    user_group && user_group.role in [:owner, :admin]
  end

  defp serialize_message(nil), do: nil

  defp serialize_message(message) do
    %{
      id: message.id,
      group_id: message.group_id,
      user_id: message.user_id,
      body: encode_binary(message.body),
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
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

  defp decode_message_attrs(params) when is_map(params) do
    %{
      "body" => decode_binary(params["body"]),
      "group_id" => params["group_id"]
    }
  end

  defp decode_message_attrs(_), do: %{}
end
