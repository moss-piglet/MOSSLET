defmodule MossletWeb.EditEmailLive do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Users.Utils

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_email(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_email} current_user={@current_user} key={@key}>
      <div
        :if={
          !@current_user.is_admin? &&
            decr(@form[:email].value, @current_user, @key) === Encrypted.Session.admin_email() &&
            @current_user.confirmed_at
        }
        class="flex justify-center"
      >
        <.button phx-click="update_admin" class="rounded-full" color="secondary">Set Admin</.button>
      </div>
      <div
        :if={
          @current_user.is_admin? &&
            decr(@form[:email].value, @current_user, @key) === Encrypted.Session.admin_email() &&
            @current_user.confirmed_at
        }
        class="flex justify-center"
      >
        <.button phx-click="update_admin" class="rounded-full" color="danger">Revoke Admin</.button>
      </div>
      <.form id="change_email_form" for={@form} phx-submit="update_email" class="max-w-lg">
        <.field
          type="email"
          field={@form[:email]}
          value={decr(@form[:email].value, @current_user, @key)}
          label={gettext("Change your email")}
          autocomplete="email"
          {alpine_autofocus()}
        />

        <div id="password-current" class="relative">
          <div id="pw-label-current-container" class="flex justify-between">
            <div id="pw-current-actions" class="absolute top-0 right-0">
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
          autocomplete="off"
          required
        />

        <div class="flex justify-end">
          <.button class="rounded-full">{gettext("Change email")}</.button>
        </div>
      </.form>
    </.settings_layout>
    """
  end

  def handle_event("update_admin", _params, socket) do
    current_user = socket.assigns.current_user
    key = socket.assigns.key
    email = decr(current_user.email, current_user, key)

    if email === Encrypted.Session.admin_email() && current_user.confirmed_at do
      case Accounts.update_user_admin(current_user) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(
             :success,
             "Your account's admin privileges have been updated successfully."
           )
           |> push_navigate(to: ~p"/app/users/edit-email")}

        {:error, changeset} ->
          Logger.info("Error updating user account admin")
          Logger.info(inspect(changeset))
          Logger.error(email)

          socket =
            socket
            |> put_flash(
              :error,
              "There was an error trying to update your account's admin privileges."
            )

          {:noreply, push_navigate(socket, to: ~p"/app/users/edit-email")}
      end
    end
  end

  def handle_event(
        "update_email",
        %{"current_password" => password, "user" => user_params} = _params,
        socket
      ) do
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.check_if_can_change_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          Utils.decrypt_user_data(user.email, user, key),
          user_params["email"],
          &url(~p"/app/users/settings/confirm-email/#{&1}")
        )

        Accounts.user_lifecycle_action("request_new_email", user, %{
          new_email: user_params["email"]
        })

        socket = socket |> clear_flash(:warning)

        {:noreply,
         put_flash(
           socket,
           :info,
           gettext("A link to confirm your e-mail change has been sent to your current address.")
         )}

      {:error, %Ecto.Changeset{errors: [email_hash: _email_error]} = changeset} ->
        error =
          MossletWeb.CoreComponents.translate_errors(changeset.errors, :email_hash)

        socket =
          socket
          |> put_flash(
            :warning,
            Gettext.gettext(
              MossletWeb.Gettext,
              "There was an error trying to update your email address: your email is #{error}."
            )
          )

        {:noreply, assign(socket, form: to_form(Accounts.change_user_email(user)))}

      {:error, %Ecto.Changeset{errors: [current_password: _password_error]} = changeset} ->
        error =
          MossletWeb.CoreComponents.translate_errors(changeset.errors, :current_password)

        socket =
          socket
          |> put_flash(
            :warning,
            Gettext.gettext(
              MossletWeb.Gettext,
              "There was an error trying to update your email address: your password #{error}."
            )
          )

        {:noreply, assign(socket, form: to_form(Accounts.change_user_email(user)))}

      {:error,
       %Ecto.Changeset{errors: [current_password: _password_error, email_hash: _email_error]} =
           changeset} ->
        error =
          MossletWeb.CoreComponents.translate_errors(changeset.errors, :current_password)

        email_error =
          MossletWeb.CoreComponents.translate_errors(changeset.errors, :email_hash)

        socket =
          socket
          |> put_flash(
            :warning,
            Gettext.gettext(
              MossletWeb.Gettext,
              "There was an error trying to update your email address: your password #{error} and your email is #{email_error}."
            )
          )

        {:noreply, assign(socket, form: to_form(Accounts.change_user_email(user)))}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(
            :warning,
            Gettext.gettext(
              MossletWeb.Gettext,
              "There was an error trying to update your email address."
            )
          )

        {:noreply, assign(socket, form: to_form(Accounts.change_user_email(user)))}
    end
  end
end
