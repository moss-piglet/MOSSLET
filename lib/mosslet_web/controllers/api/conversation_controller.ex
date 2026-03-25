defmodule MossletWeb.API.ConversationController do
  @moduledoc """
  API endpoints for E2E encrypted conversation operations.
  """
  use MossletWeb, :controller

  alias Mosslet.Conversations

  action_fallback MossletWeb.API.FallbackController

  def index(conn, _params) do
    user = conn.assigns.current_user
    user_conversations = Conversations.list_conversations(user)

    conn
    |> put_status(:ok)
    |> json(%{conversations: Enum.map(user_conversations, &serialize_user_conversation/1)})
  end

  def show(conn, %{"id" => id}) do
    conversation = Conversations.get_conversation!(id)

    conn
    |> put_status(:ok)
    |> json(%{conversation: serialize_conversation(conversation)})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"user_connection_id" => uc_id, "user_conversations" => uc_attrs_list}) do
    uc_attrs =
      Enum.map(uc_attrs_list, fn attrs ->
        %{
          user_id: attrs["user_id"],
          key: attrs["key"]
        }
      end)

    case Conversations.get_or_create_conversation(uc_id, uc_attrs) do
      {:ok, conversation} ->
        conn
        |> put_status(:created)
        |> json(%{conversation: serialize_conversation(conversation)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(_conn, _params), do: {:error, :missing_params}

  def delete(conn, %{"id" => id}) do
    conversation = Conversations.get_conversation!(id)

    case Conversations.delete_conversation(conversation) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Conversation deleted"})

      {:error, error} ->
        {:error, error}
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def mark_read(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.mark_conversation_read(id, user.id) do
      {:ok, _} ->
        conn |> put_status(:ok) |> json(%{message: "Marked as read"})

      {:error, error} ->
        {:error, error}
    end
  end

  def archive(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.archive_conversation(id, user.id) do
      {:ok, _} ->
        conn |> put_status(:ok) |> json(%{message: "Conversation archived"})

      {:error, error} ->
        {:error, error}
    end
  end

  def unarchive(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Conversations.unarchive_conversation(id, user.id) do
      {:ok, _} ->
        conn |> put_status(:ok) |> json(%{message: "Conversation unarchived"})

      {:error, error} ->
        {:error, error}
    end
  end

  def unread_count(conn, _params) do
    user = conn.assigns.current_user
    count = Conversations.count_unread_messages(user.id)

    conn
    |> put_status(:ok)
    |> json(%{count: count})
  end

  defp serialize_conversation(nil), do: nil

  defp serialize_conversation(conversation) do
    %{
      id: conversation.id,
      user_connection_id: conversation.user_connection_id,
      user_conversations: Enum.map(conversation.user_conversations || [], &serialize_uc_brief/1),
      inserted_at: conversation.inserted_at,
      updated_at: conversation.updated_at
    }
  end

  defp serialize_user_conversation(uc) do
    %{
      id: uc.id,
      key: uc.key,
      last_read_at: uc.last_read_at,
      archived: uc.archived,
      conversation_id: uc.conversation_id,
      user_id: uc.user_id,
      conversation: serialize_conversation_brief(uc.conversation),
      inserted_at: uc.inserted_at,
      updated_at: uc.updated_at
    }
  end

  defp serialize_conversation_brief(nil), do: nil

  defp serialize_conversation_brief(conversation) do
    %{
      id: conversation.id,
      user_connection_id: conversation.user_connection_id,
      inserted_at: conversation.inserted_at,
      updated_at: conversation.updated_at
    }
  end

  defp serialize_uc_brief(uc) do
    %{
      id: uc.id,
      user_id: uc.user_id,
      key: uc.key
    }
  end
end
