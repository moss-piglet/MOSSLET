defmodule Metamorphic.Memories do
  @moduledoc """
  The Memories context.
  """
  import Ecto.Query, warn: false

  alias Metamorphic.Repo

  alias Metamorphic.Accounts
  alias Metamorphic.Accounts.{Connection, User, UserConnection}
  alias Metamorphic.Memories.{Memory, Remark, UserMemory}

  @doc """
  Gets a single memory.

  Raises `Ecto.NoResultsError` if the Memory does not exist.

  ## Examples

      iex> get_memory!(123)
      %Memory{}

      iex> get_memory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_memory!(id), do: Repo.get!(Memory, id) |> Repo.preload([:user_memories, :user])

  def get_memory(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Memory, id) |> Repo.preload([:user_memories, :user])
    end
  end

  @doc """
  Gets the total count of a user's Memories.
  """
  def get_count(user) do
    query = from m in Memory, where: m.user_id == ^user.id
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
    Repo.preload(memory, [:user, :user_memories, :remarks])
  end

  @doc """
  Returns the list of non-public memories for
  the user.

  ## Examples

      iex> list_memories()
      [%Memory{}, ...]

  """
  def list_memories(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    memory_list =
      from(m in Memory,
        join: um in UserMemory,
        on: um.memory_id == m.id,
        where: m.visibility == :private and m.user_id == ^user.id,
        offset: ^offset,
        limit: ^limit,
        order_by: [desc: m.inserted_at],
        preload: [:user_memories]
      )
      |> Repo.all()

    memories =
      (memory_list ++
         list_own_connection_memories(user, opts) ++ list_connection_memories(user, opts))
      |> Enum.filter(fn memory -> memory.__meta__ != :deleted end)
      |> Enum.uniq_by(fn memory -> memory end)
      |> Enum.sort_by(fn m -> m.inserted_at end, {:desc, NaiveDateTime})

    memories
  end

  def list_own_connection_memories(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(m in Memory,
      join: um in UserMemory,
      on: um.memory_id == m.id,
      join: u in User,
      on: um.user_id == u.id,
      where: m.visibility == :connections and m.user_id == ^user.id,
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: m.inserted_at],
      preload: [:user_memories]
    )
    |> Repo.all()
  end

  def list_connection_memories(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    from(m in Memory,
      join: um in UserMemory,
      on: um.memory_id == m.id,
      join: u in User,
      on: um.user_id == u.id,
      join: c in Connection,
      on: c.user_id == u.id,
      join: uc in UserConnection,
      on: uc.connection_id == c.id,
      where: uc.user_id == ^user.id or uc.reverse_user_id == ^user.id,
      where: not is_nil(uc.confirmed_at),
      where: m.visibility == :connections,
      offset: ^offset,
      limit: ^limit,
      order_by: [desc: m.inserted_at],
      preload: [:user_memories]
    )
    |> Repo.all()
    |> Enum.filter(fn memory ->
      Enum.empty?(memory.shared_users) ||
        Enum.any?(memory.shared_users, fn x -> x.user_id == user.id end)
    end)
    |> Enum.sort_by(fn m -> m.inserted_at end, :desc)
  end

  def list_public_memories(user, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    public_memory_list =
      from(m in Memory,
        join: um in UserMemory,
        on: um.memory_id == m.id,
        where: m.visibility == :public and m.user_id == ^user.id,
        offset: ^offset,
        limit: ^limit,
        order_by: [desc: m.inserted_at],
        preload: [:user_memories]
      )
      |> Repo.all()

    public_memory_list =
      public_memory_list
      |> Enum.filter(fn memory -> memory.__meta__ != :deleted end)
      |> Enum.uniq_by(fn memory -> memory end)
      |> Enum.sort_by(fn m -> m.inserted_at end, {:desc, NaiveDateTime})

    public_memory_list
  end

  @doc """
  Returns the list of remarks for
  a memory.

  ## Examples

      iex> list_memories(memory, opts)
      [%Memory{}, ...]

  """
  def list_remarks(memory, opts) do
    limit = Keyword.fetch!(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    remark_list =
      from(r in Remark,
        where: r.memory_id == ^memory.id,
        offset: ^offset,
        limit: ^limit,
        order_by: [desc: r.inserted_at],
        preload: [:user, :memory]
      )
      |> Repo.all()

    remark_list
  end

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

    {:ok, %{insert_memory: memory, insert_user_memory: _user_memory_conn}} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:insert_memory, memory)
      |> Ecto.Multi.insert(:insert_user_memory, fn %{insert_memory: memory} ->
        UserMemory.changeset(%UserMemory{}, %{
          key: p_attrs.key
        })
        |> Ecto.Changeset.put_assoc(:memory, memory)
        |> Ecto.Changeset.put_assoc(:user, user)
      end)
      |> Repo.transaction_on_primary()

    conn = Accounts.get_connection_from_item(memory, user)

    {:ok, memory}
    |> broadcast_admin(:memory_created)

    {:ok, conn, memory |> Repo.preload([:user_memories])}
    |> broadcast(:memory_created)
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
        UserMemory.changeset(get_user_memory(memory), %{
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

  def subscribe do
    Phoenix.PubSub.subscribe(Metamorphic.PubSub, "memories")
  end

  def private_subscribe(user) do
    Phoenix.PubSub.subscribe(Metamorphic.PubSub, "priv_memories:#{user.id}")
  end

  def connections_subscribe(user) do
    Phoenix.PubSub.subscribe(Metamorphic.PubSub, "conn_memories:#{user.id}")
  end

  def admin_subscribe(user) do
    if user.is_admin? do
      Phoenix.PubSub.subscribe(Metamorphic.PubSub, "admin:memories")
    end
  end

  defp get_user_memory(memory) do
    Enum.at(memory.user_memories, 0)
    |> Repo.preload([:memory, :user])
  end

  defp broadcast({:ok, conn, struct}, event, _user_conn \\ %{}) do
    case struct.visibility do
      :public -> public_broadcast({:ok, conn, struct}, event)
      :private -> private_broadcast({:ok, conn, struct}, event)
      :connections -> connections_broadcast({:ok, conn, struct}, event)
    end
  end

  defp broadcast_admin({:ok, struct}, event) do
    Phoenix.PubSub.broadcast(Metamorphic.PubSub, "admin:memories", {event, struct})
    {:ok, struct}
  end

  defp public_broadcast({:ok, conn, memory}, event) do
    Phoenix.PubSub.broadcast(Metamorphic.PubSub, "memories", {event, memory})
    {:ok, conn, memory}
  end

  defp private_broadcast({:ok, conn, memory}, event) do
    Phoenix.PubSub.broadcast(
      Metamorphic.PubSub,
      "priv_memories:#{memory.user_id}",
      {event, memory}
    )

    {:ok, conn, memory}
  end

  defp connections_broadcast({:ok, conn, %Remark{} = remark}, event) do
    if Enum.empty?(remark.memory.shared_users) do
      Enum.each(conn.user_connections, fn uconn ->
        Phoenix.PubSub.broadcast(
          Metamorphic.PubSub,
          "conn_memories:#{uconn.user_id}",
          {event, remark}
        )

        Phoenix.PubSub.broadcast(
          Metamorphic.PubSub,
          "conn_memories:#{uconn.reverse_user_id}",
          {event, remark}
        )
      end)

      {:ok, remark}
    else
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(remark.memory.shared_users, fn shared_user ->
          cond do
            uconn.user_id == shared_user.user_id || uconn.reverse_user_id == shared_user.user_id ->
              Phoenix.PubSub.broadcast(
                Metamorphic.PubSub,
                "conn_memories:#{uconn.user_id}",
                {event, remark}
              )

              Phoenix.PubSub.broadcast(
                Metamorphic.PubSub,
                "conn_memories:#{uconn.reverse_user_id}",
                {event, remark}
              )

            true ->
              nil
          end
        end)
      end)

      {:ok, remark}
    end
  end

  defp connections_broadcast({:ok, conn, %Memory{} = memory}, event) do
    if Enum.empty?(memory.shared_users) do
      Enum.each(conn.user_connections, fn uconn ->
        Phoenix.PubSub.broadcast(
          Metamorphic.PubSub,
          "conn_memories:#{uconn.user_id}",
          {event, memory}
        )

        Phoenix.PubSub.broadcast(
          Metamorphic.PubSub,
          "conn_memories:#{uconn.reverse_user_id}",
          {event, memory}
        )
      end)

      {:ok, conn, memory}
    else
      Enum.each(conn.user_connections, fn uconn ->
        Enum.each(memory.shared_users, fn shared_user ->
          cond do
            uconn.user_id == shared_user.user_id || uconn.reverse_user_id == shared_user.user_id ->
              Phoenix.PubSub.broadcast(
                Metamorphic.PubSub,
                "conn_memories:#{uconn.user_id}",
                {event, memory}
              )

              Phoenix.PubSub.broadcast(
                Metamorphic.PubSub,
                "conn_memories:#{uconn.reverse_user_id}",
                {event, memory}
              )

            true ->
              nil
          end
        end)
      end)

      {:ok, conn, memory}
    end
  end
end
