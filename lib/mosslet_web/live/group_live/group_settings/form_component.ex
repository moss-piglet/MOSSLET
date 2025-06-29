defmodule MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive.FormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Groups

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mr-12 mt-12">
      <div class="pb-4">
        <.h2>
          {@title}
        </.h2>
        <.p :if={@action in [:edit_member]}>
          Use this form to edit {decr_item(
            @user_group.name,
            @current_user,
            @current_user_group.key,
            @key,
            @group
          )}'s role.
        </.p>
      </div>
      <.form for={@form} id="user-group-form" phx-target={@myself} phx-change="save">
        <.field type="hidden" field={@form[:id]} value={@user_group.id} />
        <.field
          type="select"
          field={@form[:role]}
          options={Ecto.Enum.values(Groups.UserGroup, :role)}
          label="Role"
        />
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{user_group: user_group} = assigns, socket) do
    if assigns.action in [:edit_member] do
      changeset = Groups.change_user_group_role(user_group)

      {:ok,
       socket
       |> assign(:action, assigns.action)
       |> assign(:group, Mosslet.Groups.get_group!(user_group.group_id))
       |> assign(:current_user_group, assigns.current_user_group)
       |> assign(assigns)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{"user_group" => user_group_params} = params
    user_group = Groups.get_user_group!(user_group_params["id"])
    role = user_group_params["role"]

    user_group_form =
      user_group
      |> Groups.change_user_group_role(user_group_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:selected_role, role)
     |> assign(:group_name, user_group_form[:name].value)
     |> assign(name_change_valid?: user_group_form.source.valid?)
     |> assign(user_group_form: user_group_form)}
  end

  @impl true
  def handle_event("save", %{"user_group" => user_group_params}, socket) do
    user_group = Groups.get_user_group!(user_group_params["id"])

    if socket.assigns.current_user_group.role in [:owner, :admin] do
      case Mosslet.Groups.update_user_group_role(user_group, user_group_params) do
        {:ok, user_group} ->
          notify_parent({:saved, user_group})

          {:noreply,
           socket
           |> put_flash(:success, "Member updated successfully.")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:info, "You do not have permission to update members.")
       |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
