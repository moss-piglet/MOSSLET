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
      current_page={:edit_group_members}
      current_user={@current_user}
      key={@key}
      group={@group}
      user_group={@current_user_group}
      edit_group_name={"Edit #{decr_item(@group.name, @current_user, @current_user_group.key, @key, @group)} Members"}
    >
      <div class="space-y-6">
        <div class="flex items-center justify-between mb-2">
          <div>
            <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              Group Members
            </h3>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
              Manage roles and permissions for members in this group
            </p>
          </div>
          <.liquid_badge color="teal">
            {length(@group.user_groups)} members
          </.liquid_badge>
        </div>

        <div class="space-y-3">
          <div :for={ug <- @group.user_groups} id={ug.id}>
            <.member_card
              user_group={ug}
              current_user_group={@current_user_group}
              current_user={@current_user}
              group={@group}
              key={@key}
            />
          </div>
        </div>

        <div class="pt-4 border-t border-slate-200/60 dark:border-slate-700/60">
          <div class="flex items-start gap-3 p-4 rounded-xl bg-gradient-to-br from-teal-50/50 to-emerald-50/50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/40 dark:border-teal-700/40">
            <.phx_icon
              name="hero-shield-check"
              class="w-5 h-5 text-teal-600 dark:text-teal-400 flex-shrink-0 mt-0.5"
            />
            <div class="text-sm">
              <p class="font-medium text-teal-800 dark:text-teal-200">Privacy-First Permissions</p>
              <p class="text-teal-700 dark:text-teal-300 mt-1">
                Member roles determine what actions they can take within the group. All group data remains encrypted and private.
              </p>
            </div>
          </div>
        </div>
      </div>

      <.liquid_modal
        :if={@live_action in [:edit_member]}
        id="user-group-edit-modal"
        show
        on_cancel={JS.patch(~p"/app/groups/#{@group}/edit-group-members")}
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
          patch={~p"/app/groups/#{@group}/edit-group-members"}
          current_user={@current_user}
          key={@key}
        />
      </.liquid_modal>
    </.settings_group_layout>
    """
  end

  attr :user_group, :map, required: true
  attr :current_user_group, :map, required: true
  attr :current_user, :map, required: true
  attr :group, :map, required: true
  attr :key, :string, required: true

  defp member_card(assigns) do
    is_self = assigns.user_group.id == assigns.current_user_group.id
    is_owner = assigns.current_user_group.role == :owner
    can_edit = !is_self || !is_owner

    assigns =
      assigns
      |> assign(:is_self, is_self)
      |> assign(:can_edit, can_edit)

    ~H"""
    <div
      id={@user_group.id <> "-edit-member-button"}
      phx-click={if @can_edit, do: JS.patch(~p"/app/groups/user_group/#{@user_group.id}/edit-member")}
      class={[
        "group relative flex items-center gap-4 p-4 rounded-xl",
        "bg-white/80 dark:bg-slate-800/60 backdrop-blur-sm",
        "border border-slate-200/60 dark:border-slate-700/60",
        "transition-all duration-200 ease-out transform-gpu",
        @can_edit &&
          "cursor-pointer hover:bg-gradient-to-r hover:from-teal-50/60 hover:via-emerald-50/40 hover:to-teal-50/60 dark:hover:from-teal-900/20 dark:hover:via-emerald-900/15 dark:hover:to-teal-900/20 hover:border-teal-300/60 dark:hover:border-teal-700/60 hover:shadow-lg hover:shadow-teal-500/10",
        !@can_edit && "opacity-80"
      ]}
      data-tippy-content={
        if !@can_edit,
          do: "This is you and you cannot currently change your role from owner.",
          else: "Click to edit member role"
      }
      phx-hook="TippyHook"
    >
      <div class="relative flex-shrink-0">
        <.phx_avatar
          :if={@current_user_group.id != @user_group.id}
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
          class={"w-12 h-12 #{group_avatar_role_style(@user_group.role)}"}
        />
        <.phx_avatar
          :if={@current_user_group.user_id == @user_group.user_id}
          src={maybe_get_user_avatar(@current_user, @key)}
          alt=""
          class={"w-12 h-12 #{group_avatar_role_style(@user_group.role)}"}
        />
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <span class="font-semibold text-slate-900 dark:text-slate-100 truncate">
            {decr_item(
              @user_group.name,
              @current_user,
              @current_user_group.key,
              @key,
              @group
            )}
          </span>
          <.liquid_badge :if={@is_self} color="cyan" size="sm">You</.liquid_badge>
        </div>

        <div class="flex items-center gap-3 text-sm">
          <span class="inline-flex items-center gap-1.5 text-slate-600 dark:text-slate-300">
            <.phx_icon name="hero-finger-print" class="w-4 h-4 text-teal-500 dark:text-teal-400" />
            <span class="truncate max-w-[140px]">
              {decr_item(
                @user_group.moniker,
                @current_user,
                @current_user_group.key,
                @key,
                @group
              )}
            </span>
          </span>
          <.liquid_badge color={role_badge_color(@user_group.role)} size="sm">
            {String.capitalize(Atom.to_string(@user_group.role))}
          </.liquid_badge>
        </div>
      </div>

      <div
        :if={@can_edit}
        class="flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity duration-200"
      >
        <.phx_icon name="hero-pencil-square" class="w-5 h-5 text-teal-500 dark:text-teal-400" />
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id} = _params, _session, socket) do
    if socket.assigns.live_action != :edit_member do
      group = Mosslet.Groups.get_group!(id)

      current_user_group =
        Mosslet.Groups.get_user_group_for_group_and_user(group, socket.assigns.current_user)

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
             socket.assigns.current_user,
             current_user_group.key,
             socket.assigns.key,
             group
           )
         )
         |> assign(:page_title, "Edit Group Members"), layout: {MossletWeb.Layouts, :app}}
      else
        {:ok,
         socket
         |> put_flash(
           :info,
           "You do not have permission to access this page or it does not exist."
         )
         |> push_navigate(to: ~p"/app/groups/#{group}")}
      end
    else
      user_group = Mosslet.Groups.get_user_group!(id)

      group = Mosslet.Groups.get_group!(user_group.group_id)

      current_user_group =
        Mosslet.Groups.get_user_group_for_group_and_user(group, socket.assigns.current_user)

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
             socket.assigns.current_user,
             get_user_group(group, socket.assigns.current_user).key,
             socket.assigns.key,
             group
           )
         )
         |> assign(:page_title, "Edit Group Members"), layout: {MossletWeb.Layouts, :app}}
      else
        {:ok,
         socket
         |> put_flash(
           :info,
           "You do not have permission to access this page or it does not exist."
         )
         |> push_navigate(to: ~p"/app/groups/#{group}")}
      end
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    if socket.assigns.live_action == :edit_member do
      if connected?(socket) do
        Endpoint.subscribe("group:#{socket.assigns.group.id}")
        Groups.private_subscribe(socket.assigns.current_user)
      end

      {:noreply, apply_action(socket, socket.assigns.live_action, id)}
    else
      if connected?(socket) do
        Endpoint.subscribe("group:#{id}")
        Groups.private_subscribe(socket.assigns.current_user)
      end

      {:noreply, apply_action(socket, socket.assigns.live_action, id)}
    end
  end

  defp apply_action(socket, :edit_member, id) do
    user_group = Mosslet.Groups.get_user_group!(id)
    group = Mosslet.Groups.get_group!(user_group.group_id)

    socket
    |> assign(:page_title, "Edit Group Members")
    |> assign(:group, group)
    |> assign(:user_group, user_group)
    |> assign(:current_user_group, socket.assigns.current_user_group)
  end

  defp apply_action(socket, nil, id) do
    socket
    |> assign(:page_title, "Edit Group Members")
    |> assign(:group, Mosslet.Groups.get_group!(id))
  end
end
