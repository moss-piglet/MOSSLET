defmodule MossletWeb.MemoryLive.Show do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Extensions.MemoryProcessor
  alias Mosslet.Memories
  alias Mosslet.Memories.Remark
  alias MossletWeb.Endpoint

  @page_default 1
  @per_page_default 5

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:slide_over, false)
     |> assign(:slide_over_content, "")
     |> assign(:remark_loading_count, 0)
     |> assign(:remark_loading, false)
     |> assign(:remark_loading_done, false)
     |> assign(:remark_finished_loading_list, [])
     |> assign(:memory_loading_count, 0)
     |> assign(:memory_loading, false)
     |> assign(:memory_loading_done, false)
     |> assign(:finished_loading_list, [])
     |> assign(:remark, %Remark{})}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Memories.private_subscribe(current_user)
      Memories.connections_subscribe(current_user)
      Endpoint.subscribe("memory:#{id}")
    end

    memory = Memories.get_memory!(id)

    # This returns the user_connection for any shared item, or the current_user struct
    # with the Connection preloaded because the item belongs to the current user
    user_connection = Accounts.get_user_connection_from_shared_item(memory, current_user)

    user_memory = Memories.get_user_memory(memory, current_user)
    user = Accounts.get_user_with_preloads(memory.user_id)

    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)

    page = param_to_integer(params["remark_page"], @page_default)
    per_page = param_to_integer(params["remark_per_page"], @per_page_default) |> limit_per_page()

    options = %{
      remark_sort_by: sort_by,
      remark_sort_order: sort_order,
      remark_page: page,
      remark_per_page: per_page
    }

    remarks = Memories.list_remarks(memory, options)
    remark_loading_list = Enum.with_index(remarks, fn element, index -> {index, element} end)

    url =
      if options.remark_page == @page_default && options.remark_per_page == @per_page_default do
        ~p"/app/memories/#{memory}"
      else
        ~p"/app/memories/#{memory}?#{options}"
      end

    socket =
      socket
      |> assign(:live_action, :show)
      |> assign(:memory, memory)
      |> assign(:user, user)
      |> assign(:user_connection, user_connection)
      |> assign(:user_memory, user_memory)
      |> assign(:options, options)
      |> assign(:remark, %Remark{})
      |> assign(:return_url, url)
      |> assign(
        :memory_shared_users,
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          socket.assigns.key,
          :memory
        )
      )
      |> assign(:excited_count, Memories.get_remarks_excited_count(memory))
      |> assign(:loved_count, Memories.get_remarks_loved_count(memory))
      |> assign(:happy_count, Memories.get_remarks_happy_count(memory))
      |> assign(:sad_count, Memories.get_remarks_sad_count(memory))
      |> assign(:thumbsy_count, Memories.get_remarks_thumbsy_count(memory))
      |> assign(:remark_count, Memories.remark_count(memory))
      |> assign(:remark_loading_count, socket.assigns[:remark_loading_count] || 0)
      |> assign(:remark_loading, socket.assigns[:remark_loading] || false)
      |> assign(:remark_loading_done, socket.assigns[:remark_loading_done] || false)
      |> assign(:remark_loading_list, remark_loading_list)
      |> assign(
        :remark_finished_loading_list,
        socket.assigns[:remark_finished_loading_list] || []
      )
      |> stream(:remarks, remarks, reset: true)

    {:noreply, socket |> apply_action(socket.assigns.live_action, id)}
  end

  defp apply_action(socket, :show, _id) do
    if not is_nil(socket.assigns.user_memory) do
      socket
      |> assign(page_title: "Show Memory")
    else
      socket
      |> put_flash(:info, "You don't have permission to view this memory or it does not exist.")
      |> push_navigate(to: ~p"/app/users/connections")
    end
  end

  @impl true
  def handle_info({MossletWeb.MemoryLive.FormComponent, {:saved, memory}}, socket) do
    if memory.id == socket.assigns.memory.id do
      {:noreply, assign(socket, :memory, memory)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.MemoryLive.Show, {:deleted, memory}}, socket) do
    if memory.user_id == socket.assigns.current_user.id do
      {:noreply, stream_delete(socket, :memories, memory)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {MossletWeb.MemoryLive.RemarkFormComponent, {:created_remark, remark}},
        socket
      ) do
    if remark.user_id == socket.assigns.current_user.id do
      socket = update_remark_reaction_count(socket, remark)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_updated, memory}, socket) do
    if memory.id == socket.assigns.memory.id do
      {:noreply, assign(socket, :memory, memory)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:memory_deleted, memory}, socket) do
    if socket.assigns.current_user.id == memory.user_id do
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/app/timeline")}
    end
  end

  @impl true
  def handle_info({:uconn_deleted, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/timeline/")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remarks_deleted, uconn}, socket) do
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
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_confirmed, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{socket.assigns.memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_username_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{socket.assigns.memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_name_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{socket.assigns.memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        memory = socket.assigns.memory
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_email_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        memory = socket.assigns.memory
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    user = socket.assigns.current_user

    cond do
      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        memory = socket.assigns.memory
        {:noreply, push_navigate(socket, to: ~p"/app/memories/#{memory}")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:remark_created, _remark}, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({:remark_deleted, remark}, socket) do
    user = socket.assigns.current_user
    uconn = get_uconn_for_shared_item(remark, user)

    cond do
      # matches on the uconn variable being a %User{}
      # since we delete in the notify_self() we don't
      # need to delete again for the user of the remark.
      uconn.id == user.id ->
        {:noreply, socket}

      uconn.user_id == user.id || uconn.reverse_user_id == user.id ->
        socket = update_remark_delete_reaction_count(socket, remark)
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
  def handle_info(%{event: "new_remark", payload: %{remark: remark}}, socket) do
    {:noreply, stream_insert(socket, :remarks, remark, at: 0)}
  end

  @impl true
  def handle_info(%{event: "updated_remark", payload: %{remark: remark}}, socket) do
    {:noreply, stream_insert(socket, :remarks, remark, at: -1)}
  end

  @impl true
  def handle_info(%{event: "deleted_remark", payload: %{remark: _remark}}, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.return_url)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info({_ref, {"get_user_avatar", remark_id, remark_list, _user_id}}, socket) do
    remark_loading_count = socket.assigns.remark_loading_count
    finished_loading_list = socket.assigns.remark_finished_loading_list

    cond do
      remark_loading_count < Enum.count(remark_list) - 1 ->
        socket =
          socket
          |> assign(:remark_loading, true)
          |> assign(:remark_loading_count, remark_loading_count + 1)
          |> assign(
            :remark_finished_loading_list,
            [remark_id | finished_loading_list] |> Enum.uniq()
          )

        remark = Memories.get_remark!(remark_id)

        {:noreply, stream_insert(socket, :remarks, remark, at: -1)}

      remark_loading_count == Enum.count(remark_list) - 1 ->
        finished_loading_list = [remark_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:remark_loading, false)
          |> assign(
            :remark_finished_loading_list,
            [remark_id | finished_loading_list] |> Enum.uniq()
          )

        if Enum.count(finished_loading_list) == Enum.count(remark_list) do
          remark = Memories.get_remark!(remark_id)

          socket =
            socket
            |> assign(:remark_loading_count, 0)
            |> assign(:remark_loading, false)
            |> assign(:remark_loading_done, true)
            |> assign(:remark_finished_loading_list, [])

          {:noreply, stream_insert(socket, :remarks, remark, at: -1)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:remark_loading, true)
          |> assign(
            :remark_finished_loading_list,
            [remark_id | finished_loading_list] |> Enum.uniq()
          )

        {:noreply, socket}
    end
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

        {:noreply, assign(socket, :memory, memory)}

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

          {:noreply,
           socket |> assign(:memory, memory) |> push_patch(to: ~p"/app/memories/#{memory}")}
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

  @doc """
  Deletes the memory in ETS and object storage.
  """
  @impl true
  def handle_event("delete_memory", %{"id" => id, "url" => url}, socket) do
    memories_bucket = Encrypted.Session.memories_bucket()
    memory = Memories.get_memory!(id)
    user = socket.assigns.current_user
    user_connection = Map.get(socket.assigns, :user_connection)

    return_url =
      if user_connection do
        ~p"/app/users/connections/#{user_connection}"
      else
        ~p"/app/timeline"
      end

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

          {:noreply, push_navigate(socket, to: return_url)}

        _rest ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-remark", %{"item_id" => id}, socket) do
    remark = Memories.get_remark!(id)
    memory = socket.assigns.memory
    user = socket.assigns.current_user

    if remark.user_id == user.id || memory.user_id == user.id do
      case Memories.delete_remark(remark, user: user) do
        {:ok, _remark} ->
          info =
            "Your remark has been deleted successfully."

          socket =
            socket
            # |> clear_flash(:success)
            |> put_flash(:success, info)

          {:noreply, socket}

        _rest ->
          {:noreply, socket}
      end
    else
      {:noreply,
       socket |> put_flash(:warning, "Woopsy, you don't have permission to delete this Remark.")}
    end
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

    {:noreply, assign(socket, :memory, memory)}
  end

  defp blur_shared_user(shared_user) do
    if shared_user.blur do
      false
    else
      true
    end
  end

  defp update_remark_reaction_count(socket, remark) do
    memory = socket.assigns.memory

    socket =
      cond do
        remark.mood == :excited ->
          assign(socket, :excited_count, Memories.get_remarks_excited_count(memory))

        remark.mood == :loved ->
          assign(socket, :loved_count, Memories.get_remarks_loved_count(memory))

        remark.mood == :happy ->
          assign(socket, :happy_count, Memories.get_remarks_happy_count(memory))

        remark.mood == :sad ->
          assign(socket, :sad_count, Memories.get_remarks_sad_count(memory))

        remark.mood == :thumbsy ->
          assign(socket, :thumbsy_count, Memories.get_remarks_thumbsy_count(memory))

        true ->
          socket
      end

    socket
  end

  defp update_remark_delete_reaction_count(socket, remark) do
    socket =
      cond do
        remark.mood == :excited ->
          assign(socket, :excited_count, socket.assigns.excited_count - 1)

        remark.mood == :loved ->
          assign(socket, :loved_count, socket.assigns.loved_count - 1)

        remark.mood == :happy ->
          assign(socket, :happy_count, socket.assigns.happy_count - 1)

        remark.mood == :sad ->
          assign(socket, :sad_count, socket.assigns.sad_count - 1)

        remark.mood == :thumbsy ->
          assign(socket, :thumbsy_count, socket.assigns.thumbsy_count - 1)

        true ->
          socket
      end

    socket
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

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id inserted_at) do
    String.to_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

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
