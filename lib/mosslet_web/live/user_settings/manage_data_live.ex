defmodule MossletWeb.ManageDataLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_user))
     )}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     assign(socket,
       page_title: "Settings",
       current_password: nil,
       form: to_form(Accounts.change_user_delete_data(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:manage_data} current_user={@current_user} key={@key}>
      <div class="max-w-prose">
        <.h3>{gettext("Manage your data")}</.h3>
        <.form for={@form} phx-change="validate_password" phx-submit="delete_data">
          <.field
            field={@form[:email]}
            type="hidden"
            id="hidden_user_email"
            value={decr(@current_user.email, @current_user, @key)}
          />
          <div class="pt-2 pb-4">
            <.p>
              Everyone deserves a fresh start. Enter your current password to delete data and start over. You can currently delete all of your Connections, Groups, Memories, Posts, Remarks, and Replies.
            </.p>
          </div>
          <div id="passwordField" class="relative">
            <div id="pw-label-container" class="flex justify-between">
              <div id="pw-actions" class="absolute top-0 right-0">
                <button
                  type="button"
                  id="eye-current-password"
                  data-tippy-content="Show current password"
                  phx-hook="TippyHook"
                  phx-click={
                    JS.set_attribute({"type", "text"}, to: "#current-password")
                    |> JS.remove_class("hidden", to: "#eye-slash-current-password")
                    |> JS.add_class("hidden", to: "#eye-current-password")
                  }
                >
                  <.icon name="hero-eye" class="h-5 w-5 dark:text-white cursor-pointer" />
                </button>
                <button
                  type="button"
                  id="eye-slash-current-password"
                  x-data
                  x-tooltip="Hide password"
                  data-tippy-content="Hide current password"
                  phx-hook="TippyHook"
                  class="hidden"
                  phx-click={
                    JS.set_attribute({"type", "password"}, to: "#current-password")
                    |> JS.add_class("hidden", to: "#eye-slash-current-password")
                    |> JS.remove_class("hidden", to: "#eye-current-password")
                  }
                >
                  <.icon name="hero-eye-slash" class="h-5 w-5  dark:text-white cursor-pointer" />
                </button>
              </div>
            </div>
          </div>
          <.field
            type="password"
            id="current-password"
            field={@form[:current_password]}
            name="current_password"
            label={gettext("Current password")}
            value={@current_password}
            required
            {alpine_autofocus()}
          />
          <!-- With col layout -->
          <.field
            field={@form[:data]}
            type="checkbox-group"
            label="Data"
            options={[
              {"Connections", "user_connections"},
              {"Groups", "groups"},
              {"Memories", "memories"},
              {"Posts", "posts"},
              {"Remarks", "remarks"},
              {"Replies", "replies"}
            ]}
            group_layout="col"
            help_text="Select which items you'd like to delete."
          />
          <.button class="rounded-full" color="danger" phx-disable-with="Deleting...">
            {gettext("Delete your data")}
          </.button>
        </.form>
      </div>
    </.settings_layout>
    """
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    form =
      socket.assigns.current_user
      |> Accounts.change_user_delete_data(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, current_password: password)}
  end

  def handle_event("delete_data", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.delete_user_data(user, password, key, user_params) do
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:ok, nil} ->
        user
        |> Accounts.change_user_delete_data(user_params)
        |> to_form()

        info = "Woops! Looks like you didn't select any data to delete."

        {:noreply,
         socket
         |> put_flash(:success, nil)
         |> put_flash(:warning, info)
         |> push_patch(to: ~p"/app/users/manage-data")}

      :ok ->
        user
        |> Accounts.change_user_delete_data(user_params)
        |> to_form()

        info = "Fresh start! The data you selected was deleted successfully."

        {:noreply,
         socket
         |> put_flash(:warning, nil)
         |> put_flash(:success, info)
         |> push_patch(to: ~p"/app/users/manage-data")}
    end
  end

  def handle_info(
        {_ref, {:ok, :memory_deleted_from_storj, info}},
        socket
      ) do
    socket = put_flash(socket, :success, info)
    {:noreply, socket |> put_flash(:success, info)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
