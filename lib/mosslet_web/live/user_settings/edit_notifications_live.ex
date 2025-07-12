defmodule MossletWeb.EditNotificationsLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User

  def mount(_params, _session, socket) do
    {:ok, assign_form(socket, socket.assigns.current_user)}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_notifications} current_user={@current_user} key={@key}>
      <.form id="update_profile_form" for={@form} phx-change="update_profile">
        <.field
          type="checkbox"
          field={@form[:is_subscribed_to_marketing_notifications]}
          label={gettext("Allow in-app notifications")}
          help_text={
            if @current_user.is_subscribed_to_marketing_notifications,
              do: "Disable to no longer receive notifications on your home page.",
              else: "Enable to recieve calm notifications on your home page."
          }
          {alpine_autofocus()}
        />
      </.form>
    </.settings_layout>
    """
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    case Accounts.update_user_notifications(socket.assigns.current_user, user_params) do
      {:ok, current_user} ->
        Accounts.user_lifecycle_action("after_update_profile", current_user)

        socket =
          socket
          |> put_flash(
            :success,
            gettext("You have successfully updated your in-app notifications.")
          )
          |> assign(current_user: current_user)
          |> assign_form(current_user)
          |> push_navigate(to: "/app/users/edit-notifications")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> put_flash(:error, gettext("Update failed. Please check the form for issues."))
          |> assign(form: to_form(changeset))
          |> push_navigate(to: "/app/users/edit-notifications")

        {:noreply, socket}
    end
  end

  defp assign_form(socket, user) do
    assign(socket, page_title: "Settings", form: to_form(User.notifications_changeset(user)))
  end
end
