defmodule Mosslet.Groups.Adapters.Native do
  @moduledoc """
  Native adapter for group operations on desktop/mobile apps.

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

  @behaviour Mosslet.Groups.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Groups.{Group, GroupBlock, UserGroup}
  alias Mosslet.Sync

  @impl true
  def get_group(id) do
    with_fallback_to_cache("group", id, fn ->
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"group" => group_data}} <- Client.get_group(token, id) do
        cache_group(group_data)
        deserialize_group(group_data)
      else
        _ -> nil
      end
    end)
  end

  @impl true
  def get_group!(id) do
    case get_group(id) do
      nil -> raise Ecto.NoResultsError, queryable: Group
      group -> group
    end
  end

  @impl true
  def list_groups(user, options \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"groups" => groups}} <- Client.list_groups(token, options) do
        Enum.each(groups, &cache_group/1)
        Enum.map(groups, &deserialize_group/1)
      else
        _ -> list_cached_groups(user)
      end
    else
      list_cached_groups(user)
    end
  end

  @impl true
  def list_unconfirmed_groups(_user, _opts \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"groups" => groups}} <- Client.list_unconfirmed_groups(token) do
        Enum.map(groups, &deserialize_group/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def list_public_groups(_user, search_term \\ nil, opts \\ []) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"groups" => groups}} <-
             Client.list_public_groups(token, search_term, opts) do
        Enum.map(groups, &deserialize_group/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def public_group_count(_user, search_term \\ nil) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"count" => count}} <- Client.public_group_count(token, search_term) do
        count
      else
        _ -> 0
      end
    else
      0
    end
  end

  @impl true
  def filter_groups_with_users(user_id, current_user_id, options) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"groups" => groups}} <-
             Client.filter_groups_with_users(token, user_id, current_user_id, options) do
        Enum.map(groups, &deserialize_group/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def group_count(_user) do
    case Cache.list_cached_items("group") do
      items when is_list(items) -> length(items)
      _ -> 0
    end
  end

  @impl true
  def group_count_confirmed(user) do
    group_count(user)
  end

  @impl true
  def list_user_groups_for_sync(_user, opts \\ []) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{"groups" => groups}} <- Client.fetch_groups(token, opts) do
      Enum.each(groups, &cache_group/1)

      Enum.flat_map(groups, fn group_data ->
        group = deserialize_group(group_data)
        group.user_groups || []
      end)
    else
      _ -> []
    end
  end

  @impl true
  def get_user_group(id) do
    case Cache.get_cached_item("user_group", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_user_group(data)

      _ ->
        nil
    end
  end

  @impl true
  def get_user_group!(id) do
    case get_user_group(id) do
      nil -> raise Ecto.NoResultsError, queryable: UserGroup
      user_group -> user_group
    end
  end

  @impl true
  def get_user_group_with_user!(id) do
    get_user_group!(id)
  end

  @impl true
  def get_user_group_for_group_and_user(group, user) do
    case Cache.list_cached_items("user_group") do
      items when is_list(items) ->
        items
        |> Enum.find(fn item ->
          ug = deserialize_user_group(item.encrypted_data)
          ug && ug.group_id == group.id && ug.user_id == user.id
        end)
        |> case do
          nil -> nil
          item -> deserialize_user_group(item.encrypted_data)
        end

      _ ->
        nil
    end
  end

  @impl true
  def list_user_groups(group) do
    case Cache.list_cached_items("user_group") do
      items when is_list(items) ->
        items
        |> Enum.filter(fn item ->
          ug = deserialize_user_group(item.encrypted_data)
          ug && ug.group_id == group.id && ug.confirmed_at != nil
        end)
        |> Enum.map(fn item -> deserialize_user_group(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def list_user_groups do
    case Cache.list_cached_items("user_group") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_user_group(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def list_user_groups_for_user(user) do
    case Cache.list_cached_items("user_group") do
      items when is_list(items) ->
        items
        |> Enum.filter(fn item ->
          ug = deserialize_user_group(item.encrypted_data)
          ug && ug.user_id == user.id
        end)
        |> Enum.map(fn item -> deserialize_user_group(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def create_group(attrs, _group_changeset, _user, _user_group_map, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"group" => group_data}} <- Client.create_group(token, attrs) do
        cache_group(group_data)
        {:ok, %{insert_group: deserialize_group(group_data), insert_user_group: nil}}
      else
        {:error, %{"errors" => errors}} ->
          {:error, :insert_group, build_changeset_errors(errors), %{}}

        {:error, reason} ->
          {:error, :insert_group, reason, %{}}
      end
    else
      Cache.queue_for_sync("group", "create", attrs)
      {:error, :insert_group, "Offline - queued for sync", %{}}
    end
  end

  @impl true
  def create_user_group(attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user_group" => ug_data}} <- Client.create_user_group(token, attrs) do
        Cache.cache_item("user_group", ug_data["id"], ug_data)
        {:ok, {:ok, deserialize_user_group(ug_data)}}
      else
        {:error, %{"errors" => errors}} ->
          {:ok, {:error, build_changeset_errors(errors)}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user_group", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_group(group, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{group: group_data}} <- Client.update_group(token, group.id, attrs) do
        cache_group(group_data)
        {:ok, deserialize_group(group_data)}
      else
        {:error, %{errors: errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("group", "update", %{id: group.id, attrs: attrs},
        resource_id: group.id
      )

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_group_multi(_group_changeset, _user_group, _user_group_attrs, opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"group" => group_data}} <-
             Client.update_group(token, opts[:group_id], opts[:attrs]) do
        cache_group(group_data)
        {:ok, %{update_group: deserialize_group(group_data), update_user_group: nil}}
      else
        {:error, %{"errors" => errors}} ->
          {:error, :update_group, build_changeset_errors(errors), %{}}

        {:error, reason} ->
          {:error, :update_group, reason, %{}}
      end
    else
      Cache.queue_for_sync("group", "update", opts[:attrs])
      {:error, :update_group, "Offline - queued for sync", %{}}
    end
  end

  @impl true
  def update_user_group(user_group, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user_group" => ug_data}} <-
             Client.update_user_group(token, user_group.id, attrs) do
        Cache.cache_item("user_group", ug_data["id"], ug_data)
        {:ok, deserialize_user_group(ug_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user_group", "update", Map.put(attrs, :id, user_group.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_group_role(user_group, _changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user_group" => ug_data}} <-
             Client.update_user_group_role(token, user_group.id) do
        Cache.cache_item("user_group", ug_data["id"], ug_data)
        {:ok, deserialize_user_group(ug_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot update role"}
    end
  end

  @impl true
  def delete_group(group) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_group(token, group.id) do
        Cache.invalidate_cache("group", group.id)
        {:ok, group}
      else
        {:error, reason} ->
          {:error, "Error deleting group: #{inspect(reason)}"}
      end
    else
      Cache.queue_for_sync("group", "delete", %{id: group.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_user_group(user_group) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_user_group(token, user_group.id) do
        Cache.invalidate_cache("user_group", user_group.id)
        {:ok, user_group}
      else
        {:error, reason} ->
          {:error, "Error deleting user_group: #{inspect(reason)}"}
      end
    else
      Cache.queue_for_sync("user_group", "delete", %{id: user_group.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def join_group_confirm(user_group) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user_group" => ug_data}} <- Client.confirm_user_group(token, user_group.id) do
        Cache.cache_item("user_group", ug_data["id"], ug_data)
        {:ok, deserialize_user_group(ug_data)}
      else
        {:error, %{"errors" => errors}} ->
          {:error, build_changeset_errors(errors)}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot confirm group membership"}
    end
  end

  @impl true
  def list_blocked_users(group_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"blocked_users" => blocks}} <-
             Client.list_group_blocked_users(token, group_id) do
        Enum.map(blocks, &deserialize_group_block/1)
      else
        _ -> []
      end
    else
      []
    end
  end

  @impl true
  def user_blocked?(group_id, user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"blocked" => blocked}} <-
             Client.user_blocked_from_group?(token, group_id, user_id) do
        blocked
      else
        _ -> false
      end
    else
      false
    end
  end

  @impl true
  def get_group_block(group_id, user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"block" => block_data}} <- Client.get_group_block(token, group_id, user_id) do
        deserialize_group_block(block_data)
      else
        _ -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_group_block!(id) do
    case Cache.get_cached_item("group_block", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_group_block(data)

      _ ->
        raise Ecto.NoResultsError, queryable: GroupBlock
    end
  end

  @impl true
  def block_member_multi(actor, target) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"block" => block_data}} <-
             Client.block_group_member(token, actor.group_id, target.user_id) do
        Cache.invalidate_cache("user_group", target.id)
        {:ok, %{block: deserialize_group_block(block_data), remove_member: target}}
      else
        {:error, %{"errors" => errors}} ->
          {:error, :block, build_changeset_errors(errors), %{}}

        {:error, reason} ->
          {:error, :block, reason, %{}}
      end
    else
      {:error, :block, "Offline - cannot block member", %{}}
    end
  end

  @impl true
  def delete_group_block(block) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.unblock_group_member(token, block.group_id, block.user_id) do
        Cache.invalidate_cache("group_block", block.id)
        {:ok, block}
      else
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot unblock member"}
    end
  end

  @impl true
  def validate_owner_count(group_id) do
    case get_group(group_id) do
      nil ->
        {:error, :must_have_at_least_one_owner}

      group ->
        owner_count =
          (group.user_groups || [])
          |> Enum.count(fn ug -> ug.role == :owner end)

        if owner_count <= 1 do
          {:error, :must_have_at_least_one_owner}
        else
          :ok
        end
    end
  end

  @impl true
  def repo_preload(struct_or_structs, _preloads) do
    struct_or_structs
  end

  defp list_cached_groups(_user) do
    case Cache.list_cached_items("group") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_group(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp with_fallback_to_cache(type, id, api_fn) do
    if Sync.online?() do
      case api_fn.() do
        nil ->
          get_from_cache(type, id)

        result ->
          result
      end
    else
      get_from_cache(type, id)
    end
  end

  defp get_from_cache(type, id) do
    case Cache.get_cached_item(type, id) do
      %{encrypted_data: data} when not is_nil(data) ->
        case type do
          "group" -> deserialize_group(data)
          "user_group" -> deserialize_user_group(data)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp cache_group(group_data) when is_map(group_data) do
    id = group_data["id"] || group_data[:id]
    Cache.cache_item("group", id, group_data)

    user_groups = group_data["user_groups"] || group_data[:user_groups] || []

    Enum.each(user_groups, fn ug ->
      ug_id = ug["id"] || ug[:id]
      Cache.cache_item("user_group", ug_id, ug)
    end)
  end

  defp deserialize_group(nil), do: nil

  defp deserialize_group(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_group(decoded)
      _ -> nil
    end
  end

  defp deserialize_group(data) when is_map(data) do
    user_groups =
      (data["user_groups"] || data[:user_groups] || [])
      |> Enum.map(&deserialize_user_group/1)
      |> Enum.reject(&is_nil/1)

    %Group{
      id: data["id"] || data[:id],
      name: data["name"] || data[:name],
      description: data["description"] || data[:description],
      public?: data["public?"] || data[:public?] || data["public"] || data[:public] || false,
      require_password?:
        data["require_password?"] || data[:require_password?] || data["require_password"] ||
          data[:require_password] || false,
      inserted_at: parse_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_datetime(data["updated_at"] || data[:updated_at]),
      user_groups: user_groups
    }
  end

  defp deserialize_user_group(nil), do: nil

  defp deserialize_user_group(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_user_group(decoded)
      _ -> nil
    end
  end

  defp deserialize_user_group(data) when is_map(data) do
    role =
      case data["role"] || data[:role] do
        r when is_atom(r) -> r
        r when is_binary(r) -> String.to_existing_atom(r)
        _ -> :member
      end

    %UserGroup{
      id: data["id"] || data[:id],
      group_id: data["group_id"] || data[:group_id],
      user_id: data["user_id"] || data[:user_id],
      name: data["name"] || data[:name],
      key: data["key"] || data[:key],
      role: role,
      moniker: data["moniker"] || data[:moniker],
      confirmed_at: parse_naive_datetime(data["confirmed_at"] || data[:confirmed_at]),
      inserted_at: parse_naive_datetime(data["inserted_at"] || data[:inserted_at]),
      updated_at: parse_naive_datetime(data["updated_at"] || data[:updated_at])
    }
  end

  defp deserialize_group_block(nil), do: nil

  defp deserialize_group_block(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> deserialize_group_block(decoded)
      _ -> nil
    end
  end

  defp deserialize_group_block(data) when is_map(data) do
    %GroupBlock{
      id: data["id"] || data[:id],
      group_id: data["group_id"] || data[:group_id],
      user_id: data["user_id"] || data[:user_id],
      blocked_by_id: data["blocked_by_id"] || data[:blocked_by_id],
      blocked_moniker: data["blocked_moniker"] || data[:blocked_moniker],
      reason: data["reason"] || data[:reason],
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

  defp build_changeset_errors(errors) when is_map(errors) do
    Enum.reduce(errors, Ecto.Changeset.change(%Group{}), fn {field, messages}, changeset ->
      field_atom = if is_binary(field), do: String.to_existing_atom(field), else: field

      Enum.reduce(List.wrap(messages), changeset, fn msg, cs ->
        Ecto.Changeset.add_error(cs, field_atom, msg)
      end)
    end)
  end

  defp build_changeset_errors(_), do: Ecto.Changeset.change(%Group{})
end
