defmodule MossletWeb.GroupLive.FormComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts
  alias Mosslet.Groups

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex overflow-y-auto mx-auto w-xs sm:w-sm md:w-md">
      <div class="grow">
        <div class="pb-4">
          <.h2>
            {@title}
          </.h2>
          <.p :if={@action in [:new]}>
            Use this form to create a new group.
          </.p>
          <.p :if={@action in [:edit]}>
            Use this form to edit the group. You can add or remove members and update the name or description.
          </.p>
        </div>
        <.form
          for={@form}
          id="group-form"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
        >
          <.field
            :if={@action in [:new]}
            phx-debounce="500"
            field={@form[:name]}
            type="text"
            label="Name"
          />
          <.field
            :if={@action in [:new]}
            phx-debounce="500"
            field={@form[:description]}
            type="text"
            label="Description"
          />
          <.field
            :if={@action in [:new]}
            field={@form[:public?]}
            type="checkbox"
            phx-debounce="500"
            label="Make group public?"
          />
          <.field
            :if={@action in [:new]}
            field={@form[:require_password?]}
            type="checkbox"
            phx-debounce="500"
            label="Require password?"
          />
          <.field
            :if={@action in [:new] && @require_password? == "true"}
            field={@form[:password]}
            type="text"
            label="Password"
            phx-debounce="500"
          />
          <.field
            :if={@action in [:edit]}
            field={@form[:name]}
            value={
              decr_item(
                @group_name,
                @current_user,
                get_user_group(@group, @current_user).key,
                @key,
                @group
              )
            }
            type="text"
            phx-debounce="500"
            label="Name"
          />
          <.field
            :if={@action in [:edit]}
            field={@form[:description]}
            value={
              decr_item(
                @group_description,
                @current_user,
                get_user_group(@group, @current_user).key,
                @key,
                @group
              )
            }
            type="text"
            phx-debounce="500"
            label="Description"
          />
          <.field field={@form[:user_id]} type="hidden" value={@current_user.id} />
          <.field
            field={@form[:user_name]}
            type="hidden"
            value={decr(@current_user.name, @current_user, @key)}
          />

          <.live_select
            :if={@action in [:new]}
            id="groups-user-select"
            field={@form[:user_connections]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-default"
            label="Add people to group"
            options={@user_connections}
            placeholder="Click or start typing to select people..."
            clear_button_class="pl-1 text-red-600 hover:text-red-500"
            dropdown_class="relative max-h-32 overflow-y-scroll bg-gray-100 inset-x-0 rounded-md shadow top-full z-50"
          >
            <:option :let={option}>
              <div class="flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={
                    maybe_get_avatar_src(
                      get_uconn_for_users!(option.value, @current_user.id),
                      @current_user,
                      @key,
                      []
                    )
                  }
                />{option.label}
              </div>
            </:option>
            <:tag :let={option}>
              <.phx_avatar
                class="mr-2 h-6 w-6 rounded-full"
                src={
                  maybe_get_avatar_src(
                    get_uconn_for_users!(option.value, @current_user.id),
                    @current_user,
                    @key,
                    []
                  )
                }
              />{option.label}
            </:tag>
          </.live_select>

          <.live_select
            :if={@action in [:edit]}
            id="groups-user-select"
            field={@form[:user_connections]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-default"
            label="Update group members"
            options={@user_connections}
            placeholder="Click or start typing to select people..."
            clear_button_class="pl-1 text-red-600 hover:text-red-500"
            dropdown_class="relative max-h-32 overflow-y-scroll bg-gray-100 inset-x-0 rounded-md shadow top-full z-50"
          >
            <:option :let={option}>
              <div :if={option.value != @current_user.id} class="flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={
                    maybe_get_avatar_src(
                      get_uconn_for_users!(option.value, @current_user.id),
                      @current_user,
                      @key,
                      @user_connections
                    )
                  }
                />{option.label}
              </div>
              <div :if={option.value == @current_user.id} class="flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={maybe_get_user_avatar(@current_user, @key)}
                />{option.label}
              </div>
            </:option>
            <:tag :let={option}>
              <span :if={option.value != @current_user.id} class="inline-flex">
                <.phx_avatar
                  :if={option.value != @current_user.id}
                  class="mr-2 h-6 w-6 rounded-full"
                  src={
                    maybe_get_avatar_src(
                      get_uconn_for_users!(option.value, @current_user.id),
                      @current_user,
                      @key,
                      @user_connections
                    )
                  }
                />{option.label}
              </span>
              <span :if={option.value == @current_user.id} class="inline-flex">
                <.phx_avatar
                  class="mr-2 h-6 w-6 rounded-full"
                  src={maybe_get_user_avatar(@current_user, @key)}
                />{option.label}
              </span>
            </:tag>
          </.live_select>
          <div class="pt-4">
            <.button
              :if={@action in [:new] && @form.source.valid?}
              class="rounded-full"
              phx-disable-with="Saving..."
            >
              Save Group
            </.button>
            <.button
              :if={@action in [:new] && !@form.source.valid?}
              phx-disable-with="Saving..."
              disabled
              class="opacity-25 rounded-full"
            >
              Save Group
            </.button>
            <.button :if={@action in [:edit]} class="rounded-full" phx-disable-with="Updating...">
              Update Group
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def update(%{group: group} = assigns, socket) do
    current_user = assigns.current_user

    if assigns.action in [:new] do
      changeset = Groups.change_group(group)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:require_password?, false)
       |> assign_form(changeset)}
    else
      key = assigns.key
      options = assigns.user_connections

      member_list =
        build_member_list_for_group(group, current_user, key)

      changeset = Groups.change_group(group)

      send_update(LiveSelect.Component,
        options: options,
        id: "groups-user-select",
        value: member_list
      )

      {:ok,
       socket
       |> assign(:group_name, group.name)
       |> assign(:group_description, group.description)
       |> assign(assigns)
       |> assign(:require_password?, group.require_password?)
       |> assign_form(changeset)}
    end
  end

  @impl true
  def handle_event("live_select_change", %{"id" => id, "text" => text}, socket) do
    options =
      if text == "" do
        socket.assigns.user_connections
      else
        socket.assigns.user_connections
        |> Enum.filter(&(String.downcase(&1[:key]) |> String.contains?(String.downcase(text))))
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-default", %{"id" => id}, socket) do
    options = socket.assigns.user_connections

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-default", %{"id" => id, "text" => text}, socket) do
    options =
      if text == "" do
        socket.assigns.user_connections
      else
        socket.assigns.user_connections
        |> Enum.filter(&(String.downcase(&1[:key]) |> String.contains?(String.downcase(text))))
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"group" => group_params}, socket) do
    socket = assign(socket, :require_password?, group_params["require_password?"])

    changeset =
      cond do
        group_params["user_connections_empty_selection"] == "" ->
          socket.assigns.group
          |> Groups.change_group(group_params,
            require_password?: group_params["require_password?"]
          )
          |> Map.put(:action, :validate)

        !Enum.empty?(group_params["user_connections"]) ->
          socket.assigns.group
          |> Map.put(:users, build_users_from_uconn_ids(group_params["user_connections"]))
          |> Groups.change_group(group_params,
            require_password?: group_params["require_password?"]
          )
          |> Map.put(:action, :validate)

        Enum.empty?(group_params["user_connections"]) ->
          socket.assigns.group
          |> Groups.change_group(group_params,
            require_password?: group_params["require_password?"]
          )
          |> Map.put(:action, :validate)
      end

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    group_params =
      cond do
        is_nil(group_params["user_connections"]) ->
          group_params

        !Enum.empty?(group_params["user_connections"]) ->
          group_params
          |> Map.put("user_group_map", %{
            user_id: group_params["user_id"],
            key: group_params["key"],
            role: group_params["role"],
            name: group_params["user_name"]
          })
          |> Map.put("users", build_users_from_uconn_ids(group_params["user_connections"]))

        true ->
          group_params
          |> Map.put("user_group_map", %{
            user_id: group_params["user_id"],
            key: group_params["key"],
            role: group_params["role"],
            name: group_params["user_name"]
          })
      end

    save_group(socket, socket.assigns.action, group_params)
  end

  defp save_group(socket, :edit, group_params) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    if can_edit_group?(get_user_group(socket.assigns.group, user), user) do
      case Groups.update_group(socket.assigns.group, group_params,
             user: user,
             key: key,
             require_password?: group_params["require_password?"]
           ) do
        {:ok, group} ->
          notify_parent({:saved, group})

          {:noreply,
           socket
           |> put_flash(:success, "Group updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:info, "You do not have permission to edit this group.")
       |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_group(socket, :new, group_params) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    if group_params["user_id"] == user.id && group_params["user_connections"] do
      case Groups.create_group(group_params,
             user: user,
             key: key,
             require_password?: group_params["require_password?"]
           ) do
        {:ok, group} ->
          notify_parent({:saved, group})

          {:noreply,
           socket
           |> put_flash(:success, "Group created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Woops! You need to add some Connections first before you can make a Group (otherwise it's just you). Head over to your Connections page to get started!"
       )
       |> push_patch(to: ~p"/app/groups/new")}
    end
  end

  defp build_users_from_uconn_ids(ids) when is_list(ids) do
    Enum.into(ids, [], fn id -> Accounts.get_user!(id) end)
  end

  defp build_users_from_uconn_ids(_ids), do: []

  defp build_member_list_for_group(group, current_user, key) do
    Enum.into(group.user_groups, [], fn user_group ->
      connection = Accounts.get_connection_from_item(user_group, current_user)
      uconn = Accounts.get_user_connection_for_user_group(user_group.user_id, current_user.id)

      [
        key:
          cond do
            is_nil(uconn) && user_group.user_id != current_user.id ->
              "private"

            is_nil(uconn) && user_group.user_id == current_user.id ->
              decr(current_user.username, current_user, key)

            true ->
              decr_uconn(connection.username, current_user, uconn.key, key)
          end,
        value: user_group.user_id,
        sticky:
          cond do
            user_group.user_id == current_user.id ->
              true

            is_nil(uconn) && user_group.user_id != current_user.id ->
              true

            user_group.role in [:admin, :member, :moderator] ->
              true

            true ->
              false
          end
      ]
    end)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
