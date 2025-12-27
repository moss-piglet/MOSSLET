defmodule MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive.FormComponent do
  use MossletWeb, :live_component

  alias Mosslet.Groups

  @impl true
  def render(assigns) do
    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.user_group.id),
        assigns.current_scope.user
      )

    is_connected = not is_nil(uconn)
    is_self = assigns.user_group.id == assigns.current_user_group.id

    member_name =
      if is_self || is_connected do
        decr_item(
          assigns.user_group.name,
          assigns.current_scope.user,
          assigns.current_user_group.key,
          assigns.current_scope.key,
          assigns.group
        )
      else
        nil
      end

    assigns = assign(assigns, :member_name, member_name)

    ~H"""
    <div class="space-y-5">
      <div class={[
        "flex items-center gap-4 p-4 rounded-xl",
        "bg-gradient-to-r from-slate-50 via-slate-100/80 to-slate-50",
        "dark:from-slate-700/50 dark:via-slate-700/70 dark:to-slate-700/50",
        "border border-slate-200/60 dark:border-slate-600/50"
      ]}>
        <.phx_avatar
          src={
            get_user_avatar(
              get_uconn_for_users(
                get_user_from_user_group_id(@user_group.id),
                @current_scope.user
              ),
              @current_scope.key
            )
          }
          alt=""
          class={"w-14 h-14 sm:w-16 sm:h-16 flex-shrink-0 " <> avatar_ring_for_role(@user_group.role)}
        />
        <div class="min-w-0 flex-1">
          <h3
            :if={@member_name}
            class="text-lg font-semibold text-slate-900 dark:text-slate-100 truncate"
          >
            {@member_name}
          </h3>
          <div class="flex items-center gap-2 mt-1.5 text-sm text-slate-500 dark:text-slate-400">
            <.phx_icon
              name="hero-finger-print"
              class="w-4 h-4 text-teal-500 dark:text-teal-400 flex-shrink-0"
            />
            <span class="truncate">
              {decr_item(
                @user_group.moniker,
                @current_scope.user,
                @current_user_group.key,
                @current_scope.key,
                @group
              )}
            </span>
          </div>
          <div class="mt-2">
            <.current_role_badge role={@user_group.role} />
          </div>
        </div>
      </div>

      <.restriction_warning
        :if={@is_last_owner}
        icon="hero-exclamation-triangle"
        color="amber"
        title="Last Owner"
        message="This is the only owner. Groups must have at least one owner. To change this role, first assign another member as owner."
      />

      <.restriction_warning
        :if={@target_is_owner and not @can_change_owner_role and not @is_last_owner}
        icon="hero-lock-closed"
        color="rose"
        title="Owner Permission Required"
        message="Only group owners can change or remove the owner role from members."
      />

      <.form for={@form} id="user-group-form" phx-target={@myself} phx-change="save" class="space-y-5">
        <input type="hidden" name={@form[:id].name} value={@user_group.id} />

        <div>
          <label
            for="user_group_role"
            class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2"
          >
            Change Role
          </label>
          <select
            id="user_group_role"
            name={@form[:role].name}
            disabled={@is_last_owner or (@target_is_owner and not @can_change_owner_role)}
            class={[
              "w-full px-4 py-3 rounded-xl",
              "bg-white dark:bg-slate-800",
              "border border-slate-300 dark:border-slate-600",
              "text-slate-900 dark:text-slate-100",
              "focus:ring-2 focus:ring-emerald-500/50 focus:border-emerald-500",
              "transition-all duration-200",
              "shadow-sm",
              (@is_last_owner or (@target_is_owner and not @can_change_owner_role)) &&
                "opacity-50 cursor-not-allowed"
            ]}
          >
            <%= for role <- Ecto.Enum.values(Groups.UserGroup, :role) do %>
              <option value={role} selected={@form[:role].value == role}>
                {String.capitalize(Atom.to_string(role))}
              </option>
            <% end %>
          </select>
        </div>

        <div class="space-y-2">
          <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide">
            Role Permissions
          </p>
          <div class="grid gap-2">
            <.role_info_card_owner />
            <.role_info_card_admin />
            <.role_info_card_moderator />
            <.role_info_card_member />
          </div>
        </div>
      </.form>

      <div
        :if={not @is_last_owner and (not @target_is_owner or @can_change_owner_role)}
        class={[
          "flex items-start gap-3 p-3 rounded-xl",
          "bg-gradient-to-r from-teal-50/60 via-emerald-50/40 to-cyan-50/60",
          "dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20",
          "border border-teal-200/50 dark:border-teal-700/40"
        ]}
      >
        <.phx_icon
          name="hero-bolt"
          class="w-4 h-4 text-teal-600 dark:text-teal-400 flex-shrink-0 mt-0.5"
        />
        <p class="text-xs text-teal-700 dark:text-teal-300 leading-relaxed">
          Role changes take effect immediately. The member will be notified of their new permissions.
        </p>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :color, :string, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true

  defp restriction_warning(assigns) do
    {bg_classes, border_classes, icon_bg, text_classes} =
      case assigns.color do
        "amber" ->
          {
            "bg-gradient-to-r from-amber-50/80 to-orange-50/80 dark:from-amber-900/30 dark:to-orange-900/30",
            "border-amber-200/60 dark:border-amber-700/50",
            "bg-gradient-to-br from-amber-500 to-orange-500 shadow-amber-500/30",
            {"text-amber-800 dark:text-amber-200", "text-amber-700 dark:text-amber-300"}
          }

        "rose" ->
          {
            "bg-gradient-to-r from-rose-50/80 to-pink-50/80 dark:from-rose-900/30 dark:to-pink-900/30",
            "border-rose-200/60 dark:border-rose-700/50",
            "bg-gradient-to-br from-rose-500 to-pink-500 shadow-rose-500/30",
            {"text-rose-800 dark:text-rose-200", "text-rose-700 dark:text-rose-300"}
          }

        _ ->
          {
            "bg-gradient-to-r from-slate-50/80 to-slate-100/80 dark:from-slate-700/30 dark:to-slate-600/30",
            "border-slate-200/60 dark:border-slate-600/50",
            "bg-gradient-to-br from-slate-500 to-slate-600 shadow-slate-500/30",
            {"text-slate-800 dark:text-slate-200", "text-slate-700 dark:text-slate-300"}
          }
      end

    {title_class, message_class} = text_classes

    assigns =
      assigns
      |> assign(:bg_classes, bg_classes)
      |> assign(:border_classes, border_classes)
      |> assign(:icon_bg, icon_bg)
      |> assign(:title_class, title_class)
      |> assign(:message_class, message_class)

    ~H"""
    <div class={[
      "flex items-start gap-3 p-4 rounded-xl border",
      @bg_classes,
      @border_classes
    ]}>
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-lg flex-shrink-0",
        @icon_bg
      ]}>
        <.phx_icon name={@icon} class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <p class={["text-sm font-semibold", @title_class]}>
          {@title}
        </p>
        <p class={["text-xs mt-1 leading-relaxed", @message_class]}>
          {@message}
        </p>
      </div>
    </div>
    """
  end

  attr :role, :atom, required: true

  defp current_role_badge(assigns) do
    {bg_classes, text_class, icon} =
      case assigns.role do
        :owner ->
          {
            "bg-gradient-to-r from-pink-100 to-rose-100 dark:from-pink-900/40 dark:to-rose-900/40 border-pink-200/60 dark:border-pink-700/50",
            "text-pink-700 dark:text-pink-300",
            "hero-star"
          }

        :admin ->
          {
            "bg-gradient-to-r from-orange-100 to-amber-100 dark:from-orange-900/40 dark:to-amber-900/40 border-orange-200/60 dark:border-orange-700/50",
            "text-orange-700 dark:text-orange-300",
            "hero-shield-check"
          }

        :moderator ->
          {
            "bg-gradient-to-r from-purple-100 to-violet-100 dark:from-purple-900/40 dark:to-violet-900/40 border-purple-200/60 dark:border-purple-700/50",
            "text-purple-700 dark:text-purple-300",
            "hero-wrench"
          }

        :member ->
          {
            "bg-gradient-to-r from-emerald-100 to-teal-100 dark:from-emerald-900/40 dark:to-teal-900/40 border-emerald-200/60 dark:border-emerald-700/50",
            "text-emerald-700 dark:text-emerald-300",
            "hero-user"
          }

        _ ->
          {
            "bg-gradient-to-r from-slate-100 to-slate-200 dark:from-slate-700/40 dark:to-slate-600/40 border-slate-200/60 dark:border-slate-600/50",
            "text-slate-700 dark:text-slate-300",
            "hero-user"
          }
      end

    assigns =
      assigns
      |> assign(:bg_classes, bg_classes)
      |> assign(:text_class, text_class)
      |> assign(:icon, icon)

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border",
      @bg_classes,
      @text_class
    ]}>
      <.phx_icon name={@icon} class="w-3 h-3" /> Current: {String.capitalize(Atom.to_string(@role))}
    </span>
    """
  end

  defp role_info_card_owner(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-3 p-3 rounded-lg",
      "bg-gradient-to-r from-pink-50/70 to-rose-50/70",
      "dark:from-pink-900/25 dark:to-rose-900/25",
      "border border-pink-200/50 dark:border-pink-700/40"
    ]}>
      <div class={[
        "flex items-center justify-center w-7 h-7 rounded-md flex-shrink-0",
        "bg-gradient-to-br from-pink-500 to-rose-500",
        "shadow-sm shadow-pink-500/30"
      ]}>
        <.phx_icon name="hero-star" class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <span class="text-sm font-semibold text-pink-800 dark:text-pink-200">
          Owner
        </span>
        <p class="text-xs text-pink-600 dark:text-pink-400 mt-0.5 leading-relaxed">
          Full control over the group including deletion
        </p>
      </div>
    </div>
    """
  end

  defp role_info_card_admin(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-3 p-3 rounded-lg",
      "bg-gradient-to-r from-orange-50/70 to-amber-50/70",
      "dark:from-orange-900/25 dark:to-amber-900/25",
      "border border-orange-200/50 dark:border-orange-700/40"
    ]}>
      <div class={[
        "flex items-center justify-center w-7 h-7 rounded-md flex-shrink-0",
        "bg-gradient-to-br from-orange-500 to-amber-500",
        "shadow-sm shadow-orange-500/30"
      ]}>
        <.phx_icon name="hero-shield-check" class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <span class="text-sm font-semibold text-orange-800 dark:text-orange-200">
          Admin
        </span>
        <p class="text-xs text-orange-600 dark:text-orange-400 mt-0.5 leading-relaxed">
          Can manage members and edit circle settings
        </p>
      </div>
    </div>
    """
  end

  defp role_info_card_moderator(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-3 p-3 rounded-lg",
      "bg-gradient-to-r from-purple-50/70 to-violet-50/70",
      "dark:from-purple-900/25 dark:to-violet-900/25",
      "border border-purple-200/50 dark:border-purple-700/40"
    ]}>
      <div class={[
        "flex items-center justify-center w-7 h-7 rounded-md flex-shrink-0",
        "bg-gradient-to-br from-purple-500 to-violet-500",
        "shadow-sm shadow-purple-500/30"
      ]}>
        <.phx_icon name="hero-eye" class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <span class="text-sm font-semibold text-purple-800 dark:text-purple-200">
          Moderator
        </span>
        <p class="text-xs text-purple-600 dark:text-purple-400 mt-0.5 leading-relaxed">
          Can moderate messages and content
        </p>
      </div>
    </div>
    """
  end

  defp role_info_card_member(assigns) do
    ~H"""
    <div class={[
      "flex items-start gap-3 p-3 rounded-lg",
      "bg-gradient-to-r from-emerald-50/70 to-teal-50/70",
      "dark:from-emerald-900/25 dark:to-teal-900/25",
      "border border-emerald-200/50 dark:border-emerald-700/40"
    ]}>
      <div class={[
        "flex items-center justify-center w-7 h-7 rounded-md flex-shrink-0",
        "bg-gradient-to-br from-emerald-500 to-teal-500",
        "shadow-sm shadow-emerald-500/30"
      ]}>
        <.phx_icon name="hero-user" class="w-4 h-4 text-white" />
      </div>
      <div class="min-w-0 flex-1">
        <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
          Member
        </span>
        <p class="text-xs text-emerald-600 dark:text-emerald-400 mt-0.5 leading-relaxed">
          Can send messages and participate
        </p>
      </div>
    </div>
    """
  end

  defp avatar_ring_for_role(:owner) do
    "rounded-full ring-2 ring-pink-400 dark:ring-pink-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp avatar_ring_for_role(:admin) do
    "rounded-full ring-2 ring-orange-400 dark:ring-orange-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp avatar_ring_for_role(:moderator) do
    "rounded-full ring-2 ring-purple-400 dark:ring-purple-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp avatar_ring_for_role(:member) do
    "rounded-full ring-2 ring-emerald-400 dark:ring-emerald-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp avatar_ring_for_role(_role) do
    "rounded-full ring-2 ring-slate-300 dark:ring-slate-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  @impl true
  def update(%{user_group: user_group} = assigns, socket) do
    if assigns.action in [:edit_member] do
      changeset = Groups.change_user_group_role(user_group)
      group = Mosslet.Groups.get_group!(user_group.group_id)

      owner_count =
        Enum.count(group.user_groups, fn ug -> ug.role == :owner end)

      is_last_owner = user_group.role == :owner and owner_count <= 1
      can_change_owner_role = assigns.current_user_group.role == :owner

      {:ok,
       socket
       |> assign(:action, assigns.action)
       |> assign(:group, group)
       |> assign(:current_user_group, assigns.current_user_group)
       |> assign(:is_last_owner, is_last_owner)
       |> assign(:can_change_owner_role, can_change_owner_role)
       |> assign(:target_is_owner, user_group.role == :owner)
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
    actor = socket.assigns.current_user_group

    if actor.role in [:owner, :admin] do
      case Mosslet.Groups.update_user_group_role(user_group, user_group_params, actor: actor) do
        {:ok, user_group} ->
          notify_parent({:saved, user_group})

          {:noreply,
           socket
           |> put_flash(:success, "Member role updated successfully.")
           |> push_event("restore-body-scroll", %{})
           |> push_patch(to: socket.assigns.patch)}

        {:error, :only_owner_can_change_owner} ->
          {:noreply,
           socket
           |> put_flash(:error, "Only circle owners can change or remove the owner role.")
           |> push_patch(to: socket.assigns.patch)}

        {:error, :only_owner_can_grant_owner} ->
          {:noreply,
           socket
           |> put_flash(:error, "Only circle owners can grant the owner role to members.")
           |> push_patch(to: socket.assigns.patch)}

        {:error, :must_have_at_least_one_owner} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Cannot remove the last owner. Circles must have at least one owner."
           )
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
