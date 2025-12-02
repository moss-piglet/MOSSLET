defmodule MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive.FormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Groups

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4 pb-4 border-b border-slate-200/60 dark:border-slate-700/60">
        <.phx_avatar
          src={
            get_user_avatar(
              get_uconn_for_users(
                get_user_from_user_group_id(@user_group.id),
                @current_user
              ),
              @key
            )
          }
          alt=""
          class={"w-14 h-14 #{group_avatar_role_style(@user_group.role)}"}
        />
        <div>
          <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {decr_item(
              @user_group.name,
              @current_user,
              @current_user_group.key,
              @key,
              @group
            )}
          </h3>
          <div class="flex items-center gap-2 mt-1 text-sm text-slate-500 dark:text-slate-400">
            <.phx_icon name="hero-finger-print" class="w-4 h-4 text-teal-500 dark:text-teal-400" />
            <span>
              {decr_item(
                @user_group.moniker,
                @current_user,
                @current_user_group.key,
                @key,
                @group
              )}
            </span>
          </div>
        </div>
      </div>

      <div class="p-4 rounded-xl bg-slate-50/80 dark:bg-slate-700/30 border border-slate-200/40 dark:border-slate-600/40">
        <div class="flex items-start gap-3">
          <.phx_icon
            name="hero-information-circle"
            class="w-5 h-5 text-slate-500 dark:text-slate-400 flex-shrink-0 mt-0.5"
          />
          <p class="text-sm text-slate-600 dark:text-slate-400">
            Select a new role for this member. Role changes take effect immediately.
          </p>
        </div>
      </div>

      <.form for={@form} id="user-group-form" phx-target={@myself} phx-change="save" class="space-y-4">
        <input type="hidden" name={@form[:id].name} value={@user_group.id} />

        <div>
          <label
            for="user_group_role"
            class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
          >
            Member Role
          </label>
          <select
            id="user_group_role"
            name={@form[:role].name}
            class={[
              "w-full px-4 py-3 rounded-xl",
              "bg-white dark:bg-slate-800",
              "border border-slate-300 dark:border-slate-600",
              "text-slate-900 dark:text-slate-100",
              "focus:ring-2 focus:ring-teal-500/50 focus:border-teal-500",
              "transition-all duration-200"
            ]}
          >
            <%= for role <- Ecto.Enum.values(Groups.UserGroup, :role) do %>
              <option value={role} selected={@form[:role].value == role}>
                {String.capitalize(Atom.to_string(role))}
              </option>
            <% end %>
          </select>
        </div>

        <div class="grid grid-cols-1 gap-3 pt-2">
          <.role_info_card
            role={:owner}
            icon="hero-crown"
            description="Full control over the group including deletion"
            color="amber"
          />
          <.role_info_card
            role={:admin}
            icon="hero-shield-check"
            description="Can manage members and edit group settings"
            color="purple"
          />
          <.role_info_card
            role={:moderator}
            icon="hero-eye"
            description="Can moderate messages and content"
            color="blue"
          />
          <.role_info_card
            role={:member}
            icon="hero-user"
            description="Can send messages and participate"
            color="teal"
          />
        </div>
      </.form>
    </div>
    """
  end

  attr :role, :atom, required: true
  attr :icon, :string, required: true
  attr :description, :string, required: true
  attr :color, :string, required: true

  defp role_info_card(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-3 p-3 rounded-lg",
      "bg-#{@color}-50/50 dark:bg-#{@color}-900/20",
      "border border-#{@color}-200/40 dark:border-#{@color}-700/40"
    ]}>
      <.phx_icon
        name={@icon}
        class={"w-4 h-4 text-#{@color}-600 dark:text-#{@color}-400 flex-shrink-0 mt-0.5"}
      />
      <div>
        <span class={"text-sm font-medium text-#{@color}-800 dark:text-#{@color}-200"}>
          {String.capitalize(Atom.to_string(@role))}
        </span>
        <p class={"text-xs text-#{@color}-600 dark:text-#{@color}-400 mt-0.5"}>
          {@description}
        </p>
      </div>
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
