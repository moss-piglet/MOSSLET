defmodule MossletWeb.API.SyncController do
  @moduledoc """
  Sync endpoints for desktop/mobile apps.

  Returns encrypted data blobs that native apps decrypt locally.
  This enables true zero-knowledge operation where the server
  never sees plaintext user content.
  """
  use MossletWeb, :controller

  alias Mosslet.{Accounts, Timeline}

  action_fallback MossletWeb.API.FallbackController

  def user(conn, _params) do
    user = Accounts.get_user_with_preloads(conn.assigns.current_user.id)

    user_data = %{
      id: user.id,
      email_hash: encode_binary(user.email_hash),
      username_hash: encode_binary(user.username_hash),
      key_pair: encode_key_pair(user.key_pair),
      key_hash: encode_binary(user.key_hash),
      conn_key: encode_binary(user.conn_key),
      connection: serialize_connection(user.connection),
      is_confirmed: not is_nil(user.confirmed_at),
      is_onboarded: user.is_onboarded?,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }

    conn
    |> put_status(:ok)
    |> json(%{user: user_data, synced_at: DateTime.utc_now()})
  end

  def posts(conn, params) do
    user = conn.assigns.current_user
    since = parse_timestamp(params["since"])
    limit = parse_limit(params["limit"], 50)

    posts = Timeline.list_user_posts_for_sync(user, since: since, limit: limit)

    conn
    |> put_status(:ok)
    |> json(%{
      posts: Enum.map(posts, &serialize_post_for_sync/1),
      synced_at: DateTime.utc_now(),
      has_more: length(posts) == limit
    })
  end

  def connections(conn, params) do
    user = conn.assigns.current_user
    since = parse_timestamp(params["since"])

    connections = Accounts.list_user_connections_for_sync(user, since: since)

    conn
    |> put_status(:ok)
    |> json(%{
      connections: Enum.map(connections, &serialize_connection_for_sync/1),
      synced_at: DateTime.utc_now()
    })
  end

  def groups(conn, params) do
    user = conn.assigns.current_user
    since = parse_timestamp(params["since"])

    groups = Mosslet.Groups.list_user_groups_for_sync(user, since: since)

    conn
    |> put_status(:ok)
    |> json(%{
      groups: Enum.map(groups, &serialize_group_for_sync/1),
      synced_at: DateTime.utc_now()
    })
  end

  def full_sync(conn, params) do
    user = conn.assigns.current_user
    since = parse_timestamp(params["since"])

    user_data = Accounts.get_user_with_preloads(user.id)
    posts = Timeline.list_user_posts_for_sync(user, since: since, limit: 100)
    connections = Accounts.list_user_connections_for_sync(user, since: since)
    groups = Mosslet.Groups.list_user_groups_for_sync(user, since: since)

    conn
    |> put_status(:ok)
    |> json(%{
      user: serialize_user_data(user_data),
      posts: Enum.map(posts, &serialize_post_for_sync/1),
      connections: Enum.map(connections, &serialize_connection_for_sync/1),
      groups: Enum.map(groups, &serialize_group_for_sync/1),
      synced_at: DateTime.utc_now()
    })
  end

  defp serialize_connection(nil), do: nil

  defp serialize_connection(connection) do
    %{
      id: connection.id,
      email: encode_binary(connection.email),
      username: encode_binary(connection.username),
      avatar_url: encode_binary(connection.avatar_url),
      updated_at: connection.updated_at
    }
  end

  defp serialize_post_for_sync(user_post) do
    post = user_post.post

    %{
      id: post.id,
      body: encode_binary(post.body),
      username: encode_binary(post.username),
      avatar_url: encode_binary(post.avatar_url),
      content_warning: encode_binary(post.content_warning),
      visibility: post.visibility,
      user_post_key: encode_binary(user_post.key),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp serialize_connection_for_sync(user_connection) do
    connection = user_connection.connection

    %{
      id: connection.id,
      user_id: connection.user_id,
      email: encode_binary(connection.email),
      username: encode_binary(connection.username),
      avatar_url: encode_binary(connection.avatar_url),
      user_connection_key: encode_binary(user_connection.key),
      updated_at: connection.updated_at
    }
  end

  defp serialize_group_for_sync(user_group) do
    group = user_group.group

    %{
      id: group.id,
      name: encode_binary(group.name),
      description: encode_binary(group.description),
      user_group_key: encode_binary(user_group.key),
      role: user_group.role,
      updated_at: group.updated_at
    }
  end

  defp serialize_user_data(user) do
    %{
      id: user.id,
      email_hash: encode_binary(user.email_hash),
      username_hash: encode_binary(user.username_hash),
      key_pair: encode_key_pair(user.key_pair),
      key_hash: encode_binary(user.key_hash),
      conn_key: encode_binary(user.conn_key),
      connection: serialize_connection(user.connection),
      is_confirmed: not is_nil(user.confirmed_at),
      is_onboarded: user.is_onboarded?,
      updated_at: user.updated_at
    }
  end

  defp encode_binary(nil), do: nil

  defp encode_binary(data) when is_binary(data) do
    Base.encode64(data)
  end

  defp encode_key_pair(nil), do: nil

  defp encode_key_pair(key_pair) when is_map(key_pair) do
    Map.new(key_pair, fn {k, v} -> {k, encode_binary(v)} end)
  end

  defp parse_timestamp(nil), do: nil

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_limit(nil, default), do: default
  defp parse_limit(limit, _default) when is_integer(limit), do: min(limit, 100)

  defp parse_limit(limit, default) when is_binary(limit) do
    case Integer.parse(limit) do
      {n, _} -> min(n, 100)
      :error -> default
    end
  end
end
