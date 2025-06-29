defmodule MossletWeb.UserTOTPHTML do
  use MossletWeb, :html

  def new(assigns) do
    ~H"""
    <.auth_layout title="Two-factor authentication">
      <:logo>
        <.logo_icon class="w-20 h-20" />
      </:logo>
      <div class="mb-4 prose prose-gray dark:prose-invert">
        <p>
          {gettext(
            "Enter the six-digit code from your device or any of your eight-character backup codes to finish logging in."
          )}
        </p>
      </div>

      <.form for={@form} action={~p"/app/users/totp"}>
        <.field
          field={@form[:code]}
          label={gettext("Code")}
          required
          autocomplete="one-time-code"
          {alpine_autofocus()}
        />

        <%= if @error_message do %>
          <.alert class="mb-5" color="danger" label={@error_message} />
        <% end %>

        <.field
          type="checkbox"
          field={@form[:remember_me]}
          label={gettext("Keep me signed in for 60 days")}
        />

        <div class="flex items-center justify-between">
          <.link class="text-sm underline" href={~p"/auth/sign_out"} method="delete">
            Sign out
          </.link>
          <.button label={gettext("Verify code and sign in")} />
        </div>
      </.form>
    </.auth_layout>
    """
  end
end
