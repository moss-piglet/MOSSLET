defmodule MossletWeb.GroupLive.GroupSettings.EditGroupMembersLive do
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

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
      <div class="space-y-2">
        <div :for={ug <- @group.user_groups} id={ug.id}>
          <div
            id={ug.id <> "-edit-member-button"}
            phx-click={
              if ug.id == @current_user_group.id && @current_user_group.role == :owner,
                do: nil,
                else: JS.patch(~p"/app/groups/user_group/#{ug.id}/edit-member")
            }
            class="relative flex items-center space-x-3 rounded-lg border border-gray-300 dark:border-emerald-400 bg-white dark:bg-gray-950 px-6 py-5 shadow-sm focus-within:ring-2 focus-within:ring-emerald-500 focus-within:ring-offset-2 hover:border-gray-400 dark:hober:border-emerald-500"
            data-tippy-content={
              if ug.id == @current_user_group.id && @current_user_group.role == :owner,
                do: "This is you and you cannot currently change your role from owner.",
                else: "Click to edit member."
            }
            phx-hook="TippyHook"
          >
            <div class="flex-shrink-0">
              <.avatar
                :if={@current_user_group.id != ug.id}
                src={
                  get_user_avatar(
                    get_uconn_for_users(
                      get_user_from_user_group_id(ug.id),
                      @current_user
                    ),
                    @key
                  )
                }
                alt=""
                class="h-10 w-10 rounded-full ring-2 ring-white dark:ring-emerald-400"
              />
              <.avatar
                :if={@current_user_group.user_id == ug.user_id}
                src={maybe_get_user_avatar(@current_user, @key)}
                alt=""
                class="h-10 w-10 rounded-full ring-2 ring-white dark:ring-emerald-400"
              />
            </div>
            <div class="min-w-0 flex-1">
              <a href="#" class="focus:outline-none">
                <span class="absolute inset-0" aria-hidden="true"></span>
                <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                  {decr_item(
                    ug.name,
                    @current_user,
                    @current_user_group.key,
                    @key,
                    @group
                  )}
                </p>
                <p class=" text-sm text-gray-500 dark:text-gray-400">
                  <span class="text-emerald-600 dark:text-emerald-400 text-xs">
                    <.icon name="hero-finger-print" class="h-4 w-4" />{decr_item(
                      ug.moniker,
                      @current_user,
                      @current_user_group.key,
                      @key,
                      @group
                    )}
                  </span>
                  /
                  <span class={"#{role_badge_color_ring(ug.role)}"}>
                    {String.capitalize(Atom.to_string(ug.role))}
                  </span>
                </p>
              </a>
            </div>
          </div>
        </div>
      </div>
      <.phx_modal
        :if={@live_action in [:edit_member]}
        id="user-group-edit-modal"
        show
        on_cancel={JS.patch(~p"/app/groups/#{@group}/edit-group-members")}
      >
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
      </.phx_modal>
    </.settings_group_layout>
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
