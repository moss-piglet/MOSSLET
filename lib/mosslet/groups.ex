defmodule Mosslet.Groups do
  @moduledoc """
  The Groups context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias Mosslet.Repo

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Groups.{Group, UserGroup}

  @existing_unconfirmed_group_event_atoms_list [
    :group_created_unconfirmed,
    :group_joined_unconfirmed,
    :group_updated_unconfirmed,
    :group_deleted_unconfirmed,
    :group_updated_member_unconfirmed,
    :group_updated_members_removed_unconfirmed
  ]

  @doc """
  Returns the list of groups for a user.

  ## Examples

      iex> list_groups(user, options)
      [%Group{}, ...]

  """
  def list_groups(user, options \\ []) do
    Group
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> where([g, ug], ug.user_id == ^user.id)
    |> where_user_group_confirmed()
    |> sort(options)
    |> paginate(options)
    |> preload([:user_groups])
    |> Repo.all()
  end

  @doc """
  Returns the list of unconfirmed groups for a user.

  ## Examples

      iex> list_groups(user)
      [%Group{}, ...]

  """
  def list_unconfirmed_groups(user, _opts \\ []) do
    from(g in Group,
      join: ug in UserGroup,
      on: ug.group_id == g.id,
      where: ug.user_id == ^user.id,
      where: is_nil(ug.confirmed_at),
      order_by: [desc: g.inserted_at],
      preload: [:user_groups]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of user_groups for a
  particular group.

  ## Examples

      iex> list_user_groups(group)
      [%UserGroup{}, ...]

  """
  def list_user_groups(group) do
    from(ug in UserGroup,
      where: ug.group_id == ^group.id,
      where: not is_nil(ug.confirmed_at),
      select: ug,
      preload: [:group, :memories, :posts, :user]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of public groups that the user is not already a member of.
  Used for discovering and joining public groups.

  ## Examples

      iex> list_public_groups(user, "search term")
      [%Group{}, ...]

  """
  def list_public_groups(user, search_term \\ nil, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    user_group_ids =
      from(ug in UserGroup,
        where: ug.user_id == ^user.id,
        select: ug.group_id
      )

    query =
      from(g in Group,
        where: g.public? == true,
        where: g.id not in subquery(user_group_ids),
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

  def public_group_count(user, search_term \\ nil) do
    user_group_ids =
      from(ug in UserGroup,
        where: ug.user_id == ^user.id,
        select: ug.group_id
      )

    query =
      from(g in Group,
        where: g.public? == true,
        where: g.id not in subquery(user_group_ids)
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

  @doc """
  Returns a list of Groups that both users are members of.
  Currently doesn't use pagination as it is limited for the
  UserConnection live show page.
  """
  def filter_groups_with_users(user_id, current_user_id, options) do
    Group
    |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
    |> join(:inner, [g, ug], ug2 in UserGroup, on: ug2.group_id == g.id)
    |> where([g, ug, ug2], ug.user_id == ^user_id and ug2.user_id == ^current_user_id)
    |> with_confirmed()
    |> sort(options[:sort])
    |> limit(5)
    |> preload([:user_groups])
    |> Repo.all()
  end

  defp with_confirmed(query) do
    query
    |> where([g, ug, ug2], not is_nil(ug.confirmed_at) and not is_nil(ug2.confirmed_at))
  end

  @doc """
  Lists all user_groups for a user (confirmed or not).
  """
  def list_user_groups_for_user(%User{} = user) do
    from(ug in UserGroup,
      where: ug.user_id == ^user.id,
      select: ug,
      preload: [:group, :memories, :posts, :user]
    )
    |> Repo.all()
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

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id), do: Repo.get!(Group, id) |> Repo.preload([:user_groups])
  def get_group(id), do: Repo.get(Group, id) |> Repo.preload([:user_groups])

  @doc """
  Gets the total count of a user's Groups.
  """
  def group_count(user) do
    query =
      from g in Group,
        inner_join: ug in UserGroup,
        on: ug.group_id == g.id,
        where: ug.user_id == ^user.id

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's confirmed groups.
  This is used to paginate the groups on the Group Live
  index page.
  """
  def group_count_confirmed(user) do
    query =
      Group
      |> join(:inner, [g], ug in UserGroup, on: ug.group_id == g.id)
      |> where([g, ug], ug.user_id == ^user.id)
      |> where_user_group_confirmed()

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  defp where_user_group_confirmed(query) do
    query
    |> where([g, ug], not is_nil(ug.confirmed_at))
  end

  @doc """
  Creates a group.

  ## Examples

      iex> create_group(%{field: value})
      {:ok, %Group{}}

      iex> create_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group(attrs \\ %{}, opts \\ []) do
    group = Group.changeset(%Group{}, attrs, opts)

    if attrs["user_id"] || attrs[:user_id] do
      user = Accounts.get_user!(attrs["user_id"] || attrs[:user_id])
      p_attrs = group.changes.user_group_map

      case Ecto.Multi.new()
           |> Ecto.Multi.insert(:insert_group, group)
           |> Ecto.Multi.insert(:insert_user_group, fn %{insert_group: group} ->
             UserGroup.changeset(
               %UserGroup{},
               %{
                 name: attrs["user_name"] || attrs[:user_name],
                 key: p_attrs.key,
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
           |> Repo.transaction_on_primary() do
        {:ok, %{insert_group: group, insert_user_group: _user_group}} ->
          for u <- attrs["users"] || attrs[:users] do
            uconn = Accounts.get_user_connection_between_users(u.id, user.id)

            ug_attrs = %{
              name:
                Encrypted.Users.Utils.decrypt_user_item(
                  uconn.connection.name,
                  user,
                  uconn.key,
                  opts[:key]
                ),
              key: p_attrs.key,
              role: "member",
              group_id: group.id,
              user_id: u.id
            }

            create_user_group(ug_attrs, user: u, key: opts[:key], public?: group.public?)
          end

          {:ok, group |> Repo.preload([:user_groups])}
          |> broadcast(:group_created)

        {:error, :insert_group, changeset, _map} ->
          {:error, changeset}

        {:error, :insert_user_group, changeset, _map} ->
          {:error, changeset}

        {:error, :insert_group, _, :insert_user_group, changeset, _map} ->
          {:error, changeset}

        rest ->
          Logger.warning("Error creating group")
          Logger.debug("Error creating group: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      {:error, group}
    end
  end

  def join_group(group, user_group, opts \\ []) do
    changeset = Group.join_changeset(group, %{password: Keyword.get(opts, :join_password)}, opts)

    if changeset.valid? do
      user_group
      |> UserGroup.confirm_changeset()
      |> Repo.update()

      group = get_group!(group.id)

      {:ok, group}
      |> broadcast(:group_joined)
    else
      {:error, changeset}
    end
  end

  @doc """
  Joins a public group that the user is not currently a member of.
  Creates a new user_group entry for the user.
  """
  def join_public_group(group, user, key, opts \\ [])

  def join_public_group(%Group{public?: true} = group, user, key, opts) do
    if group.require_password? do
      changeset =
        Group.join_changeset(group, %{password: Keyword.get(opts, :join_password)}, opts)

      if changeset.valid? do
        do_join_public_group(group, user, key)
      else
        {:error, changeset}
      end
    else
      do_join_public_group(group, user, key)
    end
  end

  def join_public_group(%Group{public?: false}, _user, _key, _opts) do
    {:error, :not_public}
  end

  defp do_join_public_group(group, user, key) do
    owner_user_group = Enum.find(group.user_groups, &(&1.role == :owner))

    if owner_user_group do
      case Encrypted.Users.Utils.decrypt_public_item_key(owner_user_group.key) do
        nil ->
          {:error, :decryption_failed}

        decrypted_group_key ->
          decrypted_name =
            Encrypted.Users.Utils.decrypt_user_item(
              user.name || user.username,
              user,
              user.user_key,
              key
            )

          attrs = %{
            name: decrypted_name,
            key: decrypted_group_key,
            role: "member",
            group_id: group.id,
            user_id: user.id,
            confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }

          case create_user_group(attrs, user: user, key: key, public?: true) do
            {:ok, {:ok, user_group}} ->
              broadcast({:ok, group}, :group_joined)
              {:ok, user_group}

            {:ok, {:error, changeset}} ->
              {:error, changeset}

            {:error, reason} ->
              {:error, reason}
          end
      end
    else
      {:error, :no_owner}
    end
  end

  @doc """
  Updates a group.

  ## Examples

      iex> update_group(group, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group(%Group{} = group, attrs, opts \\ []) do
    if attrs["user_id"] do
      user = Accounts.get_user!(attrs["user_id"])
      user_group = get_user_group_for_group_and_user(group, user)

      {:ok, d_group_key} =
        Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, opts[:key])

      opts =
        opts ++
          [
            update: true,
            group_key: d_group_key,
            require_password?: Map.get(attrs, :require_password?, false)
          ]

      group = Group.changeset(group, attrs, opts)
      p_attrs = group.changes.user_group_map

      case Ecto.Multi.new()
           |> Ecto.Multi.update(:update_group, group)
           |> Ecto.Multi.update(:update_user_group, fn %{update_group: group} ->
             UserGroup.changeset(
               user_group,
               %{
                 name: attrs["user_name"],
                 key: p_attrs.key,
                 role: user_group.role
               },
               user: user,
               key: opts[:key],
               public?: group.public?
             )
             |> Ecto.Changeset.put_assoc(:group, group)
             |> Ecto.Changeset.put_assoc(:user, user)
           end)
           |> Repo.transaction_on_primary() do
        {:ok, %{update_group: group, update_user_group: _user_group}} ->
          user_groups = group.user_groups
          user_groups_id_list = Enum.into(group.user_groups, [], fn x -> x.user_id end)
          members = attrs["users"]

          Enum.each(user_groups, fn ug ->
            if ug.user_id not in attrs["user_connections"] do
              delete_user_group(ug)
            end
          end)

          {:ok, group}
          |> broadcast(:group_updated_members_removed)

          Enum.each(members, fn member ->
            if member.id not in user_groups_id_list do
              uconn = Accounts.get_user_connection_between_users(member.id, user.id)

              ug_attrs = %{
                name:
                  Encrypted.Users.Utils.decrypt_user_item(
                    uconn.connection.name,
                    user,
                    uconn.key,
                    opts[:key]
                  ),
                key: p_attrs.key,
                role: "member",
                group_id: group.id,
                user_id: member.id
              }

              create_user_group(ug_attrs, user: member, key: opts[:key], public?: group.public?)
            end
          end)

          group = get_group!(group.id)

          {:ok, group}
          |> broadcast(:group_updated)

        {:error, :update_group, changeset, _map} ->
          {:error, changeset}

        {:error, :update_user_group, changeset, _map} ->
          {:error, changeset}

        {:error, :update_group, _, :update_user_group, changeset, _map} ->
          {:error, changeset}

        rest ->
          Logger.warning("Error updating group")
          Logger.debug("Error updating group: #{inspect(rest)}")
          {:error, "error"}
      end
    else
      group = Group.changeset(group, attrs, opts)
      {:error, group}
    end
  end

  @doc """
  Deletes a group.

  ## Examples

      iex> delete_group(group)
      {:ok, %Group{}}

      iex> delete_group(group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group(%Group{} = group) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(group)
         end) do
      {:ok, {:ok, group}} ->
        {:ok, group |> Repo.preload([:user_groups])}
        |> broadcast(:group_deleted)

      {:ok, {:error, _changeset}} ->
        # we just share the message because there's no changeset for the UI
        {:error, "Error deleting group"}

      rest ->
        Logger.warning("Error deleting group")
        Logger.debug("Error deleting group: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  def maybe_update_name_for_user_groups(%User{} = user, attrs \\ %{}, opts \\ []) do
    user_groups = list_user_groups_for_user(user)

    if Enum.empty?(user_groups) do
      nil
    else
      for user_group <- user_groups do
        name =
          Encrypted.Users.Utils.decrypt_user_item(
            attrs.encrypted_name,
            user,
            user.conn_key,
            opts[:key]
          )

        {:ok, key} =
          Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, opts[:key])

        update_user_group(
          user_group,
          %{
            name: name,
            key: key
          },
          user: user,
          key: opts[:key],
          public?: user_group.group.public?
        )
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group(group)
      %Ecto.Changeset{data: %Group{}}

  """
  def change_group(%Group{} = group, attrs \\ %{}, opts \\ []) do
    Group.changeset(group, attrs, opts)
  end

  @doc """
  Returns the list of user_groups.

  ## Examples

      iex> list_user_groups()
      [%UserGroup{}, ...]

  """
  def list_user_groups do
    Repo.all(UserGroup)
  end

  @doc """
  Gets a single user_group.

  Raises `Ecto.NoResultsError` if the User group does not exist.

  ## Examples

      iex> get_user_group!(123)
      %UserGroup{}

      iex> get_user_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_group!(id),
    do: Repo.get!(UserGroup, id) |> Repo.preload([:user, group: :user_groups])

  def get_user_group_with_user!(id), do: Repo.get!(UserGroup, id) |> Repo.preload([:user])

  @doc """
  TODO
  """
  def get_user_group_for_group_and_user(group, user) do
    UserGroup
    |> where([ug], ug.group_id == ^group.id)
    |> where([ug], ug.user_id == ^user.id)
    |> preload([:group, :user])
    |> Repo.one()
  end

  @doc """
  Creates a user_group.

  ## Examples

      iex> create_user_group(%{field: value})
      {:ok, %UserGroup{}}

      iex> create_user_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_group(attrs \\ %{}, opts \\ []) do
    Repo.transaction_on_primary(fn ->
      %UserGroup{}
      |> UserGroup.changeset(attrs, opts)
      |> Repo.insert()
    end)
  end

  @doc """
  Updates a user_group.

  ## Examples

      iex> update_user_group(user_group, %{field: new_value})
      {:ok, %UserGroup{}}

      iex> update_user_group(user_group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_group(%UserGroup{} = user_group, attrs, opts \\ []) do
    {:ok, {:ok, user_group}} =
      Repo.transaction_on_primary(fn ->
        user_group
        |> UserGroup.changeset(attrs, opts)
        |> Repo.update()
      end)

    {:ok, user_group}
  end

  @doc """
  Deletes a user_group.

  ## Examples

      iex> delete_user_group(user_group)
      {:ok, %UserGroup{}}

      iex> delete_user_group(user_group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_group(%UserGroup{} = user_group) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(user_group)
         end) do
      {:ok, {:ok, user_group}} ->
        {:ok, user_group}
        |> broadcast_user_group(:user_group_deleted)

      {:ok, {:error, _changeset}} ->
        # we just share the message because there's no changeset for the UI
        {:error, "Error deleting user_group"}

      rest ->
        Logger.warning("Error deleting user_group")
        Logger.debug("Error deleting user_group: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_group changes.

  ## Examples

      iex> change_user_group(user_group)
      %Ecto.Changeset{data: %UserGroup{}}

  """
  def change_user_group(%UserGroup{} = user_group, attrs \\ %{}) do
    UserGroup.changeset(user_group, attrs)
  end

  def change_user_group_role(%UserGroup{} = user_group, attrs \\ %{}) do
    UserGroup.role_changeset(user_group, attrs)
  end

  @doc """
  Updates a user_group's role with authorization checks.

  Options:
    - `:actor` - The UserGroup performing the action (required for authorization)

  Authorization rules:
    - Only owners can change/remove the owner role from another member
    - There must always be at least one owner in the group
  """
  def update_user_group_role(%UserGroup{} = user_group, attrs, opts \\ []) do
    actor = Keyword.get(opts, :actor)
    new_role = attrs["role"] || attrs[:role]
    new_role_atom = if is_binary(new_role), do: String.to_existing_atom(new_role), else: new_role

    with :ok <- authorize_role_change(user_group, new_role_atom, actor),
         :ok <- validate_owner_count(user_group, new_role_atom) do
      do_update_user_group_role(user_group, attrs)
    end
  end

  defp authorize_role_change(%UserGroup{role: current_role}, new_role, actor) do
    cond do
      current_role == :owner and actor.role != :owner ->
        {:error, :only_owner_can_change_owner}

      new_role == :owner and actor.role != :owner ->
        {:error, :only_owner_can_grant_owner}

      true ->
        :ok
    end
  end

  defp validate_owner_count(%UserGroup{role: :owner, group_id: group_id} = _user_group, new_role)
       when new_role != :owner do
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

  defp validate_owner_count(_user_group, _new_role), do: :ok

  defp do_update_user_group_role(%UserGroup{} = user_group, attrs) do
    return =
      Repo.transaction_on_primary(fn ->
        user_group
        |> UserGroup.role_changeset(attrs)
        |> Repo.update()
      end)

    case return do
      {:ok, {:ok, user_group}} ->
        user_group = user_group |> Repo.preload([:group])

        {:ok, user_group.group |> Repo.preload([:user_groups])}
        |> broadcast(:group_updated_member)

        {:ok, user_group}
        |> broadcast_user_group(:user_group_updated)

      {:ok, {:error, changeset}} ->
        {:error, changeset}

      rest ->
        rest
    end
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "group:#{user.id}")
  end

  @doc """
  Subscribe to a particular group's messages.
  """
  def group_subscribe(group) when is_struct(group) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "group:#{group.id}")
  end

  def public_subscribe() do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "groups")
  end

  ### PRIVATE

  defp broadcast_user_group({:ok, user_group}, event) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{user_group.group_id}",
      {event, user_group}
    )

    {:ok, user_group}
  end

  defp broadcast({:ok, group}, event) do
    member_broadcast({:ok, group}, event)
  end

  defp member_broadcast({:ok, group}, event) do
    Enum.each(group.user_groups, fn user_group ->
      cond do
        is_nil(user_group.confirmed_at) ->
          existing_event_atom = String.to_existing_atom(Atom.to_string(event) <> "_unconfirmed")

          if existing_event_atom in @existing_unconfirmed_group_event_atoms_list do
            Phoenix.PubSub.broadcast(
              Mosslet.PubSub,
              "group:#{user_group.user_id}",
              {existing_event_atom, group}
            )
          end

        true ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "group:#{user_group.user_id}",
            {event, group}
          )
      end
    end)

    {:ok, group}
  end
end
