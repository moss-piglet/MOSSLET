defmodule MossletWeb.API.ConversationController do
  @moduledoc """
  API endpoints for conversation operations (AI chat conversations).

  Note: Conversations is a legacy feature being phased out.
  """
  use MossletWeb, :controller

  alias Mosslet.Conversations

  action_fallback MossletWeb.API.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user

    conversations = Conversations.load_conversations(user)

    conn
    |> put_status(:ok)
    |> json(%{conversations: Enum.map(conversations, &serialize_conversation/1)})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(id, user) do
      nil ->
        {:error, :not_found}

      conversation ->
        conn
        |> put_status(:ok)
        |> json(%{conversation: serialize_conversation(conversation)})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def token_count(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(id, user) do
      nil ->
        {:error, :not_found}

      conversation ->
        count = Conversations.total_conversation_tokens(conversation, user)

        conn
        |> put_status(:ok)
        |> json(%{token_count: count})
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"conversation" => conversation_params}) do
    user = conn.assigns.current_user

    attrs = Map.put(conversation_params, "user_id", user.id)

    case Conversations.create_conversation(attrs) do
      {:ok, conversation} ->
        conn
        |> put_status(:created)
        |> json(%{
          conversation: serialize_conversation(conversation),
          message: "Conversation created"
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def update(conn, %{"id" => id, "conversation" => conversation_params}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(id, user) do
      nil ->
        {:error, :not_found}

      conversation ->
        case Conversations.update_conversation(conversation, conversation_params, user) do
          {:ok, updated_conversation} ->
            conn
            |> put_status(:ok)
            |> json(%{
              conversation: serialize_conversation(updated_conversation),
              message: "Conversation updated"
            })

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def update(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.get_conversation!(id, user) do
      nil ->
        {:error, :not_found}

      conversation ->
        case Conversations.delete_conversation(conversation, user) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{message: "Conversation deleted"})

          {:error, error} ->
            {:error, error}
        end
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp serialize_conversation(nil), do: nil

  defp serialize_conversation(conversation) do
    %{
      id: conversation.id,
      user_id: conversation.user_id,
      title: conversation.title,
      inserted_at: conversation.inserted_at,
      updated_at: conversation.updated_at
    }
  end
end
