defmodule MossletWeb.API.MessageController do
  @moduledoc """
  API endpoints for direct message operations (conversation messages).

  Note: Messages is a legacy feature being phased out with Conversations.
  """
  use MossletWeb, :controller

  alias Mosslet.Messages
  alias Mosslet.Conversations

  action_fallback MossletWeb.API.FallbackController

  def index(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        messages = Messages.list_messages(conversation_id)

        conn
        |> put_status(:ok)
        |> json(%{messages: Enum.map(messages, &serialize_message/1)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def show(conn, %{"conversation_id" => conversation_id, "id" => id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        case Messages.get_message!(conversation_id, id) do
          nil ->
            {:error, :not_found}

          message ->
            conn
            |> put_status(:ok)
            |> json(%{message: serialize_message(message)})
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def last(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        case Messages.get_last_message!(conversation_id) do
          nil ->
            conn
            |> put_status(:ok)
            |> json(%{message: nil})

          message ->
            conn
            |> put_status(:ok)
            |> json(%{message: serialize_message(message)})
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"conversation_id" => conversation_id, "message" => message_params}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        case Messages.create_message(conversation_id, message_params) do
          {:ok, message} ->
            conn
            |> put_status(:created)
            |> json(%{
              message: serialize_message(message),
              message_text: "Message created"
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{
        "conversation_id" => conversation_id,
        "id" => id,
        "message" => message_params
      }) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        case Messages.get_message!(conversation_id, id) do
          nil ->
            {:error, :not_found}

          message ->
            case Messages.update_message(message, message_params) do
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
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"conversation_id" => conversation_id, "id" => id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(conversation_id, user) do
      nil ->
        {:error, :not_found}

      _conversation ->
        case Messages.get_message!(conversation_id, id) do
          nil ->
            {:error, :not_found}

          message ->
            case Messages.delete_message(message) do
              {:ok, _} ->
                conn
                |> put_status(:ok)
                |> json(%{message: "Message deleted"})

              {:error, error} ->
                {:error, error}
            end
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp serialize_message(nil), do: nil

  defp serialize_message(message) do
    %{
      id: message.id,
      conversation_id: message.conversation_id,
      role: message.role,
      content: message.content,
      tokens: message.tokens,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
    }
  end
end
