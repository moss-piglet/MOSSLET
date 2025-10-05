defmodule MossletWeb.UserConnectionLive.OldIndex do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Accounts.UserConnection
  alias Mosslet.Encrypted

  import MossletWeb.UserConnectionLive.Components

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
     |> assign(arrivals_greeter_open?: false)
     |> assign(:uconn_loading_count, 0)
     |> assign(:uconn_loading, false)
     |> assign(:uconn_loading_done, false)
     |> assign(:finished_loading_list, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    current_user = socket.assigns.current_user
    sort_by = valid_sort_by(params)
    sort_order = valid_sort_order(params)
    key = socket.assigns.key

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
        do: ~p"/app/users/connections/greet",
        else: ~p"/app/users/connections/greet?#{arrivals_options}"

    # Get connections and decrypt them in the LiveView
    raw_connections = Accounts.filter_user_connections(params, current_user)
    connections = decrypt_connections_for_display(raw_connections, current_user, key)
    connections_count = length(connections)

    socket =
      socket
      |> assign(arrivals_options: arrivals_options)
      |> assign(:any_pending_arrivals?, any_pending_arrivals?)
      |> assign(:arrivals_count, Accounts.arrivals_count(current_user))
      |> assign(:connections_count, connections_count)
      |> assign(:loading_list, arrivals_loading_list)
      |> assign(:return_url, url)
      |> stream(:arrivals, uconn_arrivals, reset: true)
      |> stream(:user_connections, connections, reset: true)

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
  def handle_info(_message, socket) do
    {:noreply, socket}
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
    |> assign(:arrivals_greeter_open?, false)
  end

  defp apply_action(socket, :greet, _params) do
    socket
    |> assign(:page_title, "Arrivals Greeter")
    |> assign(:arrivals_greeter_open?, true)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Your Connections")
    |> assign(:uconn, nil)
    |> assign(:arrivals_greeter_open?, false)
  end

  defp valid_sort_by(%{"sort_by" => sort_by})
       when sort_by in ~w(id inserted_at confirmed_at) do
    String.to_atom(sort_by)
  end

  defp valid_sort_by(_params), do: :inserted_at

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

  # Decrypt connection data in the LiveView following timeline pattern
  defp decrypt_connections_for_display(connections, current_user, key) do
    Enum.map(connections, fn connection ->
      # Decrypt connection fields and add them as virtual fields for display
      decrypted_data = %{
        display_name: decr_uconn(connection.connection.name, current_user, connection.key, key),
        display_username:
          decr_uconn(connection.connection.username, current_user, connection.key, key),
        display_email: decr_uconn(connection.connection.email, current_user, connection.key, key),
        display_label: decr_uconn(connection.label, current_user, connection.key, key),
        display_status_message: get_decrypted_status_message(connection, current_user, key),
        display_avatar_url: maybe_get_avatar_src(connection, current_user, key, [])
      }

      # Add decrypted data to the connection struct for template use
      Map.merge(connection, decrypted_data)
    end)
  end

  # Helper to safely decrypt status messages
  defp get_decrypted_status_message(user_connection, current_user, key) do
    try do
      case user_connection.connection.status_message do
        nil ->
          "Available and connected 🌿"

        "" ->
          "Available and connected 🌿"

        encrypted_message when is_binary(encrypted_message) ->
          decrypted = decr_uconn(encrypted_message, current_user, user_connection.key, key)
          if String.trim(decrypted) == "", do: "Available and connected 🌿", else: decrypted

        _ ->
          "Available and connected 🌿"
      end
    rescue
      _ -> "Available and connected 🌿"
    end
  end

  # Helper to format connection date
  defp format_connection_date(%NaiveDateTime{} = date) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), date, :day)

    cond do
      diff < 1 -> "today"
      diff < 7 -> "#{diff}d ago"
      diff < 30 -> "#{div(diff, 7)}w ago"
      diff < 365 -> "#{div(diff, 30)}mo ago"
      true -> "#{div(diff, 365)}y ago"
    end
  end

  defp format_connection_date(_), do: "recently"
end
