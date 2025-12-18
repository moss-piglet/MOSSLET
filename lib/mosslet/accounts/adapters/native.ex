defmodule Mosslet.Accounts.Adapters.Native do
  @moduledoc """
  Native adapter for account operations on desktop/mobile apps.

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

  @behaviour Mosslet.Accounts.Adapter

  require Logger

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Accounts.User
  alias Mosslet.Sync

  @impl true
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    case Client.login(email, password) do
      {:ok, %{"token" => token, "user" => user_data}} ->
        NativeSession.store_session(user_data["id"], token, user_data)
        cache_user(user_data)
        deserialize_user(user_data)

      {:ok, %{token: token, user: user_data}} ->
        user_id = user_data[:id] || user_data["id"]
        NativeSession.store_session(user_id, token, user_data)
        cache_user(user_data)
        deserialize_user(user_data)

      {:error, reason} ->
        Logger.debug("Native login failed: #{inspect(reason)}")
        nil
    end
  end

  @impl true
  def register_user(user_changeset, c_attrs \\ %{}) do
    user_params =
      user_changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.from_struct()
      |> Map.take([:email, :password, :username, :name])
      |> Map.merge(%{
        email: c_attrs[:c_email] || c_attrs.c_email,
        username: c_attrs[:c_username] || c_attrs.c_username
      })

    case Client.register(user_params) do
      {:ok, %{"token" => token, "user" => user_data}} ->
        NativeSession.store_session(user_data["id"], token, user_data)
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}

      {:ok, %{token: token, user: user_data}} ->
        user_id = user_data[:id] || user_data["id"]
        NativeSession.store_session(user_id, token, user_data)
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}

      {:error, %{"errors" => errors}} ->
        changeset = apply_api_errors(user_changeset, errors)
        {:error, changeset}

      {:error, reason} ->
        Logger.error("Native registration failed: #{inspect(reason)}")
        {:error, Ecto.Changeset.add_error(user_changeset, :base, "Registration failed")}
    end
  end

  @impl true
  def get_user(id) do
    with_fallback_to_cache("user", id, fn ->
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{"user" => user_data}} <- Client.me(token) do
        cache_user(user_data)
        deserialize_user(user_data)
      else
        _ -> nil
      end
    end)
  end

  @impl true
  def get_user!(id) do
    case get_user(id) do
      nil -> raise Ecto.NoResultsError, queryable: User
      user -> user
    end
  end

  @impl true
  def get_user_by_email(email) when is_binary(email) do
    case get_cached_user_by_field(:email_hash, email) do
      nil -> nil
      user -> user
    end
  end

  @impl true
  def get_user_by_username(username) when is_binary(username) do
    case get_cached_user_by_field(:username_hash, username) do
      nil -> nil
      user -> user
    end
  end

  @impl true
  def get_user_by_session_token(_token) do
    case NativeSession.get_user_id() do
      {:ok, user_id} -> get_user(user_id)
      _ -> nil
    end
  end

  @impl true
  def generate_user_session_token(_user) do
    case NativeSession.get_token() do
      {:ok, token} -> token
      _ -> raise "No token available - user must authenticate via API"
    end
  end

  @impl true
  def delete_user_session_token(_token) do
    with {:ok, token} <- NativeSession.get_token() do
      Client.logout(token)
    end

    NativeSession.clear_session()
    :ok
  end

  @impl true
  def get_user_with_preloads(id) do
    get_user(id)
  end

  @impl true
  def get_user_from_profile_slug(slug) do
    get_user_by_username(slug)
  end

  @impl true
  def get_user_from_profile_slug!(slug) do
    case get_user_from_profile_slug(slug) do
      nil -> raise Ecto.NoResultsError, queryable: User
      user -> user
    end
  end

  @impl true
  def confirm_user(_token) do
    :error
  end

  @impl true
  def get_connection(id) do
    case Cache.get_cached_item("connection", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_connection(data)

      _ ->
        nil
    end
  end

  @impl true
  def get_connection!(id) do
    case get_connection(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Accounts.Connection
      conn -> conn
    end
  end

  @impl true
  def get_user_connection(id) do
    case Cache.get_cached_item("user_connection", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_user_connection(data)

      _ ->
        nil
    end
  end

  @impl true
  def get_user_connection!(id) do
    case get_user_connection(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Accounts.UserConnection
      uconn -> uconn
    end
  end

  @impl true
  def create_user_connection(attrs, _opts) do
    if Sync.online?() do
      Logger.warning("create_user_connection via API not yet implemented")
      {:error, "Not implemented for native yet"}
    else
      Cache.queue_for_sync("user_connection", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_connection(_uconn, attrs, _opts) do
    if Sync.online?() do
      Logger.warning("update_user_connection via API not yet implemented")
      {:error, "Not implemented for native yet"}
    else
      Cache.queue_for_sync("user_connection", "update", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_user_connection(uconn) do
    if Sync.online?() do
      Logger.warning("delete_user_connection via API not yet implemented")
      {:error, "Not implemented for native yet"}
    else
      Cache.queue_for_sync("user_connection", "delete", %{id: uconn.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def confirm_user_connection(_uconn, _attrs, _opts) do
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def filter_user_connections(_filter, user) do
    case Cache.list_cached_items("user_connection") do
      items when is_list(items) ->
        items
        |> Enum.filter(fn item ->
          data = deserialize_user_connection(item.encrypted_data)
          data && data.user_id == user.id && data.confirmed_at != nil
        end)
        |> Enum.map(fn item -> deserialize_user_connection(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def list_user_connections_for_sync(user, opts \\ []) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{"connections" => connections}} <- Client.fetch_connections(token, opts) do
      Enum.each(connections, fn conn_data ->
        Cache.cache_item("user_connection", conn_data["id"], conn_data)
      end)

      Enum.map(connections, &deserialize_user_connection/1)
    else
      _ ->
        filter_user_connections(%{}, user)
    end
  end

  defp with_fallback_to_cache(type, id, fetch_fn) do
    if Sync.online?() do
      case fetch_fn.() do
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
          "user" -> deserialize_user(data)
          "connection" -> deserialize_connection(data)
          "user_connection" -> deserialize_user_connection(data)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp cache_user(user_data) when is_map(user_data) do
    id = user_data["id"] || user_data[:id]
    if id, do: Cache.cache_item("user", id, user_data)
  end

  defp get_cached_user_by_field(field, value) do
    case Cache.list_cached_items("user") do
      items when is_list(items) ->
        Enum.find_value(items, fn item ->
          user = deserialize_user(item.encrypted_data)

          if user && Map.get(user, field) == value do
            user
          end
        end)

      _ ->
        nil
    end
  end

  defp deserialize_user(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_user(map)
      _ -> nil
    end
  end

  defp deserialize_user(data) when is_map(data) do
    struct(User, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_user(_), do: nil

  defp deserialize_connection(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_connection(map)
      _ -> nil
    end
  end

  defp deserialize_connection(data) when is_map(data) do
    struct(Mosslet.Accounts.Connection, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_connection(_), do: nil

  defp deserialize_user_connection(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_user_connection(map)
      _ -> nil
    end
  end

  defp deserialize_user_connection(data) when is_map(data) do
    struct(Mosslet.Accounts.UserConnection, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_user_connection(_), do: nil

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> map
  end

  defp apply_api_errors(changeset, errors) when is_map(errors) do
    Enum.reduce(errors, changeset, fn {field, messages}, cs ->
      field_atom =
        if is_binary(field), do: String.to_existing_atom(field), else: field

      messages = if is_list(messages), do: messages, else: [messages]

      Enum.reduce(messages, cs, fn msg, inner_cs ->
        Ecto.Changeset.add_error(inner_cs, field_atom, msg)
      end)
    end)
  rescue
    _ -> changeset
  end

  @impl true
  def preload_connection(%User{} = user) do
    case Cache.get_cached_item("connection", user.id) do
      %{encrypted_data: data} when not is_nil(data) ->
        connection = deserialize_connection(data)
        %{user | connection: connection}

      _ ->
        user
    end
  end

  @impl true
  def has_user_connection?(%User{} = user, current_user) do
    cached_connections = get_all_cached_user_connections()

    Enum.any?(cached_connections, fn uc ->
      (uc.user_id == user.id && uc.reverse_user_id == current_user.id) ||
        (uc.reverse_user_id == user.id && uc.user_id == current_user.id)
    end)
  end

  @impl true
  def has_confirmed_user_connection?(%User{} = user, current_user_id) do
    cached_connections = get_all_cached_user_connections()

    Enum.any?(cached_connections, fn uc ->
      uc.confirmed_at != nil &&
        ((uc.user_id == user.id && uc.reverse_user_id == current_user_id) ||
           (uc.reverse_user_id == user.id && uc.user_id == current_user_id))
    end)
  end

  @impl true
  def has_any_user_connections?(nil), do: nil

  def has_any_user_connections?(user) do
    cached_connections = get_all_cached_user_connections()

    Enum.any?(cached_connections, fn uc ->
      uc.confirmed_at != nil &&
        (uc.user_id == user.id || uc.reverse_user_id == user.id)
    end)
  end

  @impl true
  def filter_user_arrivals(_filter, user) do
    get_all_cached_user_connections()
    |> Enum.filter(fn uc ->
      uc.user_id == user.id && is_nil(uc.confirmed_at)
    end)
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  @impl true
  def arrivals_count(user) do
    filter_user_arrivals(%{}, user)
    |> Enum.count()
  end

  @impl true
  def list_user_arrivals_connections(user, options) do
    arrivals = filter_user_arrivals(%{}, user)

    arrivals
    |> maybe_sort(options)
    |> maybe_paginate(options)
  end

  @impl true
  def delete_both_user_connections(_uconn) do
    Logger.warning("delete_both_user_connections via API not yet implemented")
    {:error, "Not implemented for native yet"}
  end

  @impl true
  def get_all_user_connections(id) do
    get_all_cached_user_connections()
    |> Enum.filter(fn uc ->
      (uc.user_id == id || uc.reverse_user_id == id) &&
        uc.connection && uc.connection.user_id != id
    end)
  end

  @impl true
  def get_all_confirmed_user_connections(id) do
    get_all_cached_user_connections()
    |> Enum.filter(fn uc ->
      uc.confirmed_at != nil &&
        (uc.user_id == id || uc.reverse_user_id == id) &&
        uc.connection && uc.connection.user_id != id
    end)
  end

  @impl true
  def search_user_connections(user, search_query) when is_binary(search_query) do
    normalized_query = String.downcase(String.trim(search_query))

    if String.length(normalized_query) > 0 do
      get_all_cached_user_connections()
      |> Enum.filter(fn uc ->
        uc.user_id == user.id &&
          uc.confirmed_at != nil &&
          uc.label_hash == normalized_query
      end)
    else
      filter_user_connections(%{}, user)
    end
  end

  defp get_all_cached_user_connections do
    case Cache.list_cached_items("user_connection") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_user_connection(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp maybe_sort(list, %{sort_by: sort_by, sort_order: sort_order}) do
    Enum.sort_by(list, &Map.get(&1, sort_by), {sort_order, DateTime})
  end

  defp maybe_sort(list, _options), do: list

  defp maybe_paginate(list, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)
    list |> Enum.drop(offset) |> Enum.take(per_page)
  end

  defp maybe_paginate(list, _options), do: list
end
