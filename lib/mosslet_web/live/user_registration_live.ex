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
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <.color_scheme_switch />
      </:top_right>

      <%!-- Error banner with improved styling --%>
      <div
        :if={@check_errors}
        class="mb-6 p-4 rounded-xl bg-rose-50 border border-rose-200 dark:bg-rose-900/20 dark:border-rose-800/50"
      >
        <div class="flex items-start gap-3">
          <.icon
            name="hero-exclamation-triangle"
            class="w-5 h-5 text-rose-600 dark:text-rose-400 mt-0.5 flex-shrink-0"
          />
          <div>
            <h3 class="font-semibold text-rose-800 dark:text-rose-200 text-sm mb-2">
              Please check the following errors:
            </h3>
            <ul class="text-sm text-rose-700 dark:text-rose-300 space-y-1">
              <li :for={{atom, {msg, _validation}} <- @changeset.errors}>
                • {Atom.to_string(atom) |> String.split("_") |> List.first() |> String.capitalize()} {msg}
              </li>
            </ul>
          </div>
        </div>
      </div>

      <%!-- Header with improved visual hierarchy --%>
      <div class="text-center mb-8 sm:mb-10">
        <%!-- Welcome section --%>
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30 mb-4">
            <span class="text-2xl">🛡️</span>
            <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
              Join the privacy revolution
            </span>
          </div>
        </div>
        <%= case @current_step do %>
          <% 1 -> %>
            <h1 class={[
              "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
              "bg-clip-text text-transparent"
            ]}>
              Take back your privacy
            </h1>
            <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto mb-4">
              Start by setting up your email address. This will be your secure gateway to a surveillance-free social space.
            </p>
            <.step_indicator current={1} total={4} label="Email setup" />
          <% 2 -> %>
            <h1 class={[
              "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
              "bg-clip-text text-transparent"
            ]}>
              Choose your identity
            </h1>
            <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto mb-4">
              Your username is how trusted connections will find you. Choose something that feels right.
            </p>
            <.step_indicator current={2} total={4} label="Username setup" />
          <% 3 -> %>
            <h1 class={[
              "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
              "bg-clip-text text-transparent"
            ]}>
              Secure your sanctuary
            </h1>
            <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto mb-4">
              Create a strong password that protects your private space with unbreakable encryption.
            </p>
            <.step_indicator current={3} total={4} label="Password setup" />
          <% 4 -> %>
            <h1 class={[
              "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
              "bg-gradient-to-r from-teal-500 to-emerald-500",
              "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
              "bg-clip-text text-transparent"
            ]}>
              Almost there!
            </h1>
            <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto mb-4">
              Set up password recovery options to keep your account secure and accessible.
            </p>
            <.step_indicator current={4} total={4} label="Final setup" />
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
              <.phx_input
                field={@form[:email]}
                type="email"
                label="Email address"
                placeholder="Enter your email"
                required
                autocomplete="email"
                phx-debounce="500"
                tabindex="0"
                apply_classes?={true}
                classes={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "transition-all duration-200 ease-out",
                  "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
                {alpine_autofocus()}
              />
            </div>

            <div class={unless @current_step === 2, do: "hidden"}>
              <.phx_input
                field={@form[:username]}
                type="text"
                label="Username"
                placeholder="Choose your username"
                required
                autocomplete="username"
                phx-debounce="500"
                apply_classes?={true}
                classes={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "transition-all duration-200 ease-out",
                  "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
              />
            </div>

            <div id="step3" class={unless @current_step === 3, do: "hidden"}>
              <%!-- Enhanced password info section with better visual hierarchy --%>
              <div class="space-y-4 mb-6">
                <%!-- Main tip box --%>
                <div class="p-4 rounded-xl bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
                  <div class="flex items-start gap-3">
                    <div class="relative">
                      <.icon
                        name="hero-sparkles"
                        class="w-6 h-6 text-emerald-600 dark:text-emerald-400 mt-0.5 flex-shrink-0"
                      />
                      <%!-- Subtle glow effect --%>
                      <div class="absolute inset-0 w-6 h-6 bg-emerald-500/20 rounded-full blur-sm animate-pulse">
                      </div>
                    </div>
                    <div class="flex-1">
                      <h3 class="text-emerald-800 dark:text-emerald-200 font-semibold text-sm mb-2">
                        🛡️ Generate a bulletproof password
                      </h3>
                      <p class="text-emerald-700 dark:text-emerald-300 text-sm leading-relaxed mb-3">
                        Use the sparkles (✨) button to create a secure passphrase that even Big Tech can't crack.
                      </p>
                      <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.eff.org/dice"
                        class={[
                          "inline-flex items-center gap-1 text-xs font-medium",
                          "text-emerald-600 dark:text-emerald-400",
                          "hover:text-emerald-700 dark:hover:text-emerald-300",
                          "transition-colors duration-200",
                          "border-b border-emerald-300/50 hover:border-emerald-500"
                        ]}
                      >
                        <.icon name="hero-academic-cap" class="w-3 h-3" />
                        Learn about EFF's diceware method
                        <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
                      </.link>
                    </div>
                  </div>
                </div>

                <%!-- User-friendly security reminder --%>
                <div class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200/50 dark:border-slate-700/50">
                  <div class="flex items-center gap-2">
                    <.icon
                      name="hero-cog-6-tooth"
                      class="w-4 h-4 text-slate-600 dark:text-slate-400 flex-shrink-0"
                    />
                    <p class="text-xs text-slate-600 dark:text-slate-400">
                      Don't worry - you can change your password anytime in your settings
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Password field --%>
              <div class="space-y-2">
                <div class="flex justify-between items-center">
                  <div></div>
                  <%!-- Empty div to maintain layout --%>
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      id="pw-generator-button"
                      phx-hook="TippyHook"
                      data-tippy-content="Generate password"
                      phx-click={JS.push("generate-password")}
                      class="group p-1 rounded-lg hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-colors duration-200"
                    >
                      <.phx_icon
                        name="hero-sparkles"
                        class="h-5 w-5 text-slate-500 dark:text-slate-400 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors"
                      />
                    </button>
                    <button
                      type="button"
                      id="eye"
                      data-tippy-content="Show password"
                      phx-hook="TippyHook"
                      phx-click={
                        JS.set_attribute({"type", "text"}, to: "#password-text")
                        |> JS.remove_class("hidden", to: "#eye-slash")
                        |> JS.add_class("hidden", to: "#eye")
                      }
                      class="group p-1 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-200"
                    >
                      <.phx_icon
                        name="hero-eye"
                        class="h-5 w-5 text-slate-500 dark:text-slate-400 group-hover:text-slate-700 dark:group-hover:text-slate-300 transition-colors"
                      />
                    </button>
                    <button
                      type="button"
                      id="eye-slash"
                      data-tippy-content="Hide password"
                      phx-hook="TippyHook"
                      class="hidden group p-1 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "password"}, to: "#password-text")
                        |> JS.add_class("hidden", to: "#eye-slash")
                        |> JS.remove_class("hidden", to: "#eye")
                      }
                    >
                      <.phx_icon
                        name="hero-eye-slash"
                        class="h-5 w-5 text-slate-500 dark:text-slate-400 group-hover:text-slate-700 dark:group-hover:text-slate-300 transition-colors"
                      />
                    </button>
                  </div>
                </div>
                <.phx_input
                  field={@form[:password]}
                  type="password"
                  label="Password"
                  id="password-text"
                  placeholder="Create a strong password"
                  required
                  autocomplete="new-password"
                  phx-debounce="500"
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                    "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                    "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                    "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                    "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                    "transition-all duration-200 ease-out",
                    "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                    "text-base sm:text-sm sm:leading-6"
                  ]}
                />
              </div>

              <%!-- Password confirmation field --%>
              <div class="mt-4">
                <.phx_input
                  field={@form[:password_confirmation]}
                  type="password"
                  label="Confirm Password"
                  placeholder="Confirm your password"
                  required
                  autocomplete="new-password"
                  phx-debounce="500"
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                    "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                    "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                    "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                    "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                    "transition-all duration-200 ease-out",
                    "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                    "text-base sm:text-sm sm:leading-6"
                  ]}
                />
              </div>
            </div>

            <div class={unless @current_step === 4, do: "hidden"}>
              <%!-- Important notices --%>
              <div class="space-y-4 mb-6">
                <div class="p-4 rounded-xl bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-900/20 dark:to-cyan-900/20 border border-blue-200/50 dark:border-blue-700/30">
                  <div class="flex items-start gap-3">
                    <.icon
                      name="hero-shield-check"
                      class="w-5 h-5 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0"
                    />
                    <div class="text-sm">
                      <p class="text-blue-700 dark:text-blue-300 font-medium mb-1">
                        Your privacy, your responsibility
                      </p>
                      <p class="text-blue-600 dark:text-blue-400">
                        Your password is the only key to your encrypted data. We recommend using a password manager.
                      </p>
                    </div>
                  </div>
                </div>

                <div class="p-4 rounded-xl bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 border border-amber-200/50 dark:border-amber-700/30">
                  <div class="flex items-start gap-3">
                    <.icon
                      name="hero-exclamation-triangle"
                      class="w-5 h-5 text-amber-600 dark:text-amber-400 mt-0.5 flex-shrink-0"
                    />
                    <div class="text-sm">
                      <p class="text-amber-700 dark:text-amber-300 font-medium mb-1">
                        Recovery is optional but recommended
                      </p>
                      <p class="text-amber-600 dark:text-amber-400">
                        You can enable "Forgot Password?" recovery later in settings. Without it, losing your password means losing access forever.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Password reminder checkbox --%>
              <.phx_input
                field={@form[:password_reminder]}
                type="checkbox"
                label="I understand that losing my password could mean losing access to my account forever"
                required
                apply_classes?={true}
                classes={[
                  "h-5 w-5 rounded border-2 border-slate-300 dark:border-slate-600",
                  "bg-white dark:bg-slate-700 text-emerald-600 focus:ring-emerald-500/50 focus:ring-2 focus:ring-offset-2",
                  "dark:focus:ring-offset-slate-800",
                  "transition-all duration-200 ease-out",
                  "hover:border-emerald-400 dark:hover:border-emerald-500",
                  "checked:bg-gradient-to-br checked:from-emerald-500 checked:to-teal-600",
                  "checked:border-emerald-500 dark:checked:border-emerald-400"
                ]}
              />
            </div>

            <%!-- Form buttons with liquid metal styling --%>
            <div class="pt-4">
              <div class="flex gap-4">
                <%= if @current_step > 1 and @current_step < 5 do %>
                  <button
                    type="button"
                    tabindex="0"
                    phx-click="prev-step"
                    class={[
                      "group relative flex justify-center items-center gap-3",
                      "rounded-xl py-4 px-6 text-base font-semibold flex-1",
                      "bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-200",
                      "border border-slate-300 dark:border-slate-600",
                      "hover:bg-slate-50 dark:hover:bg-slate-600",
                      "transition-all duration-200 ease-out transform-gpu",
                      "hover:scale-[1.02] active:scale-[0.98]",
                      "focus:outline-none focus:ring-2 focus:ring-slate-500/50 focus:ring-offset-2",
                      "dark:focus:ring-offset-slate-800"
                    ]}
                  >
                    <.phx_icon
                      name="hero-arrow-left"
                      class="relative w-5 h-5 transition-transform group-hover:-translate-x-1"
                    />
                    <span class="relative">Back</span>
                  </button>
                <% end %>

                <%= if @current_step === 4 do %>
                  <%= if Enum.any?(Keyword.keys(@changeset.errors), fn k -> k in [:password_reminder] end) do %>
                    <button
                      type="button"
                      disabled
                      class={[
                        "group relative flex justify-center items-center gap-3 flex-1",
                        "rounded-xl py-4 px-6 text-base font-semibold",
                        "bg-slate-300 dark:bg-slate-600 text-slate-500 dark:text-slate-400",
                        "cursor-not-allowed opacity-50"
                      ]}
                    >
                      <span class="relative">Please accept the terms above</span>
                    </button>
                  <% else %>
                    <button
                      type="submit"
                      tabindex="1"
                      phx-disable-with="Creating your sanctuary..."
                      class={[
                        "group relative flex justify-center items-center gap-3 flex-1",
                        "rounded-xl py-4 px-6 text-base font-semibold",
                        "bg-gradient-to-r from-teal-500 to-emerald-500",
                        "hover:from-teal-600 hover:to-emerald-600",
                        "text-white shadow-lg shadow-emerald-500/25",
                        "transition-all duration-200 ease-out transform-gpu",
                        "hover:scale-[1.02] active:scale-[0.98]",
                        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                        "dark:focus:ring-offset-slate-800",
                        "disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
                      ]}
                    >
                      <%!-- Button shimmer effect --%>
                      <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-transparent via-white/20 to-transparent opacity-0 group-hover:opacity-100 group-hover:animate-[shimmer_1s_ease-out] transition-opacity duration-200">
                      </div>

                      <span class="relative">Join the revolution</span>
                      <.phx_icon
                        name="hero-shield-check"
                        class="relative w-5 h-5 transition-transform group-hover:scale-110"
                      />
                    </button>
                  <% end %>
                <% else %>
                  <%= if check_if_step_is_invalid(@current_step, @changeset) do %>
                    <button
                      type="button"
                      tabindex="0"
                      disabled
                      class={[
                        "group relative flex justify-center items-center gap-3 flex-1",
                        "rounded-xl py-4 px-6 text-base font-semibold",
                        "bg-slate-300 dark:bg-slate-600 text-slate-500 dark:text-slate-400",
                        "cursor-not-allowed opacity-50"
                      ]}
                    >
                      <span class="relative">
                        <.phx_icon name="hero-clock" class="size-5 mr-2" />
                        Complete step {@current_step}
                      </span>
                    </button>
                  <% else %>
                    <button
                      type="button"
                      tabindex="0"
                      phx-click="next-step"
                      class={[
                        "group relative flex justify-center items-center gap-3 flex-1",
                        "rounded-xl py-4 px-6 text-base font-semibold",
                        "bg-gradient-to-r from-teal-500 to-emerald-500",
                        "hover:from-teal-600 hover:to-emerald-600",
                        "text-white shadow-lg shadow-emerald-500/25",
                        "transition-all duration-200 ease-out transform-gpu",
                        "hover:scale-[1.02] active:scale-[0.98]",
                        "focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2",
                        "dark:focus:ring-offset-slate-800"
                      ]}
                    >
                      <%!-- Button shimmer effect --%>
                      <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-transparent via-white/20 to-transparent opacity-0 group-hover:opacity-100 group-hover:animate-[shimmer_1s_ease-out] transition-opacity duration-200">
                      </div>

                      <span class="relative">Continue</span>
                      <.phx_icon
                        name="hero-arrow-right"
                        class="relative w-5 h-5 transition-transform group-hover:translate-x-1"
                      />
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>
          </.form>
        </div>

        <%!-- Footer link with improved styling and proper spacing --%>
        <div class="mt-6 pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex flex-col sm:flex-row items-center sm:justify-between gap-4 text-center sm:text-left">
            <span class="text-sm text-slate-600 dark:text-slate-400">
              Already have an account?
            </span>
            <.link
              navigate={~p"/auth/sign_in"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" /> Sign in instead
            </.link>
          </div>
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
    changeset =
      Accounts.change_user_registration(%User{}, user_params)
      |> Map.put(:action, :update)

    {:noreply, assign_form(socket, changeset)}
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

  # Enhanced step indicator component with improved design system alignment
  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center justify-center mb-2">
      <div class="inline-flex items-center gap-3 px-4 py-2 rounded-full bg-gradient-to-r from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 border border-slate-200/50 dark:border-slate-600/50">
        <%!-- Animated progress dot --%>
        <div class="relative">
          <span class="flex h-3 w-3 rounded-full bg-gradient-to-r from-emerald-500 to-teal-500 shadow-sm shadow-emerald-500/50">
          </span>
          <%!-- Pulse animation --%>
          <span class="absolute inset-0 h-3 w-3 rounded-full bg-gradient-to-r from-emerald-400 to-teal-400 animate-ping opacity-20">
          </span>
        </div>

        <%!-- Step progress with better typography --%>
        <div class="flex items-center gap-2 text-sm">
          <span class="font-semibold text-slate-700 dark:text-slate-200">
            Step {@current}
          </span>
          <span class="text-slate-400 dark:text-slate-500">/</span>
          <span class="text-slate-500 dark:text-slate-400">{@total}</span>
          <span class="text-slate-300 dark:text-slate-600 mx-1">•</span>
          <span class="font-medium text-slate-600 dark:text-slate-300">
            {@label}
          </span>
        </div>

        <%!-- Subtle progress bar --%>
        <div class="hidden sm:flex items-center ml-2">
          <div class="w-16 h-1 bg-slate-200 dark:bg-slate-600 rounded-full overflow-hidden">
            <div
              class="h-full bg-gradient-to-r from-emerald-500 to-teal-500 rounded-full transition-all duration-500 ease-out"
              style={"width: #{(@current / @total * 100)}%"}
            >
            </div>
          </div>
        </div>
      </div>
    </div>
    """
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
