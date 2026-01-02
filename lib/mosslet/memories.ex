defmodule Mosslet.Memories do
  @moduledoc """
  The Memories context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Memories.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Memories.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.

  Note: Memories is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """
  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Memories.{Memory, Remark}
  alias Mosslet.Encrypted
  alias Mosslet.Platform
  alias MossletWeb.Endpoint

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Mosslet.Memories.Adapters.Native
    else
      Mosslet.Memories.Adapters.Web
    end
  end

  @doc """
  Gets a single memory.

  Raises `Ecto.NoResultsError` if the Memory does not exist.

  ## Examples

      iex> get_memory!(123)
      %Memory{}

      iex> get_memory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_memory!(id), do: adapter().get_memory!(id)

  def get_memory(id), do: adapter().get_memory(id)

  @doc """
  Gets the total count of a user's Memories.
  """
  def memory_count(user), do: adapter().memory_count(user)

  @doc """
  Gets the total count of a user's Memories that have
  been shared with the user. Does not include group Memories.
  """
  def shared_with_user_memory_count(user), do: adapter().shared_with_user_memory_count(user)

  @doc """
  Gets the total count of a current_user's memories
  on their timeline page.
  """
  def timeline_memory_count(current_user), do: adapter().timeline_memory_count(current_user)

  @doc """
  Gets the total count of a user's Memories that have
  been shared with the current_user by another user.
  Does not include group Memories.
  """
  def shared_between_users_memory_count(user_id, current_user_id) do
    adapter().shared_between_users_memory_count(user_id, current_user_id)
  end

  @doc """
  Gets the total count of a user's Memories.
  """
  def public_memory_count(user), do: adapter().public_memory_count(user)

  @doc """
  Gets the total count of a group's Memories.
  """
  def group_memory_count(group), do: adapter().group_memory_count(group)

  @doc """
  Gets the total count of a memory's Remarks.
  """
  def remark_count(memory), do: adapter().remark_count(memory)

  @doc """
  Returns the sum of the size of a user's memories.
  """
  def get_total_storage(user), do: adapter().get_total_storage(user)

  @doc """
  Counts all Memories.
  """
  def count_all_memories, do: adapter().count_all_memories()

  @doc """
  Returns the count of a memory's remark loved reactions.
  """
  def get_remarks_loved_count(memory), do: adapter().get_remarks_loved_count(memory)

  @doc """
  Returns the count of a memory's remark excited reactions.
  """
  def get_remarks_excited_count(memory), do: adapter().get_remarks_excited_count(memory)

  @doc """
  Returns the count of a memory's remark happy reactions.
  """
  def get_remarks_happy_count(memory), do: adapter().get_remarks_happy_count(memory)

  @doc """
  Returns the count of a memory's remark sad reactions.
  """
  def get_remarks_sad_count(memory), do: adapter().get_remarks_sad_count(memory)

  @doc """
  Returns the count of a memory's remark thumbsy reactions.
  """
  def get_remarks_thumbsy_count(memory), do: adapter().get_remarks_thumbsy_count(memory)

  @doc """
  Preloads the Memory.
  """
  def preload(memory), do: adapter().preload(memory)

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
  def list_memories(user, options), do: adapter().list_memories(user, options)

  @doc """
  Returns a list of memories for the
  current_user's timeline page. These are all
  non-public memories that have been shared.
  """
  def filter_timeline_memories(current_user, options) do
    adapter().filter_timeline_memories(current_user, options)
  end

  @doc """
  Returns a list of memories that have been shared
  with the current user by another user.
  """
  def filter_memories_shared_with_current_user(user_id, options) do
    adapter().filter_memories_shared_with_current_user(user_id, options)
  end

  @doc """
  Returns the list of user's public memories.
  """
  def list_public_memories(user, options), do: adapter().list_public_memories(user, options)

  @doc """
  Used only in group's show page.
  """
  def list_group_memories(group, options), do: adapter().list_group_memories(group, options)

  @doc """
  Returns the list of remarks for
  a memory.

  ## Examples

      iex> list_remarks(memory, options)
      [%Remark{}, ...]

  """
  def list_remarks(memory, options), do: adapter().list_remarks(memory, options)

  def get_remark!(id), do: adapter().get_remark!(id)
  def get_remark(id), do: adapter().get_remark(id)

  @doc """
  Creates a memory.

  ## Examples

      iex> create_memory(%{field: value})
      {:ok, %Memory{}}

      iex> create_memory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_memory(attrs \\ %{}, opts \\ []) do
    changeset = Memory.changeset(%Memory{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = changeset.changes.user_memory_map

    case adapter().create_memory_multi(changeset, user, p_attrs, attrs["visibility"]) do
      {:ok, memory} ->
        create_shared_user_memories(memory, attrs, p_attrs, user)

        {:ok, memory}
        |> broadcast_admin(:memory_created)

      {:error, changeset} ->
        {:error, changeset}
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
    changeset = Memory.changeset(%Memory{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = changeset.changes.user_memory_map

    case adapter().create_memory_multi(changeset, user, p_attrs, attrs["visibility"]) do
      {:ok, memory} ->
        conn = Accounts.get_connection_from_item(memory, user)

        {:ok, conn, preload(memory)}
        |> broadcast(:memory_created)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp create_shared_user_memories(memory, attrs, p_attrs, current_user) do
    if attrs["shared_users"] && !Enum.empty?(attrs["shared_users"]) do
      for su <- attrs["shared_users"] do
        user = Mosslet.Accounts.get_user!(su[:user_id] || su["user_id"])
        adapter().create_shared_user_memory(memory, user, p_attrs, attrs["visibility"])
      end

      conn = Accounts.get_connection_from_item(memory, current_user)

      {:ok, conn, preload(memory)}
      |> broadcast(:memory_created)
    else
      conn = Accounts.get_connection_from_item(memory, current_user)

      {:ok, conn, preload(memory)}
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
    changeset = Memory.changeset(memory, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)
    p_attrs = changeset.changes.user_memory_map

    case adapter().update_memory_multi(changeset, memory, user, p_attrs) do
      {:ok, updated_memory} ->
        conn = Accounts.get_connection_from_item(updated_memory, user)

        {:ok, conn, preload(updated_memory)}
        |> broadcast(:memory_updated)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def blur_memory(%Memory{} = memory, attrs, user, opts \\ []) do
    changeset = Memory.blur_changeset(memory, attrs, user, opts)

    case adapter().blur_memory_multi(changeset, opts) do
      {:ok, memory} -> {:ok, memory}
      {:error, changeset} -> {:error, changeset}
    end
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
    changeset = Remark.changeset(%Remark{}, attrs, opts)
    user = Accounts.get_user!(opts[:user].id)

    case adapter().create_remark(changeset) do
      {:ok, remark} ->
        publish_remark_created({:ok, remark})
        conn = Accounts.get_connection_from_item(remark, user)

        {:ok, conn, adapter().preload_remark_user(remark)}
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

    case adapter().delete_remark(remark) do
      {:ok, remark} ->
        publish_remark_deleted({:ok, remark})
        conn = Accounts.get_connection_from_item(remark, user)

        {:ok, conn, adapter().preload_remark_user(remark)}
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
    changeset = Memory.changeset(memory, attrs, opts)

    case adapter().update_memory_fav(changeset) do
      {:ok, memory} ->
        conn = Accounts.get_connection_from_item(memory, user)

        {:ok, conn, preload(memory)}
        |> broadcast(:memory_updated)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def inc_favs(%Memory{} = memory), do: adapter().inc_favs(memory)
  def decr_favs(%Memory{} = memory), do: adapter().decr_favs(memory)

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

    case adapter().delete_memory(memory) do
      {:ok, memory} ->
        {:ok, memory}
        |> broadcast_admin(:memory_deleted)

        {:ok, conn, memory}
        |> broadcast(:memory_deleted)

      {:error, changeset} ->
        {:error, changeset}
    end
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

  def last_ten_remarks_for(memory_id), do: adapter().last_ten_remarks_for(memory_id)

  def last_user_remark_for_memory(memory_id, user_id) do
    adapter().last_user_remark_for_memory(memory_id, user_id)
  end

  def get_previous_n_remarks(date, memory_id, n) do
    adapter().get_previous_n_remarks(date, memory_id, n)
  end

  def preload_remark_user(remark), do: adapter().preload_remark_user(remark)

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

  def get_public_user_memory(memory), do: adapter().get_public_user_memory(memory)

  def get_user_memory(memory, user), do: adapter().get_user_memory(memory, user)

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

  def publish_group_memory({event, memory}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "group:#{memory.group_id}",
      {event, memory}
    )
  end

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
