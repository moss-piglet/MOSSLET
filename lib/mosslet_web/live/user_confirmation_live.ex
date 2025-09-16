defmodule MossletWeb.UserConfirmationLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Confirm Account">
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <.color_scheme_switch />
      </:top_right>

      <%!-- Header with improved visual hierarchy --%>
      <div class="text-center mb-8 sm:mb-10">
        <%!-- Success section --%>
        <div class="mb-6">
          <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30 mb-4">
            <span class="text-2xl">✅</span>
            <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
              Ready to confirm
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
          Confirm your account
        </h1>

        <%!-- Subtitle --%>
        <p class="text-lg text-slate-600 dark:text-slate-300 max-w-md mx-auto">
          Click the button below to confirm your account and start your privacy journey.
        </p>
      </div>

      <%!-- Confirmation form with modern styling --%>
      <div class="space-y-6">
        <.form for={@form} id="confirmation_form" phx-submit="confirm_account" class="space-y-6">
          <.phx_input field={@form[:token]} type="hidden" />

          <%!-- Submit button with liquid metal styling --%>
          <div class="pt-4">
            <.liquid_button
              type="submit"
              size="lg"
              icon="hero-check-circle"
              phx-disable-with="Confirming your account..."
              class="w-full"
            >
              Confirm my account
            </.liquid_button>
          </div>
        </.form>

        <%!-- Footer links with improved spacing and styling --%>
        <div class="pt-6 border-t border-slate-200/50 dark:border-slate-700/50">
          <div class="flex justify-center">
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
          </div>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")

    {:ok, assign(socket, form: form, page_title: "Confirm Your Account"),
     temporary_assigns: [form: nil]}
  end

  # Do not log in the user after confirmation to avoid a
  # leaked token giving the user access to the account.
  #
  # Not currently being used (?) <- what does this mean?
  def handle_event("confirm_account", %{"user" => %{"token" => token}}, socket) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:success, "Account confirmed successfully.")
         |> redirect(to: ~p"/app")}

      :error ->
        # If there is a current user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the user themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "User confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end
