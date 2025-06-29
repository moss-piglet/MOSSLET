defmodule MossletWeb.MemoryLive.Index do
  @moduledoc false
  use MossletWeb, :live_view
  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.MemoryProcessor
  alias Mosslet.Groups
  alias Mosslet.Memories
  alias Mosslet.Memories.Memory

  alias MossletWeb.MemoryLive.Components

  @page_default 1
  @per_page_default 8

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Accounts.subscribe_account_deleted()
      Accounts.private_subscribe(current_user)
      Memories.private_subscribe(current_user)
      Memories.connections_subscribe(current_user)
    end

    socket =
      socket
      |> assign(page: 1, per_page: 20)
      |> assign(
        :shared_users,
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          socket.assigns.key,
          :memory
        )
      )
      |> assign(:memory_loading_count, 0)
      |> assign(:memory_loading, false)
      |> assign(:memory_loading_done, false)
      |> assign(:finished_loading_list, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)

    page = param_to_integer(params["page"], @page_default)
    per_page = param_to_integer(params["per_page"], @per_page_default) |> limit_per_page()

    options = %{
      sort_by: sort_by,
      sort_order: sort_order,
      page: page,
      per_page: per_page
    }

    memories = Memories.list_memories(current_user, options)

    loading_list = Enum.with_index(memories, fn element, index -> {index, element} end)

    url =
      if options.page == @page_default && options.per_page == @per_page_default,
        do: ~p"/app/memories",
        else: ~p"/app/memories?#{options}"

    socket =
      socket
      |> assign(:groups, Groups.list_groups(current_user))
      |> assign(:memory_count, Memories.memory_count(current_user))
      |> assign(:loading_list, loading_list)
      |> assign(:options, options)
      |> assign(:return_url, url)
      |> assign(:memory_loading_count, socket.assigns[:memory_loading_count] || 0)
      |> assign(:memory_loading, socket.assigns[:memory_loading] || false)
      |> assign(:memory_loading_done, socket.assigns[:memory_loading_done] || false)
      |> assign(:finished_loading_list, socket.assigns[:finished_loading_list] || [])
      |> stream(:memories, memories, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({MossletWeb.MemoryLive.FormComponent, {:saved, memory}}, socket) do
    if memory.visibility != :public do
      {:noreply, stream_insert(socket, :memories, memory, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.MemoryLive.FormComponent, {:updated, memory}}, socket) do
    if memory.visibility != :public do
      {:noreply, stream_insert(socket, :memories, memory, at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.MemoryLive.Index, {:deleted, memory}}, socket) do
    if memory.user_id == socket.assigns.current_user.id do
      {:noreply, stream_delete(socket, :memories, memory)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remark_created, remark}, socket) do
    if remark.visibility != :public do
      {:noreply, stream_insert(socket, :remarks, remark, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remark_updated, remark}, socket) do
    if remark.visibility != :public do
      {:noreply, stream_insert(socket, :remarks, remark, at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remark_deleted, remark}, socket) do
    if remark.visibility != :public do
      {:noreply, stream_delete(socket, :remarks, remark)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_created, memory}, socket) do
    if memory.visibility != :public && is_nil(memory.group_id) do
      {:noreply, stream_insert(socket, :memories, memory, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_deleted, memory}, socket) do
    live_action = socket.assigns.live_action
    current_memory = Map.get(socket.assigns, :memory)

    if live_action == :show_memory &&
         (not is_nil(current_memory) && memory.id == current_memory.id) do
      {:noreply, push_navigate(socket, to: ~p"/app/memories")}
    else
      {:noreply, stream_delete(socket, :memories, memory)}
    end
  end

  @impl true
  def handle_info({:memories_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_updated, uconn}, socket) do
    current_user = socket.assigns.current_user
    user = socket.assigns.user

    cond do
      is_nil(current_user) ->
        {:noreply,
         socket
         |> assign(:user, Accounts.get_user_with_preloads(user.id))
         |> redirect(to: "/profile/#{socket.assigns.slug}")}

      uconn.user_id == current_user.id && user.id != current_user.id ->
        {:noreply,
         socket
         |> assign(:user, Accounts.get_user_with_preloads(uconn.reverse_user_id))
         |> redirect(to: "/profile/#{socket.assigns.slug}")}

      uconn.reverse_user_id == current_user.id && user.id != current_user.id ->
        {:noreply,
         socket
         |> assign(:user, Accounts.get_user_with_preloads(uconn.user_id))
         |> redirect(to: "/profile/#{socket.assigns.slug}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_patch(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_confirmed, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_username_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_name_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_email_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {_ref, {:ok, :memory_deleted_from_storj, info}},
        socket
      ) do
    socket = put_flash(socket, :success, info)
    {:noreply, redirect(socket, to: "/memories")}
  end

  @impl true
  def handle_info({:account_deleted, _user}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info({_ref, {"get_user_memory", memory_id, memory_list, _user_id}}, socket) do
    memory_loading_count = socket.assigns.memory_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      memory_loading_count < Enum.count(memory_list) - 1 ->
        socket =
          socket
          |> assign(:memory_loading, true)
          |> assign(:memory_loading_count, memory_loading_count + 1)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        memory = Memories.get_memory!(memory_id)

        {:noreply, stream_insert(socket, :memories, memory, at: -1, reset: true)}

      memory_loading_count == Enum.count(memory_list) - 1 ->
        finished_loading_list = [memory_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:memory_loading, false)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        if Enum.count(finished_loading_list) == Enum.count(memory_list) do
          memory = Memories.get_memory!(memory_id)

          socket =
            socket
            |> assign(:memory_loading_count, 0)
            |> assign(:memory_loading, false)
            |> assign(:memory_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :memories, memory, at: -1, reset: true)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:memory_loading, true)
          |> assign(:finished_loading_list, [memory_id | finished_loading_list] |> Enum.uniq())

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("blur-memory", %{"id" => id}, socket) do
    memory = Memories.get_memory!(id)
    user = socket.assigns.current_user

    {:ok, memory} =
      Memories.blur_memory(
        memory,
        %{
          "shared_users" =>
            Enum.into(memory.shared_users, [], fn shared_user ->
              if shared_user.user_id == user.id,
                do: put_in(shared_user.blur, blur_shared_user(shared_user))

              put_in(shared_user.current_user_id, user.id)
              Map.from_struct(shared_user)
            end)
        },
        user,
        blur: true
      )

    {:noreply, stream_insert(socket, :memories, memory, at: -1)}
  end

  @doc """
  Deletes the memory in ETS and object storage.
  """
  @impl true
  def handle_event("delete", %{"id" => id, "url" => url}, socket) do
    memories_bucket = Encrypted.Session.memories_bucket()
    memory = Memories.get_memory!(id)
    user = socket.assigns.current_user

    if memory.user_id == user.id do
      case Memories.delete_memory(memory, user: user) do
        {:ok, conn, memory} ->
          MemoryProcessor.delete_ets_memory(
            "user:#{memory.user_id}-memory:#{memory.id}-key:#{conn.id}"
          )

          # Handle deleting the object storage memory async.
          make_async_aws_requests(memories_bucket, url)

          info =
            "Your memory has been deleted successfully."

          notify_self({:deleted, memory})

          socket =
            socket
            |> put_flash(:success, info)

          {:noreply, push_navigate(socket, to: ~p"/app/memories")}

        _rest ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp make_async_aws_requests(memories_bucket, url) do
    Task.Supervisor.async_nolink(Mosslet.StorjTask, fn ->
      case ex_aws_delete_request(memories_bucket, url) do
        {:ok, _resp} ->
          {:ok, :memory_deleted_from_storj, "Memory successfully deleted from the private cloud."}

        _rest ->
          ex_aws_delete_request(memories_bucket, url)
          {:error, :make_async_aws_requests}
      end
    end)
  end

  defp ex_aws_delete_request(memories_bucket, url) do
    ExAws.S3.delete_object(memories_bucket, url)
    |> ExAws.request()
  end

  defp blur_shared_user(shared_user) do
    if shared_user.blur do
      false
    else
      true
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Memory")
    |> assign(:memory, Memories.get_memory!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Memory")
    |> assign(:memory, %Memory{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Memories")
    |> assign(:memory, nil)
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id) do
    String.to_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :id

  defp valid_sort_order(%{"sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_atom(sort_order)
  end

  defp valid_sort_order(_params), do: :desc

  defp param_to_integer(nil, default), do: default

  defp param_to_integer(param, default) do
    case Integer.parse(param) do
      {number, _} -> number
      :error -> default
    end
  end

  defp limit_per_page(per_page) when is_integer(per_page) do
    if per_page > 24, do: 24, else: per_page
  end

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})
end
