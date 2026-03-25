defmodule MossletWeb.API.MessageController do
  @moduledoc """
  API endpoints for E2E encrypted message operations.
  """
  use MossletWeb, :controller

  alias Mosslet.Conversations

  action_fallback MossletWeb.API.FallbackController

  def index(conn, %{"conversation_id" => conversation_id} = params) do
    opts =
      []
      |> then(fn o ->
        if params["limit"],
          do: Keyword.put(o, :limit, String.to_integer(params["limit"])),
          else: o
      end)
      |> then(fn o ->
        if params["before"] do
          {:ok, dt} = NaiveDateTime.from_iso8601(params["before"])
          Keyword.put(o, :before, dt)
        else
          o
        end
      end)

    messages = Conversations.list_messages(conversation_id, opts)

    conn
    |> put_status(:ok)
    |> json(%{messages: Enum.map(messages, &serialize_message/1)})
  end

  def create(conn, %{"conversation_id" => conversation_id, "message" => message_params}) do
    user = conn.assigns.current_user

    attrs = %{
      conversation_id: conversation_id,
      sender_id: user.id,
      content: message_params["content"]
    }

    case Conversations.create_message(attrs) do
      {:ok, message} ->
        Conversations.broadcast_new_message(conversation_id, message)

        conn
        |> put_status(:created)
        |> json(%{message: serialize_message(message)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{
        "conversation_id" => _conversation_id,
        "id" => id,
        "message" => message_params
      }) do
    message = Mosslet.Repo.get!(Mosslet.Conversations.Message, id)

    case Conversations.update_message(message, %{
           content: message_params["content"],
           edited: true
         }) do
      {:ok, updated_message} ->
        Conversations.broadcast_message_updated(message.conversation_id, updated_message)

        conn
        |> put_status(:ok)
        |> json(%{message: serialize_message(updated_message)})

      {:error, changeset} ->
        {:error, changeset}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"conversation_id" => _conversation_id, "id" => id}) do
    message = Mosslet.Repo.get!(Mosslet.Conversations.Message, id)

    case Conversations.delete_message(message) do
      {:ok, deleted_message} ->
        Conversations.broadcast_message_deleted(deleted_message.conversation_id, deleted_message)

        conn
        |> put_status(:ok)
        |> json(%{message: "Message deleted"})

      {:error, error} ->
        {:error, error}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp serialize_message(nil), do: nil

  defp serialize_message(message) do
    %{
      id: message.id,
      conversation_id: message.conversation_id,
      sender_id: message.sender_id,
      content: message.content,
      edited: message.edited,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at
    }
  end
end
