defmodule MossletWeb.UserConfirmationInstructionsLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Confirm Email">
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <.color_scheme_switch />
      </:top_right>

      <%!-- Header with improved visual hierarchy --%>
      <div class="text-center mb-8 sm:mb-10">
        <%!-- Status section --%>
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/50 dark:border-teal-700/30 mb-4">
            <span class="text-2xl">📧</span>
            <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
              Check your inbox
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
          Almost there!
        </h1>

        <%!-- Main message --%>
        <p class="text-lg font-medium text-slate-800 dark:text-slate-200 max-w-lg mx-auto mb-4">
          Please check your email for a link to confirm your account.
        </p>

        <%!-- Subtitle --%>
        <p class="text-sm text-slate-600 dark:text-slate-400 max-w-md mx-auto">
          No confirmation instructions received? Check your spam folder or enter your email below and we'll send a new confirmation link to your inbox.
        </p>
      </div>

      <%!-- Resend form with modern styling --%>
      <div class="space-y-6">
        <.form
          for={@form}
          id="resend_confirmation_form"
          phx-submit="send_instructions"
          class="space-y-6"
        >
          <%!-- Email field with liquid styling --%>
          <.phx_input
            field={@form[:email]}
            type="email"
            label="Email address"
            placeholder="Enter your account email"
            required
            autocomplete="email"
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

          <%!-- Submit button with liquid metal styling --%>
          <div class="pt-4">
            <button
              type="submit"
              phx-disable-with="Sending instructions..."
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
              <span class="relative">Resend confirmation instructions</span>
            </button>
          </div>
        </.form>

        <%!-- Footer links with improved spacing and styling --%>
        <div class="pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div
            :if={is_nil(@current_user)}
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 text-center sm:text-left"
          >
            <.link
              navigate={~p"/auth/sign_in"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" /> Back to sign in
            </.link>

            <.link
              navigate={~p"/auth/register"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-user-plus" class="w-4 h-4" /> Create new account
            </.link>
          </div>

          <div :if={!is_nil(@current_user)} class="flex justify-center">
            <.link
              navigate={~p"/app/users/delete-account"}
              class={[
                "inline-flex items-center gap-2 text-sm font-medium",
                "text-rose-600 hover:text-rose-700 dark:text-rose-400 dark:hover:text-rose-300",
                "transition-colors duration-200"
              ]}
            >
              <.phx_icon name="hero-trash" class="w-4 h-4" /> Delete account
            </.link>
          </div>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{}, as: "user"),
       page_title: "Confirm Email"
     )}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        email,
        &url(~p"/auth/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:success, info)
     |> redirect(to: ~p"/")}
  end
end
