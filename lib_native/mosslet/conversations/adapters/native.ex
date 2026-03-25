defmodule Mosslet.Conversations.Adapters.Native do
  @moduledoc """
  Native adapter for E2E encrypted conversation operations on desktop/mobile apps.

  All encryption/decryption happens locally on the device.
  The server only sees encrypted blobs.
  """

  @behaviour Mosslet.Conversations.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync
  alias Mosslet.Conversations.{Conversation, Message, UserConversation}

  @impl true
  def list_conversations(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"conversations" => data}} <- Client.list_conversations(token) do
        Cache.cache_item("conversations", user.id, Jason.encode!(data))
        Enum.map(data, &deserialize_user_conversation/1)
      else
        _ -> get_cached_conversations(user.id)
      end
    else
      get_cached_conversations(user.id)
    end
  end

  @impl true
  def get_conversation!(id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"conversation" => data}} <- Client.get_conversation(token, id) do
        Cache.cache_item("conversation", id, Jason.encode!(data))
        deserialize_conversation(data)
      else
        _ ->
          case get_cached_conversation(id) do
            nil -> raise Ecto.NoResultsError, queryable: Conversation
            c -> c
          end
      end
    else
      case get_cached_conversation(id) do
        nil -> raise Ecto.NoResultsError, queryable: Conversation
        c -> c
      end
    end
  end

  @impl true
  def get_conversation_for_connection(user_connection_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"conversation" => data}} <-
             Client.get_conversation_for_connection(token, user_connection_id) do
        if data, do: deserialize_conversation(data)
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_or_create_conversation(user_connection_id, user_conversation_attrs_list) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"conversation" => data}} <-
             Client.create_conversation(token, %{
               user_connection_id: user_connection_id,
               user_conversations: user_conversation_attrs_list
             }) do
        conversation = deserialize_conversation(data)
        Cache.cache_item("conversation", conversation.id, Jason.encode!(data))
        {:ok, conversation}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "create", %{
        user_connection_id: user_connection_id,
        user_conversations: user_conversation_attrs_list
      })

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def get_user_conversation(conversation_id, user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user_conversation" => data}} <-
             Client.get_user_conversation(token, conversation_id, user_id) do
        if data, do: deserialize_user_conversation(data)
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def list_messages(conversation_id, opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"messages" => data}} <-
             Client.list_messages(token, conversation_id, opts) do
        Cache.cache_item("messages:#{conversation_id}", "list", Jason.encode!(data))
        Enum.map(data, &deserialize_message/1)
      else
        _ -> get_cached_messages(conversation_id)
      end
    else
      get_cached_messages(conversation_id)
    end
  end

  @impl true
  def create_message(attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => data}} <-
             Client.create_message(token, attrs.conversation_id, %{
               content: attrs.content
             }) do
        Cache.cache_item("message", data["id"], Jason.encode!(data))
        {:ok, deserialize_message(data)}
      else
        {:error, %{"errors" => errors}} -> {:error, build_error_message(errors)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("message", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_message(message, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => data}} <-
             Client.update_message(token, message.conversation_id, message.id, attrs) do
        Cache.cache_item("message", message.id, Jason.encode!(data))
        {:ok, deserialize_message(data)}
      else
        {:error, %{"errors" => errors}} -> {:error, build_error_message(errors)}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("message", "update", Map.put(attrs, :id, message.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_message(message) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_message(token, message.conversation_id, message.id) do
        Cache.invalidate_cache("message", message.id)
        {:ok, message}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("message", "delete", %{id: message.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def mark_conversation_read(conversation_id, _user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.mark_conversation_read(token, conversation_id) do
        {:ok, %UserConversation{}}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "mark_read", %{id: conversation_id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def archive_conversation(conversation_id, _user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.archive_conversation(token, conversation_id) do
        {:ok, %UserConversation{}}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "archive", %{id: conversation_id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def unarchive_conversation(conversation_id, _user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.unarchive_conversation(token, conversation_id) do
        {:ok, %UserConversation{}}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "unarchive", %{id: conversation_id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_conversation(conversation) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_conversation(token, conversation.id) do
        Cache.invalidate_cache("conversation", conversation.id)
        {:ok, conversation}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "delete", %{id: conversation.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def count_unread_messages(_user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.unread_message_count(token) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  defp get_cached_conversations(user_id) do
    case Cache.get_cached_item("conversations", user_id) do
      %{encrypted_data: data} when not is_nil(data) ->
        data |> Jason.decode!() |> Enum.map(&deserialize_user_conversation/1)

      _ ->
        []
    end
  end

  defp get_cached_conversation(id) do
    case Cache.get_cached_item("conversation", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_conversation(Jason.decode!(data))

      _ ->
        nil
    end
  end

  defp get_cached_messages(conversation_id) do
    case Cache.get_cached_item("messages:#{conversation_id}", "list") do
      %{encrypted_data: data} when not is_nil(data) ->
        data |> Jason.decode!() |> Enum.map(&deserialize_message/1)

      _ ->
        []
    end
  end

  defp deserialize_conversation(nil), do: nil

  defp deserialize_conversation(data) when is_map(data) do
    %Conversation{
      id: data["id"] || data[:id],
      user_connection_id: data["user_connection_id"] || data[:user_connection_id],
      user_conversations:
        (data["user_conversations"] || data[:user_conversations] || [])
        |> Enum.map(&deserialize_uc_brief/1),
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_user_conversation(nil), do: nil

  defp deserialize_user_conversation(data) when is_map(data) do
    %UserConversation{
      id: data["id"] || data[:id],
      key: data["key"] || data[:key],
      last_read_at: parse_naive_datetime(data["last_read_at"] || data[:last_read_at]),
      archived: data["archived"] || data[:archived] || false,
      conversation_id: data["conversation_id"] || data[:conversation_id],
      user_id: data["user_id"] || data[:user_id],
      conversation:
        deserialize_conversation_brief(data["conversation"] || data[:conversation]),
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_conversation_brief(nil), do: nil

  defp deserialize_conversation_brief(data) do
    %Conversation{
      id: data["id"] || data[:id],
      user_connection_id: data["user_connection_id"] || data[:user_connection_id],
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_uc_brief(nil), do: nil

  defp deserialize_uc_brief(data) do
    %UserConversation{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      key: data["key"] || data[:key]
    }
  end

  defp deserialize_message(nil), do: nil

  defp deserialize_message(data) when is_map(data) do
    %Message{
      id: data["id"] || data[:id],
      conversation_id: data["conversation_id"] || data[:conversation_id],
      sender_id: data["sender_id"] || data[:sender_id],
      content: data["content"] || data[:content],
      edited: data["edited"] || data[:edited] || false,
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp parse_naive_datetime(nil), do: nil

  defp parse_naive_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_naive_datetime(dt), do: dt

  defp build_error_message(errors) when is_map(errors) do
    errors
    |> Enum.map(fn {field, messages} ->
      "#{field}: #{Enum.join(List.wrap(messages), ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp build_error_message(_), do: "Unknown error"
end
