defmodule Mosslet.Memories do
  @moduledoc """
  The Memories context.
  """
  require Logger

  import Ecto.Query, warn: false

  alias Mosslet.Repo

  alias Mosslet.Accounts
  alias Mosslet.Memories.{Memory, Remark, UserMemory}
  alias Mosslet.Memories.Remarks
  alias Mosslet.Encrypted
  alias MossletWeb.Endpoint

  @doc """
  Gets a single memory.

  Raises `Ecto.NoResultsError` if the Memory does not exist.

  ## Examples

      iex> get_memory!(123)
      %Memory{}

      iex> get_memory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_memory!(id),
    do: Repo.get!(Memory, id) |> Repo.preload([:user_memories, :user, :group, :remarks])

  def get_memory(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Memory, id) |> Repo.preload([:user_memories, :user, :group, :remarks])
    end
  end

  @doc """
  Gets the total count of a user's Memories.
  """
  def memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility != :public,
        where: is_nil(m.group_id)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's Memories that have
  been shared with the user. Does not include group Memories.
  """
  def shared_with_user_memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility == :connections,
        where: is_nil(m.group_id)

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a current_user's memories
  on their timeline page.
  """
  def timeline_memory_count(current_user) do
    query =
      Memory
      |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
      |> where([m, um], um.user_id == ^current_user.id)
      |> with_any_visibility([:private, :connections])
      |> with_group(nil)
      |> preload([:user_memories])

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's Memories that have
  been shared with the current_user by another user.
  Does not include group Memories.
  """
  def shared_between_users_memory_count(user_id, current_user_id) do
    query =
      Memory
      |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
      |> join(:inner, [m, um], um2 in UserMemory, on: um2.memory_id == m.id)
      |> where([m, um, um2], um.user_id == ^user_id and um2.user_id == ^current_user_id)
      |> where([m, um, um2], m.visibility == :connections)
      |> where([m, um, um2], is_nil(m.group_id))

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a user's Memories.
  """
  def public_memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility == :public

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a group's Memories.
  """
  def group_memory_count(group) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: m.group_id == ^group.id,
        where: m.visibility == :connections

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Gets the total count of a memory's Remarks.
  """
  def remark_count(memory) do
    query =
      from r in Remark,
        inner_join: m in Memory,
        on: r.memory_id == m.id,
        where: r.memory_id == ^memory.id

    count = Repo.aggregate(query, :count, :id)

    case count do
      nil ->
        0

      count ->
        count
    end
  end

  @doc """
  Returns the sum of the size of a user's memories.
  """
  def get_total_storage(user) do
    query = from m in Memory, where: m.user_id == ^user.id
    sum = Repo.aggregate(query, :sum, :size)

    case sum do
      nil ->
        0

      sum ->
        sum
    end
  end

  @doc """
  Counts all Memories.
  """
  def count_all_memories() do
    query = from(m in Memory)
    Repo.aggregate(query, :count)
  end

  @doc """
  Returns the count of a memory's remark loved reactions.
  """
  def get_remarks_loved_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :loved

    Repo.aggregate(query, :count, :mood)
  end

  @doc """
  Returns the count of a memory's remark excited reactions.
  """
  def get_remarks_excited_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :excited

    Repo.aggregate(query, :count, :mood)
  end

  @doc """
  Returns the count of a memory's remark happy reactions.
  """
  def get_remarks_happy_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :happy

    Repo.aggregate(query, :count, :mood)
  end

  @doc """
  Returns the count of a memory's remark sad reactions.
  """
  def get_remarks_sad_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :sad

    Repo.aggregate(query, :count, :mood)
  end

  @doc """
  Returns the count of a memory's remark thumbsy reactions.
  """
  def get_remarks_thumbsy_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :thumbsy

    Repo.aggregate(query, :count, :mood)
  end

  @doc """
  Preloads the Memory.
  """
  def preload(memory) do
    Repo.preload(memory, [:user, :user_memories, :group, :remarks])
  end

  @doc """
  Returns the list of non-public memories for
  the user. This includes memories shared
  with user or the user's own uploaded memories.

  Example options:

  %{sort_by: :item, sort_order: :asc, page: 2, per_page: 5}

  ## Examples

      iex> list_memories(user, options)
      [%Memory{}, ...]

  """
  def list_memories(user, options) do
    from(m in Memory,
      inner_join: um in UserMemory,
      on: um.memory_id == m.id,
      where: um.user_id == ^user.id,
      where: m.visibility != :public,
      where: is_nil(m.group_id),
      order_by: [desc: m.inserted_at],
      preload: [:user_memories]
    )
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Returns a list of memories for the
  current_user's timeline page. These are all
  non-public memories that have been shared.
  """
  def filter_timeline_memories(current_user, options) do
    Memory
    |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
    |> where([m, um], um.user_id == ^current_user.id)
    |> with_any_visibility([:private, :connections])
    |> with_group(nil)
    |> preload([:user_memories, :user, :remarks])
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Returns a list of memories that have been shared
  with the current user by another user.
  """
  def filter_memories_shared_with_current_user(user_id, options) do
    Memory
    |> with_users(user_id, options[:current_user_id], :desc)
    |> with_visibility(:connections)
    |> with_group(nil)
    |> preload([:user_memories, :user, :remarks])
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  defp with_visibility(query, visibility) do
    where(query, [m], m.visibility == ^visibility)
  end

  defp with_any_visibility(query, visibility_list) do
    where(query, [m], m.visibility in ^visibility_list)
  end

  defp with_group(query, group_id) when not is_nil(group_id) do
    where(query, [m], m.group_id == ^group_id)
  end

  defp with_group(query, nil) do
    where(query, [m], is_nil(m.group_id))
  end

  defp with_users(query, user_id, current_user_id, :desc) do
    query
    |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
    |> join(:inner, [m, um], um2 in UserMemory, on: um2.memory_id == m.id)
    |> where([m, um, um2], um.user_id == ^user_id and um2.user_id == ^current_user_id)
    |> where([m, um, um2], m.user_id == ^user_id or m.user_id == ^current_user_id)
    |> order_by([m, um, um2], desc: um.inserted_at)
  end

  @doc """
  Returns the list of user's public memories.
  """
  def list_public_memories(user, options) do
    from(m in Memory,
      inner_join: um in UserMemory,
      on: um.memory_id == m.id,
      where: um.user_id == ^user.id,
      where: m.visibility == :public,
      order_by: [desc: m.inserted_at],
      preload: [:user_memories]
    )
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Used only in group's show page.
  """
  def list_group_memories(group, options) do
    from(m in Memory,
      where: m.group_id == ^group.id,
      order_by: [desc: m.inserted_at],
      preload: [:user_memories, :group, :user_group]
    )
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @doc """
  Returns the list of remarks for
  a memory.

  ## Examples

      iex> list_remarks(memory, options)
      [%Remark{}, ...]

  """
  def list_remarks(memory, options) do
    Remark
    |> join(:inner, [r], m in Memory, on: r.memory_id == m.id)
    |> where([r, m], r.memory_id == ^memory.id and m.id == ^memory.id)
    |> order_by([r, m], [{:desc, r.inserted_at}])
    |> paginate(options)
    |> preload([r, m], memory: m)
    |> Repo.all()
  end

  defp sort(query, %{sort_by: sort_by, sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, %{memory_sort_by: sort_by, memory_sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, %{remark_sort_by: sort_by, remark_sort_order: sort_order}) do
    order_by(query, {^sort_order, ^sort_by})
  end

  defp sort(query, _options), do: query

  defp paginate(query, %{page: page, per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, %{memory_page: page, memory_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, %{remark_page: page, remark_per_page: per_page}) do
    offset = max((page - 1) * per_page, 0)

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  defp paginate(query, _options), do: query

  def get_remark!(id), do: Repo.get!(Remark, id) |> Repo.preload([:user, :memory])
  def get_remark(id), do: Repo.get(Remark, id) |> Repo.preload([:user, :memory])

  @doc """
  Creates a memory.

  ## Examples

      iex> create_memory(%{field: value})
      {:ok, %Memory{}}

      iex> create_memory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_memory(attrs \\ %{}, opts \\ []) do
    memory = Memory.changeset(%Memory{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = memory.changes.user_memory_map

    # we first encrypt the Memory and UserMemory for the person
    # creating the Memory
    #
    # p_attrs.key is encrypted already

    case Ecto.Multi.new()
         |> Ecto.Multi.insert(:insert_memory, memory)
         |> Ecto.Multi.insert(:insert_user_memory, fn %{insert_memory: memory} ->
           UserMemory.changeset(
             %UserMemory{},
             %{
               key: p_attrs.temp_key,
               user_id: user.id,
               memory_id: memory.id
             },
             user: user,
             visibility: attrs["visibility"]
           )
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{insert_memory: memory, insert_user_memory: _user_memory_conn}} ->
        # we create user_memories for everyone being shared with
        create_shared_user_memories(memory, attrs, p_attrs, user)

        {:ok, memory}
        |> broadcast_admin(:memory_created)

      {:error, :insert_memory, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_user_memory, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_memory, _, :insert_user_memory, changeset, _map} ->
        {:error, changeset}

      rest ->
        Logger.warning("Error creating memory")
        Logger.debug("Error creating memory: #{inspect(rest)}")
        {:error, "error"}
    end
  end

  @doc """
  Creates a public memory.

  ## Examples

      iex> create_public_memory(%{field: value})
      {:ok, %Memory{}}

      iex> create_public_memory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_public_memory(attrs \\ %{}, opts \\ []) do
    memory = Memory.changeset(%Memory{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = memory.changes.user_memory_map

    # we first encrypt the Memory and UserMemory for the person
    # creating the Memory
    #
    # p_attrs.key is encrypted already
    {:ok, %{insert_memory: memory, insert_user_memory: _user_memory_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_memory, memory)
      |> Ecto.Multi.insert(:insert_user_memory, fn %{insert_memory: memory} ->
        UserMemory.changeset(
          %UserMemory{},
          %{
            key: p_attrs.temp_key,
            user_id: user.id,
            memory_id: memory.id
          },
          user: user,
          visibility: attrs["visibility"]
        )
      end)
      |> Repo.transaction_on_primary()

    # we do not create multiple user_memories as the memory is
    # symmetrically encrypted with the server public key.

    conn = Accounts.get_connection_from_item(memory, user)

    {:ok, conn, memory |> Repo.preload([:user_memories])}
    |> broadcast(:memory_created)
  end

  defp create_shared_user_memories(memory, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])

        user_memory =
          UserMemory.sharing_changeset(
            %UserMemory{},
            %{
              key: p_attrs.temp_key,
              memory_id: memory.id,
              user_id: user.id
            },
            user: user,
            visibility: attrs["visibility"]
          )

        # p_attrs.temp_key is not encrypted yet
        {:ok, %{insert_user_memory: _user_memory}} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:insert_user_memory, user_memory)
          |> Repo.transaction_on_primary()
      end

      conn = Accounts.get_connection_from_item(memory, current_user)

      {:ok, conn, memory |> Repo.preload([:user_memories])}
      |> broadcast(:memory_created)
    else
      conn = Accounts.get_connection_from_item(memory, current_user)

      {:ok, conn, memory |> Repo.preload([:user_memories])}
      |> broadcast(:memory_created)
    end
  end

  @doc """
  Updates a memory.

  ## Examples

      iex> update_memory(memory, %{field: new_value})
      {:ok, %Memory{}}

      iex> update_memory(memory, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_memory(%Memory{} = memory, attrs, opts \\ []) do
    memory = Memory.changeset(memory, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = memory.changes.user_memory_map

    {:ok, %{update_memory: memory, update_user_memory: _user_memory_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:update_memory, memory)
      |> Ecto.Multi.update(:update_user_memory, fn %{update_memory: memory} ->
        UserMemory.changeset(get_user_memory(memory, user), %{
          key: p_attrs.key
        })
        |> Ecto.Changeset.put_assoc(:memory, memory)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Repo.transaction_on_primary()

    conn = Accounts.get_connection_from_item(memory, user)

    {:ok, conn, memory |> Repo.preload([:user_memories])}
    |> broadcast(:memory_updated)
  end

  def blur_memory(%Memory{} = memory, attrs, user, opts \\ []) do
    memory = Memory.blur_changeset(memory, attrs, user, opts)

    {:ok, %{update_blur_memory: memory}} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:update_blur_memory, memory, opts)
      |> Repo.transaction_on_primary()

    {:ok, memory}
  end

  @doc """
  Creates a remark.

  ## Examples

      iex> create_remark(%{field: value})
      {:ok, %Memory{}}

      iex> create_remark(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_remark(attrs \\ %{}, opts \\ []) do
    remark = Remark.changeset(%Remark{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        remark
        |> Repo.insert()
      end)

    return |> publish_remark_created()

    case return do
      {:ok, remark} ->
        conn = Accounts.get_connection_from_item(remark, user)

        {:ok, conn, remark |> Repo.preload([:memory, :user])}
        |> broadcast(:remark_created)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a remark.

  ## Examples

      iex> delete_remark(remark)
      {:ok, %Memory{}}

      iex> delete_remark(remark)
      {:error, %Ecto.Changeset{}}

  """
  def delete_remark(%Remark{} = remark, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        remark
        |> Repo.delete()
      end)

    return |> publish_remark_deleted()

    case return do
      {:ok, remark} ->
        conn = Accounts.get_connection_from_item(remark, user)

        {:ok, conn, remark |> Repo.preload([:memory, :user])}
        |> broadcast(:remark_deleted)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a memory for faving/unfaving.
  """
  def update_memory_fav(%Memory{} = memory, attrs, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    {:ok, {:ok, memory}} =
      Repo.transaction_on_primary(fn ->
        Memory.changeset(memory, attrs, opts)
        |> Repo.update()
      end)

    conn = Accounts.get_connection_from_item(memory, user)

    {:ok, conn, memory |> Repo.preload([:user_memories])}
    |> broadcast(:memory_updated)
  end

  def inc_favs(%Memory{id: id}) do
    {:ok, {1, [memory]}} =
      Repo.transaction_on_primary(fn ->
        from(m in Memory, where: m.id == ^id, select: m)
        |> Repo.update_all(inc: [favs_count: 1])
      end)

    {:ok, memory |> Repo.preload([:user_memories])}
  end

  def decr_favs(%Memory{id: id}) do
    {:ok, {1, [memory]}} =
      Repo.transaction_on_primary(fn ->
        from(m in Memory, where: m.id == ^id, select: m)
        |> Repo.update_all(inc: [favs_count: -1])
      end)

    {:ok, memory |> Repo.preload([:user_memories])}
  end

  @doc """
  Deletes a memory.

  ## Examples

      iex> delete_memory(memory)
      {:ok, %Memory{}}

      iex> delete_memory(memory)
      {:error, %Ecto.Changeset{}}

  """
  def delete_memory(%Memory{} = memory, opts \\ []) do
    user = Accounts.get_user!(opts[:user].id)

    conn = Accounts.get_connection_from_item(memory, user)

    {:ok, {:ok, memory}} =
      Repo.transaction_on_primary(fn ->
        Repo.delete(memory)
      end)

    {:ok, memory}
    |> broadcast_admin(:memory_deleted)

    {:ok, conn, memory}
    |> broadcast(:memory_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking memory changes.

  ## Examples

      iex> change_memory(memory)
      %Ecto.Changeset{data: %Memory{}}

  """
  def change_memory(%Memory{} = memory, attrs \\ %{}, opts \\ []) do
    Memory.changeset(memory, attrs, opts)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking remark changes.

  ## Examples

      iex> change_remark(remark)
      %Ecto.Changeset{data: %Remark{}}

  """
  def change_remark(%Remark{} = remark, attrs \\ %{}, opts \\ []) do
    Remark.changeset(remark, attrs, opts)
  end

  def last_ten_remarks_for(memory_id) do
    Remarks.Query.for_memory(memory_id)
    |> Repo.all()
  end

  def last_user_remark_for_memory(memory_id, user_id) do
    Remarks.Query.last_user_remark_for_memory(memory_id, user_id)
    |> Repo.one()
  end

  def get_previous_n_remarks(date, memory_id, n) do
    if is_nil(date) do
      []
    else
      Remarks.Query.previous_n(date, memory_id, n)
      |> Repo.all()
    end
  end

  def preload_remark_user(remark) do
    remark
    |> Repo.preload([:user, :memory])
  end

  def publish_remark_created({:ok, remark} = result) do
    Endpoint.broadcast("memory:#{remark.memory_id}", "new_remark", %{remark: remark})
    result
  end

  def publish_remark_created(result), do: result

  def publish_remark_deleted({:ok, remark} = result) do
    Endpoint.broadcast("memory:#{remark.memory_id}", "deleted_remark", %{remark: remark})
    result
  end

  def publish_remark_deleted(result), do: result

  def publish_remark_updated({:ok, remark} = result) do
    Endpoint.broadcast("memory:#{remark.memory_id}", "updated_remark", %{remark: remark})
    result
  end

  def publish_remark_updated(result), do: result

  def subscribe do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "memories")
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "priv_memories:#{user.id}")
  end

  def connections_subscribe(user) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "conn_memories:#{user.id}")
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Mosslet.PubSub, "admin:memories")
    end
  end

  # The user_memory is always just one
  # and is the first in the list
  def get_public_user_memory(memory) do
    Enum.at(memory.user_memories, 0)
    |> Repo.preload([:memory, :user])
  end

  def get_user_memory(memory, user) do
    Repo.one(from um in UserMemory, where: um.memory_id == ^memory.id and um.user_id == ^user.id)
  end

  defp broadcast({:ok, conn, struct}, event, _user_conn \\ %{}) do
    case struct.visibility do
      :public -> public_broadcast({:ok, conn, struct}, event)
      :private -> private_broadcast({:ok, conn, struct}, event)
      :connections -> connections_broadcast({:ok, conn, struct}, event)
    end
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "admin:memories", {event, struct})
    {:ok, struct}
  end

  defp public_broadcast({:ok, conn, memory}, event) do
    Phoenix.PubSub.broadcast(Mosslet.PubSub, "memories", {event, memory})
    {:ok, conn, memory}
  end

  defp private_broadcast({:ok, conn, memory}, event) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "priv_memories:#{memory.user_id}",
      {event, memory}
    )

    {:ok, conn, memory}
  end

  defp connections_broadcast({:ok, conn, %Remark{} = remark}, event) do
    if Enum.empty?(remark.memory.shared_users) do
      Enum.each(conn.user_connections, fn uconn ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_memories:#{uconn.user_id}",
          {event, remark}
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_memories:#{uconn.reverse_user_id}",
          {event, remark}
        )
      end)

      {:ok, remark}
    else
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(remark.memory.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_memories:#{uconn.user_id}",
            {event, remark}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_memories:#{uconn.reverse_user_id}",
            {event, remark}
          )
        end)
      end)

      {:ok, remark}
    end
  end

  defp connections_broadcast({:ok, conn, %Memory{} = memory}, event) do
    maybe_publish_group_memory({event, memory})

    if Enum.empty?(memory.shared_users) do
      Enum.each(conn.user_connections, fn uconn ->
        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_memories:#{uconn.user_id}",
          {event, memory}
        )

        Phoenix.PubSub.broadcast(
          Mosslet.PubSub,
          "conn_memories:#{uconn.reverse_user_id}",
          {event, memory}
        )
      end)

      {:ok, conn, memory}
    else
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(memory.shared_users, fn _shared_user ->
          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_memories:#{uconn.reverse_user_id}",
            {event, memory}
          )

          Phoenix.PubSub.broadcast(
            Mosslet.PubSub,
            "conn_memories:#{uconn.user_id}",
            {event, memory}
          )
        end)
      end)

      {:ok, conn, memory}
    end
  end

  defp maybe_publish_group_memory({event, memory}) do
    if not is_nil(memory.group_id) do
      publish_group_memory({event, memory})
    end
  end

  ##  Group Post broadcasts

  def publish_group_memory({event, memory}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{memory.group_id}",
      {event, memory}
    )
  end

  ## Object storage requests

  # delete 1,000 objects at a time
  def make_async_aws_requests(urls) when is_list(urls) do
    memories_bucket = Encrypted.Session.memories_bucket()

    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ex_aws_delete_multiple_objects_request(memories_bucket, urls) do
        {:ok, _resp} ->
          {:ok, :memory_deleted_from_storj,
           "Memories successfully deleted from the private cloud."}

        _rest ->
          ex_aws_delete_multiple_objects_request(memories_bucket, urls)
          {:error, :make_async_aws_requests}
      end
    end)
  end

  def ex_aws_delete_multiple_objects_request(memories_bucket, urls) do
    ExAws.S3.delete_multiple_objects(memories_bucket, urls)
    |> ExAws.request()
  end
end
