defmodule MossletWeb.UserConnectionLive.Index do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserConnection
  alias Mosslet.Encrypted

  @page_default 1
  @per_page_default 8

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Accounts.private_subscribe(user)
      Accounts.subscribe_account_deleted()
    end

    {:ok,
     socket
     |> assign(return_to: ~p"/app/users/connections")
     |> assign(active_tab: "connections")
     |> assign(:uconn_loading_count, 0)
     |> assign(:uconn_loading, false)
     |> assign(:uconn_loading_done, false)
     |> assign(:finished_loading_list, [])
     |> assign(:show_visibility_group_modal, false)
     |> assign(:editing_group, nil)
     |> assign(:show_block_modal, false)
     |> assign(:blocked_user_id, nil)
     |> assign(:blocked_user_name, nil)
     |> assign(:blocked_connection_id, nil)
     |> assign(:show_edit_connection_modal, false)
     |> assign(:editing_connection, nil)
     |> assign(:edit_connection_form, to_form(%{"label" => ""}))
     |> assign(:show_new_connection_form, false)
     |> assign(:new_connection_selector, nil)
     |> assign(:recipient_id, nil)
     |> assign(:request_email, nil)
     |> assign(:request_username, nil)
     |> assign(:recipient_key, nil)
     |> assign(:temp_label, nil)
     |> assign(
       :new_connection_form,
       to_form(Accounts.change_user_connection(%Accounts.UserConnection{}))
     )
     |> stream_configure(:visibility_groups,
       dom_id: fn %{group: group} -> "visibility-group-#{group.id}" end
     )
     |> stream(:visibility_groups, [])
     |> stream_configure(:user_connections,
       dom_id: fn connection -> "user-connection-#{connection.id}" end
     )
     |> stream(:user_connections, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)

    # Search functionality
    search_query = params["search"]

    # Arrivals pagination
    arrivals_page = param_to_integer(params["page"], @page_default)

    arrivals_per_page =
      param_to_integer(params["per_page"], @per_page_default) |> limit_per_page()

    arrivals_options = %{
      sort_by: sort_by,
      sort_order: sort_order,
      page: arrivals_page,
      per_page: arrivals_per_page
    }

    uconn_arrivals = Accounts.list_user_arrivals_connections(current_user, arrivals_options)
    any_pending_arrivals? = !Enum.empty?(uconn_arrivals)

    arrivals_loading_list =
      Enum.with_index(uconn_arrivals, fn element, index -> {index, element} end)

    url =
      if arrivals_options.page == @page_default && arrivals_options.per_page == @per_page_default,
        do: ~p"/app/users/connections",
        else: ~p"/app/users/connections?#{arrivals_options}"

    # Get connections with search
    connections =
      if search_query && String.trim(search_query) != "" do
        Accounts.search_user_connections(current_user, search_query)
      else
        Accounts.filter_user_connections(params, current_user)
      end

    connections_count = length(connections)

    # Load visibility groups for streaming
    visibility_groups = Accounts.get_user_visibility_groups_with_connections(current_user)

    socket =
      socket
      |> assign(arrivals_options: arrivals_options)
      |> assign(:any_pending_arrivals?, any_pending_arrivals?)
      |> assign(:arrivals_count, Accounts.arrivals_count(current_user))
      |> assign(:connections_count, connections_count)
      |> assign(:modal_connections, connections)
      |> assign(:loading_list, arrivals_loading_list)
      |> assign(:return_url, url)
      |> assign(:search_query, search_query)
      |> stream(:arrivals, uconn_arrivals, reset: true)
      |> stream(:user_connections, connections, reset: true)
      |> stream(:visibility_groups, visibility_groups, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({MossletWeb.UserConnectionLive.FormComponent, {:saved, uconn}}, socket) do
    cond do
      (uconn.user_id == socket.assigns.current_user.id ||
         uconn.reverse_user_id == socket.assigns.current_user.id) && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.UserConnectionLive.FormComponent, {:updated, uconn}}, socket) do
    cond do
      (uconn.user_id == socket.assigns.current_user.id ||
         uconn.reverse_user_id == socket.assigns.current_user.id) && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply,
         stream_insert(socket, :arrivals, uconn)
         |> push_patch(to: ~p"/app/users/connections/greet")}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MossletWeb.UserConnectionLive.Index, {:deleted, uconn}}, socket) do
    cond do
      (uconn.user_id == socket.assigns.current_user.id ||
         uconn.reverse_user_id == socket.assigns.current_user.id) && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply,
         socket |> stream_delete(:arrivals, uconn) |> push_patch(to: socket.assigns.return_url)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {MossletWeb.UserConnectionLive.Index, {:uconn_confirmed, upd_uconn}},
        socket
      ) do
    cond do
      (upd_uconn.user_id == socket.assigns.current_user.id ||
         upd_uconn.reverse_user_id == socket.assigns.current_user.id) && upd_uconn.confirmed_at ->
        {:noreply,
         socket
         |> stream_delete(:arrivals, upd_uconn)
         |> push_patch(to: socket.assigns.return_to)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    cond do
      (uconn.user_id == socket.assigns.current_user.id ||
         uconn.reverse_user_id == socket.assigns.current_user.id) && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_deleted, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_delete(socket, :arrivals, uconn)}

      uconn.reverse_user_id == socket.assigns.current_user.id ->
        {:noreply, stream_delete(socket, :arrivals, uconn)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_created, uconn}, socket) do
    current_user = socket.assigns.current_user

    cond do
      uconn.user_id == current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == current_user.id ->
        # Update both stream and count for real-time updates
        updated_count = Accounts.arrivals_count(current_user)

        {:noreply,
         socket
         |> stream_insert(:arrivals, uconn, at: 0)
         |> assign(:arrivals_count, updated_count)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_confirmed, uconn}, socket) do
    current_user = socket.assigns.current_user

    cond do
      uconn.user_id == current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_email_updated, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_username_updated, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_name_updated, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    cond do
      uconn.user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.reverse_user_id == socket.assigns.current_user.id && uconn.confirmed_at ->
        {:noreply,
         socket
         |> push_patch(to: socket.assigns.return_to)}

      uconn.user_id == socket.assigns.current_user.id ->
        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1)}

      true ->
        {:noreply, socket}
    end
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
  def handle_info({_ref, {"get_user_avatar", uconn_id, uconn_list, _user_id}}, socket) do
    uconn_loading_count = socket.assigns.uconn_loading_count
    finished_loading_list = socket.assigns.finished_loading_list

    cond do
      uconn_loading_count < Enum.count(uconn_list) - 1 ->
        socket =
          socket
          |> assign(:uconn_loading, true)
          |> assign(:uconn_loading_count, uconn_loading_count + 1)
          |> assign(:finished_loading_list, [uconn_id | finished_loading_list] |> Enum.uniq())

        uconn = Accounts.get_user_connection!(uconn_id)

        {:noreply, stream_insert(socket, :arrivals, uconn, at: -1, reset: true)}

      uconn_loading_count == Enum.count(uconn_list) - 1 ->
        finished_loading_list = [uconn_id | finished_loading_list] |> Enum.uniq()

        socket =
          socket
          |> assign(:uconn_loading, false)
          |> assign(:finished_loading_list, [uconn_id | finished_loading_list] |> Enum.uniq())

        if Enum.count(finished_loading_list) == Enum.count(uconn_list) do
          uconn = Accounts.get_user_connection!(uconn_id)

          socket =
            socket
            |> assign(:uconn_loading_count, 0)
            |> assign(:uconn_loading, false)
            |> assign(:uconn_loading_done, true)
            |> assign(:finished_loading_list, [])

          {:noreply, stream_insert(socket, :arrivals, uconn, at: -1, reset: true)}
        else
          {:noreply, socket}
        end

      true ->
        socket =
          socket
          |> assign(:uconn_loading, true)
          |> assign(:finished_loading_list, [uconn_id | finished_loading_list] |> Enum.uniq())

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:close_block_modal}, socket) do
    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:blocked_user_id, nil)
     |> assign(:blocked_user_name, nil)
     |> assign(:blocked_connection_id, nil)
     |> assign(:show_edit_connection_modal, false)
     |> assign(:editing_connection, nil)
     |> assign(:edit_connection_form, to_form(%{"label" => ""}))}
  end

  @impl true
  def handle_info({:submit_block, block_params}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    blocked_user_id = socket.assigns.blocked_user_id
    blocked_connection_id = socket.assigns.blocked_connection_id

    # Get the user struct from the ID
    blocked_user = Accounts.get_user!(blocked_user_id)

    case Accounts.block_user(current_user, blocked_user, block_params,
           user: current_user,
           key: key
         ) do
      {:ok, _user_block} ->
        # Remove the connection from the stream if it exists
        socket =
          if blocked_connection_id do
            connection = Accounts.get_user_connection!(blocked_connection_id)
            socket |> stream_delete(:user_connections, connection)
          else
            socket
          end

        {:noreply,
         socket
         |> assign(:show_block_modal, false)
         |> assign(:blocked_user_id, nil)
         |> assign(:blocked_user_name, nil)
         |> assign(:blocked_connection_id, nil)
         |> put_flash(:success, "User has been blocked")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to block user")}
    end
  end

  @impl true
  def handle_info({:connection_updated}, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_connection_modal, false)
     |> assign(:editing_connection, nil)
     |> put_flash(:success, "Label updated!")}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_connections", %{"search_query" => search_query}, socket) do
    # Update the URL with search parameters to maintain state
    search_params = if String.trim(search_query) == "", do: %{}, else: %{"search" => search_query}
    {:noreply, push_patch(socket, to: ~p"/app/users/connections?#{search_params}")}
  end

  @impl true
  def handle_event("edit_connection", %{"id" => connection_id}, socket) do
    case Accounts.get_user_connection!(connection_id) do
      connection ->
        current_user = socket.assigns.current_user
        key = socket.assigns.key

        # Get the decrypted label for the form
        current_label =
          get_decrypted_connection_label(
            connection,
            socket.assigns.current_user,
            socket.assigns.key
          )

        # Create form with the current label and color - using params format that matches the form structure
        attrs = %{
          "temp_label" => current_label,
          "color" => connection.color
        }

        changeset =
          Accounts.change_user_connection_label(connection, attrs, user: current_user, key: key)

        form = to_form(changeset)

        {:noreply,
         socket
         |> assign(:temp_label, current_label)
         |> assign(:show_edit_connection_modal, true)
         |> assign(:editing_connection, connection)
         |> assign(:edit_connection_form, form)}
    end
  end

  @impl true
  def handle_event("toggle_mute", %{"id" => connection_id}, socket) do
    case Accounts.get_user_connection!(connection_id) do
      connection ->
        # Toggle the zen? field
        new_zen_value = !connection.zen?

        case Accounts.update_user_connection_zen(connection, %{zen?: new_zen_value}, []) do
          {:ok, updated_connection} ->
            # Update the stream
            info = if(new_zen_value, do: "User muted", else: "User unmuted")

            {:noreply,
             socket
             |> stream_insert(:user_connections, updated_connection)
             |> put_flash(:success, info)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update mute status")}
        end
    end
  end

  @impl true
  def handle_event("toggle_photos", %{"id" => connection_id}, socket) do
    case Accounts.get_user_connection!(connection_id) do
      connection ->
        # Toggle the photos? field
        new_photos_value = !connection.photos?

        case Accounts.update_user_connection_photos(connection, %{photos?: new_photos_value}, []) do
          {:ok, updated_connection} ->
            # Update the stream
            {:noreply,
             socket
             |> stream_insert(:user_connections, updated_connection)
             |> put_flash(
               :success,
               if(new_photos_value,
                 do: "Photo downloads enabled",
                 else: "Photo downloads disabled"
               )
             )}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update photo settings")}
        end
    end
  end

  @impl true
  def handle_event("block_user", %{"id" => connection_id, "name" => name}, socket) do
    case Accounts.get_user_connection!(connection_id) do
      connection ->
        # Get the user to block (the other user in the connection)
        blocked_user_id =
          if connection.user_id == socket.assigns.current_user.id,
            do: connection.reverse_user_id,
            else: connection.user_id

        blocked_user = Accounts.get_user!(blocked_user_id)

        # Show the block modal instead of immediately blocking
        {:noreply,
         socket
         |> assign(:show_block_modal, true)
         |> assign(:blocked_user_id, blocked_user.id)
         |> assign(:blocked_user_name, name)
         |> assign(:blocked_connection_id, connection_id)}
    end
  end

  @impl true
  def handle_event("toggle_new_connection_form", _params, socket) do
    show_form = !socket.assigns.show_new_connection_form

    socket =
      if show_form do
        # Initialize the form with proper changeset when showing the form
        changeset = Accounts.change_user_connection(%Accounts.UserConnection{})

        socket
        |> assign(:show_new_connection_form, true)
        |> assign(:new_connection_form, to_form(changeset))
        |> assign(:new_connection_selector, nil)
        |> assign(:recipient_id, nil)
        |> assign(:request_email, nil)
        |> assign(:request_username, nil)
        |> assign(:recipient_key, nil)
      else
        # Reset the form when hiding it
        changeset = Accounts.change_user_connection(%Accounts.UserConnection{})

        socket
        |> assign(:show_new_connection_form, false)
        |> assign(:new_connection_form, to_form(changeset))
        |> assign(:new_connection_selector, nil)
        |> assign(:recipient_id, nil)
        |> assign(:request_email, nil)
        |> assign(:request_username, nil)
        |> assign(:recipient_key, nil)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_new_connection", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key
    selector = uconn_params["selector"] || socket.assigns.new_connection_selector

    changeset =
      %Accounts.UserConnection{}
      |> Accounts.change_user_connection(uconn_params,
        selector: selector,
        user: user,
        key: key
      )
      |> Map.put(:action, :validate)

    # Check if the changeset has the necessary fields populated (like when a valid user is found)
    socket =
      if Map.has_key?(changeset.changes, :reverse_user_id) do
        # reverse_user_id contains the recipient (person we found)
        # user_id contains the current user
        socket
        |> assign(:request_username, changeset.changes.request_username)
        |> assign(:recipient_key, changeset.changes.key)
        |> assign(:recipient_id, changeset.changes.user_id)
        |> assign(:temp_label, Ecto.Changeset.get_change(changeset, :temp_label))
        |> assign(:selector, selector)
      else
        socket
        |> assign(:recipient_id, nil)
        |> assign(:request_email, nil)
        |> assign(:request_username, nil)
        |> assign(:recipient_key, nil)
      end

    {:noreply,
     socket
     |> assign(:new_connection_form, to_form(changeset))
     |> assign(:new_connection_selector, uconn_params["selector"])}
  end

  @impl true
  def handle_event("save_new_connection", %{"user_connection" => uconn_params}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key
    selector = uconn_params["selector"] || socket.assigns.new_connection_selector

    case Accounts.create_user_connection(uconn_params, user: user, key: key, selector: selector) do
      {:ok, _uconn} ->
        {:noreply,
         socket
         |> assign(:show_new_connection_form, false)
         |> assign(
           :new_connection_form,
           to_form(Accounts.change_user_connection(%Accounts.UserConnection{}))
         )
         |> put_flash(:success, "Connection request sent successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :new_connection_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("show_new_connection_modal", _params, socket) do
    {:noreply, assign(socket, :show_new_connection_form, true)}
  end

  @impl true
  def handle_event("close_new_connection_modal", _params, socket) do
    IO.puts("CLOSE NEW CONNECTION MODAL HANDLE EVENT")

    socket =
      socket
      |> assign(:show_new_connection_form, false)
      |> assign(:new_connection_selector, nil)
      |> assign(
        :new_connection_form,
        to_form(Accounts.change_user_connection(%Accounts.UserConnection{}))
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_connection", %{"id" => connection_id}, socket) do
    # Use the existing delete functionality
    handle_event("delete", %{"id" => connection_id}, socket)
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(active_tab: tab)

    # Reload appropriate data streams when switching tabs
    socket =
      case tab do
        "requests" ->
          # When switching to requests tab, ensure arrivals are properly loaded
          arrivals_options = socket.assigns.arrivals_options || %{}
          uconn_arrivals = Accounts.list_user_arrivals_connections(current_user, arrivals_options)

          socket
          |> stream(:arrivals, uconn_arrivals, reset: true)
          |> assign(:arrivals_count, Accounts.arrivals_count(current_user))

        "connections" ->
          # When switching to connections tab, ensure connections are properly loaded
          search_query = socket.assigns.search_query

          connections =
            if search_query && String.trim(search_query) != "" do
              Accounts.search_user_connections(current_user, search_query)
            else
              Accounts.filter_user_connections(%{}, current_user)
            end

          socket
          |> stream(:user_connections, connections, reset: true)
          |> assign(:connections_count, length(connections))

        _ ->
          # For any other tabs, just update the active tab
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_visibility_group", _params, socket) do
    # Show the modal for creating a new visibility group
    {:noreply, assign(socket, :show_visibility_group_modal, true)}
  end

  @impl true
  def handle_event("edit_visibility_group", %{"group-id" => group_id}, socket) do
    # Set the editing state and show modal with pre-filled data
    current_user = socket.assigns.current_user

    # Find the group being edited
    visibility_groups = Accounts.get_user_visibility_groups_with_connections(current_user)
    editing_group = Enum.find(visibility_groups, fn %{group: group} -> group.id == group_id end)

    {:noreply,
     socket
     |> assign(:show_visibility_group_modal, true)
     |> assign(:editing_group, editing_group)}
  end

  @impl true
  def handle_event("delete_visibility_group", params, socket) do
    group_id = params["group-id"] || params["value"]["group-id"]
    current_user = socket.assigns.current_user

    case Accounts.delete_visibility_group(current_user, group_id) do
      {:ok, _updated_user} ->
        # Find the group to delete from the stream
        # We need to create a fake group object with the ID for stream_delete
        group_to_delete = %{group: %{id: group_id}, user: current_user, user_connections: []}

        {:noreply,
         socket
         |> stream_delete(:visibility_groups, group_to_delete)
         |> put_flash(:success, "Visibility group deleted successfully!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete visibility group")}
    end
  end

  @impl true
  def handle_event("close_visibility_group_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_visibility_group_modal, false)
     |> assign(:editing_group, nil)
     |> assign(:show_block_modal, false)
     |> assign(:blocked_user_id, nil)
     |> assign(:blocked_user_name, nil)
     |> assign(:blocked_connection_id, nil)
     |> assign(:show_edit_connection_modal, false)
     |> assign(:editing_connection, nil)
     |> assign(:edit_connection_form, to_form(%{"label" => ""}))
     |> assign(:show_new_connection_form, false)
     |> assign(:new_connection_selector, nil)
     |> assign(:recipient_id, nil)
     |> assign(:request_email, nil)
     |> assign(:request_username, nil)
     |> assign(:recipient_key, nil)
     |> assign(
       :new_connection_form,
       to_form(Accounts.change_user_connection(%Accounts.UserConnection{}))
     )}
  end

  @impl true
  def handle_event("save_edit_connection", %{"connection" => connection_params}, socket) do
    editing_connection = socket.assigns.editing_connection
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Prepare the attributes for update using temp_label (virtual field) and color
    attrs = %{
      "temp_label" => connection_params["label"],
      "color" => String.to_existing_atom(connection_params["color"])
    }

    case Accounts.update_user_connection_label(editing_connection, attrs,
           user: current_user,
           key: key
         ) do
      {:ok, updated_connection} ->
        send(self(), {:connection_updated})

        {:noreply,
         socket
         |> assign(
           :edit_connection_form,
           to_form(%{})
         )
         |> assign(:show_edit_connection_modal, false)
         |> assign(:editing_connection, nil)
         |> stream_insert(:user_connections, updated_connection)
         |> push_event("restore-body-scroll", %{})}

      {:error, %Ecto.Changeset{} = _changeset} ->
        # Create a form from the changeset errors
        error_form =
          to_form(%{
            "label" => connection_params["label"]
          })

        {:noreply,
         socket
         |> assign(:edit_connection_form, error_form)
         |> put_flash(:error, "Failed to update connection")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update connection")}
    end
  end

  @impl true
  def handle_event("close_edit_connection_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_connection_modal, false)
     |> assign(:editing_connection, nil)
     |> assign(:edit_connection_form, to_form(%{"label" => ""}))}
  end

  @impl true
  def handle_event("close_block_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_block_modal, false)
      |> assign(:block_user_id, nil)
      |> assign(:block_user_name, nil)
      |> assign(:blocked_connection_id, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_visibility_group", %{"visibility_group" => group_params}, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    editing_group = socket.assigns[:editing_group]

    # Extract connection_ids from the form (they come as a list when using checkboxes)
    connection_ids =
      case group_params["connection_ids"] do
        list when is_list(list) -> list
        single when is_binary(single) -> [single]
        _ -> []
      end

    # Add connection_ids to the group_params
    updated_group_params = Map.put(group_params, "connection_ids", connection_ids)

    # Determine if we're creating or updating based on editing_group
    result =
      if editing_group do
        # Update existing group
        Accounts.update_visibility_group(
          current_user,
          editing_group.group.id,
          updated_group_params,
          user: current_user,
          key: key
        )
      else
        # Create new group
        Accounts.create_visibility_group(
          current_user,
          updated_group_params,
          user: current_user,
          key: key
        )
      end

    case result do
      {:ok, _updated_user} ->
        # Extract visibility groups from the updated user
        visibility_groups = Accounts.get_user_visibility_groups_with_connections(current_user)

        action = if editing_group, do: "updated", else: "created"

        {:noreply,
         socket
         |> assign(:show_visibility_group_modal, false)
         |> assign(:editing_group, nil)
         |> stream(:visibility_groups, visibility_groups, reset: true)
         |> put_flash(:success, "Visibility group #{action} successfully!")}

      {:error, changeset} ->
        # Handle validation errors
        error_message =
          if is_struct(changeset, Ecto.Changeset) do
            changeset.errors
            |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
            |> Enum.join(", ")
          else
            "Unknown error occurred"
          end

        action = if editing_group, do: "updating", else: "creating"

        {:noreply,
         put_flash(socket, :error, "Error #{action} visibility group: #{error_message}")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    uconn = Accounts.get_user_connection!(id)

    if uconn.user_id == socket.assigns.current_user.id do
      case Accounts.delete_both_user_connections(uconn) do
        {:ok, _uconns} ->
          {:noreply, socket}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("accept_uconn", %{"id" => id}, socket) do
    uconn = Accounts.get_user_connection!(id)
    user = socket.assigns.current_user

    if uconn.user_id == user.id do
      key = socket.assigns.key
      attrs = build_accepting_uconn_attrs(uconn, user, key)

      case Accounts.confirm_user_connection(uconn, attrs, user: user, key: key, confirm: true) do
        {:ok, upd_uconn, _ins_uconn} ->
          notify_self({:uconn_confirmed, upd_uconn})

          {:noreply,
           socket
           |> put_flash(:success, "Connection accepted successfully.")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, changeset.msg)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("decline_uconn", %{"id" => id}, socket) do
    uconn = Accounts.get_user_connection!(id)

    if uconn.user_id == socket.assigns.current_user.id do
      case Accounts.delete_user_connection(uconn) do
        {:ok, uconn} ->
          notify_self({:deleted, uconn})
          {:noreply, push_patch(socket, to: socket.assigns.return_to)}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "#{changeset.message}")}
      end
    else
      {:noreply, socket}
    end
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Connection")
    |> assign(:uconn, %UserConnection{})
    |> assign(:active_tab, "connections")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Your Connections")
    |> assign(:uconn, nil)
    |> assign(:active_tab, "connections")
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id inserted_at confirmed_at) do
    String.to_existing_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

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

  defp build_accepting_uconn_attrs(uconn, user, key) do
    d_req_email =
      Encrypted.Users.Utils.decrypt_user_item(uconn.request_email, user, uconn.key, key)

    d_req_username =
      Encrypted.Users.Utils.decrypt_user_item(uconn.request_username, user, uconn.key, key)

    d_label = Encrypted.Users.Utils.decrypt_user_item(uconn.label, user, uconn.key, key)
    # TODO
    # reverse_user_id is the requesting user when accepting
    # req_user = Accounts.get_user_by_email(d_req_email)

    %{
      connection_id: user.connection.id,
      user_id: uconn.reverse_user_id,
      reverse_user_id: user.id,
      email: d_req_email,
      username: d_req_username,
      temp_label: d_label,
      request_username: d_req_username,
      request_email: d_req_email,
      color: uconn.color
    }
  end

  defp notify_self(msg), do: send(self(), {__MODULE__, msg})

  # Helper functions for decrypting connection data (using pattern matching)
  defp get_decrypted_connection_name(connection, current_user, key) do
    case decr_uconn(connection.connection.name, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  defp get_decrypted_connection_username(connection, current_user, key) do
    case decr_uconn(connection.connection.username, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[encrypted]"
    end
  end

  defp get_decrypted_connection_label(connection, current_user, key) do
    case decr_uconn(connection.label, current_user, connection.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  defp get_connection_avatar_src(connection, current_user, key) do
    if !show_avatar?(connection) do
      "/images/logo.svg"
    else
      case maybe_get_avatar_src(connection, current_user, key, []) do
        "" -> "/images/logo.svg"
        nil -> "/images/logo.svg"
        result when is_binary(result) -> result
      end
    end
  end

  defp get_decrypted_arrival_name(arrival, current_user, key) do
    case decr_uconn(arrival.request_username, current_user, arrival.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  defp get_decrypted_arrival_email(arrival, current_user, key) do
    case decr_uconn(arrival.request_email, current_user, arrival.key, key) do
      result when is_binary(result) -> result
      _ -> "[encrypted@example.com]"
    end
  end

  defp get_decrypted_arrival_label(arrival, current_user, key) do
    case decr_uconn(arrival.label, current_user, arrival.key, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted]"
    end
  end

  defp get_arrival_avatar_src(arrival, current_user, key) do
    if !show_avatar?(arrival) do
      "/images/logo.svg"
    else
      case maybe_get_avatar_src(arrival, current_user, key, []) do
        "" -> "/images/logo.svg"
        nil -> "/images/logo.svg"
        result when is_binary(result) -> result
      end
    end
  end

  # Helper functions for visibility groups with liquid metal design consistency

  # Card background and border classes following the liquid metal aesthetic
  defp get_group_card_classes(color) do
    base_classes = "bg-white/95 dark:bg-slate-800/95"

    case color do
      :teal ->
        "#{base_classes} border-teal-200/40 dark:border-teal-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-teal-300/60 dark:hover:border-teal-600/60 hover:shadow-teal-500/10"

      :emerald ->
        "#{base_classes} border-emerald-200/40 dark:border-emerald-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-emerald-300/60 dark:hover:border-emerald-600/60 hover:shadow-emerald-500/10"

      :cyan ->
        "#{base_classes} border-cyan-200/40 dark:border-cyan-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-cyan-300/60 dark:hover:border-cyan-600/60 hover:shadow-cyan-500/10"

      :purple ->
        "#{base_classes} border-purple-200/40 dark:border-purple-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-purple-300/60 dark:hover:border-purple-600/60 hover:shadow-purple-500/10"

      :rose ->
        "#{base_classes} border-rose-200/40 dark:border-rose-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-rose-300/60 dark:hover:border-rose-600/60 hover:shadow-rose-500/10"

      :amber ->
        "#{base_classes} border-amber-200/40 dark:border-amber-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-amber-300/60 dark:hover:border-amber-600/60 hover:shadow-amber-500/10"

      :orange ->
        "#{base_classes} border-orange-200/40 dark:border-orange-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-orange-300/60 dark:hover:border-orange-600/60 hover:shadow-orange-500/10"

      :indigo ->
        "#{base_classes} border-indigo-200/40 dark:border-indigo-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-indigo-300/60 dark:hover:border-indigo-600/60 hover:shadow-indigo-500/10"

      _ ->
        "#{base_classes} border-slate-200/40 dark:border-slate-700/40 hover:bg-white/98 dark:hover:bg-slate-800/98 hover:border-slate-300/60 dark:hover:border-slate-600/60 hover:shadow-slate-500/10"
    end
  end

  # Color indicator with gradient and ring following liquid metal patterns
  defp get_group_color_indicator_classes(color) do
    case color do
      :teal ->
        "bg-gradient-to-br from-teal-400 to-teal-500 ring-2 ring-teal-500/20"

      :emerald ->
        "bg-gradient-to-br from-emerald-400 to-emerald-500 ring-2 ring-emerald-500/20"

      :cyan ->
        "bg-gradient-to-br from-cyan-400 to-cyan-500 ring-2 ring-cyan-500/20"

      :purple ->
        "bg-gradient-to-br from-purple-400 to-purple-500 ring-2 ring-purple-500/20"

      :rose ->
        "bg-gradient-to-br from-rose-400 to-rose-500 ring-2 ring-rose-500/20"

      :amber ->
        "bg-gradient-to-br from-amber-400 to-amber-500 ring-2 ring-amber-500/20"

      :orange ->
        "bg-gradient-to-br from-orange-400 to-orange-500 ring-2 ring-orange-500/20"

      :indigo ->
        "bg-gradient-to-br from-indigo-400 to-indigo-500 ring-2 ring-indigo-500/20"

      _ ->
        "bg-gradient-to-br from-slate-400 to-slate-500 ring-2 ring-slate-500/20"
    end
  end

  # Badge classes with subtle background and matching text colors
  defp get_group_badge_classes(color) do
    case color do
      :teal ->
        "bg-teal-100/80 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300"

      :emerald ->
        "bg-emerald-100/80 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300"

      :cyan ->
        "bg-cyan-100/80 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300"

      :purple ->
        "bg-purple-100/80 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300"

      :rose ->
        "bg-rose-100/80 dark:bg-rose-900/30 text-rose-700 dark:text-rose-300"

      :amber ->
        "bg-amber-100/80 dark:bg-amber-900/30 text-amber-700 dark:text-amber-300"

      :orange ->
        "bg-orange-100/80 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300"

      :indigo ->
        "bg-indigo-100/80 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300"

      _ ->
        "bg-slate-100/80 dark:bg-slate-900/30 text-slate-700 dark:text-slate-300"
    end
  end

  # Edit button classes with color-coordinated hover states
  defp get_group_edit_button_classes(color) do
    base_classes = "text-slate-400 dark:text-slate-500"

    case color do
      :teal ->
        "#{base_classes} hover:text-teal-600 hover:bg-teal-50 dark:hover:text-teal-400 dark:hover:bg-teal-900/20"

      :emerald ->
        "#{base_classes} hover:text-emerald-600 hover:bg-emerald-50 dark:hover:text-emerald-400 dark:hover:bg-emerald-900/20"

      :cyan ->
        "#{base_classes} hover:text-cyan-600 hover:bg-cyan-50 dark:hover:text-cyan-400 dark:hover:bg-cyan-900/20"

      :purple ->
        "#{base_classes} hover:text-purple-600 hover:bg-purple-50 dark:hover:text-purple-400 dark:hover:bg-purple-900/20"

      :rose ->
        "#{base_classes} hover:text-rose-600 hover:bg-rose-50 dark:hover:text-rose-400 dark:hover:bg-rose-900/20"

      :amber ->
        "#{base_classes} hover:text-amber-600 hover:bg-amber-50 dark:hover:text-amber-400 dark:hover:bg-amber-900/20"

      :orange ->
        "#{base_classes} hover:text-orange-600 hover:bg-orange-50 dark:hover:text-orange-400 dark:hover:bg-orange-900/20"

      :indigo ->
        "#{base_classes} hover:text-indigo-600 hover:bg-indigo-50 dark:hover:text-indigo-400 dark:hover:bg-indigo-900/20"

      _ ->
        "#{base_classes} hover:text-slate-600 hover:bg-slate-50 dark:hover:text-slate-400 dark:hover:bg-slate-900/20"
    end
  end

  defp get_decrypted_group_name(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.name, current_user, key) do
      result when is_binary(result) -> result
      _ -> "[Encrypted Group]"
    end
  end

  defp get_decrypted_group_description(group_data, current_user, key) do
    group =
      case group_data do
        %{group: g} -> g
        g -> g
      end

    case decr(group.description, current_user, key) do
      result when is_binary(result) -> result
      _ -> ""
    end
  end

  # Helper function to check if a connection is in a visibility group
  defp connection_in_group?(connection, editing_group, current_user, key) do
    case editing_group do
      nil ->
        false

      %{group: %{connection_ids: []}} ->
        false

      %{group: %{connection_ids: nil}} ->
        false

      %{group: %{connection_ids: connection_ids}} when is_list(connection_ids) ->
        # Each connection ID in the list is individually encrypted
        # We need to decrypt each one and compare with the current connection ID
        Enum.any?(connection_ids, fn encrypted_connection_id ->
          case Mosslet.Encrypted.Users.Utils.decrypt_user_item(
                 encrypted_connection_id,
                 current_user,
                 current_user.user_key,
                 key
               ) do
            decrypted_id when is_binary(decrypted_id) ->
              decrypted_id == connection.id

            _ ->
              false
          end
        end)

      _ ->
        false
    end
  end

  # Helper function to check if current user has been blocked by the connection owner
  # This is used to hide Profile/Message buttons for privacy (asymmetric blocking)
  defp blocked_by_connection?(connection, current_user) do
    # The connection owner is the reverse_user_id (the person we're connected to)
    # Check if that person has blocked us (current_user)
    reverse_user_id = connection.reverse_user_id
    reverse_user = Accounts.get_user!(reverse_user_id)

    case Accounts.get_user_block(reverse_user, current_user.id) do
      %Accounts.UserBlock{block_type: :full} -> true
      # Hide interactions for posts_only too
      %Accounts.UserBlock{block_type: :posts_only} -> true
      _ -> false
    end
  end
end
