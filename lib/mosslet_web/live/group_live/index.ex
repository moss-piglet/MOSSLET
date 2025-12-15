defmodule MossletWeb.GroupLive.Index do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Groups.Group

  @page_default 1
  @per_page_default 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, :circles)
     |> assign(:user_group_loading_count, 0)
     |> assign(:user_group_loading, false)
     |> assign(:user_group_loading_done, false)
     |> assign(:finished_loading_list, [])
     |> assign(:load_more_loading, false)
     |> assign(:load_more_public_loading, false)
     |> assign(:loaded_groups_count, 0)
     |> assign(:loaded_public_groups_count, 0)}
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
    pending_groups_count = length(pending_groups)
    any_pending_groups? = pending_groups_count > 0
    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)

    page = param_to_integer(params["page"], @page_default)
    per_page = param_to_integer(params["per_page"], @per_page_default) |> limit_per_page()
    active_tab = params["tab"] || "my_groups"
    search_term = params["search"] || ""

    options = %{
      sort_by: sort_by,
      sort_order: sort_order,
      page: page,
      per_page: per_page
    }

    url =
      if options.page == @page_default && options.per_page == @per_page_default,
        do: ~p"/app/circles",
        else: ~p"/app/circles?#{options}"

    public_groups =
      if active_tab == "discover" do
        Groups.list_public_groups(current_user, search_term, limit: per_page)
      else
        []
      end

    total_groups = Groups.group_count_confirmed(current_user)
    total_public_groups = Groups.public_group_count(current_user, search_term)
    initial_groups = Enum.take(groups, per_page)

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
      |> assign(:group_count, total_groups)
      |> assign(:pending_groups_count, pending_groups_count)
      |> assign(:any_pending_groups?, any_pending_groups?)
      |> assign(:return_url, url)
      |> assign(:active_tab, active_tab)
      |> assign(:search_term, search_term)
      |> assign(:public_groups, public_groups)
      |> assign(:loaded_groups_count, length(initial_groups))
      |> assign(:loaded_public_groups_count, length(public_groups))
      |> assign(:has_more_groups, length(initial_groups) < total_groups)
      |> assign(:remaining_groups_count, max(0, total_groups - length(initial_groups)))
      |> assign(:has_more_public_groups, length(public_groups) < total_public_groups)
      |> assign(
        :remaining_public_groups_count,
        max(0, total_public_groups - length(public_groups))
      )
      |> assign(:load_more_loading, false)
      |> assign(:load_more_public_loading, false)
      |> stream(:groups, initial_groups, reset: true)
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
      |> assign(:page_title, "Edit Circle")
      |> assign(:group, group)
    else
      socket
      |> put_flash(:info, "You do not have permission to edit this circle.")
      |> push_patch(to: ~p"/app/circles")
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Circle")
    |> assign(:group, %Group{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Circles")
    |> assign(:group, nil)
    |> assign(:groups_greeter_open?, false)
  end

  defp apply_action(socket, :greet, _params) do
    socket
    |> assign(:page_title, "Circle Invitations")
    |> assign(:active_tab, "invites")
    |> assign(:groups_greeter_open?, false)
  end

  defp apply_action(socket, :join, %{"id" => id}) do
    group = Groups.get_group!(id)

    if group.require_password? do
      socket
      |> push_navigate(to: ~p"/app/circles/#{group}/join-password")
    else
      user_group = get_user_group(group, socket.assigns.current_user)

      if can_join_group?(group, user_group, socket.assigns.current_user) do
        join_result =
          if group.public? && is_nil(user_group) do
            Groups.join_public_group(group, socket.assigns.current_user, socket.assigns.key)
          else
            Groups.join_group(group, user_group)
          end

        case join_result do
          {:ok, _result} ->
            notify_self({:joined, group, user_group})

            socket
            |> assign(:page_title, "New Circle Invitations")
            |> assign(:live_action, :show)
            |> assign(:groups_greeter_open?, false)
            |> put_flash(:success, "You have joined this circle!")
            |> push_navigate(to: ~p"/app/circles/#{group}")

          {:error, %Ecto.Changeset{} = _changeset} ->
            notify_self({:error_joined, group, user_group})

            socket
            |> assign(:page_title, "New Circle Invitations")
            |> assign(:live_action, :greet)
            |> assign(:groups_greeter_open?, true)
            |> put_flash(:success, "You could not join this circle.")
            |> push_patch(to: ~p"/app/circles/greet")

          {:error, _reason} ->
            socket
            |> assign(:page_title, "New Circle Invitations")
            |> assign(:live_action, :greet)
            |> assign(:groups_greeter_open?, true)
            |> put_flash(:error, "Could not join this circle.")
            |> push_patch(to: ~p"/app/circles/greet")
        end
      else
        socket
        |> assign(:page_title, "New Circle Invitations")
        |> assign(:live_action, :greet)
        |> assign(:groups_greeter_open?, true)
        |> put_flash(:info, "You do not have permission to join this circle.")
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
       |> put_flash(:warning, "You do not have permission to delete this circle.")
       |> push_patch(to: ~p"/app/circles")}
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
       |> put_flash(:warning, "You do not have permission to delete this circle invitation.")
       |> push_patch(to: ~p"/app/circles/greet")}
    end
  end

  @impl true
  def handle_event("change", _message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_public_groups", %{"search" => search_term}, socket) do
    current_user = socket.assigns.current_user
    per_page = socket.assigns.options.per_page
    public_groups = Groups.list_public_groups(current_user, search_term, limit: per_page)
    total_public_groups = Groups.public_group_count(current_user, search_term)

    {:noreply,
     socket
     |> assign(:public_groups, public_groups)
     |> assign(:search_term, search_term)
     |> assign(:loaded_public_groups_count, length(public_groups))
     |> assign(:has_more_public_groups, length(public_groups) < total_public_groups)
     |> assign(
       :remaining_public_groups_count,
       max(0, total_public_groups - length(public_groups))
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user
    per_page = socket.assigns.options.per_page

    {public_groups, total_public_groups} =
      if tab == "discover" do
        groups = Groups.list_public_groups(current_user, "", limit: per_page)
        total = Groups.public_group_count(current_user, "")
        {groups, total}
      else
        {[], 0}
      end

    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:search_term, "")
      |> assign(:public_groups, public_groups)
      |> assign(:loaded_public_groups_count, length(public_groups))
      |> assign(:has_more_public_groups, length(public_groups) < total_public_groups)
      |> assign(
        :remaining_public_groups_count,
        max(0, total_public_groups - length(public_groups))
      )

    socket =
      if tab == "my_groups" do
        all_groups = Groups.list_groups(current_user)
        initial_groups = Enum.take(all_groups, per_page)
        total_groups = socket.assigns.group_count

        socket
        |> assign(:loaded_groups_count, length(initial_groups))
        |> assign(:has_more_groups, length(initial_groups) < total_groups)
        |> assign(:remaining_groups_count, max(0, total_groups - length(initial_groups)))
        |> stream(:groups, initial_groups, reset: true)
      else
        socket
      end

    socket =
      if tab == "invites" do
        pending_groups = Groups.list_unconfirmed_groups(current_user)
        pending_groups_count = length(pending_groups)

        socket
        |> assign(:pending_groups_count, pending_groups_count)
        |> assign(:any_pending_groups?, pending_groups_count > 0)
        |> stream(:pending_groups, pending_groups, reset: true)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("join_public_group", %{"id" => id}, socket) do
    group = Groups.get_group!(id)

    if group.require_password? do
      {:noreply, push_navigate(socket, to: ~p"/app/circles/#{group}/join-password")}
    else
      case Groups.join_public_group(group, socket.assigns.current_user, socket.assigns.key) do
        {:ok, _user_group} ->
          public_groups =
            Groups.list_public_groups(socket.assigns.current_user, socket.assigns.search_term)

          {:noreply,
           socket
           |> assign(:public_groups, public_groups)
           |> assign(:group_count, Groups.group_count_confirmed(socket.assigns.current_user))
           |> stream(:groups, Groups.list_groups(socket.assigns.current_user), reset: true)
           |> put_flash(:success, "You have joined this circle!")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not join this circle.")}
      end
    end
  end

  @impl true
  def handle_event("load_more_groups", _params, socket) do
    socket = assign(socket, :load_more_loading, true)
    current_user = socket.assigns.current_user
    per_page = socket.assigns.options.per_page
    loaded_count = socket.assigns.loaded_groups_count

    all_groups = Groups.list_groups(current_user)
    new_groups = all_groups |> Enum.drop(loaded_count) |> Enum.take(per_page)
    new_loaded_count = loaded_count + length(new_groups)
    total_groups = socket.assigns.group_count

    socket =
      socket
      |> assign(:loaded_groups_count, new_loaded_count)
      |> assign(:has_more_groups, new_loaded_count < total_groups)
      |> assign(:remaining_groups_count, max(0, total_groups - new_loaded_count))
      |> assign(:load_more_loading, false)

    socket =
      Enum.reduce(new_groups, socket, fn group, acc -> stream_insert(acc, :groups, group) end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_public_groups", _params, socket) do
    socket = assign(socket, :load_more_public_loading, true)
    current_user = socket.assigns.current_user
    search_term = socket.assigns.search_term
    loaded_count = socket.assigns.loaded_public_groups_count

    total_public_groups = Groups.public_group_count(current_user, search_term)

    new_public_groups =
      Groups.list_public_groups(current_user, search_term,
        offset: loaded_count,
        limit: 10
      )

    new_loaded_count = loaded_count + length(new_public_groups)

    socket =
      socket
      |> assign(:public_groups, socket.assigns.public_groups ++ new_public_groups)
      |> assign(:loaded_public_groups_count, new_loaded_count)
      |> assign(:has_more_public_groups, new_loaded_count < total_public_groups)
      |> assign(:remaining_public_groups_count, max(0, total_public_groups - new_loaded_count))
      |> assign(:load_more_public_loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.FormComponent, {:saved, group}}, socket) do
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({MossletWeb.GroupLive.Index, {:joined, _group, _user_group}}, socket) do
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
    pending_groups_count = length(pending_groups)

    {:noreply,
     socket
     |> assign(:pending_groups_count, pending_groups_count)
     |> assign(:any_pending_groups?, pending_groups_count > 0)
     |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
     |> stream(:pending_groups, pending_groups, reset: true)}
  end

  @impl true
  def handle_info(
        {MossletWeb.GroupLive.PendingComponent, {:joined, _group, _user_group}},
        socket
      ) do
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
    pending_groups_count = length(pending_groups)

    {:noreply,
     socket
     |> assign(:pending_groups_count, pending_groups_count)
     |> assign(:any_pending_groups?, pending_groups_count > 0)
     |> stream(:groups, Groups.list_groups(socket.assigns.current_user))
     |> stream(:pending_groups, pending_groups, reset: true)}
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
    {:noreply, stream_insert(socket, :pending_groups, group, at: -1)}
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
  def handle_info({:group_member_kicked, {group, kicked_user_id}}, socket) do
    if kicked_user_id == socket.assigns.current_user.id do
      new_group_count = Groups.group_count_confirmed(socket.assigns.current_user)

      {:noreply,
       socket
       |> assign(:group_count, new_group_count)
       |> stream_delete(:groups, group)}
    else
      {:noreply, stream_insert(socket, :groups, group, at: -1)}
    end
  end

  @impl true
  def handle_info({:group_member_blocked, {group, blocked_user_id}}, socket) do
    if blocked_user_id == socket.assigns.current_user.id do
      new_group_count = Groups.group_count_confirmed(socket.assigns.current_user)

      {:noreply,
       socket
       |> assign(:group_count, new_group_count)
       |> stream_delete(:groups, group)}
    else
      {:noreply, stream_insert(socket, :groups, group, at: -1)}
    end
  end

  @impl true
  def handle_info({:group_member_unblocked, {group, blocked_user_id}}, socket) do
    if blocked_user_id == socket.assigns.current_user.id do
      current_user = socket.assigns.current_user
      per_page = socket.assigns.options.per_page
      search_term = socket.assigns.search_term
      all_groups = Groups.list_groups(current_user)
      initial_groups = Enum.take(all_groups, per_page)
      new_group_count = Groups.group_count_confirmed(current_user)
      public_groups = Groups.list_public_groups(current_user, search_term, limit: per_page)
      total_public_groups = Groups.public_group_count(current_user, search_term)

      {:noreply,
       socket
       |> assign(:group_count, new_group_count)
       |> assign(:loaded_groups_count, length(initial_groups))
       |> assign(:has_more_groups, length(initial_groups) < new_group_count)
       |> assign(:remaining_groups_count, max(0, new_group_count - length(initial_groups)))
       |> assign(:public_groups, public_groups)
       |> assign(:loaded_public_groups_count, length(public_groups))
       |> assign(:has_more_public_groups, length(public_groups) < total_public_groups)
       |> assign(
         :remaining_public_groups_count,
         max(0, total_public_groups - length(public_groups))
       )
       |> stream(:groups, initial_groups, reset: true)}
    else
      {:noreply, stream_insert(socket, :groups, group, at: -1)}
    end
  end

  @impl true
  def handle_info({:user_group_deleted, user_group}, socket) do
    if user_group.user_id == socket.assigns.current_user.id do
      case Groups.get_group(user_group.group_id) do
        nil ->
          {:noreply, socket}

        group ->
          new_group_count = Groups.group_count_confirmed(socket.assigns.current_user)
          pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
          pending_groups_count = length(pending_groups)

          {:noreply,
           socket
           |> assign(:group_count, new_group_count)
           |> assign(:pending_groups_count, pending_groups_count)
           |> assign(:any_pending_groups?, pending_groups_count > 0)
           |> stream_delete(:groups, group)
           |> stream_delete(:pending_groups, group)}
      end
    else
      case Groups.get_group(user_group.group_id) do
        nil ->
          {:noreply, socket}

        group ->
          current_user_group = get_user_group(group, socket.assigns.current_user)

          cond do
            is_nil(current_user_group) ->
              {:noreply, socket}

            is_nil(current_user_group.confirmed_at) ->
              {:noreply, stream_insert(socket, :pending_groups, group, at: -1)}

            true ->
              {:noreply, stream_insert(socket, :groups, group, at: -1)}
          end
      end
    end
  end

  @impl true
  def handle_info({:user_group_updated, user_group}, socket) do
    group = Groups.get_group!(user_group.group_id)
    {:noreply, stream_insert(socket, :groups, group, at: -1)}
  end

  @impl true
  def handle_info({:group_updated_members_removed, group}, socket) do
    new_group_count = Groups.group_count_confirmed(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:group_count, new_group_count)
     |> stream_delete(:groups, group)}
  end

  @impl true
  def handle_info({:group_updated_members_removed_unconfirmed, group}, socket) do
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
    pending_groups_count = length(pending_groups)

    {:noreply,
     socket
     |> assign(:pending_groups_count, pending_groups_count)
     |> assign(:any_pending_groups?, pending_groups_count > 0)
     |> stream_delete(:pending_groups, group)}
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
    pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
    pending_groups_count = length(pending_groups)

    {:noreply,
     socket
     |> assign(:pending_groups_count, pending_groups_count)
     |> assign(:any_pending_groups?, pending_groups_count > 0)
     |> stream_delete(:pending_groups, group)}
  end

  @impl true
  def handle_info({:group_member_kicked_unconfirmed, {group, kicked_user_id}}, socket) do
    if kicked_user_id == socket.assigns.current_user.id do
      pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
      pending_groups_count = length(pending_groups)

      {:noreply,
       socket
       |> assign(:pending_groups_count, pending_groups_count)
       |> assign(:any_pending_groups?, pending_groups_count > 0)
       |> stream_delete(:pending_groups, group)}
    else
      {:noreply, stream_insert(socket, :pending_groups, group, at: -1)}
    end
  end

  @impl true
  def handle_info({:group_member_blocked_unconfirmed, {group, blocked_user_id}}, socket) do
    if blocked_user_id == socket.assigns.current_user.id do
      pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
      pending_groups_count = length(pending_groups)

      {:noreply,
       socket
       |> assign(:pending_groups_count, pending_groups_count)
       |> assign(:any_pending_groups?, pending_groups_count > 0)
       |> stream_delete(:pending_groups, group)}
    else
      {:noreply, stream_insert(socket, :pending_groups, group, at: -1)}
    end
  end

  @impl true
  def handle_info({:group_member_unblocked_unconfirmed, {group, unblocked_user_id}}, socket) do
    if unblocked_user_id == socket.assigns.current_user.id do
      pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
      pending_groups_count = length(pending_groups)

      {:noreply,
       socket
       |> assign(:pending_groups_count, pending_groups_count)
       |> assign(:any_pending_groups?, pending_groups_count > 0)
       |> stream(:pending_groups, pending_groups, reset: true)}
    else
      {:noreply, stream_insert(socket, :pending_groups, group, at: -1)}
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
      pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
      pending_groups_count = length(pending_groups)

      socket
      |> assign(:pending_groups_count, pending_groups_count)
      |> assign(:any_pending_groups?, true)
    else
      pending_groups = Groups.list_unconfirmed_groups(socket.assigns.current_user)
      pending_groups_count = length(pending_groups)

      socket
      |> assign(:pending_groups_count, pending_groups_count)
      |> assign(:any_pending_groups?, pending_groups_count > 0)
    end
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id) do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :id

  defp valid_sort_order(%{"sort_order" => sort_order})
       when sort_order in ~w(asc desc) do
    String.to_existing_atom(sort_order)
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
