defmodule MossletWeb.GroupLive.FormComponent do
  @moduledoc false
  use MossletWeb, :live_component

  alias Mosslet.Accounts
  alias Mosslet.Groups

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-5">
      <div class="flex items-center gap-3 pb-4 border-b border-slate-200/60 dark:border-slate-700/60">
        <div class="p-2.5 rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
          <.phx_icon name="hero-circle-stack" class="h-5 w-5 text-teal-600 dark:text-teal-400" />
        </div>
        <div>
          <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
            {@title}
          </h2>
          <p :if={@action in [:new]} class="text-sm text-slate-600 dark:text-slate-400">
            Create a new circle to share and collaborate with your connections
          </p>
          <p :if={@action in [:edit]} class="text-sm text-slate-600 dark:text-slate-400">
            Update circle details and manage members
          </p>
        </div>
      </div>

      <.form
        for={@form}
        id="group-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <.phx_input
          :if={@action in [:new]}
          phx-debounce="500"
          field={@form[:name]}
          type="text"
          label="Name"
          placeholder="Enter circle name..."
        />
        <.phx_input
          :if={@action in [:new]}
          phx-debounce="500"
          field={@form[:description]}
          type="text"
          label="Description"
          placeholder="What is this circle about?"
        />

        <div :if={@action in [:new]} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <MossletWeb.DesignSystem.liquid_checkbox
            field={@form[:public?]}
            label="Make circle public?"
            help="Public circles can be discovered by others"
            phx-debounce="500"
          />
          <MossletWeb.DesignSystem.liquid_checkbox
            field={@form[:require_password?]}
            label="Require password?"
            help="Members need a password to join"
            phx-debounce="500"
          />
        </div>

        <.phx_input
          :if={@action in [:new] && @require_password? == "true"}
          field={@form[:password]}
          type="password"
          label="Password"
          placeholder="Enter circle password..."
          phx-debounce="500"
        />

        <.phx_input
          :if={@action in [:edit]}
          field={@form[:name]}
          value={@group_name}
          type="text"
          phx-debounce="500"
          label="Name"
          placeholder="Enter circle name..."
        />
        <.phx_input
          :if={@action in [:edit]}
          field={@form[:description]}
          value={@group_description}
          type="text"
          phx-debounce="500"
          label="Description"
          placeholder="What is this circle about?"
        />
        <.phx_input field={@form[:user_id]} type="hidden" value={@current_scope.user.id} />
        <.phx_input
          field={@form[:user_name]}
          type="hidden"
          value={decr(@current_scope.user.name, @current_scope.user, @current_scope.key)}
        />

        <div class="p-4 -mx-1 sm:mx-0 rounded-xl bg-gradient-to-br from-slate-50/80 to-slate-100/50 dark:from-slate-800/50 dark:to-slate-900/30 border border-slate-200/60 dark:border-slate-700/40">
          <div class="flex items-center gap-2 mb-3">
            <.phx_icon name="hero-users" class="h-4 w-4 text-slate-500 dark:text-slate-400" />
            <label class="text-sm font-medium text-slate-900 dark:text-slate-100">
              {if @action in [:new], do: "Add people to circle", else: "Update circle members"}
            </label>
          </div>
          <.live_select
            :if={@action in [:new]}
            id="groups-user-select"
            field={@form[:user_connections]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-default"
            options={@user_connections}
            placeholder="Click or start typing to select people..."
          >
            <:option :let={option}>
              <div class="flex items-center gap-2">
                <.phx_avatar
                  class="h-7 w-7 rounded-full ring-2 ring-white dark:ring-slate-700"
                  src={
                    maybe_get_avatar_src(
                      get_uconn_for_users!(option.value, @current_scope.user.id),
                      @current_scope.user,
                      @current_scope.key,
                      []
                    )
                  }
                />
                <span class="font-medium">{option.label}</span>
              </div>
            </:option>
            <:tag :let={option}>
              <.phx_avatar
                class="h-5 w-5 rounded-full"
                alt={option.label}
                src={
                  maybe_get_avatar_src(
                    get_uconn_for_users!(option.value, @current_scope.user.id),
                    @current_scope.user,
                    @current_scope.key,
                    []
                  )
                }
              />
              <span>{option.label}</span>
            </:tag>
          </.live_select>

          <.live_select
            :if={@action in [:edit]}
            id="groups-user-select"
            field={@form[:user_connections]}
            mode={:tags}
            phx-target={@myself}
            phx-focus="set-default"
            options={@user_connections}
            placeholder="Click or start typing to select people..."
          >
            <:option :let={option}>
              <div class="flex items-center gap-2">
                <.phx_avatar
                  class="h-7 w-7 rounded-full ring-2 ring-white dark:ring-slate-700"
                  src={
                    if option.value == @current_scope.user.id do
                      maybe_get_user_avatar(@current_scope.user, @current_scope.key)
                    else
                      maybe_get_avatar_src(
                        get_uconn_for_users!(option.value, @current_scope.user.id),
                        @current_scope.user,
                        @current_scope.key,
                        @user_connections
                      )
                    end
                  }
                />
                <span class="font-medium">{option.label}</span>
              </div>
            </:option>
            <:tag :let={option}>
              <.phx_avatar
                class="h-5 w-5 rounded-full"
                alt={option.label}
                src={
                  if option.value == @current_scope.user.id do
                    maybe_get_user_avatar(@current_scope.user, @current_scope.key)
                  else
                    maybe_get_avatar_src(
                      get_uconn_for_users!(option.value, @current_scope.user.id),
                      @current_scope.user,
                      @current_scope.key,
                      @user_connections
                    )
                  end
                }
              />
              <span>{option.label}</span>
            </:tag>
          </.live_select>
          <p class="mt-2 text-xs text-slate-500 dark:text-slate-400">
            Select connections to invite to this circle
          </p>
        </div>

        <div class="flex flex-col-reverse sm:flex-row gap-3 sm:justify-end pt-5 mt-2 border-t border-slate-200/60 dark:border-slate-700/60">
          <MossletWeb.DesignSystem.liquid_button
            type="button"
            variant="secondary"
            color="slate"
            phx-click={JS.exec("data-cancel", to: "#group-modal")}
            class="w-full sm:w-auto"
          >
            Cancel
          </MossletWeb.DesignSystem.liquid_button>

          <MossletWeb.DesignSystem.liquid_button
            :if={@action in [:new] && @form.source.valid?}
            type="submit"
            color="teal"
            icon="hero-check"
            class="w-full sm:w-auto"
            phx-disable-with="Saving..."
          >
            Save Circle
          </MossletWeb.DesignSystem.liquid_button>

          <MossletWeb.DesignSystem.liquid_button
            :if={@action in [:new] && !@form.source.valid?}
            type="submit"
            color="slate"
            icon="hero-check"
            disabled
            class="w-full sm:w-auto"
          >
            Save Circle
          </MossletWeb.DesignSystem.liquid_button>

          <MossletWeb.DesignSystem.liquid_button
            :if={@action in [:edit]}
            type="submit"
            color="teal"
            icon="hero-check"
            class="w-full sm:w-auto"
            phx-disable-with="Updating..."
          >
            Update Circle
          </MossletWeb.DesignSystem.liquid_button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{group: group} = assigns, socket) do
    current_user = assigns.current_scope.user
    user_connections = convert_options_for_live_select(assigns.user_connections)

    if assigns.action in [:new] do
      changeset = Groups.change_group(group)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(:user_connections, user_connections)
       |> assign(:require_password?, false)
       |> assign_form(changeset)}
    else
      key = assigns.current_scope.key
      user_connections = convert_options_for_live_select(assigns.user_connections)

      member_list =
        build_member_list_for_group(group, current_user, key)

      changeset = Groups.change_group(group)

      send_update(LiveSelect.Component,
        options: user_connections,
        id: "groups-user-select",
        value: member_list
      )

      decrypted_name =
        decr_item(
          group.name,
          current_user,
          get_user_group(group, current_user).key,
          key,
          group
        )

      decrypted_description =
        decr_item(
          group.description,
          current_user,
          get_user_group(group, current_user).key,
          key,
          group
        )

      {:ok,
       socket
       |> assign(:group_name, decrypted_name)
       |> assign(:group_description, decrypted_description)
       |> assign(assigns)
       |> assign(:user_connections, user_connections)
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
        |> Enum.filter(fn opt ->
          label = opt[:label] || opt[:key]
          label && String.downcase(label) |> String.contains?(String.downcase(text))
        end)
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
        |> Enum.filter(fn opt ->
          label = opt[:label] || opt[:key]
          label && String.downcase(label) |> String.contains?(String.downcase(text))
        end)
      end

    send_update(LiveSelect.Component, options: options, id: id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"group" => group_params}, socket) do
    socket =
      socket
      |> assign(:require_password?, group_params["require_password?"])
      |> maybe_update_decrypted_fields(group_params)

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
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

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
           |> put_flash(:success, "Circle updated successfully")
           |> push_event("restore-body-scroll", %{})
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:info, "You do not have permission to edit this circle.")
       |> push_event("restore-body-scroll", %{})
       |> push_patch(to: socket.assigns.patch)}
    end
  end

  defp save_group(socket, :new, group_params) do
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

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
           |> put_flash(:success, "Circle created successfully")
           |> push_event("restore-body-scroll", %{})
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :info,
         "Woops! You need to add some Connections first before you can make a Circle (otherwise it's just you). Head over to your Connections page to get started!"
       )
       |> push_patch(to: ~p"/app/circles/new")}
    end
  end

  defp build_users_from_uconn_ids(ids) when is_list(ids) do
    Enum.into(ids, [], fn id -> Accounts.get_user!(id) end)
  end

  defp build_users_from_uconn_ids(_ids), do: []

  defp convert_options_for_live_select(options) do
    Enum.map(options, fn opt ->
      [label: opt[:key], value: opt[:value], current_user_id: opt[:current_user_id]]
    end)
  end

  defp build_member_list_for_group(group, current_user, key) do
    Enum.into(group.user_groups, [], fn user_group ->
      connection = Accounts.get_connection_from_item(user_group, current_user)
      uconn = Accounts.get_user_connection_for_user_group(user_group.user_id, current_user.id)

      [
        label:
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

  defp maybe_update_decrypted_fields(socket, group_params) do
    if socket.assigns.action == :edit do
      socket
      |> maybe_assign_field(:group_name, group_params["name"])
      |> maybe_assign_field(:group_description, group_params["description"])
    else
      socket
    end
  end

  defp maybe_assign_field(socket, key, value) when is_binary(value) and value != "" do
    assign(socket, key, value)
  end

  defp maybe_assign_field(socket, _key, _value), do: socket

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
