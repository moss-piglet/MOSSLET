defmodule Mosslet.Messages.Adapters.Native do
  @moduledoc """
  Native adapter for message operations on desktop/mobile apps.

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
  """

  @behaviour Mosslet.Messages.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Messages.Message
  alias Mosslet.Sync

  @impl true
  def list_messages(conversation_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"messages" => messages}} <- Client.list_messages(token, conversation_id) do
        Enum.each(messages, &cache_message/1)
        Enum.map(messages, &deserialize_message/1)
      else
        _ -> get_cached_messages(conversation_id)
      end
    else
      get_cached_messages(conversation_id)
    end
  end

  @impl true
  def get_message!(conversation_id, id) do
    case get_message(conversation_id, id) do
      nil -> raise Ecto.NoResultsError, queryable: Message
      message -> message
    end
  end

  defp get_message(conversation_id, id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <- Client.get_message(token, conversation_id, id) do
        cache_message(message_data)
        deserialize_message(message_data)
      else
        _ -> get_cached_message(id)
      end
    else
      get_cached_message(id)
    end
  end

  @impl true
  def get_last_message!(conversation_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <- Client.get_last_message(token, conversation_id) do
        if message_data do
          cache_message(message_data)
          deserialize_message(message_data)
        else
          raise Ecto.NoResultsError, queryable: Message
        end
      else
        _ ->
          case get_cached_last_message(conversation_id) do
            nil -> raise Ecto.NoResultsError, queryable: Message
            message -> message
          end
      end
    else
      case get_cached_last_message(conversation_id) do
        nil -> raise Ecto.NoResultsError, queryable: Message
        message -> message
      end
    end
  end

  @impl true
  def create_message(conversation_id, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.create_message(token, conversation_id, attrs) do
        cache_message(message_data)
        {:ok, deserialize_message(message_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("message", "create", Map.put(attrs, :conversation_id, conversation_id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_message(message, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.update_message(token, message.conversation_id, message.id, attrs) do
        cache_message(message_data)
        {:ok, deserialize_message(message_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
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
        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("message", "delete", %{id: message.id})
      {:error, "Offline - queued for sync"}
    end
  end

  defp get_cached_messages(conversation_id) do
    case Cache.list_cached_items("message") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_message(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn msg -> msg.conversation_id == conversation_id end)
        |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})

      _ ->
        []
    end
  end

  defp get_cached_message(id) do
    case Cache.get_cached_item("message", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_message(data)

      _ ->
        nil
    end
  end

  defp get_cached_last_message(conversation_id) do
    case get_cached_messages(conversation_id) do
      [] -> nil
      messages -> List.last(messages)
    end
  end

  defp cache_message(message_data) when is_map(message_data) do
    id = message_data["id"] || message_data[:id]
    Cache.cache_item("message", id, message_data)
  end

  defp deserialize_message(nil), do: nil

  defp deserialize_message(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_message(decoded)
      _ -> nil
    end
  end

  defp deserialize_message(data) when is_map(data) do
    role =
      case data["role"] || data[:role] do
        r when is_atom(r) -> r
        r when is_binary(r) -> String.to_existing_atom(r)
        _ -> :user
      end

    status =
      case data["status"] || data[:status] do
        nil -> nil
        s when is_atom(s) -> s
        s when is_binary(s) -> String.to_existing_atom(s)
      end

    %Message{
      id: data["id"] || data[:id],
      conversation_id: data["conversation_id"] || data[:conversation_id],
      content: data["content"] || data[:content],
      role: role,
      status: status,
      edited: data["edited"] || data[:edited] || false,
      tokens: data["tokens"] || data[:tokens],
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

  defp build_changeset_errors(errors) when is_map(errors) do
    Enum.reduce(errors, Ecto.Changeset.change(%Message{}), fn {field, messages}, changeset ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field

      Enum.reduce(List.wrap(messages), changeset, fn msg, cs ->
        Ecto.Changeset.add_error(cs, field_atom, msg)
      end)
    end)
  end

  defp build_changeset_errors(_), do: Ecto.Changeset.change(%Message{})
end
