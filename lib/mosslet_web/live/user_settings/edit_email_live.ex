defmodule MossletWeb.EditEmailLive do
  @moduledoc false
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias Mosslet.Encrypted.Users.Utils
  alias MossletWeb.DesignSystem

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Settings",
       form: to_form(Accounts.change_user_email(socket.assigns.current_user))
     )}
  end

  def render(assigns) do
    ~H"""
    <.layout current_user={@current_user} current_page={:edit_email} sidebar_current_page={:edit_email} key={@key} type="sidebar">
      <DesignSystem.liquid_container max_width="lg" class="py-16">
        <%!-- Page header with liquid metal styling --%>
        <div class="mb-12">
          <div class="mb-8">
            <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Email Settings
            </h1>
            <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
              Manage the email address belonging to your MOSSLET account.
            </p>
          </div>
          <%!-- Decorative accent line --%>
          <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
          </div>
        </div>

        <div class="space-y-8 max-w-3xl">
          <%!-- Admin status buttons --%>
          <div
            :if={
              !@current_user.is_admin? &&
                decr(@form[:email].value, @current_user, @key) === Encrypted.Session.admin_email() &&
                @current_user.confirmed_at
            }
            class="flex justify-center mb-8"
          >
            <DesignSystem.liquid_button
              phx-click="update_admin"
              variant="secondary"
              color="blue"
              icon="hero-shield-check"
            >
              Set Admin
            </DesignSystem.liquid_button>
          </div>

          <div
            :if={
              @current_user.is_admin? &&
                decr(@form[:email].value, @current_user, @key) === Encrypted.Session.admin_email() &&
                @current_user.confirmed_at
            }
            class="flex justify-center mb-8"
          >
            <DesignSystem.liquid_button
              phx-click="update_admin"
              variant="primary"
              color="rose"
              icon="hero-shield-exclamation"
            >
              Revoke Admin
            </DesignSystem.liquid_button>
          </div>

          <%!-- Email form with liquid card --%>
          <DesignSystem.liquid_card>
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
                  <.phx_icon name="hero-envelope" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
                </div>
                Change Email Address
              </div>
            </:title>

            <.form id="change_email_form" for={@form} phx-submit="update_email" class="space-y-6">
              <DesignSystem.liquid_input
                field={@form[:email]}
                type="email"
                label="New Email Address"
                placeholder="Enter your new email address"
                value={decr(@form[:email].value, @current_user, @key)}
                required
                help="We'll send a confirmation link to verify your new email address."
              />

              <%!-- Current password field with enhanced styling --%>
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
                    id="current-password"
                    name="current_password"
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
                      data-tippy-content="Show current password"
                      phx-hook="TippyHook"
                      class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200"
                      phx-click={
                        JS.set_attribute({"type", "text"}, to: "#current-password")
                        |> JS.remove_class("hidden", to: "#eye-slash-current-password")
                        |> JS.add_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                      <span class="sr-only">Show current password</span>
                    </button>
                    <button
                      type="button"
                      id="eye-slash-current-password"
                      data-tippy-content="Hide current password"
                      phx-hook="TippyHook"
                      class="group/eye p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-200 hidden"
                      phx-click={
                        JS.set_attribute({"type", "password"}, to: "#current-password")
                        |> JS.add_class("hidden", to: "#eye-slash-current-password")
                        |> JS.remove_class("hidden", to: "#eye-current-password")
                      }
                    >
                      <.phx_icon
                        name="hero-eye-slash"
                        class="h-5 w-5 text-slate-400 dark:text-slate-500 group-hover/eye:text-emerald-600 dark:group-hover/eye:text-emerald-400 transition-colors duration-200"
                      />
                      <span class="sr-only">Hide current password</span>
                    </button>
                  </div>
                </div>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Confirm your current password to proceed with the email change.
                </p>
              </div>

              <%!-- Submit button --%>
              <div class="flex justify-end pt-4">
                <DesignSystem.liquid_button
                  type="submit"
                  icon="hero-envelope"
                  color="blue"
                >
                  Change Email
                </DesignSystem.liquid_button>
              </div>
            </.form>
          </DesignSystem.liquid_card>

          <%!-- Email Promise Card --%>
          <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
            <:title>
              <div class="flex items-center gap-3">
                <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
                  <.phx_icon
                    name="hero-shield-check"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <span class="text-emerald-800 dark:text-emerald-200">Our Email Promise</span>
              </div>
            </:title>

            <div class="space-y-4">
              <p class="text-emerald-700 dark:text-emerald-300 leading-relaxed">
                MOSSLET respects your inbox as much as we respect your attention.
                We commit to <strong class="font-medium">never sending you</strong>:
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-x-circle"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Marketing emails
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    No promotional content ever
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-x-circle"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Newsletters
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    No regular updates or digests
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-x-circle"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Activity summaries
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    No "you missed this" emails
                  </p>
                </div>

                <div class="space-y-2">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-x-circle"
                      class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                    />
                    <span class="text-sm font-semibold text-emerald-800 dark:text-emerald-200">
                      Third-party promotions
                    </span>
                  </div>
                  <p class="text-sm text-emerald-700 dark:text-emerald-300 ml-6">
                    We never share your email
                  </p>
                </div>
              </div>

              <div class="pt-4 border-t border-emerald-200 dark:border-emerald-700">
                <p class="text-sm text-emerald-700 dark:text-emerald-300">
                  <span class="font-medium">Your email address is sacred to us.</span>
                  We use it only for essential account operations and security – never for marketing or engagement tactics.
                </p>
              </div>
            </div>
          </DesignSystem.liquid_card>
        </div>
      </DesignSystem.liquid_container>
    </.layout>
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
