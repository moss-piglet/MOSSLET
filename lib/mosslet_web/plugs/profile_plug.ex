defmodule MossletWeb.Plugs.ProfilePlug do
  @moduledoc """
  A plug that routes profile requests based on the profile visibility.

  - Public profiles → /profile/:slug (no authentication required)
  - Authenticated profiles (connections/private) → /app/profile/:slug (authentication required)

  This allows non-authenticated users to view public profiles while keeping
  connection and private profiles protected.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Mosslet.Accounts

  def init(opts), do: opts

  def call(%{path_info: ["profile", slug]} = conn, _opts) do
    case Accounts.get_user_from_profile_slug(slug) do
      %Accounts.User{} = user ->
        handle_profile_routing(conn, user, slug)

      nil ->
        conn
        |> put_flash(:error, "Profile not found.")
        |> redirect(to: "/")
        |> halt()
    end
  end

  def call(%{path_info: ["app", "profile", slug]} = conn, _opts) do
    case Accounts.get_user_from_profile_slug(slug) do
      %Accounts.User{} = user ->
        visibility = user.connection.profile.visibility

        if visibility == :public && is_nil(conn.assigns[:current_user]) do
          conn
          |> redirect(to: "/profile/#{slug}")
          |> halt()
        else
          conn
        end

      nil ->
        conn
        |> put_flash(:info, "Profile is not viewable or does not exist.")
        |> redirect(to: "/")
        |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp handle_profile_routing(conn, user, slug) do
    current_user = conn.assigns[:current_user]
    visibility = user.connection.profile.visibility

    cond do
      visibility == :public ->
        conn

      current_user && visibility in [:connections, :private] ->
        conn
        |> redirect(to: "/app/profile/#{slug}")
        |> halt()

      true ->
        conn
        |> put_flash(:info, "Profile is not viewable or does not exist.")
        |> redirect(to: "/auth/sign_in")
        |> halt()
    end
  end
end
