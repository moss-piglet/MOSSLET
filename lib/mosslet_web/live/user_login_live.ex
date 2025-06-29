defmodule MossletWeb.UserLoginLive do
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.mosslet_auth_layout conn={@socket} title="Log In">
      <:logo>
        <.logo class="h-8 transition-transform duration-300 ease-out transform hover:scale-105" />
      </:logo>
      <:top_right>
        <.color_scheme_switch />
      </:top_right>
      <div class="flex flex-col items-start justify-start">
        <.link navigate="/" class="-ml-4">
          <.logo class="mb-2 h-16 w-auto" />
        </.link>

        <h2 class="mt-16 text-2xl font-bold tracking-tight text-pretty sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          Sign in to your account.
        </h2>
        <p class="mt-2 text-sm text-gray-700 dark:text-gray-400">
          👋 Welcome back!
        </p>
      </div>
      <div class="mt-10">
        <.form for={@form} id="login_form" action={~p"/auth/sign_in"} phx-update="ignore">
          <.field
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="off"
            required
            {alpine_autofocus()}
          />
          <.field field={@form[:password]} type="password" label="Password" required />

          <.field field={@form[:remember_me]} type="checkbox" label="Keep me signed in" />

          <div class="flex-1 pb-4 space-x-4">
            <button
              type="submit"
              phx-disable-with="Signing in..."
              class="inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-full w-full shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              Sign in <.icon name="hero-arrow-long-right" class="w-5 h-5 ml-2" />
            </button>
          </div>
        </.form>
        <div class="flex justify-between text-sm dark:text-gray-200">
          <.link
            navigate={~p"/auth/reset-password"}
            class="text-sm hover:text-emerald-600 active:text-emerald-500"
          >
            Forgot your password?
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
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form, page_title: "Log In"), temporary_assigns: [form: form]}
  end
end
