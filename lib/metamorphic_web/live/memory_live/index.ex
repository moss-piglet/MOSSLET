defmodule MetamorphicWeb.MemoryLive.Index do
  @moduledoc false
  use MetamorphicWeb, :live_view

  alias Metamorphic.Accounts
  alias Metamorphic.Memories
  alias Metamorphic.Memories.Memory

  alias MetamorphicWeb.MemoryLive.Components

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Accounts.private_subscribe(socket.assigns.current_user)
      Memories.private_subscribe(socket.assigns.current_user)
      Memories.connections_subscribe(socket.assigns.current_user)
    end

    {:ok,
     socket
     |> assign(page: 1, per_page: 20)
     |> assign(plan_memories: assign_plan_memories(socket.assigns.current_user))
     |> assign(memory_storage_total: Memories.get_total_storage(socket.assigns.current_user))
     |> paginate_memories(1)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Map.get(socket.assigns.flash, "success") do
      "Your memory has been deleted successfully. Sit back and relax while we delete your memory from the private cloud." ->
        {:noreply, socket}

      _rest ->
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
    end
  end

  @impl true
  def handle_info({MetamorphicWeb.MemoryLive.FormComponent, {:saved, memory}}, socket) do
    if memory.visibility != :public do
      {:noreply, stream_insert(socket, :memories, memory, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MetamorphicWeb.MemoryLive.FormComponent, {:updated, memory}}, socket) do
    if memory.visibility != :public do
      {:noreply, stream_insert(socket, :memories, memory, at: -1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MetamorphicWeb.MemoryLive.Index, {:deleted, memory}}, socket) do
    if memory.user_id == socket.assigns.current_user.id do
      {:noreply, stream_delete(socket, :memories, memory)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_created, memory}, socket) do
    if memory.visibility != :public do
      {:noreply, stream_insert(socket, :memories, memory, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_deleted, memory}, socket) do
    {:noreply, stream_delete(socket, :memories, memory)}
  end

  @impl true
  def handle_info({:uconn_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_confirmed, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_username_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_name_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_email_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, paginate_memories(socket, socket.assigns.page, true)}

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
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("next-page", _, socket) do
    {:noreply, paginate_memories(socket, socket.assigns.page + 1)}
  end

  @impl true
  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_memories(socket, 1)}
  end

  @impl true
  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, paginate_memories(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Memory")
    |> assign(:memory_storage_total, Memories.get_total_storage(socket.assigns.current_user))
    |> assign(:memory, Memories.get_memory!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Memory")
    |> assign(:memory_storage_total, Memories.get_total_storage(socket.assigns.current_user))
    |> assign(:memory, %Memory{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Your Memories")
    |> assign(:memory_storage_total, Memories.get_total_storage(socket.assigns.current_user))
    |> assign(:memory, nil)
  end

  defp paginate_memories(socket, new_page, reset \\ false) when new_page >= 1 do
    %{per_page: per_page, page: cur_page} = socket.assigns
    user = socket.assigns.current_user
    memories = Memories.list_memories(user, offset: (new_page - 1) * per_page, limit: per_page)

    {memories, at, limit} =
      if new_page >= cur_page do
        {memories, -1, per_page * 3 * -1}
      else
        {Enum.reverse(memories), 0, per_page * 3}
      end

    case memories do
      [] ->
        socket
        |> assign(end_of_memories?: at == -1)
        |> stream(:memories, [])

      [_ | _] = memories ->
        socket
        |> assign(end_of_memories?: false)
        |> assign(page: new_page)
        |> stream(:memories, memories, at: at, limit: limit, reset: reset)
    end
  end
end
