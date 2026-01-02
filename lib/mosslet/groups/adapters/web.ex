defmodule Mosslet.Groups.Adapters.Web do
  @moduledoc """
  Web adapter for group operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes. It preserves all
  existing functionality from the original Groups context.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Groups.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Groups.{Group, GroupBlock, UserGroup}

  @impl true
  def get_group(id) do
    Repo.get(Group, id) |> Repo.preload([:user_groups])
  end

  @impl true
  def get_group!(id) do
    Repo.get!(Group, id) |> Repo.preload([:user_groups])
  end

  @impl true
  def list_groups(user, options \\ []) do
    Group
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> where([g, ug], ug.user_id == ^user.id)
    |> where([g, ug], not is_nil(ug.confirmed_at))
    |> sort(options)
    |> paginate(options)
    |> preload([:user_groups])
    |> Repo.all()
  end

  @impl true
  def list_unconfirmed_groups(user, _opts \\ []) do
    blocked_group_ids =
      from(gb in GroupBlock,
        where: gb.user_id == ^user.id,
        select: gb.group_id
      )

    from(g in Group,
      join: ug in UserGroup,
      on: ug.group_id == g.id,
      where: ug.user_id == ^user.id,
      where: is_nil(ug.confirmed_at),
      where: g.id not in subquery(blocked_group_ids),
      order_by: [desc: g.inserted_at],
      preload: [:user_groups]
    )
    |> Repo.all()
  end

  @impl true
  def list_public_groups(user, search_term \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    user_group_ids =
      from(ug in UserGroup,
        where: ug.user_id == ^user.id,
        select: ug.group_id
      )

    blocked_group_ids =
      from(gb in GroupBlock,
        where: gb.user_id == ^user.id,
        select: gb.group_id
      )

    query =
      from(g in Group,
        where: g.public? == true,
        where: g.id not in subquery(user_group_ids),
        where: g.id not in subquery(blocked_group_ids),
        order_by: [desc: g.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:user_groups]
      )

    query =
      if search_term && String.trim(search_term) != "" do
        search_pattern = "%#{String.downcase(search_term)}%"
        from(g in query, where: g.name_hash == ^search_pattern)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def public_group_count(user, search_term \\ nil) do
    user_group_ids =
      from(ug in UserGroup,
        where: ug.user_id == ^user.id,
        select: ug.group_id
      )

    blocked_group_ids =
      from(gb in GroupBlock,
        where: gb.user_id == ^user.id,
        select: gb.group_id
      )

    query =
      from(g in Group,
        where: g.public? == true,
        where: g.id not in subquery(user_group_ids),
        where: g.id not in subquery(blocked_group_ids)
      )

    query =
      if search_term && String.trim(search_term) != "" do
        search_pattern = "%#{String.downcase(search_term)}%"
        from(g in query, where: g.name_hash == ^search_pattern)
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @impl true
  def filter_groups_with_users(user_id, current_user_id, options) do
    Group
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> join(:inner, [g, ug], ug2 in UserGroup, on: ug2.group_id == g.id)
    |> where([g, ug, ug2], ug.user_id == ^user_id and ug2.user_id == ^current_user_id)
    |> where([g, ug, ug2], not is_nil(ug.confirmed_at) and not is_nil(ug2.confirmed_at))
    |> sort(options[:sort])
    |> limit(5)
    |> preload([:user_groups])
    |> Repo.all()
  end

  @impl true
  def group_count(user) do
    query =
      from g in Group,
        inner_join: ug in UserGroup,
        on: ug.group_id == g.id,
        where: ug.user_id == ^user.id

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def group_count_confirmed(user) do
    query =
      Group
      |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
      |> where([g, ug], ug.user_id == ^user.id)
      |> where([g, ug], not is_nil(ug.confirmed_at))

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def list_user_groups_for_sync(user, opts \\ []) do
    since = opts[:since]

    query =
      from(ug in UserGroup,
        join: g in assoc(ug, :group),
        where: ug.user_id == ^user.id,
        where: not is_nil(ug.confirmed_at),
        order_by: [desc: g.updated_at],
        preload: [:group]
      )

    query =
      if since do
        from([ug, g] in query, where: g.updated_at > ^since)
      else
        query
      end

    Repo.all(query)
  end

  @impl true
  def get_user_group(id) do
    Repo.get(UserGroup, id) |> Repo.preload([:user, group: :user_groups])
  end

  @impl true
  def get_user_group!(id) do
    Repo.get!(UserGroup, id) |> Repo.preload([:user, group: :user_groups])
  end

  @impl true
  def get_user_group_with_user!(id) do
    Repo.get!(UserGroup, id) |> Repo.preload([:user])
  end

  @impl true
  def get_user_group_for_group_and_user(group, user) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id)
    |> where([ug], ug.user_id == ^user.id)
    |> preload([:group, :user])
    |> Repo.one()
  end

  @impl true
  def list_user_groups(group) do
    from(ug in UserGroup,
      where: ug.group_id == ^group.id,
      where: not is_nil(ug.confirmed_at),
      select: ug,
      preload: [:group, :memories, :posts, :user]
    )
    |> Repo.all()
  end

  @impl true
  def list_user_groups do
    Repo.all(UserGroup)
  end

  @impl true
  def list_user_groups_for_user(user) do
    from(ug in UserGroup,
      where: ug.user_id == ^user.id,
      select: ug,
      preload: [:group, :memories, :posts, :user]
    )
    |> Repo.all()
  end

  @impl true
  def create_group(attrs, group_changeset, user, user_group_map, opts) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_group, group_changeset)
    |> Ecto.Multi.insert(:insert_user_group, fn %{insert_group: group} ->
      UserGroup.changeset(
        %UserGroup{},
        %{
          name: attrs["user_name"] || attrs[:user_name],
          key: user_group_map.key,
          role: "owner",
          confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        },
        user: user,
        key: opts[:key],
        public?: group.public?
      )
      |> Ecto.Changeset.put_assoc(:group, group)
      |> Ecto.Changeset.put_assoc(:user, user)
    end)
    |> Repo.transaction_on_primary()
  end

  @impl true
  def create_user_group(attrs, opts) do
    Repo.transaction_on_primary(fn ->
      %UserGroup{}
      |> UserGroup.changeset(attrs, opts)
      |> Repo.insert()
    end)
  end

  @impl true
  def update_group(group, attrs, opts) do
    case Repo.transaction_on_primary(fn ->
           group
           |> Group.changeset(attrs, opts)
           |> Repo.update()
         end) do
      {:ok, {:ok, updated_group}} -> {:ok, updated_group}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def update_group_multi(group_changeset, user_group, user_group_attrs, opts) do
    user = opts[:user]

    Ecto.Multi.new()
    |> Ecto.Multi.update(:update_group, group_changeset)
    |> Ecto.Multi.update(:update_user_group, fn %{update_group: updated_group} ->
      UserGroup.changeset(
        user_group,
        user_group_attrs,
        user: user,
        key: opts[:key],
        public?: updated_group.public?
      )
      |> Ecto.Changeset.put_assoc(:group, updated_group)
      |> Ecto.Changeset.put_assoc(:user, user)
    end)
    |> Repo.transaction_on_primary()
  end

  @impl true
  def update_user_group(user_group, attrs, opts) do
    {:ok, {:ok, updated_user_group}} =
      Repo.transaction_on_primary(fn ->
        user_group
        |> UserGroup.changeset(attrs, opts)
        |> Repo.update()
      end)

    {:ok, updated_user_group}
  end

  @impl true
  def update_user_group_role(_user_group, changeset) do
    case Repo.transaction_on_primary(fn ->
           Repo.update(changeset)
         end) do
      {:ok, {:ok, updated}} -> {:ok, updated}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def delete_group(group) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(group)
         end) do
      {:ok, {:ok, deleted_group}} ->
        {:ok, deleted_group |> Repo.preload([:user_groups])}

      {:ok, {:error, _changeset}} ->
        {:error, "Error deleting group"}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def delete_user_group(user_group) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(user_group)
         end) do
      {:ok, {:ok, deleted}} ->
        {:ok, deleted}

      {:ok, {:error, _changeset}} ->
        {:error, "Error deleting user_group"}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def join_group_confirm(user_group) do
    changeset = UserGroup.confirm_changeset(user_group)

    case Repo.transaction_on_primary(fn -> Repo.update(changeset) end) do
      {:ok, {:ok, updated}} -> {:ok, updated}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def list_blocked_users(group_id) do
    from(gb in GroupBlock,
      where: gb.group_id == ^group_id,
      preload: [:user, :blocked_by]
    )
    |> Repo.all()
  end

  @impl true
  def user_blocked?(group_id, user_id) do
    from(gb in GroupBlock,
      where: gb.group_id == ^group_id and gb.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  @impl true
  def get_group_block(group_id, user_id) do
    from(gb in GroupBlock,
      where: gb.group_id == ^group_id and gb.user_id == ^user_id,
      preload: [:user, :blocked_by]
    )
    |> Repo.one()
  end

  @impl true
  def get_group_block!(id) do
    GroupBlock
    |> Repo.get!(id)
    |> Repo.preload([:user, :blocked_by])
  end

  @impl true
  def block_member_multi(actor, target) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:block, fn _changes ->
      %GroupBlock{}
      |> GroupBlock.changeset(%{
        group_id: actor.group_id,
        user_id: target.user_id,
        blocked_by_id: actor.user_id,
        blocked_moniker: target.moniker,
        reason: "Blocked by group moderator"
      })
    end)
    |> Ecto.Multi.delete(:remove_member, target)
    |> Repo.transaction_on_primary()
  end

  @impl true
  def delete_group_block(block) do
    case Repo.transaction_on_primary(fn -> Repo.delete(block) end) do
      {:ok, {:ok, deleted}} -> {:ok, deleted}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def validate_owner_count(group_id) do
    owner_count =
      from(ug in UserGroup,
        where: ug.group_id == ^group_id and ug.role == :owner,
        select: count(ug.id)
      )
      |> Repo.one()

    if owner_count <= 1 do
      {:error, :must_have_at_least_one_owner}
    else
      :ok
    end
  end

  @impl true
  def repo_preload(struct_or_structs, preloads) do
    Repo.preload(struct_or_structs, preloads)
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, _options), do: order_by(query, [g, ug], {:desc, g.inserted_at})

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, _options), do: query
end
