defmodule MossletWeb.UserForgotPasswordLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

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
        <%!-- Reset password section --%>
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-900/20 dark:to-cyan-900/20 border border-blue-200/50 dark:border-blue-700/30 mb-4">
            <span class="text-2xl">🔐</span>
            <span class="text-sm font-medium text-blue-700 dark:text-blue-300">
              Password recovery
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
          Forgot your password?
        </h1>

        <%!-- Subtitle --%>
        <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto">
          Enter the email used with your account and we'll send a password reset link to your inbox.
        </p>
      </div>

      <%!-- Reset password form with modern styling --%>
      <div class="space-y-6">
        <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-6">
          <%!-- Email field with liquid styling --%>
          <div class="space-y-2">
            <label
              for={@form[:email].name}
              class="block text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              Email address
            </label>
            <div class="relative">
              <input
                type="email"
                name={@form[:email].name}
                id={@form[:email].id}
                value={@form[:email].value}
                autocomplete="email"
                required
                {alpine_autofocus()}
                class={[
                  "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                  "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                  "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                  "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                  "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                  "transition-all duration-200 ease-out",
                  "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                  "text-base sm:text-sm sm:leading-6"
                ]}
                placeholder="Enter your email"
              />
              <%!-- Input shimmer effect --%>
              <div class="absolute inset-0 rounded-xl bg-gradient-to-r from-transparent via-emerald-500/5 to-transparent opacity-0 hover:opacity-100 transition-opacity duration-300 pointer-events-none">
              </div>
            </div>
          </div>

          <%!-- Submit button with liquid metal styling --%>
          <div class="pt-4">
            <button
              type="submit"
              phx-disable-with="Sending..."
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
                name="hero-paper-airplane"
                class="relative w-5 h-5"
              />
              <span class="relative">Send password reset instructions</span>
            </button>
          </div>
        </.form>

        <%!-- Footer links with improved spacing and styling --%>
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
              <.icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" /> Back to sign in
            </.link>

            <.link
              navigate={~p"/auth/register"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.icon name="hero-user-plus" class="w-4 h-4" /> Create account
            </.link>
          </div>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"), page_title: "Forgot Your Password?")}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        email,
        &url(~p"/auth/reset-password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:success, info)
     |> redirect(to: ~p"/")}
  end
end
