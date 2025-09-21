defmodule MossletWeb.UserResetPasswordLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Reset Password">
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <MossletWeb.Layouts.theme_toggle />
      </:top_right>

      <%!-- Header with improved visual hierarchy --%>
      <div class="text-center mb-8 sm:mb-10">
        <%!-- Security badge section --%>
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/50 dark:border-teal-700/30 mb-4">
            <span class="text-2xl">🔐</span>
            <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
              Secure password reset
            </span>
          </div>
        </div>

        <%!-- Main heading with gradient --%>
        <h1 class={[
          "text-3xl sm:text-4xl lg:text-5xl font-bold tracking-tight leading-tight mb-4",
          "bg-gradient-to-r from-teal-500 to-emerald-500",
          "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
          "bg-clip-text text-transparent"
        ]}>
          Reset your password
        </h1>

        <%!-- Subtitle or warning message --%>
        <div :if={!@user.is_forgot_pwd? || !@user.key} class="max-w-md mx-auto">
          <.liquid_banner type="warning" icon="hero-exclamation-triangle" class="text-left">
            <:title>Password reset unavailable</:title>
            In order to maximize the security of your account, you cannot reset your password using this method. If you wish to change this, you must log in and change your account's
            <span class="italic font-semibold">forgot password</span>
            setting.
          </.liquid_banner>
        </div>

        <p
          :if={@user.is_forgot_pwd? && @user.key}
          class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto"
        >
          Enter your new password below to secure your account.
        </p>
      </div>

      <%!-- Password reset form with modern styling --%>
      <div :if={@user.is_forgot_pwd? && @user.key} class="space-y-6">
        <.form
          for={@form}
          id="reset_password_form"
          phx-submit="reset_password"
          phx-change="validate"
          class="space-y-6"
        >
          <%!-- New password field with liquid styling --%>
          <div class="space-y-2">
            <div class="flex justify-between items-center">
              <div></div>
              <%!-- Empty div to maintain layout --%>
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  id="eye"
                  data-tippy-content="Show password"
                  phx-hook="TippyHook"
                  phx-click={
                    JS.set_attribute({"type", "text"}, to: "##{@form[:password].id}")
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
                    JS.set_attribute({"type", "password"}, to: "##{@form[:password].id}")
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
              label="New password"
              placeholder="Enter your new password"
              required
              autocomplete="new-password"
              phx-debounce="blur"
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

          <%!-- Confirm password field with liquid styling --%>
          <div class="space-y-2">
            <.phx_input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              placeholder="Confirm your new password"
              required
              autocomplete="new-password"
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

          <%!-- Submit button with liquid metal styling --%>
          <div class="pt-4">
            <button
              type="submit"
              phx-disable-with="Resetting..."
              class={[
                "group relative w-full flex justify-center items-center gap-3",
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

              <.phx_icon
                name="hero-shield-check"
                class="relative w-5 h-5"
              />
              <span class="relative">Reset password</span>
            </button>
          </div>
        </.form>

        <%!-- Footer links with improved styling --%>
        <div class="pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex flex-col sm:flex-row items-center sm:justify-between gap-4 text-center sm:text-left">
            <.link
              navigate={~p"/auth/sign_in"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-arrow-left-start-on-rectangle" class="w-4 h-4" /> Back to sign in
            </.link>

            <.link
              navigate={~p"/auth/register"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-user-plus" class="w-4 h-4" /> Create account
            </.link>
          </div>
        </div>
      </div>

      <%!-- Footer links for when password reset is unavailable --%>
      <div :if={!@user.is_forgot_pwd? || !@user.key} class="space-y-6">
        <%!-- Footer links with improved styling --%>
        <div class="pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex flex-col sm:flex-row items-center sm:justify-between gap-4 text-center sm:text-left">
            <.link
              navigate={~p"/auth/sign_in"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-arrow-left-start-on-rectangle" class="w-4 h-4" /> Back to sign in
            </.link>

            <.link
              navigate={~p"/auth/register"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-user-plus" class="w-4 h-4" /> Create account
            </.link>
          </div>
        </div>
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
