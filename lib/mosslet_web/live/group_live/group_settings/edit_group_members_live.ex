defmodule MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive do
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent
  import MossletWeb.DesignSystem

  alias Mosslet.Groups
  alias MossletWeb.Endpoint

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_group_layout
      current_page={:edit_circle_members}
      current_scope={@current_scope}
      group={@group}
      user_group={@current_user_group}
      edit_group_name={"Edit #{decr_item(@group.name, @current_scope.user, @current_user_group.key, @current_scope.key, @group)} Members"}
    >
      <div class="space-y-6">
        <header class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div class="space-y-1">
            <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100">
              Circle Members
            </h2>
            <p class="text-sm text-slate-500 dark:text-slate-400">
              Manage roles and permissions for members in this circle
            </p>
          </div>
          <.liquid_badge color="teal" size="md">
            <.phx_icon name="hero-users" class="w-4 h-4 mr-1.5" />
            {length(@group.user_groups)} members
          </.liquid_badge>
        </header>

        <div
          role="list"
          aria-label="Group members"
          class="grid gap-3 sm:gap-4"
        >
          <div :for={ug <- @group.user_groups} role="listitem">
            <.member_card
              user_group={ug}
              current_user_group={@current_user_group}
              current_scope={@current_scope}
              group={@group}
            />
          </div>
        </div>

        <aside
          aria-label="Privacy information"
          class="pt-4 border-t border-slate-200/60 dark:border-slate-700/60"
        >
          <div class={[
            "flex items-start gap-4 p-4 sm:p-5 rounded-xl",
            "bg-gradient-to-br from-teal-50/60 via-emerald-50/40 to-cyan-50/60",
            "dark:from-teal-900/25 dark:via-emerald-900/20 dark:to-cyan-900/25",
            "border border-teal-200/50 dark:border-teal-700/40",
            "shadow-sm shadow-teal-500/5 dark:shadow-teal-400/5"
          ]}>
            <div class={[
              "flex-shrink-0 flex items-center justify-center w-10 h-10 rounded-lg",
              "bg-gradient-to-br from-teal-500 to-emerald-600",
              "shadow-md shadow-emerald-500/30 dark:shadow-emerald-400/20"
            ]}>
              <.phx_icon name="hero-shield-check" class="w-5 h-5 text-white" />
            </div>
            <div class="flex-1 min-w-0">
              <h3 class="font-semibold text-teal-800 dark:text-teal-200">
                Privacy-First Permissions
              </h3>
              <p class="mt-1 text-sm text-teal-700 dark:text-teal-300 leading-relaxed">
                Member roles determine what actions they can take within the group.
                All group data remains encrypted and private.
              </p>
            </div>
          </div>
        </aside>
      </div>

      <div id="user-group-edit-modal-component-container">
        <.liquid_modal
          :if={@live_action in [:edit_member]}
          id="user-group-edit-modal"
          show
          on_cancel={JS.patch(~p"/app/circles/#{@group}/edit-group-members")}
        >
          <:title>Edit Member Role</:title>
          <.live_component
            module={MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive.FormComponent}
            id="user-group-edit"
            title={@page_title}
            action={@live_action}
            group={@group}
            current_user_group={@current_user_group}
            user_group={@user_group}
            patch={~p"/app/circles/#{@group}/edit-group-members"}
            current_scope={@current_scope}
          />
        </.liquid_modal>
      </div>
    </.settings_group_layout>
    """
  end

  attr :user_group, :map, required: true
  attr :current_user_group, :map, required: true
  attr :current_scope, :map, required: true
  attr :group, :map, required: true

  defp member_card(assigns) do
    is_self = assigns.user_group.id == assigns.current_user_group.id
    is_owner = assigns.current_user_group.role == :owner
    target_is_owner = assigns.user_group.role == :owner
    can_edit = (!is_self || !is_owner) && (is_owner || !target_is_owner)

    uconn =
      get_uconn_for_users(
        get_user_from_user_group_id(assigns.user_group.id),
        assigns.current_scope.user
      )

    is_connected = not is_nil(uconn)

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

    assigns =
      assigns
      |> assign(:is_self, is_self)
      |> assign(:can_edit, can_edit)
      |> assign(:member_name, member_name)

    ~H"""
    <div
      id={@user_group.id <> "-edit-member-button"}
      phx-click={
        if @can_edit, do: JS.patch(~p"/app/circles/user_group/#{@user_group.id}/edit-member")
      }
      role={if @can_edit, do: "button", else: nil}
      tabindex={if @can_edit, do: "0", else: nil}
      aria-label={
        if @can_edit do
          if @member_name do
            "Edit role for #{@member_name}"
          else
            "Edit member role"
          end
        else
          nil
        end
      }
      phx-keydown={
        if @can_edit, do: JS.patch(~p"/app/circles/user_group/#{@user_group.id}/edit-member")
      }
      phx-key="Enter"
      class={[
        "group relative flex flex-col sm:flex-row sm:items-center gap-3 p-3 sm:p-5 rounded-xl",
        "bg-white/90 dark:bg-slate-800/80 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "transition-all duration-200 ease-out transform-gpu",
        "shadow-sm shadow-slate-900/5 dark:shadow-slate-900/20",
        @can_edit &&
          [
            "cursor-pointer",
            "hover:bg-gradient-to-r hover:from-teal-50/70 hover:via-emerald-50/50 hover:to-cyan-50/70",
            "dark:hover:from-teal-900/25 dark:hover:via-emerald-900/20 dark:hover:to-cyan-900/25",
            "hover:border-teal-300/70 dark:hover:border-teal-700/70",
            "hover:shadow-lg hover:shadow-teal-500/10 dark:hover:shadow-teal-400/10",
            "hover:-translate-y-0.5",
            "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
            "dark:focus:ring-offset-slate-900"
          ],
        !@can_edit && "opacity-85"
      ]}
      data-tippy-content={
        if !@can_edit,
          do: "This is you and you cannot currently change your role from owner.",
          else: "Click to edit member role"
      }
      phx-hook="TippyHook"
    >
      <div class={[
        "absolute inset-0 rounded-xl opacity-0 transition-all duration-300 ease-out pointer-events-none",
        "bg-gradient-to-r from-transparent via-emerald-200/20 to-transparent",
        "dark:via-emerald-400/10",
        @can_edit && "group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
      ]}>
      </div>

      <div class="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
        <div class="relative flex-shrink-0 p-1">
          <.phx_avatar
            :if={@current_user_group.id != @user_group.id}
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
            class={"w-10 h-10 sm:w-12 sm:h-12 #{role_avatar_ring(@user_group.role)}"}
          />
          <.phx_avatar
            :if={@current_user_group.user_id == @user_group.user_id}
            src={maybe_get_user_avatar(@current_scope.user, @current_scope.key)}
            alt=""
            class={"w-10 h-10 sm:w-12 sm:h-12 #{role_avatar_ring(@user_group.role)}"}
          />
          <div
            :if={@is_self}
            class={[
              "absolute -bottom-1 -right-1 w-5 h-5 rounded-full",
              "bg-gradient-to-br from-cyan-500 to-teal-600",
              "border-2 border-white dark:border-slate-800",
              "flex items-center justify-center",
              "shadow-md shadow-cyan-500/30"
            ]}
            aria-hidden="true"
          >
            <.phx_icon name="hero-check-mini" class="w-3 h-3 text-white" />
          </div>
        </div>

        <div class="flex-1 min-w-0 space-y-1.5 overflow-hidden">
          <div class="flex flex-wrap items-center gap-2">
            <span
              :if={@member_name}
              class="font-semibold text-slate-900 dark:text-slate-100 truncate text-sm sm:text-base"
            >
              {@member_name}
            </span>
            <.liquid_badge :if={@is_self} color="cyan" size="xs" variant="soft">
              You
            </.liquid_badge>
          </div>

          <div class="flex flex-wrap items-center gap-x-2 sm:gap-x-3 gap-y-1 text-xs sm:text-sm">
            <span class="inline-flex items-center gap-1.5 text-slate-700 dark:text-slate-300 min-w-0">
              <.phx_icon
                name="hero-finger-print"
                class="w-4 h-4 text-teal-500 dark:text-teal-400 flex-shrink-0"
              />
              <span class="truncate">
                {decr_item(
                  @user_group.moniker,
                  @current_scope,
                  @current_user_group.key,
                  @current_scope.key,
                  @group
                )}
              </span>
            </span>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end gap-2 sm:gap-3 sm:flex-shrink-0">
        <.role_badge role={@user_group.role} />

        <div
          :if={@can_edit}
          class={[
            "flex items-center justify-center w-8 h-8 sm:w-9 sm:h-9 rounded-lg",
            "bg-slate-100/80 dark:bg-slate-700/60",
            "text-slate-400 dark:text-slate-500",
            "transition-all duration-200 transform-gpu",
            "group-hover:bg-gradient-to-br group-hover:from-teal-500 group-hover:to-emerald-600",
            "group-hover:text-white group-hover:shadow-md group-hover:shadow-emerald-500/30"
          ]}
          aria-hidden="true"
        >
          <.phx_icon name="hero-pencil-square" class="w-4 h-4" />
        </div>
      </div>
    </div>
    """
  end

  attr :role, :atom, required: true

  defp role_badge(assigns) do
    {color, icon} =
      case assigns.role do
        :owner -> {"pink", "hero-star"}
        :admin -> {"orange", "hero-shield-check"}
        :moderator -> {"purple", "hero-wrench"}
        :member -> {"emerald", "hero-user"}
        _ -> {"teal", "hero-user"}
      end

    assigns =
      assigns
      |> assign(:color, color)
      |> assign(:icon, icon)

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold",
      "transition-all duration-200 transform-gpu",
      role_badge_styles(@color)
    ]}>
      <.phx_icon name={@icon} class="w-3.5 h-3.5" />
      {String.capitalize(Atom.to_string(@role))}
    </span>
    """
  end

  defp role_badge_styles("pink") do
    [
      "bg-gradient-to-r from-pink-100 to-rose-100 text-pink-700",
      "dark:from-pink-900/40 dark:to-rose-900/40 dark:text-pink-300",
      "border border-pink-200/60 dark:border-pink-700/50",
      "shadow-sm shadow-pink-500/10 dark:shadow-pink-400/10"
    ]
  end

  defp role_badge_styles("orange") do
    [
      "bg-gradient-to-r from-orange-100 to-amber-100 text-orange-700",
      "dark:from-orange-900/40 dark:to-amber-900/40 dark:text-orange-300",
      "border border-orange-200/60 dark:border-orange-700/50",
      "shadow-sm shadow-orange-500/10 dark:shadow-orange-400/10"
    ]
  end

  defp role_badge_styles("purple") do
    [
      "bg-gradient-to-r from-purple-100 to-violet-100 text-purple-700",
      "dark:from-purple-900/40 dark:to-violet-900/40 dark:text-purple-300",
      "border border-purple-200/60 dark:border-purple-700/50",
      "shadow-sm shadow-purple-500/10 dark:shadow-purple-400/10"
    ]
  end

  defp role_badge_styles("emerald") do
    [
      "bg-gradient-to-r from-emerald-100 to-teal-100 text-emerald-700",
      "dark:from-emerald-900/40 dark:to-teal-900/40 dark:text-emerald-300",
      "border border-emerald-200/60 dark:border-emerald-700/50",
      "shadow-sm shadow-emerald-500/10 dark:shadow-emerald-400/10"
    ]
  end

  defp role_badge_styles(_color) do
    [
      "bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-700",
      "dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-300",
      "border border-teal-200/60 dark:border-teal-700/50",
      "shadow-sm shadow-teal-500/10 dark:shadow-teal-400/10"
    ]
  end

  defp role_avatar_ring(:owner) do
    "rounded-full ring-2 ring-pink-400 dark:ring-pink-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:admin) do
    "rounded-full ring-2 ring-orange-400 dark:ring-orange-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:moderator) do
    "rounded-full ring-2 ring-purple-400 dark:ring-purple-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(:member) do
    "rounded-full ring-2 ring-emerald-400 dark:ring-emerald-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  defp role_avatar_ring(_role) do
    "rounded-full ring-2 ring-teal-300 dark:ring-teal-500 ring-offset-2 ring-offset-white dark:ring-offset-slate-800"
  end

  @impl true
  def mount(%{"id" => id} = _params, _session, socket) do
    if socket.assigns.live_action != :edit_member do
      group = Mosslet.Groups.get_group!(id)

      current_user_group =
        Mosslet.Groups.get_user_group_for_group_and_user(group, socket.assigns.current_scope.user)

      if current_user_group.role in [:owner, :admin] do
        {:ok,
         socket
         |> assign(:group, group)
         |> assign(:current_user_group, current_user_group)
         |> assign(:selected_role, nil)
         |> assign(
           :group_name,
           decr_item(
             group.name,
             socket.assigns.current_scope.user,
             current_user_group.key,
             socket.assigns.current_scope.key,
             group
           )
         )
         |> assign(:page_title, "Edit Circle Members"), layout: {MossletWeb.Layouts, :app}}
      else
        {:ok,
         socket
         |> put_flash(
           :info,
           "You do not have permission to access this page or it does not exist."
         )
         |> push_navigate(to: ~p"/app/circles/#{group}")}
      end
    else
      user_group = Mosslet.Groups.get_user_group!(id)

      group = Mosslet.Groups.get_group!(user_group.group_id)

      current_user_group =
        Mosslet.Groups.get_user_group_for_group_and_user(group, socket.assigns.current_scope.user)

      if user_group.role in [:owner, :admin] do
        {:ok,
         socket
         |> assign(:group, group)
         |> assign(:user_group, user_group)
         |> assign(:current_user_group, current_user_group)
         |> assign(:selected_role, nil)
         |> assign(
           :group_name,
           decr_item(
             group.name,
             socket.assigns.current_scope.user,
             get_user_group(group, socket.assigns.current_scope.user).key,
             socket.assigns.key,
             group
           )
         )
         |> assign(:page_title, "Edit Circle Members"), layout: {MossletWeb.Layouts, :app}}
      else
        {:ok,
         socket
         |> put_flash(
           :info,
           "You do not have permission to access this page or it does not exist."
         )
         |> push_navigate(to: ~p"/app/circles/#{group}")}
      end
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    if socket.assigns.live_action == :edit_member do
      if connected?(socket) do
        Endpoint.subscribe("group:#{socket.assigns.group.id}")
        Groups.private_subscribe(socket.assigns.current_scope.user)
      end

      {:noreply, apply_action(socket, socket.assigns.live_action, id)}
    else
      if connected?(socket) do
        Endpoint.subscribe("group:#{id}")
        Groups.private_subscribe(socket.assigns.current_scope.user)
      end

      {:noreply, apply_action(socket, socket.assigns.live_action, id)}
    end
  end

  defp apply_action(socket, :edit_member, id) do
    user_group = Mosslet.Groups.get_user_group!(id)
    group = Mosslet.Groups.get_group!(user_group.group_id)

    socket
    |> assign(:page_title, "Edit Circle Members")
    |> assign(:group, group)
    |> assign(:user_group, user_group)
    |> assign(:current_user_group, socket.assigns.current_user_group)
  end

  defp apply_action(socket, nil, id) do
    socket
    |> assign(:page_title, "Edit Circle Members")
    |> assign(:group, Mosslet.Groups.get_group!(id))
  end

  @impl true
  def handle_event("restore-body-scroll", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_joined, group}, socket) do
    if group.id == socket.assigns.group.id do
      {:noreply, assign(socket, :group, group)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if kicked_user_id == socket.assigns.current_scope.user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this circle.")
         |> push_navigate(to: ~p"/app/circles")}
      else
        {:noreply, assign(socket, :group, group)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      if blocked_user_id == socket.assigns.current_scope.user.id do
        {:noreply,
         socket
         |> put_flash(:info, "You have been removed from this circle.")
         |> push_navigate(to: ~p"/app/circles")}
      else
        blocked_users = Groups.list_blocked_users(group.id)

        {:noreply,
         socket
         |> assign(:group, group)
         |> assign(:blocked_users, blocked_users)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_member_unblocked, {group, _target_user_id}}, socket) do
    if group.id == socket.assigns.group.id do
      blocked_users = Groups.list_blocked_users(group.id)

      {:noreply,
       socket
       |> assign(:group, group)
       |> assign(:blocked_users, blocked_users)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
