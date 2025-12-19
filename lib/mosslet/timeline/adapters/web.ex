defmodule Mosslet.Timeline.Adapters.Web do
  @moduledoc """
  Web adapter for timeline operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Timeline.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Accounts
  alias Mosslet.Accounts.{UserConnection, UserBlock}
  alias Mosslet.Repo
  alias Mosslet.Timeline.{Post, Reply, UserPost, UserPostReceipt, Bookmark}

  @impl true
  def get_post(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Post, id)
      |> Repo.preload([
        :user_posts,
        :replies,
        :group,
        :user,
        :replies,
        :user_group,
        :user_post_receipts
      ])
    end
  end

  @impl true
  def get_post!(id) do
    Repo.get!(Post, id)
    |> Repo.preload([:user_posts, :user, :user_post_receipts])
  end

  @impl true
  def get_reply(id) do
    Repo.get(Reply, id)
  end

  @impl true
  def get_reply!(id) do
    Repo.get!(Reply, id)
    |> Repo.preload([:user, :post, :parent_reply, :child_replies])
  end

  @impl true
  def get_user_post!(id) do
    Repo.get!(UserPost, id)
    |> Repo.preload([:user, :post, :user_post_receipt])
  end

  @impl true
  def get_user_post_receipt!(id) do
    Repo.get!(UserPostReceipt, id)
    |> Repo.preload([:user, :user_post])
  end

  @impl true
  def get_user_post_by_post_id_and_user_id!(post_id, user_id) do
    Repo.one!(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  @impl true
  def get_user_post_by_post_id_and_user_id(post_id, user_id) do
    Repo.one(
      from up in UserPost,
        where: up.post_id == ^post_id,
        where: up.user_id == ^user_id,
        preload: [:post, :user, :user_post_receipt]
    )
  end

  @impl true
  def get_all_posts(user) do
    from(p in Post,
      where: p.user_id == ^user.id
    )
    |> Repo.all()
  end

  @impl true
  def get_all_shared_posts(user_id) do
    Repo.all(
      from p in Post,
        where: p.user_id == ^user_id,
        where: p.visibility == :connections,
        preload: [:user_posts]
    )
  end

  @impl true
  def list_user_posts_for_sync(user, opts \\ []) do
    since = opts[:since]
    limit = opts[:limit] || 50

    query =
      from(up in UserPost,
        join: p in assoc(up, :post),
        where: up.user_id == ^user.id,
        order_by: [desc: p.updated_at],
        limit: ^limit,
        preload: [:post]
      )

    query =
      if since do
        from([up, p] in query, where: p.updated_at > ^since)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def preload_group(post) do
    post |> Repo.preload([:group])
  end

  @impl true
  def count_all_posts do
    from(p in Post)
    |> Repo.aggregate(:count)
  end

  @impl true
  def post_count(user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: up.user_id == ^user.id and p.visibility != :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  defp filter_by_user_id(query, %{filter: %{user_id: ""}}), do: query

  defp filter_by_user_id(query, %{filter: %{user_id: user_id}}) do
    query
    |> where([p, up], p.user_id == ^user_id)
  end

  defp filter_by_user_id(query, _options), do: query

  @impl true
  def shared_between_users_post_count(user_id, current_user_id) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> join(:inner, [p, up], up2 in UserPost, on: up2.post_id == p.id)
      |> where([p, up, up2], up.user_id == ^user_id and up2.user_id == ^current_user_id)
      |> where([p, up, up2], p.visibility == :connections)
      |> where([p, up, up2], is_nil(p.group_id))

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def timeline_post_count(current_user, options) do
    query =
      Post
      |> join(:inner, [p], up in UserPost, on: up.post_id == p.id)
      |> where([p, up], up.user_id == ^current_user.id)
      |> where([p], p.visibility in [:private, :connections, :specific_groups, :specific_users])
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def reply_count(post, options) do
    user_connection_query = user_connection_subquery(options.current_user_id)

    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> filter_by_user_id(options)
      |> where(
        [r, p],
        r.user_id in subquery(user_connection_query) or r.user_id == ^options.current_user_id
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  defp user_connection_subquery(current_user_id) do
    UserConnection
    |> where([uc], uc.user_id == ^current_user_id)
    |> select([uc], uc.reverse_user_id)
  end

  @impl true
  def public_reply_count(post, options) do
    query =
      Reply
      |> join(:inner, [r], p in assoc(r, :post))
      |> where([r, p], r.post_id == ^post.id)
      |> where([r, p], r.visibility == :public and p.visibility == :public)
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def group_post_count(group) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.group_id == ^group.id,
        where: p.visibility == :connections
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def public_post_count_filtered(_user, options) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.visibility == :public
      )
      |> filter_by_user_id(options)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def public_post_count(user) do
    query =
      from(p in Post,
        inner_join: up in UserPost,
        on: up.post_id == p.id,
        where: p.user_id == ^user.id and p.visibility == :public
      )

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil -> 0
      count -> count
    end
  end

  @impl true
  def repo_all(query), do: Repo.all(query)

  @impl true
  def repo_all(query, opts), do: Repo.all(query, opts)

  @impl true
  def repo_one(query), do: Repo.one(query)

  @impl true
  def repo_one(query, opts), do: Repo.one(query, opts)

  @impl true
  def repo_one!(query), do: Repo.one!(query)

  @impl true
  def repo_one!(query, opts), do: Repo.one!(query, opts)

  @impl true
  def repo_aggregate(query, aggregate, field), do: Repo.aggregate(query, aggregate, field)

  @impl true
  def repo_aggregate(query, aggregate, field, opts),
    do: Repo.aggregate(query, aggregate, field, opts)

  @impl true
  def repo_exists?(query), do: Repo.exists?(query)

  @impl true
  def repo_preload(struct_or_structs, preloads), do: Repo.preload(struct_or_structs, preloads)

  @impl true
  def repo_preload(struct_or_structs, preloads, opts),
    do: Repo.preload(struct_or_structs, preloads, opts)

  @impl true
  def repo_insert(changeset),
    do: Fly.Repo.transaction_on_primary(fn -> Repo.insert(changeset) end) |> unwrap_transaction()

  @impl true
  def repo_insert!(changeset),
    do:
      Fly.Repo.transaction_on_primary(fn -> Repo.insert!(changeset) end) |> unwrap_transaction!()

  @impl true
  def repo_update(changeset),
    do: Fly.Repo.transaction_on_primary(fn -> Repo.update(changeset) end) |> unwrap_transaction()

  @impl true
  def repo_update!(changeset),
    do:
      Fly.Repo.transaction_on_primary(fn -> Repo.update!(changeset) end) |> unwrap_transaction!()

  @impl true
  def repo_delete(struct),
    do: Fly.Repo.transaction_on_primary(fn -> Repo.delete(struct) end) |> unwrap_transaction()

  @impl true
  def repo_delete!(struct),
    do: Fly.Repo.transaction_on_primary(fn -> Repo.delete!(struct) end) |> unwrap_transaction!()

  @impl true
  def repo_delete_all(query),
    do: Fly.Repo.transaction_on_primary(fn -> Repo.delete_all(query) end) |> unwrap_transaction!()

  @impl true
  def repo_update_all(query, updates),
    do:
      Fly.Repo.transaction_on_primary(fn -> Repo.update_all(query, updates) end)
      |> unwrap_transaction!()

  @impl true
  def repo_transaction(fun), do: Fly.Repo.transaction_on_primary(fun)

  @impl true
  def repo_get(schema, id), do: Repo.get(schema, id)

  @impl true
  def repo_get!(schema, id), do: Repo.get!(schema, id)

  @impl true
  def repo_get_by(schema, clauses), do: Repo.get_by(schema, clauses)

  @impl true
  def repo_get_by!(schema, clauses), do: Repo.get_by!(schema, clauses)

  defp unwrap_transaction({:ok, {:ok, result}}), do: {:ok, result}
  defp unwrap_transaction({:ok, {:error, changeset}}), do: {:error, changeset}
  defp unwrap_transaction({:error, reason}), do: {:error, reason}

  defp unwrap_transaction!({:ok, result}), do: result
  defp unwrap_transaction!({:error, reason}), do: raise("Transaction failed: #{inspect(reason)}")
end
