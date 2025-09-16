defmodule MossletWeb.UserResetPasswordLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout title="Reset Password" conn={@socket}>
      <.link navigate="/" class="-ml-4">
        <.logo class="mb-2 h-16 w-auto" />
      </.link>
      <div class="mb-4 prose prose-gray dark:prose-invert">
        <p :if={!@user.is_forgot_pwd? || !@user.key}>
          In order to maximize the security of your account, you cannot reset your password using this method. If you wish to change this, you must log in and change your account's
          <span class="italic font-semibold">forgot password</span>
          setting.
        </p>
      </div>

      <.form
        :if={@user.is_forgot_pwd? && @user.key}
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
      >
        <div id="passwordField" class="relative">
          <div id="pw-label-container" class="flex justify-between">
            <div id="pw-actions" class="absolute top-0 right-0">
              <button
                type="button"
                id="eye"
                data-tippy-content="Show password"
                phx-hook="TippyHook"
                phx-click={
                  JS.set_attribute({"type", "text"}, to: "#password")
                  |> JS.remove_class("hidden", to: "#eye-slash")
                  |> JS.add_class("hidden", to: "#eye")
                }
              >
                <.icon name="hero-eye" class="h-5 w-5 dark:text-white cursor-pointer" />
              </button>
              <button
                type="button"
                id="eye-slash"
                x-data
                x-tooltip="Hide password"
                data-tippy-content="Hide password"
                phx-hook="TippyHook"
                class="hidden"
                phx-click={
                  JS.set_attribute({"type", "password"}, to: "#password")
                  |> JS.add_class("hidden", to: "#eye-slash")
                  |> JS.remove_class("hidden", to: "#eye")
                }
              >
                <.icon name="hero-eye-slash" class="h-5 w-5  dark:text-white cursor-pointer" />
              </button>
            </div>
          </div>
        </div>
        <.field
          id="password"
          field={@form[:password]}
          type="password"
          label="New password"
          phx-debounce="blur"
          required
        />
        <.field
          field={@form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          required
        />

        <button
          class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
          phx-disable-with="Resetting..."
        >
          Reset Password
        </button>
      </.form>
      <div class="py-4 flex justify-between text-sm dark:text-gray-200">
        <.link navigate={~p"/auth/sign_in"} class=" hover:text-emerald-600 active:text-emerald-500">
          Login
        </.link>
        <.link navigate={~p"/auth/register"} class=" hover:text-emerald-600 active:text-emerald-500">
          Register
        </.link>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(page_title: "Reset Password")
      |> assign_user_and_token(params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    if socket.assigns.user.is_forgot_pwd? && socket.assigns.user.key do
      user = socket.assigns.user
      key = socket.assigns.user.key

      case Accounts.reset_user_password(socket.assigns.user, user_params,
             user: user,
             key: key,
             reset_password: true
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:success, "Password reset successfully.")
           |> redirect(to: ~p"/auth/sign_in")}

        {:error, changeset} ->
          {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Woops, you cannot reset your password.")
       |> redirect(to: ~p"/auth/sign_in")}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end
