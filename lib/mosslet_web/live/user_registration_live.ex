defmodule MossletWeb.UserRegistrationLive do
  use MossletWeb, :live_view
  import Ecto.Changeset

  alias Mosslet.Accounts
  alias Mosslet.Accounts.User
  alias Mosslet.Extensions.PasswordGenerator.PassphraseGenerator

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok,
     socket
     |> assign(:page_title, "Register")
     |> assign(:current_step, 1)
     |> assign(:generated_password?, false)
     |> assign(:changeset, changeset)
     |> assign(:temp_email, nil)
     |> assign(:error_message, nil)
     |> assign(:loading, false)
     |> assign(trigger_submit: false, check_errors: false)
     |> assign_new(:meta_description, fn ->
       Application.get_env(:mosslet, :seo_description)
     end)
     |> assign_form(changeset), temporary_assigns: [form: nil]}
  end

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Register">
      <div class="flex flex-col items-start justify-start">
        <.link navigate="/" class="-ml-4">
          <.logo class="mb-2 h-16 w-auto" />
        </.link>
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below:
          <:errors_list>
            <li :for={{atom, {msg, _validation}} <- @changeset.errors}>
              {Atom.to_string(atom) |> String.split("_") |> List.first()} is {msg}
            </li>
          </:errors_list>
        </.error>
        <%= case @current_step do %>
          <% 1 -> %>
            <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Take back your privacy today.
            </h2>

            <div class="space-y-4">
              <div class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                <p class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                  Enter your email to get started. People can send you requests to connect by knowing your email and it will be used when signing into your account.
                </p>
              </div>
            </div>
          <% 2 -> %>
            <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Create your username.
            </h2>

            <div class="space-y-4">
              <div class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                <p class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                  People can also send you requests to connect by knowing your username and it will be used when sharing items.
                </p>
              </div>
            </div>
          <% 3 -> %>
            <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Create a password.
            </h2>
            <p class="mt-2 text-sm text-gray-700 dark:text-gray-200">
              Your password is used to create a secure key that keeps your account encrypted and private. You can change it at any time from within your account settings.
            </p>

            <div class="mt-4 rounded-md bg-background-50 dark:bg-emerald-50 p-4 shadow-md dark:shadow-emerald-500/50">
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
                    <.phx_icon name="hero-sparkles" class="size-3 mr-1" /> button.
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
          <% 4 -> %>
            <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Why still a password?
            </h2>
            <div class="space-y-4">
              <div class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                <p>
                  Only your password can be used to unlock your data thanks to strong asymmetric encryption. So, it's super important to keep your password safe (we recommend a password manager).
                </p>
              </div>
              <div class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                <p>
                  Once you confirm your account you will be able to go into your settings and set the "Forgot Password?" option. This option enables you to reset your password in the event that you forget it.
                </p>
              </div>
              <div class="mt-2 text-sm text-gray-700 dark:text-gray-200">
                <p>
                  If you are in a very security conscious environment, then you can choose not to set that option. If you do not set that option, and forget your password, we can not help you get back into your account.
                </p>
              </div>
            </div>
          <% true -> %>
            <h2 class="mt-16 text-lg font-semibold text-gray-900 dark:text-white"></h2>
            <p class="mt-2 text-sm text-gray-700 dark:text-gray-400"></p>
        <% end %>
      </div>

      <div id="user-form-container-spacer" class="mt-10">
        <div id="user-form-container" class="mt-6">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/auth/sign_in?_action=registered"}
            method="post"
            autocomplete="off"
          >
            <div class={unless @current_step === 1, do: "hidden"}>
              <.field
                tabindex="0"
                type="email"
                field={@form[:email]}
                label="Email"
                autocomplete="off"
                class="relative"
                required
                phx-debounce="500"
                {alpine_autofocus()}
              />
            </div>

            <div class={unless @current_step === 2, do: "hidden"}>
              <.field
                type="text"
                field={@form[:username]}
                label="Username"
                autocomplete="off"
                class="relative"
                required
                phx-debounce="500"
              />
            </div>

            <div id="step3" class={unless @current_step === 3, do: "hidden"}>
              <div id="passwordField" class="relative">
                <div id="pw-label-container" class="flex justify-between">
                  <div id="pw-actions" class="absolute top-0 right-0">
                    <button
                      type="button"
                      id="pw-generator-button"
                      phx-hook="TippyHook"
                      data-tippy-content="Generate password"
                      phx-click={JS.push("generate-password")}
                      class="mr-2"
                    >
                      <.phx_icon name="hero-sparkles" class="h-5 w-5 dark:text-white cursor-pointer" />
                    </button>
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
                <.field
                  type="password"
                  id="password"
                  label="Password"
                  field={@form[:password]}
                  phx-debounce="500"
                  autocomplete="current-password"
                  required
                />
                <div id="pw-errors" class="absolute"></div>
              </div>

              <div id="passwordConfirmationField" class="relative mt-4">
                <.field
                  type="text"
                  class="password-mask"
                  id="password-confirmation"
                  label="Confirm Password"
                  field={@form[:password_confirmation]}
                  placeholder="Confirm password"
                  phx-debounce="500"
                  autocomplete="current-password-confirmation"
                  required
                />
              </div>
            </div>

            <div class={unless @current_step === 4, do: "hidden"}>
              <div class="flex justify-between">
                <.field
                  type="checkbox"
                  field={@form[:password_reminder]}
                  label="Password Reminder"
                  required
                />
              </div>
            </div>

            <div class="flex mt-6 py-4 space-x-4">
              <%= if @current_step > 1 and @current_step < 5 do %>
                <.button
                  tabindex="0"
                  type="button"
                  class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  phx-click="prev-step"
                >
                  <.icon name="hero-arrow-long-left" class="w-5 h-5 mr-2" /> Back
                </.button>
              <% end %>

              <%= if @current_step === 4 do %>
                <%= if Enum.any?(Keyword.keys(@changeset.errors), fn k -> k in [:password_reminder] end) do %>
                  <.button
                    type="button"
                    class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 disabled:opacity-50 pointer-events-none"
                    disabled
                  >
                    Waiting...
                  </.button>
                <% else %>
                  <.button
                    tabindex="1"
                    type="submit"
                    phx-disable-with="Registering..."
                    class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  >
                    Register
                  </.button>
                <% end %>
              <% else %>
                <.button
                  :if={!check_if_step_is_invalid(@current_step, @changeset)}
                  tabindex="0"
                  aria-label="continue button"
                  type="button"
                  class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  phx-click="next-step"
                >
                  Continue <.icon name="hero-arrow-long-right" class="w-5 h-5 ml-2" />
                </.button>
                <.button
                  :if={check_if_step_is_invalid(@current_step, @changeset)}
                  tabindex="0"
                  aria-label="continue button"
                  type="button"
                  class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
                  phx-click="next-step"
                  disabled
                >
                  Waiting...
                </.button>
              <% end %>
            </div>
          </.form>
        </div>

        <div
          tabindex="1"
          aria-label="existing account log-in link"
          class="flex justify-between text-sm dark:text-gray-200"
        >
          <p>
            Already have an account?
          </p>
          <.link navigate={~p"/auth/sign_in"} class=" hover:text-emerald-700 active:text-emerald-500">
            Sign in
          </.link>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def handle_info({:flash, key, message}, socket) do
    {:noreply, put_flash(socket, key, message)}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @doc """
  Generates a strong, memorable passphrase.
  We optionally pass random words and separators.
  """
  def handle_event("generate-password", _params, socket) do
    changeset = socket.assigns.changeset

    words = Enum.random([5, 6, 7])
    separator = Enum.random([" ", "-", "."])
    generated_passphrase = PassphraseGenerator.generate_passphrase(words, separator)

    changeset =
      changeset
      |> put_change(:password, generated_passphrase)

    changeset = Accounts.change_user_registration(%User{}, changeset.changes)

    {:noreply,
     socket
     |> assign(:generated_password?, true)
     |> assign_form(changeset)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"user" => %{"email" => email} = user_params}, socket) do
    with user_changeset <- User.registration_changeset(%User{}, user_params),
         true <- user_changeset.valid?,
         %{} = c_attrs <- user_changeset.changes.connection_map,
         {:ok, user} <- Accounts.register_user(user_changeset, c_attrs) do
      {:ok, _} =
        Accounts.deliver_user_confirmation_instructions(
          user,
          email,
          &url(~p"/auth/confirm/#{&1}")
        )

      {:noreply, socket |> assign(trigger_submit: true)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      false ->
        changeset =
          User.registration_changeset(%User{}, user_params)

        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      _error ->
        socket = put_flash(socket, :error, "There was an unexpected error trying to register.")
        {:noreply, push_patch(socket, to: ~p"/auth/register")}
    end
  end

  def handle_event("prev-step", _, socket) do
    new_step = max(socket.assigns.current_step - 1, 1)

    {:noreply,
     socket
     |> assign(:current_step, new_step)}
  end

  def handle_event("next-step", _, socket) do
    current_step = socket.assigns.current_step
    changeset = socket.assigns.changeset

    step_invalid = check_if_step_is_invalid(current_step, changeset)
    new_step = if step_invalid, do: current_step, else: current_step + 1

    if Map.has_key?(socket.assigns.changeset.changes, :email) do
      socket =
        socket
        |> assign(:temp_email, socket.assigns.changeset.changes.email)

      {:noreply,
       socket
       |> assign(:current_step, new_step)}
    else
      {:noreply,
       socket
       |> assign(:current_step, new_step)}
    end
  end

  defp check_if_step_is_invalid(current_step, changeset) do
    case current_step do
      1 ->
        Enum.any?(Keyword.keys(changeset.errors), fn k -> k in [:email, :email_hash] end)

      2 ->
        Enum.any?(Keyword.keys(changeset.errors), fn k -> k in [:username, :username_hash] end)

      3 ->
        Enum.any?(Keyword.keys(changeset.errors), fn k ->
          k in [:password, :password_confirmation]
        end)

      4 ->
        Enum.any?(Keyword.keys(changeset.errors), fn k ->
          k in [:password_reminder]
        end)

      _ ->
        true
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false, changeset: changeset)
    else
      assign(socket, form: form, changeset: changeset)
    end
  end
end
