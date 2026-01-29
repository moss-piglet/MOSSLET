defmodule Mosslet.GroupMessages.Adapters.Native do
  @moduledoc """
  Native adapter for group message operations on desktop/mobile apps.

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

  @behaviour Mosslet.GroupMessages.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Groups.{Group, GroupMessage}
  alias Mosslet.Sync

  @impl true
  def list_groups do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"groups" => groups}} <- Client.list_groups(token, []) do
        Enum.map(groups, &deserialize_group/1)
      else
        _ -> list_cached_groups()
      end
    else
      list_cached_groups()
    end
  end

  @impl true
  def get_message!(id) do
    case get_message(id) do
      nil -> raise Ecto.NoResultsError, queryable: GroupMessage
      message -> message
    end
  end

  defp get_message(id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <- Client.get_group_message(token, id) do
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
  def last_ten_messages_for(group_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"messages" => messages}} <-
             Client.list_group_messages(token, group_id, limit: 10) do
        Enum.each(messages, &cache_message/1)
        Enum.map(messages, &deserialize_message/1)
      else
        _ -> get_cached_messages_for_group(group_id, 10)
      end
    else
      get_cached_messages_for_group(group_id, 10)
    end
  end

  @impl true
  def last_user_message_for_group(group_id, user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.last_user_group_message(token, group_id, user_id) do
        if message_data do
          cache_message(message_data)
          deserialize_message(message_data)
        else
          nil
        end
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def create_message(attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <- Client.create_group_message(token, attrs) do
        cache_message(message_data)
        {:ok, deserialize_message(message_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("group_message", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_message(message, attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.update_group_message(token, message.id, attrs) do
        cache_message(message_data)
        {:ok, deserialize_message(message_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("group_message", "update", Map.put(attrs, :id, message.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_message(message) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_group_message(token, message.id) do
        Cache.invalidate_cache("group_message", message.id)
        {:ok, message}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("group_message", "delete", %{id: message.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def preload_message_sender(message) do
    message
  end

  @impl true
  def get_previous_n_messages(date, group_id, n) do
    if is_nil(date) do
      []
    else
      if Sync.online?() do
        with {:ok, token} <- NativeSession.get_token(),
             {:ok, %{"messages" => messages}} <-
               Client.list_group_messages(token, group_id, before: date, limit: n) do
          Enum.each(messages, &cache_message/1)
          Enum.map(messages, &deserialize_message/1)
        else
          _ -> []
        end
      else
        []
      end
    end
  end

  @impl true
  def get_message_count_for_group(group_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.group_message_count(token, group_id) do
        count
      else
        _ -> 0
      end
    else
      case Cache.list_cached_items("group_message") do
        items when is_list(items) ->
          items
          |> Enum.count(fn item ->
            msg = deserialize_message(item.encrypted_data)
            msg && msg.group_id == group_id
          end)

        _ ->
          0
      end
    end
  end

  defp list_cached_groups do
    case Cache.list_cached_items("group") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_group(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp get_cached_message(id) do
    case Cache.get_cached_item("group_message", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_message(data)

      _ ->
        nil
    end
  end

  defp get_cached_messages_for_group(group_id, limit) do
    case Cache.list_cached_items("group_message") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_message(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn msg -> msg.group_id == group_id end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Enum.take(limit)
        |> Enum.reverse()

      _ ->
        []
    end
  end

  defp cache_message(message_data) when is_map(message_data) do
    id = message_data["id"] || message_data[:id]
    Cache.cache_item("group_message", id, message_data)
  end

  defp deserialize_group(nil), do: nil

  defp deserialize_group(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_group(decoded)
      _ -> nil
    end
  end

  defp deserialize_group(data) when is_map(data) do
    %Group{
      id: data["id"] || data[:id],
      name: data["name"] || data[:name],
      description: data["description"] || data[:description],
      public?: data["public?"] || data[:public?] || data["public"] || data[:public] || false,
      inserted_at: parse_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_message(nil), do: nil

  defp deserialize_message(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_message(decoded)
      _ -> nil
    end
  end

  defp deserialize_message(data) when is_map(data) do
    %GroupMessage{
      id: data["id"] || data[:id],
      group_id: data["group_id"] || data[:group_id],
      sender_id: data["sender_id"] || data[:sender_id],
      content: data["content"] || data[:content],
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(dt), do: dt

  defp parse_naive_datetime(nil), do: nil

  defp parse_naive_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_naive_datetime(dt), do: dt

  @impl true
  def get_next_message_after(message) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),\
           {:ok, %{"message" => message_data}} <-
             Client.get_next_group_message_after(token, message.id) do
        if message_data do
          cache_message(message_data)
          deserialize_message(message_data)
        else
          nil
        end
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_previous_message_before(message) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.get_previous_group_message_before(token, message.id) do
        if message_data do
          cache_message(message_data)
          deserialize_message(message_data)
        else
          nil
        end
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_last_message_for_group(group_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"message" => message_data}} <-
             Client.get_last_group_message(token, group_id) do
        if message_data do
          cache_message(message_data)
          deserialize_message(message_data)
        else
          nil
        end
      else
        _ -> nil
      end
    else
      nil
    end
  end

  defp build_changeset_errors(errors) when is_map(errors) do
    Enum.reduce(errors, Ecto.Changeset.change(%GroupMessage{}), fn {field, messages}, changeset ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field

      Enum.reduce(List.wrap(messages), changeset, fn msg, cs ->
        Ecto.Changeset.add_error(cs, field_atom, msg)
      end)
    end)
  end

  defp build_changeset_errors(_), do: Ecto.Changeset.change(%GroupMessage{})
end
