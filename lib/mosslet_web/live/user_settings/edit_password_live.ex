defmodule MossletWeb.EditPasswordLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Extensions.PasswordGenerator.PassphraseGenerator
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       trigger_submit: false,
       form: to_form(Accounts.change_user_password(socket.assigns.current_scope.user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout
      current_scope={@current_scope}
      current_page={:edit_password}
      sidebar_current_page={:edit_password}
      type="sidebar"
    >
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Password Settings
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Update your password to keep your MOSSLET account secure.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-2xl">
          <%!-- Password Generator Tip Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-purple-50/50 to-violet-50/30 dark:from-purple-900/20 dark:to-violet-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
                  <.phx_icon
                    name="hero-light-bulb"
                    class="h-4 w-4 text-purple-600 dark:text-purple-400"
                  />
                </div>
                <span class="text-purple-800 dark:text-purple-200">Password Generator Tip</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-purple-700 dark:text-purple-300">
                Generate a strong, memorable password using the
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-semibold rounded-lg bg-gradient-to-r from-purple-500 to-violet-500 text-white border border-purple-600">
                  <.phx_icon name="hero-sparkles" class="h-3.5 w-3.5" /> Generate
                </span>
                button positioned above the new password field.
              </p>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <span class="text-sm text-purple-600 dark:text-purple-400">
                  Uses EFF's Diceware method for security
                </span>
                <DesignSystem.liquid_button
                  href="https://www.eff.org/dice"
                  target="_blank"
                  rel="noopener noreferrer"
                  variant="secondary"
                  color="purple"
                  size="sm"
                  icon="hero-arrow-top-right-on-square"
                  class="text-purple-700 dark:text-purple-300 hover:text-purple-800 dark:hover:text-purple-200 self-start sm:self-auto"
                >
                  Learn More
                </DesignSystem.liquid_button>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <%!-- Password Change Form Card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-teal-100 via-emerald-50 to-teal-100 dark:from-teal-900/30 dark:via-emerald-900/25 dark:to-teal-900/30">
                  <.phx_icon name="hero-key" class="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                </div>
                <span>Change Password</span>
              </div>
            </:title>

            <.form
              for={@form}
              action={~p"/auth/sign_in?_action=password_updated"}
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="space-y-8"
            >
              <%!-- Hidden email field for form submission --%>
              <input
                type="hidden"
                name="email"
                value={decr(@current_user.email, @current_user, @key)}
              />

              <%!-- Current Password Section --%>
              <div class="space-y-3">
                <label class="block text-sm font-medium text-slate-900 dark:text-slate-100">
                  Current Password <span class="text-rose-500 ml-1">*</span>
                </label>

                <div class="group relative">
                  <%!-- Enhanced liquid background effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
                  </div>

                  <%!-- Enhanced shimmer effect on focus --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
                  </div>

                  <%!-- Focus ring with liquid metal styling --%>
                  <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
                  </div>

                  <%!-- Secondary focus ring for better definition --%>
                  <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
                  </div>

                  <%!-- Password input with show/hide functionality --%>
                  <input
                    type="password"
                    id="user_current_password"
                    name="user[current_password]"
                    required
                    class={[
                      "relative block w-full rounded-xl px-4 py-3 pr-12 text-slate-900 dark:text-slate-100",
                      "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                      "border-2 border-slate-200 dark:border-slate-700",
                      "hover:border-slate-300 dark:hover:border-slate-600",
                      "focus:border-emerald-500 dark:focus:border-emerald-400",
                      "focus:outline-none focus:ring-0",
                      "transition-all duration-200 ease-out",
                      "sm:text-sm sm:leading-6",
                      "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
                      "focus:bg-white dark:focus:bg-slate-800"
                    ]}
                    placeholder="Enter your current password"
                  />

                  <%!-- Show/Hide password buttons with liquid styling --%>
                  <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                    <button
                      type="button"
                      id="eye-current-password"
                      aria-label="Show current password"
                      data-tippy-content="Show current password"
                      phx-hook="TippyHook"
                      class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "text"}, to: "#user_current_password")
                        |> JS.remove_class("hidden", to: "#eye-slash-current-password")
                        |> JS.add_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                    </button>
                    <button
                      type="button"
                      id="eye-slash-current-password"
                      aria-label="Hide current password"
                      data-tippy-content="Hide current password"
                      phx-hook="TippyHook"
                      class="hidden group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "password"}, to: "#user_current_password")
                        |> JS.add_class("hidden", to: "#eye-slash-current-password")
                        |> JS.remove_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye-slash"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                    </button>
                  </div>
                </div>
              </div>

              <%!-- New Password Section --%>
              <div class="space-y-3">
                <div class="relative">
                  <%!-- Label and Generate button container with proper alignment --%>
                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 sm:gap-0 mb-3">
                    <label class="flex items-center gap-1 text-sm font-medium text-slate-900 dark:text-slate-100">
                      New Password <span class="text-rose-500">*</span>
                    </label>
                    <button
                      type="button"
                      id="pw-generator-button"
                      phx-hook="TippyHook"
                      data-tippy-content="Generate secure password"
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold rounded-lg border transition-all duration-200 ease-out transform-gpu bg-gradient-to-r from-purple-500 to-violet-500 hover:from-purple-600 hover:to-violet-600 border-purple-600 hover:border-purple-700 text-white shadow-sm hover:shadow-md hover:scale-105 active:scale-95 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:ring-offset-2 self-start sm:self-auto"
                      phx-click={JS.push("generate-password")}
                    >
                      <.phx_icon name="hero-sparkles" class="h-3.5 w-3.5" />
                      <span class="whitespace-nowrap">Generate</span>
                    </button>
                  </div>

                  <%!-- Input field with eye toggle --%>
                  <div class="group relative">
                    <%!-- Enhanced liquid background effect on focus --%>
                    <div class="absolute inset-0 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-emerald-50/30 via-teal-50/40 to-emerald-50/30 dark:from-emerald-900/15 dark:via-teal-900/20 dark:to-emerald-900/15 group-focus-within:opacity-100 rounded-xl">
                    </div>

                    <%!-- Enhanced shimmer effect on focus --%>
                    <div class="absolute inset-0 opacity-0 transition-all duration-700 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-focus-within:opacity-100 group-focus-within:translate-x-full -translate-x-full rounded-xl">
                    </div>

                    <%!-- Focus ring with liquid metal styling --%>
                    <div class="absolute -inset-1 opacity-0 transition-all duration-200 ease-out rounded-xl bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 group-focus-within:opacity-100 blur-sm">
                    </div>

                    <%!-- Secondary focus ring for better definition --%>
                    <div class="absolute -inset-0.5 opacity-0 transition-all duration-200 ease-out rounded-xl border-2 border-emerald-500 dark:border-emerald-400 group-focus-within:opacity-100">
                    </div>

                    <%!-- Password input with show/hide functionality --%>
                    <input
                      type="password"
                      id="user_password"
                      name="user[password]"
                      required
                      class={[
                        "relative block w-full rounded-xl px-4 py-3 pr-12 text-slate-900 dark:text-slate-100",
                        "bg-slate-50 dark:bg-slate-900 placeholder:text-slate-500 dark:placeholder:text-slate-400",
                        "border-2 border-slate-200 dark:border-slate-700",
                        "hover:border-slate-300 dark:hover:border-slate-600",
                        "focus:border-emerald-500 dark:focus:border-emerald-400",
                        "focus:outline-none focus:ring-0",
                        "transition-all duration-200 ease-out",
                        "sm:text-sm sm:leading-6",
                        "shadow-sm focus:shadow-lg focus:shadow-emerald-500/10",
                        "focus:bg-white dark:focus:bg-slate-800"
                      ]}
                      placeholder="Enter your new password"
                      value={@form[:password].value}
                    />

                    <%!-- Show/Hide password buttons with liquid styling --%>
                    <div class="absolute inset-y-0 right-0 flex items-center pr-3">
                      <button
                        type="button"
                        id="eye-new-password"
                        aria-label="Show new password"
                        data-tippy-content="Show new password"
                        phx-hook="TippyHook"
                        class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                        phx-click={
                          JS.set_attribute({"type", "text"}, to: "#user_password")
                          |> JS.remove_class("hidden", to: "#eye-slash-new-password")
                          |> JS.add_class("hidden", to: "#eye-new-password")
                        }
                      >
                        <.phx_icon
                          name="hero-eye"
                          class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                        />
                      </button>
                      <button
                        type="button"
                        id="eye-slash-new-password"
                        aria-label="Hide new password"
                        data-tippy-content="Hide new password"
                        phx-hook="TippyHook"
                        class="hidden group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                        phx-click={
                          JS.set_attribute({"type", "password"}, to: "#user_password")
                          |> JS.add_class("hidden", to: "#eye-slash-new-password")
                          |> JS.remove_class("hidden", to: "#eye-new-password")
                        }
                      >
                        <.phx_icon
                          name="hero-eye-slash"
                          class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                        />
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Confirm New Password --%>
              <DesignSystem.liquid_input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm New Password"
                placeholder="Confirm your new password"
                required
              />

              <%!-- Action buttons --%>
              <div class="flex flex-col sm:flex-row justify-between gap-4 pt-6">
                <DesignSystem.liquid_button
                  type="button"
                  variant="ghost"
                  color="slate"
                  phx-click="send_password_reset_email"
                  phx-value-email={decr(@current_user.email, @current_user, @key)}
                  data-confirm={
                    gettext("This will send a reset password link to the email '%{email}'. Continue?",
                      email: decr(@current_user.email, @current_user, @key)
                    )
                  }
                  icon="hero-envelope"
                >
                  Forgot Password?
                </DesignSystem.liquid_button>

                <DesignSystem.liquid_button
                  type="submit"
                  phx-disable-with="Updating..."
                  icon="hero-key"
                >
                  Update Password
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Security Tips Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-blue-600 dark:text-blue-400"
                  />
                </div>
                <span class="text-blue-800 dark:text-blue-200">Security Best Practices</span>
              </div>
            </:title>

            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Use unique passwords
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Don't reuse passwords across different services
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Use a password manager
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Store passwords securely and generate strong ones
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Enable 2FA when available
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Add an extra layer of security to your accounts
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-check-circle"
                      class="h-4 w-4 text-blue-600 dark:text-blue-400"
                    />
                    <span class="text-sm font-semibold text-blue-800 dark:text-blue-200">
                      Update regularly
                    </span>
                  </div>
                  <p class="text-sm text-blue-700 dark:text-blue-300 ml-6">
                    Change passwords periodically, especially if compromised
                  </p>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
    """
  end

  @doc """
  Generates a strong, memorable passphrase.
  We optionally pass random words and separators.
  """
  def handle_event("generate-password", _params, socket) do
    current_user = socket.assigns.current_scope.user

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
    current_password = Map.get(params, "current_password", "")
    user_params = Map.get(params, "user", %{})

    form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, change_password: true)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, current_password: current_password)}
  end

  def handle_event("update_password", params, socket) do
    current_password = Map.get(params, "current_password", "")
    user_params = Map.get(params, "user", %{})
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    case Accounts.update_user_password(user, current_password, user_params,
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
      socket.assigns.current_scope.user,
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
