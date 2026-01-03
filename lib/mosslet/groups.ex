defmodule Mosslet.Groups do
  @moduledoc """
  The Groups context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Groups.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Groups.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Platform
  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Encrypted
  alias Mosslet.Groups.{Group, GroupBlock, UserGroup}

  @existing_unconfirmed_group_event_atoms_list [
    :group_created_unconfirmed,
    :group_joined_unconfirmed,
    :group_updated_unconfirmed,
    :group_deleted_unconfirmed,
    :group_member_kicked_unconfirmed,
    :group_member_blocked_unconfirmed,
    :group_member_unblocked_unconfirmed,
    :group_updated_member_unconfirmed,
    :group_updated_members_removed_unconfirmed
  ]

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Mosslet.Groups.Adapters.Native
    else
      Mosslet.Groups.Adapters.Web
    end
  end

  @doc """
  Returns the list of groups for a user.

  ## Examples

      iex> list_groups(user, options)
      [%Group{}, ...]

  """
  def list_groups(user, options \\ []) do
    adapter().list_groups(user, options)
  end

  @doc """
  Returns the list of unconfirmed groups for a user.

  ## Examples

      iex> list_groups(user)
      [%Group{}, ...]

  """
  def list_unconfirmed_groups(user, opts \\ []) do
    adapter().list_unconfirmed_groups(user, opts)
  end

  @doc """
  Returns the list of user_groups for a
  particular group.

  ## Examples

      iex> list_user_groups(group)
      [%UserGroup{}, ...]

  """
  def list_user_groups(group) do
    adapter().list_user_groups(group)
  end

  @doc """
  Returns the list of public groups that the user is not already a member of.
  Used for discovering and joining public groups.

  ## Examples

      iex> list_public_groups(user, "search term")
      [%Group{}, ...]

  """
  def list_public_groups(user, search_term \\ nil, opts \\ []) do
    adapter().list_public_groups(user, search_term, opts)
  end

  def public_group_count(user, search_term \\ nil) do
    adapter().public_group_count(user, search_term)
  end

  @doc """
  Returns a list of Groups that both users are members of.
  Currently doesn't use pagination as it is limited for the
  UserConnection live show page.
  """
  def filter_groups_with_users(user_id, current_user_id, options) do
    adapter().filter_groups_with_users(user_id, current_user_id, options)
  end

  @doc """
  Lists all user_groups for a user (confirmed or not).
  """
  def list_user_groups_for_user(%User{} = user) do
    adapter().list_user_groups_for_user(user)
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id), do: adapter().get_group!(id)
  def get_group(id), do: adapter().get_group(id)

  @doc """
  Gets the total count of a user's Groups.
  """
  def group_count(user) do
    adapter().group_count(user)
  end

  @doc """
  Gets the total count of a user's confirmed groups.
  This is used to paginate the groups on the Group Live
  index page.
  """
  def group_count_confirmed(user) do
    adapter().group_count_confirmed(user)
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
    group_changeset = Group.changeset(%Group{}, attrs, opts)

    if attrs["user_id"] || attrs[:user_id] do
      user = Accounts.get_user!(attrs["user_id"] || attrs[:user_id])
      user_group_map = group_changeset.changes.user_group_map

      case adapter().create_group(attrs, group_changeset, user, user_group_map, opts) do
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
              key: user_group_map.key,
              role: "member",
              group_id: group.id,
              user_id: u.id
            }

            create_user_group(ug_attrs, user: u, key: opts[:key], public?: group.public?)
          end

          {:ok, adapter().get_group!(group.id)}
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
      {:error, group_changeset}
    end
  end

  def join_group(group, user_group, opts \\ []) do
    changeset = Group.join_changeset(group, %{password: Keyword.get(opts, :join_password)}, opts)

    if changeset.valid? do
      adapter().join_group_confirm(user_group)
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
    if user_blocked?(group.id, user.id) do
      {:error, :blocked}
    else
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
                group = get_group!(user_group.group_id)

                {:ok, group}
                |> broadcast(:group_joined)

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
    require Logger
    Logger.debug("update_group called with attrs keys: #{inspect(Map.keys(attrs))}")
    Logger.debug("update_group opts: #{inspect(Keyword.keys(opts))}")

    if attrs["user_id"] do
      user = opts[:user] || Accounts.get_user!(attrs["user_id"])
      user_group = get_user_group_for_group_and_user(group, user)

      Logger.debug("user_group found: #{inspect(user_group.id)}")
      Logger.debug("user_group.key present: #{user_group.key != nil}")
      Logger.debug("opts[:key] present: #{opts[:key] != nil}")

      result =
        if group.public? do
          d_group_key = Encrypted.Users.Utils.decrypt_public_item_key(user_group.key)
          if d_group_key, do: {:ok, d_group_key}, else: {:error, :decryption_failed}
        else
          Encrypted.Users.Utils.decrypt_user_attrs_key(user_group.key, user, opts[:key])
        end

      case result do
        {:ok, d_group_key} ->
          do_update_group(group, attrs, opts, user, user_group, d_group_key)

        error ->
          Logger.error("Decryption failed in update_group: #{inspect(error)}")
          Logger.error("user_group.key: #{inspect(user_group.key)}")
          Logger.error("opts[:key] present?: #{opts[:key] != nil}")
          {:error, :decryption_failed}
      end
    else
      adapter().update_group(group, attrs, opts)
      |> broadcast(:group_updated)
    end
  end

  defp do_update_group(group, attrs, opts, user, user_group, d_group_key) do
    opts =
      opts ++
        [
          update: true,
          group_key: d_group_key,
          require_password?: Map.get(attrs, :require_password?, false)
        ]

    group_changeset = Group.changeset(group, attrs, opts)
    p_attrs = group_changeset.changes.user_group_map

    user_group_attrs = %{
      name: attrs["user_name"],
      key: p_attrs.key,
      role: user_group.role
    }

    case adapter().update_group_multi(group_changeset, user_group, user_group_attrs,
           user: user,
           key: opts[:key],
           group_id: group.id,
           attrs: attrs
         ) do
      {:ok, %{update_group: updated_group, update_user_group: _user_group}} ->
        user_groups = updated_group.user_groups
        user_groups_id_list = Enum.into(updated_group.user_groups, [], fn x -> x.user_id end)
        members = attrs["users"]

        Enum.each(user_groups, fn ug ->
          if ug.user_id not in attrs["user_connections"] do
            delete_user_group(ug)
          end
        end)

        {:ok, updated_group}
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
              group_id: updated_group.id,
              user_id: member.id
            }

            create_user_group(ug_attrs,
              user: member,
              key: opts[:key],
              public?: updated_group.public?
            )
          end
        end)

        group = get_group!(updated_group.id)

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
    case adapter().delete_group(group) do
      {:ok, deleted_group} ->
        {:ok, deleted_group}
        |> broadcast(:group_deleted)

      {:error, reason} ->
        Logger.warning("Error deleting group")
        Logger.debug("Error deleting group: #{inspect(reason)}")
        {:error, reason}
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
    adapter().list_user_groups()
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
  def get_user_group!(id), do: adapter().get_user_group!(id)
  def get_user_group(id), do: adapter().get_user_group(id)
  def get_user_group_with_user!(id), do: adapter().get_user_group_with_user!(id)

  @doc """
  TODO
  """
  def get_user_group_for_group_and_user(group, user) do
    adapter().get_user_group_for_group_and_user(group, user)
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
    adapter().create_user_group(attrs, opts)
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
    adapter().update_user_group(user_group, attrs, opts)
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
    case adapter().delete_user_group(user_group) do
      {:ok, deleted_user_group} ->
        {:ok, deleted_user_group}
        |> broadcast_user_group(:user_group_deleted)

      {:error, reason} ->
        Logger.warning("Error deleting user_group")
        Logger.debug("Error deleting user_group: #{inspect(reason)}")
        {:error, reason}
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

  @role_levels %{owner: 4, admin: 3, moderator: 2, member: 1}

  @doc """
  Checks if the actor role can moderate the target role.

  Role hierarchy (highest to lowest):
    - Owner (4): can moderate admin, moderator, member
    - Admin (3): can moderate moderator, member
    - Moderator (2): can moderate member only
    - Member (1): cannot moderate anyone

  ## Examples

      iex> can_moderate?(:owner, :admin)
      true

      iex> can_moderate?(:admin, :owner)
      false

      iex> can_moderate?(:moderator, :moderator)
      false
  """
  def can_moderate?(actor_role, target_role) do
    @role_levels[actor_role] > @role_levels[target_role]
  end

  @doc """
  Kicks a member from a group (removes them but doesn't block).

  The actor must have a higher role than the target.
  """
  def kick_member(%UserGroup{} = actor, %UserGroup{} = target) do
    cond do
      actor.group_id != target.group_id ->
        {:error, :different_groups}

      actor.id == target.id ->
        {:error, :cannot_kick_self}

      not can_moderate?(actor.role, target.role) ->
        {:error, :insufficient_permissions}

      true ->
        case delete_user_group(target) do
          {:ok, user_group} ->
            broadcast(
              {:ok, get_group!(user_group.group_id), target.user_id},
              :group_member_kicked
            )

            {:ok, user_group}

          error ->
            error
        end
    end
  end

  @doc """
  Blocks a member from a group (removes them and prevents rejoining).

  The actor must have a higher role than the target.
  For public groups, this prevents the user from rejoining.
  For private groups, they would need to be re-invited.
  """
  def block_member(%UserGroup{} = actor, %UserGroup{} = target) do
    cond do
      actor.group_id != target.group_id ->
        {:error, :different_groups}

      actor.id == target.id ->
        {:error, :cannot_block_self}

      not can_moderate?(actor.role, target.role) ->
        {:error, :insufficient_permissions}

      true ->
        case adapter().block_member_multi(actor, target) do
          {:ok, %{block: block, remove_member: _}} ->
            broadcast_user_group({:ok, target}, :user_group_deleted)
            broadcast({:ok, get_group!(actor.group_id), target.user_id}, :group_member_blocked)
            {:ok, block}

          {:error, :block, changeset, _} ->
            {:error, changeset}

          {:error, :remove_member, changeset, _} ->
            {:error, changeset}
        end
    end
  end

  @doc """
  Unblocks a user from a group, allowing them to rejoin.
  """
  def unblock_member(%UserGroup{} = actor, %GroupBlock{} = block) do
    if actor.role in [:owner, :admin] and actor.group_id == block.group_id do
      case adapter().delete_group_block(block) do
        {:ok, deleted_block} ->
          target_user_id = deleted_block.user_id
          broadcast({:ok, get_group!(actor.group_id), target_user_id}, :group_member_unblocked)
          {:ok, deleted_block}

        error ->
          error
      end
    else
      {:error, :insufficient_permissions}
    end
  end

  @doc """
  Lists all blocked users for a group.
  """
  def list_blocked_users(group_id) do
    adapter().list_blocked_users(group_id)
  end

  @doc """
  Checks if a user is blocked from a group.
  """
  def user_blocked?(group_id, user_id) do
    adapter().user_blocked?(group_id, user_id)
  end

  @doc """
  Gets a specific block record.
  """
  def get_group_block(group_id, user_id) do
    adapter().get_group_block(group_id, user_id)
  end

  @doc """
  Gets a specific block record by id. Raises if not found.
  """
  def get_group_block!(id) do
    adapter().get_group_block!(id)
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
    adapter().validate_owner_count(group_id)
  end

  defp validate_owner_count(_user_group, _new_role), do: :ok

  defp do_update_user_group_role(%UserGroup{} = user_group, attrs) do
    changeset = UserGroup.role_changeset(user_group, attrs)

    case adapter().update_user_group_role(user_group, changeset) do
      {:ok, updated_user_group} ->
        updated_user_group = adapter().repo_preload(updated_user_group, [:group])

        {:ok, adapter().repo_preload(updated_user_group.group, [:user_groups])}
        |> broadcast(:group_updated_member)

        {:ok, updated_user_group}
        |> broadcast_user_group(:user_group_updated)

      {:error, changeset} ->
        {:error, changeset}
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

  @doc """
  Returns user groups for sync with desktop/mobile apps.

  Returns UserGroup records with associated groups, including encrypted
  data blobs that native apps decrypt locally.

  ## Options

  - `:since` - Only return groups updated after this timestamp
  """
  def list_user_groups_for_sync(user, opts \\ []) do
    adapter().list_user_groups_for_sync(user, opts)
  end

  ### PRIVATE

  defp broadcast_user_group({:ok, user_group}, event) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{user_group.group_id}",
      {event, user_group}
    )

    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{user_group.user_id}",
      {event, user_group}
    )

    user_group = adapter().repo_preload(user_group, group: :user_groups)

    Enum.each(user_group.group.user_groups, fn ug ->
      if ug.user_id != user_group.user_id do
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "group:#{ug.user_id}",
          {event, user_group}
        )
      end
    end)

    {:ok, user_group}
  end

  defp broadcast({:ok, group}, event) do
    member_broadcast({:ok, group}, event)
  end

  defp broadcast({:ok, group, target_user_id}, event) do
    member_broadcast({:ok, group}, event, target_user_id)
  end

  defp member_broadcast({:ok, group}, event, target_user_id \\ nil) do
    message = if target_user_id, do: {group, target_user_id}, else: group

    case message do
      {group, target_user_id} ->
        Enum.each(group.user_groups, fn user_group ->
          cond do
            is_nil(user_group.confirmed_at) ->
              existing_event_atom =
                String.to_existing_atom(Atom.to_string(event) <> "_unconfirmed")

              if existing_event_atom in @existing_unconfirmed_group_event_atoms_list do
                Phoenix.PubSub.broadcast(
                  Mosslet.PubSub,
                  "group:#{user_group.user_id}",
                  {existing_event_atom, message}
                )
              end

            true ->
              Phoenix.PubSub.broadcast(
                Mosslet.PubSub,
                "group:#{user_group.user_id}",
                {event, message}
              )
          end
        end)

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "group:#{target_user_id}",
          {event, message}
        )

        {:ok, group}

      group ->
        Enum.each(group.user_groups, fn user_group ->
          cond do
            is_nil(user_group.confirmed_at) ->
              existing_event_atom =
                String.to_existing_atom(Atom.to_string(event) <> "_unconfirmed")

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
end
