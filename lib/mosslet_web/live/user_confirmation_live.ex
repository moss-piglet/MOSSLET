defmodule MossletWeb.UserConfirmationLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Resend Confirmation Instructions">
      <div class="flex flex-col items-start justify-start">
        <.link navigate="/" class="-ml-4">
          <.logo class="mb-2 h-16 w-auto" />
        </.link>

        <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          Confirm Account
        </h2>
        <p class="mt-2 text-sm text-gray-700 dark:text-gray-400">
          Click the button below to confirm your account email.
        </p>
      </div>
      <div class="mt-10 mx-auto max-w-sm">
        <.form for={@form} id="confirmation_form" phx-submit="confirm_account">
          <.field field={@form[:token]} type="hidden" />

          <.button phx-disable-with="Confirming..." class="w-full rounded-full">
            Confirm my account
          </.button>
        </.form>
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
