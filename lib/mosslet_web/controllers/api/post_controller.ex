defmodule MossletWeb.API.PostController do
  @moduledoc """
  API endpoints for post CRUD operations.

  Native apps send pre-encrypted data (encrypted locally with enacl).
  The server stores this encrypted data with an additional Cloak layer.

  ## Zero-Knowledge Flow

  1. Native app encrypts content locally with post_key
  2. Native app encrypts post_key for each recipient's public key
  3. Server receives encrypted blobs, adds Cloak layer, stores in Postgres
  4. Server never sees plaintext content
  """
  use MossletWeb, :controller

  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post

  action_fallback MossletWeb.API.FallbackController

  def index(conn, params) do
    user = conn.assigns.current_user
    opts = build_list_opts(params)

    posts = Timeline.list_user_posts_for_sync(user, opts)

    conn
    |> put_status(:ok)
    |> json(%{
      posts: Enum.map(posts, &serialize_post/1),
      has_more: length(posts) == (opts[:limit] || 50)
    })
  end

  def show(conn, %{"id" => post_id}) do
    user = conn.assigns.current_user

    case Timeline.get_user_post_by_post_id_and_user_id(post_id, user.id) do
      nil ->
        {:error, :not_found}

      user_post ->
        conn
        |> put_status(:ok)
        |> json(%{post: serialize_post(user_post)})
    end
  end

  def create(conn, %{"post" => post_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    opts = [
      user: user,
      key: session_key,
      api: true
    ]

    post_params = normalize_post_params(post_params, user)

    handle_create_result(conn, Timeline.create_post(post_params, opts))
  end

  defp handle_create_result(conn, {:ok, %Post{} = post}) do
    conn
    |> put_status(:created)
    |> json(%{post: serialize_created_post(post)})
  end

  defp handle_create_result(_conn, {:error, changeset}) do
    {:error, changeset}
  end

  def update(conn, %{"id" => post_id, "post" => post_params}) do
    user = conn.assigns.current_user
    session_key = conn.assigns.session_key

    with {:ok, post} <- get_user_owned_post(post_id, user) do
      opts = [
        user: user,
        key: session_key,
        api: true
      ]

      case Timeline.update_post(post, post_params, opts) do
        {:ok, updated_post} ->
          conn
          |> put_status(:ok)
          |> json(%{post: serialize_created_post(updated_post)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def delete(conn, %{"id" => post_id}) do
    user = conn.assigns.current_user

    with {:ok, post} <- get_user_owned_post(post_id, user) do
      opts = [user: user]
      handle_delete_result(conn, Timeline.delete_post(post, opts))
    end
  end

  defp handle_delete_result(conn, {:ok, _deleted}) do
    conn
    |> put_status(:ok)
    |> json(%{message: "Post deleted successfully"})
  end

  defp handle_delete_result(_conn, {:error, reason}) do
    {:error, reason}
  end

  defp get_user_owned_post(post_id, user) do
    case Timeline.get_post(post_id) do
      nil ->
        {:error, :not_found}

      %Post{user_id: user_id} = post when user_id == user.id ->
        {:ok, post}

      _ ->
        {:error, :forbidden}
    end
  end

  defp normalize_post_params(params, user) do
    params
    |> Map.put("visibility", params["visibility"] || "connections")
    |> Map.put("user_id", user.id)
    |> Map.put("username", user.username)
    |> Map.put("username_hash", user.username_hash)
    |> maybe_add_shared_users(params)
  end

  defp maybe_add_shared_users(params, original) do
    case original["shared_users"] do
      nil -> params
      users when is_list(users) -> Map.put(params, "shared_users", users)
      _ -> params
    end
  end

  defp build_list_opts(params) do
    opts = []

    opts =
      case params["since"] do
        nil -> opts
        ts -> Keyword.put(opts, :since, parse_timestamp(ts))
      end

    opts =
      case params["limit"] do
        nil -> opts
        limit -> Keyword.put(opts, :limit, parse_limit(limit))
      end

    opts
  end

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_limit(limit) when is_integer(limit), do: min(limit, 100)

  defp parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {n, _} -> min(n, 100)
      :error -> 50
    end
  end

  defp serialize_post(user_post) do
    post = user_post.post

    %{
      id: post.id,
      body: post.body,
      username: post.username,
      avatar_url: post.avatar_url,
      content_warning: post.content_warning,
      visibility: post.visibility,
      user_post_key: user_post.key,
      group_id: post.group_id,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp serialize_created_post(post) do
    %{
      id: post.id,
      visibility: post.visibility,
      group_id: post.group_id,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end
end
