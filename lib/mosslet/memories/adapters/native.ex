defmodule Mosslet.Memories.Adapters.Native do
  @moduledoc """
  Native adapter for memory operations on desktop/mobile apps.

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

  Note: Memories is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """

  @behaviour Mosslet.Memories.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync
  alias Mosslet.Memories.{Memory, Remark, UserMemory}

  @impl true
  def get_memory!(id) do
    case get_memory(id) do
      nil -> raise Ecto.NoResultsError, queryable: Memory
      memory -> memory
    end
  end

  @impl true
  def get_memory(id) do
    if :new == id || "new" == id do
      nil
    else
      case Cache.get_cached_item("memory", id) do
        %{encrypted_data: data} when not is_nil(data) ->
          if Sync.online?() do
            fetch_and_cache_memory(id)
          else
            deserialize_memory(Jason.decode!(data))
          end

        nil ->
          fetch_and_cache_memory(id)
      end
    end
  end

  defp fetch_and_cache_memory(id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{"memory" => memory_data}} <- Client.get_memory(token, id) do
      memory = deserialize_memory(memory_data)
      Cache.cache_item("memory", id, Jason.encode!(memory_data))
      memory
    else
      {:error, _reason} ->
        case Cache.get_cached_item("memory", id) do
          %{encrypted_data: data} when not is_nil(data) ->
            deserialize_memory(Jason.decode!(data))

          nil ->
            nil
        end
    end
  end

  @impl true
  def memory_count(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.get_memory_count(token, user.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def shared_with_user_memory_count(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <-
             Client.get_shared_with_user_memory_count(token, user.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def timeline_memory_count(current_user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <-
             Client.get_timeline_memory_count(token, current_user.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def shared_between_users_memory_count(user_id, current_user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <-
             Client.get_shared_between_users_memory_count(token, user_id, current_user_id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_memory_count(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.get_public_memory_count(token, user.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def group_memory_count(group) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.get_group_memory_count(token, group.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def remark_count(memory) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.get_remark_count(token, memory.id) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def get_total_storage(user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"total" => total}} <- Client.get_total_storage(token, user.id) do
        total
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def count_all_memories do
    0
  end

  @impl true
  def get_remarks_loved_count(memory) do
    get_remarks_mood_count(memory, :loved)
  end

  @impl true
  def get_remarks_excited_count(memory) do
    get_remarks_mood_count(memory, :excited)
  end

  @impl true
  def get_remarks_happy_count(memory) do
    get_remarks_mood_count(memory, :happy)
  end

  @impl true
  def get_remarks_sad_count(memory) do
    get_remarks_mood_count(memory, :sad)
  end

  @impl true
  def get_remarks_thumbsy_count(memory) do
    get_remarks_mood_count(memory, :thumbsy)
  end

  defp get_remarks_mood_count(memory, mood) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.get_remarks_mood_count(token, memory.id, mood) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def preload(memory) do
    memory
  end

  @impl true
  def list_memories(user, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memories" => memories_data}} <-
             Client.list_memories(token, user.id, options) do
        Enum.map(memories_data, &deserialize_memory/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def filter_timeline_memories(current_user, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memories" => memories_data}} <-
             Client.filter_timeline_memories(token, current_user.id, options) do
        Enum.map(memories_data, &deserialize_memory/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def filter_memories_shared_with_current_user(user_id, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memories" => memories_data}} <-
             Client.filter_memories_shared_with_current_user(token, user_id, options) do
        Enum.map(memories_data, &deserialize_memory/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def list_public_memories(user, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memories" => memories_data}} <-
             Client.list_public_memories(token, user.id, options) do
        Enum.map(memories_data, &deserialize_memory/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def list_group_memories(group, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memories" => memories_data}} <-
             Client.list_group_memories(token, group.id, options) do
        Enum.map(memories_data, &deserialize_memory/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def list_remarks(memory, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"remarks" => remarks_data}} <-
             Client.list_remarks(token, memory.id, options) do
        Enum.map(remarks_data, &deserialize_remark/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def get_remark!(id) do
    case get_remark(id) do
      nil -> raise Ecto.NoResultsError, queryable: Remark
      remark -> remark
    end
  end

  @impl true
  def get_remark(id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"remark" => remark_data}} <- Client.get_remark(token, id) do
        deserialize_remark(remark_data)
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def create_memory_multi(_changeset, _user, _p_attrs, _visibility) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memory" => memory_data}} <- Client.create_memory(token, %{}) do
        {:ok, deserialize_memory(memory_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("memory", "create", %{})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def create_shared_user_memory(_memory, _user, _p_attrs, _visibility) do
    {:ok, nil}
  end

  @impl true
  def update_memory_multi(_changeset, memory, _user, _p_attrs) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memory" => memory_data}} <- Client.update_memory(token, memory.id, %{}) do
        {:ok, deserialize_memory(memory_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("memory", "update", %{id: memory.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def blur_memory_multi(_changeset, _opts) do
    {:error, "Not supported on native"}
  end

  @impl true
  def create_remark(_changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"remark" => remark_data}} <- Client.create_remark(token, %{}) do
        {:ok, deserialize_remark(remark_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_error_message(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("remark", "create", %{})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_remark(remark) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_remark(token, remark.id) do
        {:ok, remark}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("remark", "delete", %{id: remark.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_memory_fav(_changeset) do
    {:error, "Not supported on native"}
  end

  @impl true
  def inc_favs(memory) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memory" => memory_data}} <- Client.inc_memory_favs(token, memory.id) do
        {:ok, deserialize_memory(memory_data)}
      else
        _ -> {:ok, memory}
      end
    else
      {:ok, memory}
    end
  end

  @impl true
  def decr_favs(memory) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"memory" => memory_data}} <- Client.decr_memory_favs(token, memory.id) do
        {:ok, deserialize_memory(memory_data)}
      else
        _ -> {:ok, memory}
      end
    else
      {:ok, memory}
    end
  end

  @impl true
  def delete_memory(memory) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_memory(token, memory.id) do
        Cache.delete_cached_item("memory", memory.id)
        {:ok, memory}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("memory", "delete", %{id: memory.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def last_ten_remarks_for(memory_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"remarks" => remarks_data}} <- Client.last_ten_remarks_for(token, memory_id) do
        Enum.map(remarks_data, &deserialize_remark/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def last_user_remark_for_memory(memory_id, user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"remark" => remark_data}} <-
             Client.last_user_remark_for_memory(token, memory_id, user_id) do
        deserialize_remark(remark_data)
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_previous_n_remarks(date, memory_id, n) do
    if is_nil(date) do
      []
    else
      if Sync.online?() do
        with {:ok, token} <- NativeSession.get_token(),
             {:ok, %{"remarks" => remarks_data}} <-
               Client.get_previous_n_remarks(token, date, memory_id, n) do
          Enum.map(remarks_data, &deserialize_remark/1)
        else
          _ -> []
        end
      else
        []
      end
    end
  end

  @impl true
  def preload_remark_user(remark) do
    remark
  end

  @impl true
  def get_public_user_memory(memory) do
    Enum.at(memory.user_memories || [], 0)
  end

  @impl true
  def get_user_memory(memory, user) do
    Enum.find(memory.user_memories || [], fn um -> um.user_id == user.id end)
  end

  defp deserialize_memory(nil), do: nil

  defp deserialize_memory(data) when is_map(data) do
    visibility =
      case data["visibility"] || data[:visibility] do
        nil -> :private
        v when is_atom(v) -> v
        v when is_binary(v) -> String.to_existing_atom(v)
      end

    %Memory{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      group_id: data["group_id"] || data[:group_id],
      visibility: visibility,
      size: data["size"] || data[:size],
      favs_count: data["favs_count"] || data[:favs_count] || 0,
      shared_users: data["shared_users"] || data[:shared_users] || [],
      user_memories: deserialize_user_memories(data["user_memories"] || data[:user_memories]),
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_user_memories(nil), do: []

  defp deserialize_user_memories(user_memories) when is_list(user_memories) do
    Enum.map(user_memories, &deserialize_user_memory/1)
  end

  defp deserialize_user_memory(nil), do: nil

  defp deserialize_user_memory(data) when is_map(data) do
    %UserMemory{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      memory_id: data["memory_id"] || data[:memory_id],
      key: data["key"] || data[:key],
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_remark(nil), do: nil

  defp deserialize_remark(data) when is_map(data) do
    mood =
      case data["mood"] || data[:mood] do
        nil -> nil
        m when is_atom(m) -> m
        m when is_binary(m) -> String.to_existing_atom(m)
      end

    %Remark{
      id: data["id"] || data[:id],
      user_id: data["user_id"] || data[:user_id],
      memory_id: data["memory_id"] || data[:memory_id],
      mood: mood,
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
