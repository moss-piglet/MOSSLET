defmodule MossletWeb.UserOnMountHooks do
  @moduledoc """
  This module houses on_mount hooks used by live views.
  Docs: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1
  """
  use MossletWeb, :verified_routes

  use Gettext, backend: MossletWeb.Gettext
  import Phoenix.Component
  import Phoenix.LiveView

  alias Mosslet.Accounts

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = maybe_assign_user(socket, session)

    if socket.assigns.current_user do
      if socket.assigns.current_user.confirmed_at do
        {:cont, socket}
      else
        socket =
          put_flash(
            socket,
            :info,
            gettext(
              "You must confirm your account first, please check your email for a confirmation link or send a new one."
            )
          )

        {:halt, redirect(socket, to: ~p"/auth/confirm")}
      end
    else
      socket = put_flash(socket, :error, gettext("You must sign in to access this page."))
      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_authenticated_user_not_confirmed, _params, session, socket) do
    socket = maybe_assign_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket = put_flash(socket, :error, gettext("You must sign in to access this page."))
      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_confirmed_user, _params, session, socket) do
    socket = maybe_assign_user(socket, session)

    if socket.assigns.current_user && socket.assigns.current_user.confirmed_at do
      {:cont, socket}
    else
      socket =
        put_flash(socket, :error, gettext("You must confirm your email to access this page."))

      {:halt, redirect(socket, to: ~p"/auth/sign_in")}
    end
  end

  def on_mount(:require_admin_user, _params, session, socket) do
    socket = maybe_assign_user(socket, session)

    if socket.assigns.current_user && socket.assigns.current_user.is_admin? do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/")}
    end
  end

  def on_mount(:maybe_assign_user, _params, session, socket) do
    {:cont, maybe_assign_user(socket, session)}
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = maybe_assign_user(socket, session)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: "/")}
    else
      {:cont, socket}
    end
  end

  defp maybe_assign_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      get_user(session["user_token"])
    end)
  end

  defp get_user(nil), do: nil
  defp get_user(token), do: Accounts.get_user_by_session_token(token)
end
