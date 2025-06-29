defmodule MossletWeb.GroupLive.RemarkFormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Memories
  alias Mosslet.Memories.Remark

  @impl true
  def update(%{remark: remark, memory: _memory} = assigns, socket) do
    changeset = Memories.change_remark(remark || %Remark{}, %{}, user: assigns.current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:body, Map.get(assigns, :body))
     |> assign(:mood, Map.get(assigns, :mood, "nothing"))
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"remark" => remark_params}, socket) do
    memory = socket.assigns.memory
    current_user = socket.assigns.current_user

    if has_user_connection?(memory, current_user) || memory.user_id == current_user.id do
      changeset =
        socket.assigns.remark
        |> Memories.change_remark(remark_params, user: socket.assigns.current_user)
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign_form(changeset)
       |> assign(:body, remark_params["body"] || "")
       |> assign(:mood, socket.assigns.mood)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mood", %{"mood" => mood, "body" => body, "visibility" => visibility}, socket) do
    remark_params = %{body: body, mood: mood, visibility: visibility}

    changeset =
      socket.assigns.remark
      |> Memories.change_remark(remark_params, user: socket.assigns.current_user)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign_form(changeset) |> assign(mood: mood)}
  end

  @impl true
  def handle_event("save", %{"remark" => remark_params}, socket) do
    memory = socket.assigns.memory
    current_user = socket.assigns.current_user

    if has_user_connection?(memory, current_user) || memory.user_id == current_user.id do
      remark_params = remark_params |> Map.put("mood", socket.assigns.mood)
      save_remark(socket, :new, remark_params)
    else
      {:noreply, socket}
    end
  end

  defp save_remark(socket, :new, remark_params) do
    user = socket.assigns.current_user
    key = socket.assigns.key
    memory = socket.assigns.memory
    memory_key = get_memory_key(memory, user)

    case Memories.create_remark(remark_params, user: user, key: key, memory_key: memory_key) do
      {:ok, remark} ->
        info = "Your remark has been made successfully."

        notify_parent({:created_remark, remark})

        remark_form =
          %Remark{}
          |> Memories.change_remark()
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(remark_form: remark_form)
         |> push_patch(to: socket.assigns.patch)}

      {:ok, _connection, remark} ->
        info = "Your remark has been made successfully."

        notify_parent({:created_remark, remark})

        remark_form =
          %Remark{}
          |> Memories.change_remark()
          |> to_form()

        {:noreply,
         socket
         |> put_flash(:success, info)
         |> assign(remark_form: remark_form)
         |> push_patch(to: socket.assigns.patch)}

      {:error, changeset} ->
        {:noreply, socket |> assign_form(changeset)}
    end
  end

  ## PRIVATE

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
