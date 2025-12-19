defmodule Mosslet.Timeline.Adapters.Native do
  @moduledoc """
  Native adapter for timeline operations.

  This adapter uses HTTP API calls to the cloud server via `Mosslet.API.Client`
  and local SQLite cache via `Mosslet.Cache`.

  This adapter is used for desktop and mobile native app deployments.
  """

  @behaviour Mosslet.Timeline.Adapter

  alias Mosslet.API.Client
  alias Mosslet.Cache
  alias Mosslet.Session.Native, as: NativeSession
  alias Mosslet.Sync

  defp get_token do
    case NativeSession.get_token() do
      {:ok, token} -> token
      _ -> nil
    end
  end

  @impl true
  def get_post(id) do
    if :new == id || "new" == id do
      nil
    else
      token = get_token()

      if Sync.online?() && token do
        case Client.get_post(token, id) do
          {:ok, %{post: post_data}} -> deserialize_post(post_data)
          {:error, _reason} -> get_cached_post(id)
        end
      else
        get_cached_post(id)
      end
    end
  end

  @impl true
  def get_post!(id) do
    case get_post(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.Post
      post -> post
    end
  end

  @impl true
  def get_reply(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_reply(token, id) do
        {:ok, %{reply: reply_data}} -> deserialize_reply(reply_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_reply!(id) do
    case get_reply(id) do
      nil -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.Reply
      reply -> reply
    end
  end

  @impl true
  def get_user_post!(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post(token, id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
    end
  end

  @impl true
  def get_user_post_receipt!(id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_receipt(token, id) do
        {:ok, %{receipt: receipt_data}} ->
          deserialize_user_post_receipt(receipt_data)

        {:error, _reason} ->
          raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPostReceipt
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPostReceipt
    end
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_by_post_and_user(token, post_id, user_id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
      end
    else
      raise Ecto.NoResultsError, queryable: Mosslet.Timeline.UserPost
    end
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_post_by_post_and_user(token, post_id, user_id) do
        {:ok, %{user_post: user_post_data}} -> deserialize_user_post(user_post_data)
        {:error, _reason} -> nil
      end
    else
      nil
    end
  end

  @impl true
  def get_all_posts(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_user_posts(token, user.id) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def get_all_shared_posts(user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.get_shared_posts(token, user_id) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def list_user_posts_for_sync(_user, opts \\ []) do
    token = get_token()

    if Sync.online?() && token do
      case Client.fetch_posts(token, opts) do
        {:ok, %{posts: posts_data}} -> Enum.map(posts_data, &deserialize_user_post/1)
        {:error, _reason} -> []
      end
    else
      []
    end
  end

  @impl true
  def preload_group(post) do
    post
  end

  @impl true
  def count_all_posts do
    token = get_token()

    if Sync.online?() && token do
      case Client.count_all_posts(token) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def post_count(user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.post_count(token, user.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def shared_between_users_post_count(user_id, current_user_id) do
    token = get_token()

    if Sync.online?() && token do
      case Client.shared_between_users_post_count(token, user_id, current_user_id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def timeline_post_count(current_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.timeline_post_count(token, current_user.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def reply_count(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.reply_count(token, post.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_reply_count(post, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_reply_count(token, post.id, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def group_post_count(group) do
    token = get_token()

    if Sync.online?() && token do
      case Client.group_post_count(token, group.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_post_count_filtered(_user, options) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_post_count_filtered(token, options) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  @impl true
  def public_post_count(user) do
    token = get_token()

    if Sync.online?() && token do
      case Client.public_post_count(token, user.id) do
        {:ok, %{count: count}} -> count
        {:error, _reason} -> 0
      end
    else
      0
    end
  end

  defp get_cached_post(id) do
    case Cache.get_cached_item("post", id) do
      %{encrypted_data: data} when not is_nil(data) ->
        data
        |> Jason.decode!()
        |> deserialize_post()

      _ ->
        nil
    end
  end

  defp deserialize_post(nil), do: nil

  defp deserialize_post(data) when is_map(data) do
    %Mosslet.Timeline.Post{
      id: data["id"],
      body: data["body"],
      visibility: parse_atom(data["visibility"]),
      user_id: data["user_id"],
      group_id: data["group_id"],
      image_urls: data["image_urls"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_reply(nil), do: nil

  defp deserialize_reply(data) when is_map(data) do
    %Mosslet.Timeline.Reply{
      id: data["id"],
      body: data["body"],
      user_id: data["user_id"],
      post_id: data["post_id"],
      parent_reply_id: data["parent_reply_id"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_user_post(nil), do: nil

  defp deserialize_user_post(data) when is_map(data) do
    %Mosslet.Timeline.UserPost{
      id: data["id"],
      user_id: data["user_id"],
      post_id: data["post_id"],
      key: data["key"],
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp deserialize_user_post_receipt(nil), do: nil

  defp deserialize_user_post_receipt(data) when is_map(data) do
    %Mosslet.Timeline.UserPostReceipt{
      id: data["id"],
      user_id: data["user_id"],
      user_post_id: data["user_post_id"],
      is_read?: data["is_read"],
      read_at: parse_datetime(data["read_at"]),
      inserted_at: parse_datetime(data["inserted_at"]),
      updated_at: parse_datetime(data["updated_at"])
    }
  end

  defp parse_atom(nil), do: nil
  defp parse_atom(value) when is_atom(value), do: value
  defp parse_atom(value) when is_binary(value), do: String.to_existing_atom(value)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case NaiveDateTime.from_iso8601(value) do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(value), do: value
end
