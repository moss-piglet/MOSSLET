defmodule MossletWeb.EditForgotPasswordLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_visibility(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_forgot_password} current_user={@current_user} key={@key}>
      <div class="max-w-prose">
        <.h3>{gettext("Forgot password")}</.h3>
        <div :if={!@current_user.is_forgot_pwd?} class="flex items-center gap-2 mb-6">
          <.icon solid name="hero-lock-closed" class="w-10 h-10 text-green-600 dark:text-green-400" />

          <div class="font-semibold dark:text-gray-100">
            {gettext("Forgot Password Disabled")}
          </div>
        </div>
        <div :if={@current_user.is_forgot_pwd?} class="flex items-center gap-2 mb-6">
          <.icon solid name="hero-lock-open" class="w-10 h-10 text-emerald-600 dark:text-emerald-400" />

          <div class="font-semibold dark:text-gray-100">
            {gettext("Forgot Password Enabled")}
          </div>
        </div>
        <div class="pb-4">
          <.p :if={!@current_user.is_forgot_pwd?}>
            Total privacy! You cannot regain access to your account if you forget your password. If you feel that your password may have been breached, you can change it in the Edit password section of your settings.
          </.p>
          <.p :if={!@current_user.is_forgot_pwd?}>
            Enabling this setting will store the key to your data with strong symmetric encryption, at-rest, in our database. This is how we are able to reset your password should you forget it.
          </.p>
          <.p :if={@current_user.is_forgot_pwd?}>
            Total convenience! You can regain access to your account by using the reset password feature on the login page. Your account is still protected with strong encryption, though it may now be possible for a governing authority to request access to it.
          </.p>
          <.p :if={@current_user.is_forgot_pwd?}>
            Disabling this setting will delete the encrypted key to your data from our database. Only your password will be able to unlock your data and we will no longer be able to reset your password if you forget it.
          </.p>
        </div>

        <.form id="change_forgot_password_form" for={@form} phx-change="update_forgot_password">
          <.field
            type="checkbox"
            field={@form[:is_forgot_pwd?]}
            label={gettext("Change your forgot password")}
            autocomplete="forgot_password"
            data-confirm={gettext("Are you sure you want to change your forgot password setting?")}
            {alpine_autofocus()}
          />
        </.form>
      </div>
    </.settings_layout>
    """
  end

  def handle_event("validate_forgot_password", %{"user" => user_params}, socket) do
    forgot_password_form =
      socket.assigns.current_user
      |> Accounts.change_user_forgot_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, forgot_password_form: forgot_password_form)}
  end

  def handle_event("update_forgot_password", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    if user && user.confirmed_at do
      case Accounts.update_user_forgot_password(user, user_params,
             change_forgot_password: true,
             key: key,
             user: user
           ) do
        {:ok, user} ->
          forgot_password_form =
            user
            |> Accounts.change_user_forgot_password(user_params)
            |> to_form()

          info = "Your forgot password setting has been updated successfully."

          {:noreply,
           socket
           |> put_flash(:success, info)
           |> assign(forgot_password_form: forgot_password_form)
           |> push_navigate(to: ~p"/app/users/change-forgot-password")}

        {:error, _changeset} ->
          info = "Your forgot password setting could not be updated. Please try again later."

          {:noreply,
           socket
           |> put_flash(:error, info)
           |> push_navigate(to: ~p"/app/users/change-forgot-password")}
      end
    else
      info = "Woops, you need to confirm your account first."

      {:noreply,
       socket
       |> put_flash(:error, info)
       |> push_navigate(to: ~p"/app/users/change-forgot-password")}
    end
  end
end
