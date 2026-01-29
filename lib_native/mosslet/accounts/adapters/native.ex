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
  def confirm_user!(%User{} = user) do
    user
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
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <- Client.create_connection(token, attrs) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        {:ok, deserialize_user_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "create", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_connection(uconn, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <- Client.update_connection(token, uconn.id, attrs) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        {:ok, deserialize_user_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "update", Map.put(attrs, :id, uconn.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_user_connection(uconn) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_connection(token, uconn.id) do
        Cache.invalidate_cache("user_connection", uconn.id)
        {:ok, uconn}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "delete", %{id: uconn.id})
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def confirm_user_connection(uconn, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data, reverse_connection: reverse_data}} <-
             Client.confirm_connection(token, uconn.id, attrs) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        Cache.cache_item("user_connection", reverse_data.id, reverse_data)
        {:ok, deserialize_user_connection(conn_data), deserialize_user_connection(reverse_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot confirm connection"}
    end
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

  defp encode_binary(nil), do: nil
  defp encode_binary(data) when is_binary(data), do: Base.encode64(data)

  defp serialize_profile(nil), do: nil

  defp serialize_profile(profile) when is_map(profile) do
    Map.new(profile, fn
      {k, v} when is_binary(v) and byte_size(v) > 100 -> {k, Base.encode64(v)}
      {k, v} -> {k, v}
    end)
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
  def delete_both_user_connections(uconn) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_both_connections(token, uconn.id) do
        Cache.invalidate_cache("user_connection", uconn.id)
        {:ok, [uconn]}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot delete connections"}
    end
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

  @impl true
  def get_user_by_username_for_connection(user, username) when is_binary(username) do
    case get_cached_user_by_field(:username_hash, username) do
      nil ->
        nil

      found_user ->
        if found_user.id != user.id && !has_user_connection?(found_user, user) do
          found_user
        else
          nil
        end
    end
  end

  @impl true
  def get_user_by_email_for_connection(user, email) when is_binary(email) do
    case get_cached_user_by_field(:email_hash, email) do
      nil ->
        nil

      found_user ->
        if found_user.id != user.id && !has_user_connection?(found_user, user) do
          found_user
        else
          nil
        end
    end
  end

  @impl true
  def get_both_user_connections_between_users!(user_id, reverse_user_id) do
    get_all_cached_user_connections()
    |> Enum.filter(fn uc ->
      (uc.user_id == user_id && uc.reverse_user_id == reverse_user_id) ||
        (uc.user_id == reverse_user_id && uc.reverse_user_id == user_id)
    end)
  end

  @impl true
  def get_user_connection_between_users(user_id, current_user_id) do
    unless is_nil(user_id) do
      get_all_cached_user_connections()
      |> Enum.find(fn uc ->
        uc.user_id == current_user_id && uc.reverse_user_id == user_id
      end)
    end
  end

  @impl true
  def get_user_connection_between_users!(user_id, current_user_id) do
    case get_user_connection_between_users(user_id, current_user_id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Accounts.UserConnection
      uconn -> uconn
    end
  end

  @impl true
  def update_user_connection_label(uconn, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           label <- Map.get(attrs, "label") || Map.get(attrs, :label),
           label_hash <- Map.get(attrs, "label_hash") || Map.get(attrs, :label_hash),
           {:ok, %{connection: conn_data}} <-
             Client.update_connection_label(
               token,
               uconn.id,
               encode_binary(label),
               encode_binary(label_hash)
             ) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        {:ok, deserialize_user_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "update_label", Map.put(attrs, :id, uconn.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_connection_zen(uconn, attrs, _opts) do
    if Sync.online?() do
      zen = Map.get(attrs, "zen?") || Map.get(attrs, :zen?)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <- Client.update_connection_zen(token, uconn.id, zen) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        {:ok, deserialize_user_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "update_zen", Map.put(attrs, :id, uconn.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_connection_photos(uconn, attrs, _opts) do
    if Sync.online?() do
      photos = Map.get(attrs, "photos?") || Map.get(attrs, :photos?)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <-
             Client.update_connection_photos(token, uconn.id, photos) do
        Cache.cache_item("user_connection", conn_data.id, conn_data)
        {:ok, deserialize_user_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user_connection", "update_photos", Map.put(attrs, :id, uconn.id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_profile(user, _conn, changeset) do
    if Sync.online?() do
      profile_attrs = Ecto.Changeset.get_field(changeset, :profile)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <-
             Client.update_user_profile(token, %{profile: serialize_profile(profile_attrs)}) do
        Cache.cache_item("connection", user.connection.id, conn_data)
        {:ok, deserialize_connection(conn_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - profile update requires network"}
    end
  end

  @impl true
  def update_user_name(_user, _conn, user_changeset, c_attrs) do
    if Sync.online?() do
      name = Ecto.Changeset.get_field(user_changeset, :name)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_name(token, %{
               name: encode_binary(name),
               connection_map: %{
                 c_name: encode_binary(c_attrs.c_name),
                 c_name_hash: encode_binary(c_attrs.c_name_hash)
               }
             }) do
        cache_user(user_data)
        user = deserialize_user(user_data)
        conn = user.connection || %Mosslet.Accounts.Connection{}
        {:ok, user, conn}
      else
        {:error, {_status, %{errors: errors}}} ->
          {:error, apply_api_errors(user_changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_name", %{
        name: Ecto.Changeset.get_field(user_changeset, :name)
      })

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_username(_user, _conn, user_changeset, c_attrs) do
    if Sync.online?() do
      username = Ecto.Changeset.get_field(user_changeset, :username)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_username(token, %{
               username: encode_binary(username),
               connection_map: %{
                 c_username: encode_binary(c_attrs.c_username),
                 c_username_hash: encode_binary(c_attrs.c_username_hash)
               }
             }) do
        cache_user(user_data)
        user = deserialize_user(user_data)
        conn = user.connection || %Mosslet.Accounts.Connection{}
        {:ok, user, conn}
      else
        {:error, {_status, %{errors: errors}}} ->
          {:error, apply_api_errors(user_changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_username", %{
        username: Ecto.Changeset.get_field(user_changeset, :username)
      })

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_visibility(_user, attrs, _opts) do
    if Sync.online?() do
      visibility = Map.get(attrs, "visibility") || Map.get(attrs, :visibility)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <- Client.update_user_visibility(token, visibility) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_visibility", attrs)
      {:error, "Offline - visibility update requires network"}
    end
  end

  @impl true
  def update_user_password(_user, changeset) do
    if Sync.online?() do
      password = Ecto.Changeset.get_field(changeset, :password)
      password_confirmation = Ecto.Changeset.get_field(changeset, :password_confirmation)
      current_password = Ecto.Changeset.get_field(changeset, :current_password)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_password(
               token,
               current_password,
               password,
               password_confirmation
             ) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - password update requires network"}
    end
  end

  @impl true
  def reset_user_password(user, attrs, _opts) do
    if Sync.online?() do
      current_password = Map.get(attrs, "current_password") || Map.get(attrs, :current_password)
      password = Map.get(attrs, "password") || Map.get(attrs, :password)

      password_confirmation =
        Map.get(attrs, "password_confirmation") || Map.get(attrs, :password_confirmation)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.reset_user_password(
               token,
               current_password,
               password,
               password_confirmation
             ) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = User.password_changeset(user, attrs)
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - password reset requires network"}
    end
  end

  @impl true
  def update_user_avatar(_user, _conn, user_changeset, c_attrs, opts) do
    if Sync.online?() do
      avatar_url = c_attrs.c_avatar_url || Map.get(c_attrs, :c_avatar_url)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data, connection: conn_data}} <-
             Client.update_user_avatar(token, encode_binary(avatar_url),
               delete: opts[:delete_avatar]
             ) do
        cache_user(user_data)
        user = deserialize_user(user_data)
        conn = deserialize_connection(conn_data)
        {:ok, user, conn}
      else
        {:error, {_status, %{errors: errors}}} ->
          {:error, apply_api_errors(user_changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - avatar update requires network"}
    end
  end

  @impl true
  def block_user(_blocker, blocked_user, attrs, _opts) do
    if Sync.online?() do
      reason = Map.get(attrs, "reason") || Map.get(attrs, :reason)
      note = Map.get(attrs, "note") || Map.get(attrs, :note)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{block: block_data}} <-
             Client.block_user(token, blocked_user.id, reason: reason, note: note) do
        Cache.cache_item("user_block", block_data.id, block_data)
        {:ok, deserialize_user_block(block_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot block user"}
    end
  end

  @impl true
  def unblock_user(_blocker, blocked_user) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _response} <- Client.unblock_user(token, blocked_user.id) do
        case Cache.list_cached_items("user_block") do
          items when is_list(items) ->
            Enum.each(items, fn item ->
              block = deserialize_user_block(item.encrypted_data)

              if block && block.blocked_id == blocked_user.id do
                Cache.invalidate_cache("user_block", block.id)
              end
            end)

          _ ->
            :ok
        end

        {:ok, blocked_user}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot unblock"}
    end
  end

  @impl true
  def user_blocked?(blocker, blocked_user) do
    case Cache.list_cached_items("user_block") do
      items when is_list(items) ->
        Enum.any?(items, fn item ->
          block = deserialize_user_block(item.encrypted_data)
          block && block.blocker_id == blocker.id && block.blocked_id == blocked_user.id
        end)

      _ ->
        false
    end
  end

  @impl true
  def list_blocked_users(user) do
    case Cache.list_cached_items("user_block") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_user_block(item.encrypted_data) end)
        |> Enum.filter(fn block -> block && block.blocker_id == user.id end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def get_user_block(blocker, blocked_user_id) when is_binary(blocked_user_id) do
    case Cache.list_cached_items("user_block") do
      items when is_list(items) ->
        Enum.find_value(items, fn item ->
          block = deserialize_user_block(item.encrypted_data)

          if block && block.blocker_id == blocker.id && block.blocked_id == blocked_user_id do
            block
          end
        end)

      _ ->
        nil
    end
  end

  @impl true
  def delete_user_account(user, password, _changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _response} <- Client.delete_account(token, password) do
        NativeSession.clear_session()
        Cache.invalidate_cache("user", user.id)
        {:ok, user}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = User.password_changeset(user, %{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          changeset = User.password_changeset(user, %{})
          {:error, Ecto.Changeset.add_error(changeset, :current_password, inspect(error))}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - account deletion requires network connection"}
    end
  end

  @impl true
  def deliver_user_reset_password_instructions(email) when is_binary(email) do
    if Sync.online?() do
      case Client.request_password_reset(email) do
        {:ok, _response} ->
          {:ok, %{message: "Password reset instructions sent if email exists"}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - password reset requires network connection"}
    end
  end

  def deliver_user_reset_password_instructions(_user_token) do
    Logger.warning("deliver_user_reset_password_instructions via API not yet implemented")
    {:error, "Password reset must be done via web interface"}
  end

  @impl true
  def get_user_by_reset_password_token(token) do
    if Sync.online?() do
      case Client.verify_password_reset_token(token) do
        {:ok, %{valid: true, user_id: user_id}} ->
          get_user(user_id)

        _ ->
          nil
      end
    else
      nil
    end
  end

  @impl true
  def insert_user_confirmation_token(_user_token) do
    Logger.warning("insert_user_confirmation_token via API not yet implemented")
    {:error, "Confirmation must be done via web interface"}
  end

  @impl true
  def confirm_user(token) do
    if Sync.online?() do
      case Client.confirm_email_with_token(token) do
        {:ok, _response} ->
          {:ok, %User{}}

        {:error, _reason} ->
          :error
      end
    else
      :error
    end
  end

  @impl true
  def insert_user_email_change_token(_user_token) do
    Logger.warning("insert_user_email_change_token via API - use request_email_change instead")
    {:error, "Use request_email_change API endpoint"}
  end

  @impl true
  def update_user_email(_user, _d_email, token, _key) do
    if Sync.online?() do
      with {:ok, api_token} <- NativeSession.get_token(),
           {:ok, _response} <- Client.confirm_email_change(api_token, token) do
        :ok
      else
        _ -> :error
      end
    else
      :error
    end
  end

  defp deserialize_user_block(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_user_block(map)
      _ -> nil
    end
  end

  defp deserialize_user_block(data) when is_map(data) do
    struct(Mosslet.Accounts.UserBlock, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_user_block(_), do: nil

  @impl true
  def get_shared_user_by_username(user_id, username) when is_binary(username) do
    case get_cached_user_by_field(:username_hash, username) do
      nil ->
        nil

      found_user ->
        if found_user.id != user_id && has_confirmed_user_connection?(found_user, user_id) do
          found_user
        else
          nil
        end
    end
  end

  def get_shared_user_by_username(_, _), do: nil

  @impl true
  def get_user_connection_for_user_group(user_id, current_user_id) do
    get_all_cached_user_connections()
    |> Enum.find(fn uc ->
      uc.user_id == user_id && uc.reverse_user_id == current_user_id
    end)
  end

  @impl true
  def get_user_connection_for_reply_shared_users(reply_user_id, current_user_id) do
    get_all_cached_user_connections()
    |> Enum.find(fn uc ->
      uc.user_id == current_user_id &&
        uc.reverse_user_id == reply_user_id &&
        uc.confirmed_at != nil
    end)
  end

  @impl true
  def get_current_user_connection_between_users!(user_id, current_user_id) do
    case get_all_cached_user_connections()
         |> Enum.find(fn uc ->
           uc.user_id == current_user_id && uc.reverse_user_id == user_id
         end) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Accounts.UserConnection
      uconn -> uconn
    end
  end

  @impl true
  def validate_users_in_connection(user_connection_id, current_user_id) do
    case get_user_connection(user_connection_id) do
      nil -> false
      uc -> current_user_id in [uc.user_id, uc.reverse_user_id]
    end
  end

  @impl true
  def get_user_connection_from_shared_item(item, current_user) do
    get_all_cached_user_connections()
    |> Enum.find(fn uc ->
      uc.connection && uc.connection.user_id == item.user_id && uc.user_id == current_user.id
    end)
  end

  @impl true
  def get_post_author_permissions_for_viewer(item, current_user) do
    get_all_cached_user_connections()
    |> Enum.find(fn uc ->
      uc.connection && uc.connection.user_id == current_user.id && uc.user_id == item.user_id
    end)
  end

  @impl true
  def get_user_from_post(post) do
    get_user(post.user_id)
  end

  @impl true
  def get_user_from_item(item) do
    get_user(item.user_id)
  end

  @impl true
  def get_user_from_item!(item) do
    case get_user(item.user_id) do
      nil -> raise Ecto.NoResultsError, queryable: User
      user -> user
    end
  end

  @impl true
  def get_connection_from_item(item, _current_user) do
    case Cache.list_cached_items("connection") do
      items when is_list(items) ->
        Enum.find_value(items, fn cache_item ->
          conn = deserialize_connection(cache_item.encrypted_data)
          if conn && conn.user_id == item.user_id, do: conn
        end)

      _ ->
        nil
    end
  end

  @impl true
  def list_all_users do
    case Cache.list_cached_items("user") do
      items when is_list(items) ->
        items
        |> Enum.map(fn item -> deserialize_user(item.encrypted_data) end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @impl true
  def count_all_users do
    list_all_users() |> Enum.count()
  end

  @impl true
  def list_all_confirmed_users do
    list_all_users()
    |> Enum.filter(fn u -> u.confirmed_at != nil end)
  end

  @impl true
  def count_all_confirmed_users do
    list_all_confirmed_users() |> Enum.count()
  end

  @impl true
  def create_user_profile(_user, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{connection: conn_data}} <- Client.create_user_profile(token, attrs) do
        Cache.cache_item("connection", conn_data.id, conn_data)
        {:ok, deserialize_connection(conn_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = Ecto.Changeset.change(%Mosslet.Accounts.Connection{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - profile creation requires network"}
    end
  end

  @impl true
  def delete_user_profile(_changeset) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _response} <- Client.delete_user_profile(token) do
        {:ok, %Mosslet.Accounts.Connection{}}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = Ecto.Changeset.change(%Mosslet.Accounts.Connection{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - cannot delete profile"}
    end
  end

  @impl true
  def update_user_onboarding(_user, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <- Client.update_user_onboarding(token, attrs) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_onboarding", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_onboarding_profile(_user, _conn, user_changeset, c_attrs) do
    if Sync.online?() do
      name = Ecto.Changeset.get_field(user_changeset, :name)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data, connection: conn_data}} <-
             Client.update_user_onboarding_profile(token, %{
               name: encode_binary(name),
               connection_map: %{
                 c_name: encode_binary(c_attrs[:c_name] || c_attrs["c_name"]),
                 c_name_hash: encode_binary(c_attrs[:c_name_hash] || c_attrs["c_name_hash"])
               }
             }) do
        cache_user(user_data)
        user = deserialize_user(user_data)
        conn = deserialize_connection(conn_data)
        {:ok, user, conn}
      else
        {:error, {_status, %{errors: errors}}} ->
          {:error, apply_api_errors(user_changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_onboarding_profile", %{
        name: Ecto.Changeset.get_field(user_changeset, :name)
      })

      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_notifications(_user, attrs, _opts) do
    if Sync.online?() do
      notifications = Map.get(attrs, "notifications?") || Map.get(attrs, :notifications?)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <- Client.update_user_notifications(token, notifications) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_notifications", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_tokens(_user, attrs) do
    if Sync.online?() do
      tokens = Map.get(attrs, "tokens") || Map.get(attrs, :tokens)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <- Client.update_user_tokens(token, tokens) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_tokens", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_user_email_notification_received_at(_user, timestamp) do
    if Sync.online?() do
      ts_string =
        if is_struct(timestamp, DateTime), do: DateTime.to_iso8601(timestamp), else: timestamp

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_email_notification_received_at(token, ts_string) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - skipping notification timestamp update"}
    end
  end

  @impl true
  def update_user_reply_notification_received_at(_user, timestamp) do
    if Sync.online?() do
      ts_string =
        if is_struct(timestamp, DateTime), do: DateTime.to_iso8601(timestamp), else: timestamp

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_reply_notification_received_at(token, ts_string) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - skipping notification timestamp update"}
    end
  end

  @impl true
  def update_user_replies_seen_at(_user, timestamp) do
    if Sync.online?() do
      ts_string =
        if is_struct(timestamp, DateTime), do: DateTime.to_iso8601(timestamp), else: timestamp

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <- Client.update_user_replies_seen_at(token, ts_string) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - skipping replies seen timestamp update"}
    end
  end

  @impl true
  def apply_user_email(user, password, attrs, _opts) do
    changeset =
      user
      |> User.email_changeset(attrs, [])
      |> User.validate_current_password(password)

    Ecto.Changeset.apply_action(changeset, :update)
  end

  @impl true
  def check_if_can_change_user_email(user, password, attrs) do
    changeset =
      user
      |> User.email_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Changeset.apply_action(changeset, :update)
  end

  @impl true
  def suspend_user(_user, _admin_user) do
    Logger.warning("suspend_user must be done via web interface")
    {:error, :unauthorized}
  end

  @impl true
  def create_visibility_group(_user, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data, visibility_groups: _groups}} <-
             Client.create_visibility_group(token, attrs) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = Ecto.Changeset.change(%User{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "create_visibility_group", attrs)
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def update_visibility_group(_user, group_id, attrs, _opts) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data, visibility_groups: _groups}} <-
             Client.update_visibility_group(token, group_id, attrs) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, %{errors: errors}}} ->
          changeset = Ecto.Changeset.change(%User{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, error}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      Cache.queue_for_sync("user", "update_visibility_group", Map.put(attrs, :id, group_id))
      {:error, "Offline - queued for sync"}
    end
  end

  @impl true
  def delete_visibility_group(_user, group_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data, visibility_groups: _groups}} <-
             Client.delete_visibility_group(token, group_id) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot delete visibility group"}
    end
  end

  @impl true
  def get_user_visibility_groups_with_connections(user) do
    case get_user(user.id) do
      nil ->
        []

      cached_user ->
        cached_user
    end
  end

  @impl true
  def delete_user_data(user, password, key, attrs, _opts) do
    if Sync.online?() do
      data = Map.get(attrs, "data", %{})

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, deletable_data} <- Client.get_deletable_data(token, data),
           :ok <- delete_storage_files(user, key, deletable_data),
           {:ok, _response} <- Client.delete_data_records(token, password, data) do
        invalidate_local_caches(data)
        :ok
      else
        {:error, {_status, %{errors: errors}}} when is_map(errors) ->
          changeset = Ecto.Changeset.change(%User{})
          {:error, apply_api_errors(changeset, errors)}

        {:error, {_status, %{error: error}}} ->
          {:error, error}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - data deletion requires network connection"}
    end
  end

  defp delete_storage_files(user, key, deletable_data) do
    urls = collect_all_urls(user, key, deletable_data)

    case urls do
      [] -> :ok
      urls -> delete_urls_from_storage(urls)
    end
  end

  defp collect_all_urls(user, key, data) do
    post_urls = collect_post_urls(user, key, Map.get(data, "posts", []))
    memory_urls = collect_memory_urls(user, key, Map.get(data, "memories", []))
    reply_urls = collect_reply_urls(user, key, Map.get(data, "replies", []))
    post_reply_urls = collect_reply_urls(user, key, Map.get(data, "post_replies", []))

    (post_urls ++ memory_urls ++ reply_urls ++ post_reply_urls)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp collect_post_urls(user, key, posts) when is_list(posts) do
    Enum.flat_map(posts, fn post ->
      with false <- post["repost"] || false,
           image_urls when is_list(image_urls) <- post["image_urls"],
           {:ok, post_key} <- decode_key(post["e_key"]) do
        image_urls
        |> Enum.map(&decode_image_url/1)
        |> Enum.map(&decrypt_url(&1, user, post_key, key, post["visibility"]))
      else
        _ -> []
      end
    end)
  end

  defp collect_post_urls(_user, _key, _), do: []

  defp collect_memory_urls(user, key, memories) when is_list(memories) do
    Enum.flat_map(memories, fn memory ->
      with {:ok, memory_key} <- decode_key(memory["e_key"]),
           url when is_binary(url) <- memory["image_url"],
           decoded_url <- decode_image_url(url) do
        [decrypt_url(decoded_url, user, memory_key, key, nil)]
      else
        _ -> []
      end
    end)
  end

  defp collect_memory_urls(_user, _key, _), do: []

  defp collect_reply_urls(user, key, replies) when is_list(replies) do
    Enum.flat_map(replies, fn reply ->
      with image_urls when is_list(image_urls) and image_urls != [] <- reply["image_urls"],
           %{"e_key" => e_key, "visibility" => visibility} <- reply["post"],
           {:ok, post_key} <- decode_key(e_key) do
        image_urls
        |> Enum.map(&decode_image_url/1)
        |> Enum.map(&decrypt_url(&1, user, post_key, key, visibility))
      else
        _ -> []
      end
    end)
  end

  defp collect_reply_urls(_user, _key, _), do: []

  defp decode_image_url(nil), do: nil

  defp decode_image_url(url) when is_binary(url) do
    case Base.decode64(url) do
      {:ok, decoded} -> decoded
      :error -> url
    end
  end

  defp decrypt_url(encrypted_url, user, item_key, session_key, visibility)
       when is_binary(encrypted_url) and is_binary(item_key) do
    case visibility do
      "public" ->
        Mosslet.Encrypted.Users.Utils.decrypt_public_item(encrypted_url, item_key)

      _ ->
        Mosslet.Encrypted.Users.Utils.decrypt_user_item(
          encrypted_url,
          user,
          item_key,
          session_key
        )
    end
  end

  defp decrypt_url(_, _, _, _, _), do: nil

  defp decode_key(nil), do: {:error, :no_key}

  defp decode_key(data) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, data}
    end
  end

  defp delete_urls_from_storage(urls) when is_list(urls) do
    bucket = Mosslet.Encrypted.Session.memories_bucket()

    results =
      urls
      |> Enum.chunk_every(100)
      |> Enum.map(fn chunk ->
        ExAws.S3.delete_multiple_objects(bucket, chunk)
        |> ExAws.request()
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to delete storage files: #{inspect(reason)}")
        {:error, "Failed to delete storage files"}
    end
  end

  defp invalidate_local_caches(data) do
    if data["posts"] == "true", do: Cache.clear_cache("post")
    if data["memories"] == "true", do: Cache.clear_cache("memory")
    if data["replies"] == "true", do: Cache.clear_cache("reply")
    if data["user_connections"] == "true", do: Cache.clear_cache("user_connection")
    if data["groups"] == "true", do: Cache.clear_cache("group")
    if data["remarks"] == "true", do: Cache.clear_cache("remark")
    :ok
  end

  @impl true
  def get_all_user_connections_from_shared_item(_item, _current_user) do
    []
  end

  @impl true
  def update_user_forgot_password(_user, attrs, _opts) do
    if Sync.online?() do
      forgot_password = Map.get(attrs, "forgot_password?") || Map.get(attrs, :forgot_password?)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_forgot_password(token, forgot_password) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot update forgot password status"}
    end
  end

  @impl true
  def update_user_oban_reset_token_id(_user, attrs, _opts) do
    if Sync.online?() do
      oban_reset_token_id =
        Map.get(attrs, "oban_reset_token_id") || Map.get(attrs, :oban_reset_token_id)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_oban_reset_token_id(token, oban_reset_token_id) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - cannot update oban reset token"}
    end
  end

  @impl true
  def update_user_admin(_user, _attrs, _opts) do
    Logger.warning("update_user_admin must be done via web interface")
    nil
  end

  # ============================================================================
  # TOTP / 2FA Functions
  # ============================================================================

  alias Mosslet.Accounts.UserTOTP

  @impl true
  def two_factor_auth_enabled?(user) do
    case get_user_totp(user) do
      nil -> false
      _ -> true
    end
  end

  @impl true
  def get_user_totp(user) do
    case Cache.get_cached_item("user_totp", user.id) do
      %{encrypted_data: data} when not is_nil(data) ->
        deserialize_user_totp(data)

      _ ->
        nil
    end
  end

  @impl true
  def change_user_totp(totp, attrs \\ %{}) do
    UserTOTP.changeset(totp, attrs)
  end

  @impl true
  def upsert_user_totp(totp, attrs) do
    if Sync.online?() do
      code = Map.get(attrs, :code) || Map.get(attrs, "code")
      secret = Base.encode32(totp.secret, padding: false)

      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{enabled: true, backup_codes: backup_codes}} <-
             Client.enable_totp(token, secret, code) do
        updated_totp = %{
          totp
          | backup_codes: Enum.map(backup_codes, fn code -> %{code: code, used_at: nil} end)
        }

        Cache.cache_item("user_totp", totp.user_id, updated_totp)
        {:ok, updated_totp}
      else
        {:error, {_status, %{error: error}}} ->
          changeset =
            UserTOTP.changeset(totp, attrs)
            |> Ecto.Changeset.add_error(:code, error)

          {:error, changeset}

        {:error, reason} ->
          changeset =
            UserTOTP.changeset(totp, attrs)
            |> Ecto.Changeset.add_error(:base, inspect(reason))

          {:error, changeset}
      end
    else
      {:error, "Offline - 2FA setup requires network connection"}
    end
  end

  @impl true
  def regenerate_user_totp_backup_codes(totp) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           current_code <- get_current_totp_code(totp),
           {:ok, %{backup_codes: backup_codes}} <-
             Client.regenerate_backup_codes(token, current_code) do
        updated_totp = %{
          totp
          | backup_codes: Enum.map(backup_codes, fn code -> %{code: code, used_at: nil} end)
        }

        Cache.cache_item("user_totp", totp.user_id, updated_totp)
        {:ok, updated_totp}
      else
        {:error, {_status, %{error: error}}} ->
          changeset =
            UserTOTP.changeset(totp, %{})
            |> Ecto.Changeset.add_error(:code, error)

          {:error, changeset}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - backup code regeneration requires network connection"}
    end
  end

  defp get_current_totp_code(totp) do
    NimbleTOTP.verification_code(totp.secret)
  end

  @impl true
  def delete_user_totp(user_totp) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           current_code <- get_current_totp_code(user_totp),
           {:ok, %{enabled: false}} <- Client.disable_totp(token, code: current_code) do
        Cache.invalidate_cache("user_totp", user_totp.user_id)
        {:ok, user_totp}
      else
        {:error, {_status, %{error: error}}} ->
          changeset =
            UserTOTP.changeset(user_totp, %{})
            |> Ecto.Changeset.add_error(:base, error)

          {:error, changeset}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Offline - 2FA deletion requires network connection"}
    end
  end

  @impl true
  def validate_user_totp(user, code) do
    case get_user_totp(user) do
      nil ->
        :invalid

      totp ->
        cond do
          UserTOTP.valid_totp?(totp, code) ->
            :valid_totp

          changeset = UserTOTP.validate_backup_code(totp, code) ->
            remaining =
              Enum.count(
                Ecto.Changeset.get_field(changeset, :backup_codes, []),
                &is_nil(&1.used_at)
              )

            {:valid_backup_code, remaining}

          true ->
            :invalid
        end
    end
  end

  defp deserialize_user_totp(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_user_totp(map)
      _ -> nil
    end
  end

  defp deserialize_user_totp(data) when is_map(data) do
    struct(UserTOTP, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_user_totp(_), do: nil

  @impl true
  def update_last_signed_in_info(user, _ip, _key) do
    {:ok, user}
  end

  @impl true
  def preload_org_data(user, current_org_slug) do
    user = preload_user_orgs(user)

    if current_org_slug do
      %{user | current_org: Enum.find(user.orgs || [], &(&1.slug == current_org_slug))}
    else
      user
    end
  end

  defp preload_user_orgs(user) do
    case Cache.list_cached_items("org") do
      items when is_list(items) ->
        orgs =
          items
          |> Enum.map(fn item -> deserialize_org(item.encrypted_data) end)
          |> Enum.filter(fn org -> org && org.user_id == user.id end)

        %{user | orgs: orgs}

      _ ->
        %{user | orgs: []}
    end
  end

  defp deserialize_org(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, map} -> deserialize_org(map)
      _ -> nil
    end
  end

  defp deserialize_org(data) when is_map(data) do
    struct(Mosslet.Orgs.Org, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_org(_), do: nil

  @impl true
  def preload_user_connection(user_connection, preloads) do
    Enum.reduce(preloads, user_connection, fn
      :user, uc ->
        case uc.user_id do
          nil -> uc
          user_id -> %{uc | user: get_user(user_id)}
        end

      :connection, uc ->
        case uc.connection_id do
          nil -> uc
          conn_id -> %{uc | connection: get_connection(conn_id)}
        end

      :reverse_user, uc ->
        case uc.reverse_user_id do
          nil -> uc
          user_id -> %{uc | reverse_user: get_user(user_id)}
        end

      _, uc ->
        uc
    end)
  end

  @impl true
  def preload_connection_assocs(connection, preloads) do
    Enum.reduce(preloads, connection, fn
      :user, conn ->
        case conn.user_id do
          nil -> conn
          user_id -> %{conn | user: get_user(user_id)}
        end

      :user_connections, conn ->
        uconns =
          get_all_cached_user_connections()
          |> Enum.filter(fn uc -> uc.connection_id == conn.id end)

        %{conn | user_connections: uconns}

      _, conn ->
        conn
    end)
  end

  # ============================================================================
  # Delete User Data Functions
  # These call API endpoints to perform deletions on the server.
  # The context handles business logic like URL decryption for S3 deletion
  # locally (zero-knowledge), then calls these to do the DB deletions.
  # ============================================================================

  @impl true
  def delete_all_user_connections(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_user_connections(token, user_id) do
      Cache.clear_cache("user_connection")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_groups(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_groups(token, user_id) do
      Cache.clear_cache("group")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_memories(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_memories(token, user_id) do
      Cache.clear_cache("memory")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_posts(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_posts(token, user_id) do
      Cache.clear_cache("post")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_user_memories(uconn) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, _response} <- Client.delete_all_user_memories(token, uconn.id) do
      {:ok, :deleted}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_user_posts(uconn) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, _response} <- Client.delete_all_user_posts(token, uconn.id) do
      {:ok, :deleted}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_remarks(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_remarks(token, user_id) do
      Cache.clear_cache("remark")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_replies(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_replies(token, user_id) do
      Cache.clear_cache("reply")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_all_bookmarks(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{count: count}} <- Client.delete_all_bookmarks(token, user_id) do
      Cache.clear_cache("bookmark")
      {:ok, count}
    else
      {:error, {_status, error}} -> {:error, error}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def cleanup_shared_users_from_posts(uconn_user_id, uconn_reverse_user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, _response} <-
           Client.cleanup_shared_users_from_posts(token, uconn_user_id, uconn_reverse_user_id) do
      {:ok, :cleaned}
    else
      {:error, {_status, _error}} -> {:ok, :cleaned}
      {:error, _reason} -> {:ok, :cleaned}
    end
  end

  @impl true
  def cleanup_shared_users_from_memories(uconn_user_id, uconn_reverse_user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, _response} <-
           Client.cleanup_shared_users_from_memories(
             token,
             uconn_user_id,
             uconn_reverse_user_id
           ) do
      {:ok, :cleaned}
    else
      {:error, {_status, _error}} -> {:ok, :cleaned}
      {:error, _reason} -> {:ok, :cleaned}
    end
  end

  @impl true
  def get_all_memories_for_user(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{memories: memories}} <- Client.get_all_memories_for_user(token, user_id) do
      Enum.map(memories, &deserialize_memory/1)
    else
      _ -> []
    end
  end

  @impl true
  def get_all_posts_for_user(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{posts: posts}} <- Client.get_all_posts_for_user(token, user_id) do
      Enum.map(posts, &deserialize_post/1)
    else
      _ -> []
    end
  end

  @impl true
  def get_all_replies_for_user(user_id) do
    with {:ok, token} <- NativeSession.get_token(),
         {:ok, %{replies: replies}} <- Client.get_all_replies_for_user(token, user_id) do
      Enum.map(replies, &deserialize_reply/1)
    else
      _ -> []
    end
  end

  @impl true
  def update_journal_privacy(_user, enabled) when is_boolean(enabled) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_journal_privacy(token, enabled) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, error}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - journal privacy update requires network"}
    end
  end

  @impl true
  def delete_all_journals(user_id) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, _} <- Client.delete_all_journals(token, user_id) do
        {:ok, :deleted}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Offline - journal deletion requires network"}
    end
  end

  @impl true
  def update_mood_insights_enabled(user, enabled) when is_boolean(enabled) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_mood_insights_enabled(token, enabled) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "#{error}")}
        {:error, reason} -> {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "#{reason}")}
      end
    else
      {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "Offline - update requires network")}
    end
  end

  @impl true
  def update_user_mention_email_received_at(user, timestamp) do
    if Sync.online?() do
      with {:ok, token} <- NativeSession.get_token(),
           {:ok, %{user: user_data}} <-
             Client.update_user_mention_email_received_at(token, timestamp) do
        cache_user(user_data)
        {:ok, deserialize_user(user_data)}
      else
        {:error, {_status, error}} -> {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "#{error}")}
        {:error, reason} -> {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "#{reason}")}
      end
    else
      {:error, Ecto.Changeset.change(user) |> Ecto.Changeset.add_error(:base, "Offline - update requires network")}
    end
  end

  defp deserialize_memory(data) when is_map(data) do
    struct(Mosslet.Memories.Memory, atomize_keys(data))
  rescue
    _ -> nil
  end

  defp deserialize_memory(_), do: nil

  defp deserialize_post(data) when is_map(data) do
    post = struct(Mosslet.Timeline.Post, atomize_keys(data))

    replies =
      case data[:replies] || data["replies"] do
        nil -> []
        replies -> Enum.map(replies, &deserialize_reply/1) |> Enum.reject(&is_nil/1)
      end

    %{post | replies: replies}
  rescue
    _ -> nil
  end

  defp deserialize_post(_), do: nil

  defp deserialize_reply(data) when is_map(data) do
    reply = struct(Mosslet.Timeline.Reply, atomize_keys(data))

    post =
      case data[:post] || data["post"] do
        nil -> nil
        post_data -> struct(Mosslet.Timeline.Post, atomize_keys(post_data))
      end

    %{reply | post: post}
  rescue
    _ -> nil
  end

  defp deserialize_reply(_), do: nil
end
