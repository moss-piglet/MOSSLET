defmodule MossletWeb.API.BlueskyController do
  @moduledoc """
  API endpoints for Bluesky sync operations.

  Used by native apps to sync Bluesky import/export state with the server.
  """
  use MossletWeb, :controller

  alias Mosslet.Timeline

  action_fallback MossletWeb.API.FallbackController

  def unexported_posts(conn, %{"user_id" => user_id, "limit" => limit}) do
    limit = if is_binary(limit), do: String.to_integer(limit), else: limit
    posts = Timeline.get_unexported_public_posts(user_id, limit)

    conn
    |> put_status(:ok)
    |> json(%{posts: Enum.map(posts, &serialize_post/1)})
  end

  def export_post(conn, %{"id" => post_id}) do
    case Timeline.get_post_for_export(post_id) do
      nil ->
        {:error, :not_found}

      post ->
        conn
        |> put_status(:ok)
        |> json(%{post: serialize_post(post)})
    end
  end

  def mark_post_synced(conn, %{"post_id" => post_id, "uri" => uri, "cid" => cid}) do
    post = Timeline.get_post!(post_id)

    case Timeline.mark_post_as_synced_to_bluesky(post, uri, cid) do
      {:ok, post} ->
        conn
        |> put_status(:ok)
        |> json(%{post: serialize_post(post)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def clear_sync_info(conn, %{"post_id" => post_id}) do
    post = Timeline.get_post!(post_id)

    case Timeline.clear_bluesky_sync_info(post) do
      {:ok, post} ->
        conn
        |> put_status(:ok)
        |> json(%{post: serialize_post(post)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def export_reply(conn, %{"id" => reply_id}) do
    case Timeline.get_reply_for_export(reply_id) do
      nil ->
        {:error, :not_found}

      reply ->
        conn
        |> put_status(:ok)
        |> json(%{reply: serialize_reply(reply)})
    end
  end

  def mark_reply_synced(conn, %{
        "reply_id" => reply_id,
        "uri" => uri,
        "cid" => cid,
        "reply_ref" => reply_ref
      }) do
    reply = Timeline.get_reply!(reply_id)

    case Timeline.mark_reply_as_synced_to_bluesky(reply, uri, cid, reply_ref) do
      {:ok, reply} ->
        conn
        |> put_status(:ok)
        |> json(%{reply: serialize_reply(reply)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp serialize_post(post) do
    %{
      id: post.id,
      body: post.body,
      username: post.username,
      visibility: post.visibility,
      source: post.source,
      external_uri: post.external_uri,
      external_cid: post.external_cid,
      external_reply_root_uri: post.external_reply_root_uri,
      external_reply_root_cid: post.external_reply_root_cid,
      external_reply_parent_uri: post.external_reply_parent_uri,
      external_reply_parent_cid: post.external_reply_parent_cid,
      bluesky_account_id: post.bluesky_account_id,
      user_id: post.user_id,
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp serialize_reply(reply) do
    %{
      id: reply.id,
      body: reply.body,
      username: reply.username,
      visibility: reply.visibility,
      source: reply.source,
      external_uri: reply.external_uri,
      external_cid: reply.external_cid,
      external_reply_root_uri: reply.external_reply_root_uri,
      external_reply_root_cid: reply.external_reply_root_cid,
      external_reply_parent_uri: reply.external_reply_parent_uri,
      external_reply_parent_cid: reply.external_reply_parent_cid,
      bluesky_account_id: reply.bluesky_account_id,
      post_id: reply.post_id,
      parent_reply_id: reply.parent_reply_id,
      user_id: reply.user_id,
      inserted_at: reply.inserted_at,
      updated_at: reply.updated_at
    }
  end
end
