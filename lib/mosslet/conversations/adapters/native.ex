defmodule Mosslet.Conversations.Adapters.Native do
  @moduledoc """
  Native adapter for conversation operations on desktop/mobile apps.

  This adapter communicates with the cloud server via HTTP API and
  caches data locally in SQLite for offline support.

  ## Flow

  1. API calls go to Fly.io server
  2. Server validates and returns data
  3. Data cached locally for offline access
  4. Offline operations queued for sync

  ## Zero-Knowledge

  All encryption/decryption happens locally on the device.
  The server only sees encrypted blobs.

  Note: Conversations is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """

  @behaviour Mosslet.Conversations.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync
  alias Mosslet.Conversations.Conversation

  @impl true
  def load_conversations(user) do
    case Cache.get_cached_item("conversations", user.id) do
      %{encrypted_data: data} when not is_nil(data) ->
        if Sync.online?() do
          fetch_and_cache_conversations(user)
        else
          data
          |> Jason.decode!()
          |> Enum.map(&deserialize_conversation/1)
        end

      nil ->
        fetch_and_cache_conversations(user)
    end
  end

  defp fetch_and_cache_conversations(user) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{"conversations" => conversations_data}} <- Client.load_conversations(token) do
      conversations = Enum.map(conversations_data, &deserialize_conversation/1)
      Cache.cache_item("conversations", user.id, Jason.encode!(conversations_data))
      conversations
    else
      {:error, _reason} ->
        case Cache.get_cached_item("conversations", user.id) do
          %{encrypted_data: data} when not is_nil(data) ->
            data
            |> Jason.decode!()
            |> Enum.map(&deserialize_conversation/1)

          nil ->
            []
        end
    end
  end

  @impl true
  def get_conversation!(id, user) do
    case get_conversation(id, user) do
      nil -> raise Ecto.NoResultsError, queryable: Conversation
      conversation -> conversation
    end
  end

  defp get_conversation(id, user) do
    case Cache.get_cached_item("conversation", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        if Sync.online?() do
          fetch_and_cache_conversation(id, user)
        else
          deserialize_conversation(Jason.decode!(data))
        end

      nil ->
        fetch_and_cache_conversation(id, user)
    end
  end

  defp fetch_and_cache_conversation(id, _user) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{"conversation" => conversation_data}} <- Client.get_conversation(token, id) do
      conversation = deserialize_conversation(conversation_data)
      Cache.cache_item("conversation", id, Jason.encode!(conversation_data))
      conversation
    else
      {:error, _reason} ->
        case Cache.get_cached_item("conversation", id) do
          %{encrypted_data: data} when not is_nil(data) ->
            deserialize_conversation(Jason.decode!(data))

          nil ->
            nil
        end
    end
  end

  @impl true
  def total_conversation_tokens(conversation, _user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"total" => total}} <-
             Client.get_total_conversation_tokens(token, conversation.id) do
        total
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def create_conversation(attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"conversation" => conversation_data}} <-
             Client.create_conversation(token, attrs) do
        conversation = deserialize_conversation(conversation_data)
        Cache.cache_item("conversation", conversation.id, Jason.encode!(conversation_data))
        {:ok, conversation}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("conversation", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_conversation(conversation, attrs, user) do
    if conversation.user_id == user.id do
      if Sync.online?() do
        with {:ok, token} <- NativeSession.get_token(),
             {:ok, %{"conversation" => conversation_data}} <-
               Client.update_conversation(token, conversation.id, attrs) do
          updated_conversation = deserialize_conversation(conversation_data)
          Cache.cache_item("conversation", conversation.id, Jason.encode!(conversation_data))
          {:ok, updated_conversation}
        else
          {:error, %{"errors" => errors}} ->
            {:error, build_error_message(errors)}

          {:error, reason} ->
            {:error, reason}
        end
      else
        Cache.queue_for_sync("conversation", "update", Map.put(attrs, :id, conversation.id))
        {:error, "Offline - queued for sync"}
      end
    end
  end

  @impl true
  def delete_conversation(conversation, user) do
    if conversation.user_id == user.id do
      if Sync.online?() do
        with {:ok, token} <- NativeSession.get_token(),
             {:ok, _} <- Client.delete_conversation(token, conversation.id) do
          Cache.delete_cached_item("conversation", conversation.id)
          {:ok, conversation}
        else
          {:error, reason} ->
            {:error, reason}
        end
      else
        Cache.queue_for_sync("conversation", "delete", %{id: conversation.id})
        {:error, "Offline - queued for sync"}
      end
    end
  end

  defp deserialize_conversation(nil), do: nil

  defp deserialize_conversation(data) when is_map(data) do
    %Conversation{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      name: data["name"] || data[:name],
      model: data["model"] || data[:model],
      temperature: data["temperature"] || data[:temperature] || 1.0,
      frequency_penalty: data["frequency_penalty"] || data[:frequency_penalty] || 0.0,
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
