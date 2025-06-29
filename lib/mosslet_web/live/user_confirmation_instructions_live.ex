defmodule MossletWeb.UserConfirmationInstructionsLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Register">
      <div class="flex flex-col items-start justify-start">
        <.link navigate="/" class="-ml-4">
          <.logo class="mb-2 h-16 w-auto" />
        </.link>

        <h2 class="mt-16 text-lg font-semibold text-gray-900 dark:text-white">
          Please check your email for a link to confirm your account.
        </h2>
        <p class="mt-2 text-sm text-gray-700 dark:text-gray-400">
          No confirmation instructions received? Check your spam folder or enter your email below and we'll send a new confirmation link to your inbox.
        </p>
      </div>
      <div class="mt-10 mx-auto max-w-sm">
        <.form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
          <.field
            field={@form[:email]}
            type="email"
            placeholder="Enter your account email"
            autocomplete="off"
            required
          />

          <.button phx-disable-with="Sending..." class="w-full rounded-full">
            Resend confirmation instructions
          </.button>
        </.form>

        <div :if={is_nil(@current_user)} class="py-4 flex justify-between text-sm dark:text-gray-200">
          <.link navigate={~p"/auth/sign_in"} class=" hover:text-emerald-600 active:text-emerald-500">
            Login
          </.link>
          <.link navigate={~p"/auth/register"} class=" hover:text-emerald-600 active:text-emerald-500">
            Register
          </.link>
        </div>
        <div :if={!is_nil(@current_user)} class="py-4 flex justify-end text-sm dark:text-gray-200">
          <.link
            navigate={~p"/app/users/delete-account"}
            class=" hover:text-emerald-600 active:text-emerald-500"
          >
            Delete Account
          </.link>
        </div>
      </div>
    </.mosslet_auth_layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{}, as: "user"),
       page_title: "Resend Confirmation Instructions"
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
