defmodule Mosslet.Memories.Adapters.Web do
  @moduledoc """
  Web adapter for memory operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Memories.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Memories.{Memory, Remark, UserMemory}
  alias Mosslet.Memories.Remarks

  @impl true
  def get_memory!(id) do
    Repo.get!(Memory, id) |> Repo.preload([:user_memories, :user, :group, :remarks])
  end

  @impl true
  def get_memory(id) do
    if :new == id || "new" == id do
      nil
    else
      Repo.get(Memory, id) |> Repo.preload([:user_memories, :user, :group, :remarks])
    end
  end

  @impl true
  def memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility != :public,
        where: is_nil(m.group_id)

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def shared_with_user_memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility == :connections,
        where: is_nil(m.group_id)

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def timeline_memory_count(current_user) do
    query =
      Memory
      |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
      |> where([m, um], um.user_id == ^current_user.id)
      |> where([m], m.visibility in [:private, :connections])
      |> where([m], is_nil(m.group_id))

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def shared_between_users_memory_count(user_id, current_user_id) do
    query =
      Memory
      |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
      |> join(:inner, [m, um], um2 in UserMemory, on: um2.memory_id == m.id)
      |> where([m, um, um2], um.user_id == ^user_id and um2.user_id == ^current_user_id)
      |> where([m, um, um2], m.visibility == :connections)
      |> where([m, um, um2], is_nil(m.group_id))

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def public_memory_count(user) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: um.user_id == ^user.id,
        where: m.visibility == :public

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def group_memory_count(group) do
    query =
      from m in Memory,
        inner_join: um in UserMemory,
        on: um.memory_id == m.id,
        where: m.group_id == ^group.id,
        where: m.visibility == :connections

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def remark_count(memory) do
    query =
      from r in Remark,
        inner_join: m in Memory,
        on: r.memory_id == m.id,
        where: r.memory_id == ^memory.id

    Repo.aggregate(query, :count, :id) || 0
  end

  @impl true
  def get_total_storage(user) do
    query = from m in Memory, where: m.user_id == ^user.id
    Repo.aggregate(query, :sum, :size) || 0
  end

  @impl true
  def count_all_memories do
    query = from(m in Memory)
    Repo.aggregate(query, :count)
  end

  @impl true
  def get_remarks_loved_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :loved
    Repo.aggregate(query, :count, :mood)
  end

  @impl true
  def get_remarks_excited_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :excited
    Repo.aggregate(query, :count, :mood)
  end

  @impl true
  def get_remarks_happy_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :happy
    Repo.aggregate(query, :count, :mood)
  end

  @impl true
  def get_remarks_sad_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :sad
    Repo.aggregate(query, :count, :mood)
  end

  @impl true
  def get_remarks_thumbsy_count(memory) do
    query = from r in Remark, where: r.memory_id == ^memory.id, where: r.mood == :thumbsy
    Repo.aggregate(query, :count, :mood)
  end

  @impl true
  def preload(memory) do
    Repo.preload(memory, [:user, :user_memories, :group, :remarks])
  end

  @impl true
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

  @impl true
  def filter_timeline_memories(current_user, options) do
    Memory
    |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
    |> where([m, um], um.user_id == ^current_user.id)
    |> where([m], m.visibility in [:private, :connections])
    |> where([m], is_nil(m.group_id))
    |> preload([:user_memories, :user, :remarks])
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
  def filter_memories_shared_with_current_user(user_id, options) do
    Memory
    |> join(:inner, [m], um in UserMemory, on: um.memory_id == m.id)
    |> join(:inner, [m, um], um2 in UserMemory, on: um2.memory_id == m.id)
    |> where([m, um, um2], um.user_id == ^user_id and um2.user_id == ^options[:current_user_id])
    |> where([m, um, um2], m.user_id == ^user_id or m.user_id == ^options[:current_user_id])
    |> where([m], m.visibility == :connections)
    |> where([m], is_nil(m.group_id))
    |> order_by([m, um, um2], desc: um.inserted_at)
    |> preload([:user_memories, :user, :remarks])
    |> sort(options)
    |> paginate(options)
    |> Repo.all()
  end

  @impl true
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

  @impl true
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

  @impl true
  def list_remarks(memory, options) do
    Remark
    |> join(:inner, [r], m in Memory, on: r.memory_id == m.id)
    |> where([r, m], r.memory_id == ^memory.id and m.id == ^memory.id)
    |> order_by([r, m], [{:desc, r.inserted_at}])
    |> paginate(options)
    |> preload([r, m], memory: m)
    |> Repo.all()
  end

  @impl true
  def get_remark!(id), do: Repo.get!(Remark, id) |> Repo.preload([:user, :memory])

  @impl true
  def get_remark(id), do: Repo.get(Remark, id) |> Repo.preload([:user, :memory])

  @impl true
  def create_memory_multi(changeset, user, p_attrs, visibility) do
    case Ecto.Multi.new()
         |> Ecto.Multi.insert(:insert_memory, changeset)
         |> Ecto.Multi.insert(:insert_user_memory, fn %{insert_memory: memory} ->
           UserMemory.changeset(
             %UserMemory{},
             %{
               key: p_attrs.temp_key,
               user_id: user.id,
               memory_id: memory.id
             },
             user: user,
             visibility: visibility
           )
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{insert_memory: memory, insert_user_memory: _user_memory_conn}} ->
        {:ok, memory}

      {:error, :insert_memory, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_user_memory, changeset, _map} ->
        {:error, changeset}

      {:error, :insert_memory, _, :insert_user_memory, changeset, _map} ->
        {:error, changeset}

      _rest ->
        {:error, "error"}
    end
  end

  @impl true
  def create_shared_user_memory(memory, user, p_attrs, visibility) do
    user_memory =
      UserMemory.sharing_changeset(
        %UserMemory{},
        %{
          key: p_attrs.temp_key,
          memory_id: memory.id,
          user_id: user.id
        },
        user: user,
        visibility: visibility
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:insert_user_memory, user_memory)
    |> Repo.transaction_on_primary()
  end

  @impl true
  def update_memory_multi(changeset, memory, user, p_attrs) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_memory, changeset)
         |> Ecto.Multi.update(:update_user_memory, fn %{update_memory: updated_memory} ->
           get_user_memory(memory, user)
           |> UserMemory.changeset(%{key: p_attrs.key})
           |> Ecto.Changeset.put_assoc(:memory, updated_memory)
           |> Ecto.Changeset.put_assoc(:user, user)
         end)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_memory: memory, update_user_memory: _user_memory_conn}} ->
        {:ok, memory}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def blur_memory_multi(changeset, opts) do
    case Ecto.Multi.new()
         |> Ecto.Multi.update(:update_blur_memory, changeset, opts)
         |> Repo.transaction_on_primary() do
      {:ok, %{update_blur_memory: memory}} ->
        {:ok, memory}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  @impl true
  def create_remark(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.insert(changeset)
    end)
    |> case do
      {:ok, {:ok, remark}} -> {:ok, remark}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def delete_remark(remark) do
    Repo.transaction_on_primary(fn ->
      Repo.delete(remark)
    end)
    |> case do
      {:ok, {:ok, remark}} -> {:ok, remark}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def update_memory_fav(changeset) do
    Repo.transaction_on_primary(fn ->
      Repo.update(changeset)
    end)
    |> case do
      {:ok, {:ok, memory}} -> {:ok, memory}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def inc_favs(%Memory{id: id}) do
    {:ok, {1, [memory]}} =
      Repo.transaction_on_primary(fn ->
        from(m in Memory, where: m.id == ^id, select: m)
        |> Repo.update_all(inc: [favs_count: 1])
      end)

    {:ok, memory |> Repo.preload([:user_memories])}
  end

  @impl true
  def decr_favs(%Memory{id: id}) do
    {:ok, {1, [memory]}} =
      Repo.transaction_on_primary(fn ->
        from(m in Memory, where: m.id == ^id, select: m)
        |> Repo.update_all(inc: [favs_count: -1])
      end)

    {:ok, memory |> Repo.preload([:user_memories])}
  end

  @impl true
  def delete_memory(memory) do
    Repo.transaction_on_primary(fn ->
      Repo.delete(memory)
    end)
    |> case do
      {:ok, {:ok, memory}} -> {:ok, memory}
      {:ok, {:error, changeset}} -> {:error, changeset}
      error -> error
    end
  end

  @impl true
  def last_ten_remarks_for(memory_id) do
    Remarks.Query.for_memory(memory_id)
    |> Repo.all()
  end

  @impl true
  def last_user_remark_for_memory(memory_id, user_id) do
    Remarks.Query.last_user_remark_for_memory(memory_id, user_id)
    |> Repo.one()
  end

  @impl true
  def get_previous_n_remarks(date, memory_id, n) do
    if is_nil(date) do
      []
    else
      Remarks.Query.previous_n(date, memory_id, n)
      |> Repo.all()
    end
  end

  @impl true
  def preload_remark_user(remark) do
    Repo.preload(remark, [:user, :memory])
  end

  @impl true
  def get_public_user_memory(memory) do
    Enum.at(memory.user_memories, 0)
    |> Repo.preload([:memory, :user])
  end

  @impl true
  def get_user_memory(memory, user) do
    Repo.one(from um in UserMemory, where: um.memory_id == ^memory.id and um.user_id == ^user.id)
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
end
