defmodule MossletWeb.EditPasswordLive do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.UserSettingsLayoutComponent

  alias Mosslet.Accounts
  alias Mosslet.Extensions.PasswordGenerator.PassphraseGenerator

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       trigger_submit: false,
       form: to_form(Accounts.change_user_password(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.settings_layout current_page={:edit_password} current_user={@current_user} key={@key}>
      <div class="flex justify-center">
        <div class="max-w-md mb-4 rounded-md bg-background-50 dark:bg-emerald-50 p-4 shadow-md dark:shadow-emerald-500/50">
          <div class="flex">
            <div class="shrink-0">
              <.phx_icon
                name="hero-information-circle"
                class="size-5 text-background-700 dark:text-emerald-700"
              />
            </div>
            <div class="ml-3 flex-1 md:flex md:justify-between">
              <p class="text-sm text-background-700 dark:text-emerald-700">
                Generate a strong, memorable password with the
                <.phx_icon name="hero-sparkles" class="size-4 mr-1" /> button.
              </p>
              <p class="mt-3 text-sm md:mt-0 md:ml-6">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://www.eff.org/dice"
                  class="font-medium whitespace-nowrap text-background-700 hover:text-background-600 dark:text-emerald-700 dark:hover:text-emerald-600"
                >
                  Details <span aria-hidden="true"> &rarr;</span>
                </.link>
              </p>
            </div>
          </div>
        </div>
      </div>

      <.form
        for={@form}
        action={~p"/auth/sign_in?_action=password_updated"}
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <.field
          field={@form[:email]}
          type="hidden"
          id="hidden_user_email"
          value={decr(@current_user.email, @current_user, @key)}
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
          phx-debounce="500"
          required
          {alpine_autofocus()}
        />

        <div id="password-new" class="relative">
          <div id="pw-label-new-container" class="flex justify-between">
            <div id="pw-new-actions" class="absolute top-0 right-0">
              <button
                type="button"
                id="pw-generator-button"
                phx-hook="TippyHook"
                data-tippy-content="Generate new password"
                phx-click={JS.push("generate-password")}
                class="mr-2"
              >
                <.phx_icon name="hero-sparkles" class="h-5 w-5 dark:text-white cursor-pointer" />
              </button>
              <button
                type="button"
                id="eye"
                data-tippy-content="Show new password"
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
                data-tippy-content="Hide new password"
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
          type="password"
          field={@form[:password]}
          label={gettext("New password")}
          autocomplete="off"
          phx-debounce="500"
          required
        />

        <.field
          type="password"
          field={@form[:password_confirmation]}
          label={gettext("New password confirmation")}
          phx-debounce="500"
          autocomplete="off"
        />

        <div class="flex justify-between">
          <button
            type="button"
            phx-click="send_password_reset_email"
            phx-value-email={decr(@current_user.email, @current_user, @key)}
            data-confirm={
              gettext("This will send a reset password link to the email '%{email}'. Continue?",
                email: decr(@current_user.email, @current_user, @key)
              )
            }
            class="text-sm text-gray-500 underline dark:text-gray-400"
          >
            {gettext("Forgot your password?")}
          </button>

          <.button class="rounded-full">{gettext("Change password")}</.button>
        </div>
      </.form>
    </.settings_layout>
    """
  end

  @doc """
  Generates a strong, memorable passphrase.
  We optionally pass random words and separators.
  """
  def handle_event("generate-password", _params, socket) do
    current_user = socket.assigns.current_user

    words = Enum.random([5, 6, 7])
    separator = Enum.random([" ", "-", "."])
    generated_passphrase = PassphraseGenerator.generate_passphrase(words, separator)

    form =
      Accounts.change_user_password(current_user, %{"password" => generated_passphrase},
        change_password: true
      )
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:generated_password?, true)
     |> assign(:form, form)}
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params, change_password: true)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_password(user, password, user_params,
           change_password: true,
           key: key,
           user: user
         ) do
      {:ok, user} ->
        form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, form: form)}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("send_password_reset_email", %{"email" => email}, socket) do
    Accounts.deliver_user_reset_password_instructions(
      socket.assigns.current_user,
      email,
      &url(~p"/auth/reset-password/#{&1}")
    )

    {:noreply,
     put_flash(
       socket,
       :info,
       gettext("You will receive instructions to reset your password shortly.")
     )}
  end
end
