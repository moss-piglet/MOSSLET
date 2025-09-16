defmodule MossletWeb.UserForgotPasswordLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Reset Password">
      <div class="flex flex-col items-start justify-start">
        <.link navigate="/" class="-ml-4">
          <.logo class="mb-2 h-16 w-auto" />
        </.link>

        <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          Forgot your password?
        </h2>
        <p class="mt-2 text-sm text-gray-700 dark:text-gray-400">
          Enter the email used with your account and we'll send a password reset link to your inbox.
        </p>
      </div>
      <div class="mt-10">
        <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-6">
          <.field
            field={@form[:email]}
            type="email"
            placeholder="isabella@example.com"
            autocomplete="off"
            required
          />

          <button
            phx-disable-with="Sending..."
            class="w-full rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
          >
            Send password reset instructions
          </button>
        </.form>

        <div class="mt-6 flex justify-between text-sm dark:text-gray-200">
          <.link navigate={~p"/auth/sign_in"} class=" hover:text-emerald-600 active:text-emerald-500">
            Sign in
          </.link>
          <.link navigate={~p"/auth/register"} class=" hover:text-emerald-600 active:text-emerald-500">
            Register
          </.link>
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
