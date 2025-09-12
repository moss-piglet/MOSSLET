defmodule MossletWeb.GroupLive.Index do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Groups.Group

  import MossletWeb.GroupLive.Components

  @page_default 1
  @per_page_default 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, :groups)
     |> assign(:user_group_loading_count, 0)
     |> assign(:user_group_loading, false)
     |> assign(:user_group_loading_done, false)
     |> assign(:finished_loading_list, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    groups = Groups.list_groups(current_user)

    if connected?(socket) do
      Accounts.subscribe_account_deleted()
      Groups.private_subscribe(socket.assigns.current_user)
      Groups.public_subscribe()
      subscribe_to_groups(groups)
    end

    pending_groups = Groups.list_unconfirmed_groups(current_user)
    any_pending_groups? = !Enum.empty?(pending_groups)
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

    url =
      if options.page == @page_default && options.per_page == @per_page_default,
        do: ~p"/app/groups",
        else: ~p"/app/groups?#{options}"

    socket =
      socket
      |> assign(
        :user_connections,
        decrypt_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          socket.assigns.key
        )
      )
      |> assign(:options, options)
      |> assign(:group_count, Groups.group_count_confirmed(current_user))
      |> assign(:any_pending_groups?, any_pending_groups?)
      |> assign(:return_url, url)
      |> stream(:groups, groups)
      |> stream(:pending_groups, pending_groups)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    group = Groups.get_group!(id)

    if can_edit_group?(
         get_user_group(group, socket.assigns.current_user),
         socket.assigns.current_user
       ) do
      socket
      |> assign(:page_title, "Edit Group")
      |> assign(:group, group)
    else
      socket
      |> put_flash(:info, "You do not have permission to edit this group.")
      |> push_patch(to: ~p"/app/groups")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Group")
    |> assign(:group, %Group{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Groups")
    |> assign(:group, nil)
    |> assign(:groups_greeter_open?, false)
  end

  defp apply_action(socket, :greet, _params) do
    socket
    |> assign(:page_title, "New Group Invitations")
    |> assign(:live_action, :greet)
    |> assign(:groups_greeter_open?, true)
  end

  defp apply_action(socket, :join, %{"id" => id}) do
    group = Groups.get_group!(id)

    if group.require_password? do
      socket
      |> push_navigate(to: ~p"/app/groups/#{group}/join-password")
    else
      user_group = get_user_group(group, socket.assigns.current_user)

      if can_join_group?(group, user_group, socket.assigns.current_user) do
        case Groups.join_group(group, user_group) do
          {:ok, group} ->
            notify_self({:joined, group, user_group})

            socket
            |> assign(:page_title, "New Group Invitations")
            |> assign(:live_action, :show)
            |> assign(:groups_greeter_open?, false)
            |> put_flash(:success, "You have joined this group!")
            |> push_navigate(to: ~p"/app/groups/#{group}")

          {:error, %Ecto.Changeset{} = _changeset} ->
            notify_self({:error_joined, group, user_group})

            socket
            |> assign(:page_title, "New Group Invitations")
            |> assign(:live_action, :greet)
            |> assign(:groups_greeter_open?, true)
            |> put_flash(:success, "You could not join this group.")
            |> push_patch(to: ~p"/app/groups/greet")
        end
      else
        socket
        |> assign(:page_title, "New Group Invitations")
        |> assign(:live_action, :greet)
        |> assign(:groups_greeter_open?, true)
        |> put_flash(:info, "You do not have permission to join this group.")
      end
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    group = Groups.get_group!(id)
    current_user = socket.assigns.current_user

    if can_delete_group?(group, current_user) do
      {:ok, _} = Groups.delete_group(group)

      {:noreply, stream_delete(socket, :groups, group)}
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to delete this group.")
       |> push_patch(to: ~p"/app/groups")}
    end
  end

  @impl true
  def handle_event("delete-user-group", %{"id" => id}, socket) do
    user_group = Groups.get_user_group!(id)

    if can_delete_user_group?(user_group, socket.assigns.current_user) do
      {:ok, _} = Groups.delete_user_group(user_group)

      {:noreply, stream_delete(socket, :pending_groups, user_group)}
    else
      {:noreply,
       socket
       |> put_flash(:warning, "You do not have permission to delete this group invitation.")
       |> push_patch(to: ~p"/app/groups/greet")}
    end
  end

  @impl true
  def handle_event("change", _message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.FormComponent, {:saved, group}}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.Index, {:joined, _group, _user_group}}, socket) do
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)

    if Enum.empty?(pending_groups) do
      {:noreply,
       socket
       |> assign(:any_pending_groups?, false)
       |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
       |> stream(:pending_groups, [], reset: true)}
    else
      {:noreply,
       socket
       |> assign(:any_pending_groups?, true)
       |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
       |> stream(:pending_groups, pending_groups)}
    end
  end

  @impl true
  def handle_info(
        {MossletWeb.GroupLive.PendingComponent, {:joined, _group, _user_group}},
        socket
      ) do
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)

    if Enum.empty?(pending_groups) do
      {:noreply,
       socket
       |> assign(:any_pending_groups?, false)
       |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
       |> stream(:pending_groups, [], reset: true)}
    else
      {:noreply,
       socket
       |> assign(:any_pending_groups?, true)
       |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
       |> stream(:pending_groups, pending_groups)}
    end
  end

  @impl true
  def handle_info(
        {MossletWeb.GroupLive.PendingComponent, {:error_joined, _group, _user_group}},
        socket
      ) do
    {:noreply,
     socket
     |> stream(:pending_groups, Groups.list_unconfirmed_groups(socket.assigns.current_user),
       reset: true
     )}
  end

  @impl true
  def handle_info({:updated_options, _opts}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_created, group}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: 0)}
  end

  @impl true
  def handle_info({:group_created_unconfirmed, group}, socket) do
    {:noreply,
     socket
     |> update_pending_groups_flag(group)
     |> stream_insert(:pending_groups, group, at: 0)}
  end

  @impl true
  def handle_info({:group_joined, group}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:group_joined_unconfirmed, group}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:group_updated, group}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:group_updated_unconfirmed, group}, socket) do
    {:noreply,
     socket
     |> update_pending_groups_flag(group)
     |> stream_insert(:pending_groups, group, at: -1)}
  end

  @impl true
  def handle_info({:user_group_deleted, user_group}, socket) do
    group = Groups.get_group!(user_group.group_id)
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:user_group_updated, user_group}, socket) do
    group = Groups.get_group!(user_group.group_id)
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:group_updated_members_removed, group}, socket) do
    {:noreply, stream_delete(socket, :groups, group)}
  end

  @impl true
  def handle_info({:group_updated_members_removed_unconfirmed, group}, socket) do
    if Enum.empty?(Groups.list_unconfirmed_groups(socket.assigns.current_user)) do
      {:noreply,
       socket
       |> assign(:any_pending_groups?, false)
       |> stream_delete(:pending_groups, group)}
    else
      {:noreply,
       socket
       |> assign(:any_pending_groups?, true)
       |> stream_delete(:pending_groups, group)}
    end
  end

  @impl true
  def handle_info({:group_deleted, group}, socket) do
    {:noreply,
     socket
     |> assign(:group_count, Groups.group_count(socket.assigns.current_user))
     |> stream_delete(:groups, group)}
  end

  @impl true
  def handle_info({:group_deleted_unconfirmed, group}, socket) do
    if Enum.empty?(Groups.list_unconfirmed_groups(socket.assigns.current_user)) do
      {:noreply,
       socket
       |> assign(:any_pending_groups?, false)
       |> stream_delete(:pending_groups, group)}
    else
      {:noreply,
       socket
       |> assign(:any_pending_groups?, true)
       |> stream_delete(:pending_groups, group)}
    end
  end

  @impl true
  def handle_info({:groups_deleted, _struct}, socket) do
    {:noreply, socket |> push_patch(to: socket.assigns.return_url)}
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
  def handle_info({_ref, {"get_user_avatar", user_group_id, user_group_list, _user_id}}, socket) do
    user_group_loading_count = socket.assigns.user_group_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      user_group_loading_count < Enum.count(user_group_list) - 1 ->
        socket =
          socket
          |> assign(:user_group_loading, true)
          |> assign(:user_group_loading_count, user_group_loading_count + 1)
          |> assign(
            :finished_loading_list,
            [user_group_id | finished_loading_list] |> Enum.uniq()
          )

        user_group = Groups.get_user_group!(user_group_id)

        {:noreply, stream_insert(socket, :groups, user_group.group, at: -1, reset: true)}

      user_group_loading_count == Enum.count(user_group_list) - 1 ->
        finished_loading_list = [user_group_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:user_group_loading, false)
          |> assign(
            :finished_loading_list,
            [user_group_id | finished_loading_list] |> Enum.uniq()
          )

        if Enum.count(finished_loading_list) == Enum.count(user_group_list) do
          user_group = Groups.get_user_group!(user_group_id)

          socket =
            socket
            |> assign(:user_group_loading_count, 0)
            |> assign(:user_group_loading, false)
            |> assign(:user_group_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :groups, user_group.group, at: -1, reset: true)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:user_group_loading, true)
          |> assign(
            :finished_loading_list,
            [user_group_id | finished_loading_list] |> Enum.uniq()
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp update_pending_groups_flag(socket, group) do
    if Enum.any?(group.user_groups, fn user_group ->
         is_nil(user_group.confirmed_at) && user_group.user_id == socket.assigns.current_user.id
       end) do
      socket
      |> assign(:any_pending_groups?, true)
    else
      socket
      |> assign(:any_pending_groups?, false)
    end
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

  defp subscribe_to_groups(groups) do
    for group <- groups do
      Groups.group_subscribe(group)
    end
  end

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})
end
