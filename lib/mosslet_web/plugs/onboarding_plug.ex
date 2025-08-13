defmodule MossletWeb.OnboardingPlug do
  @moduledoc """
  This plug shows an onboarding screen for new users.
  Good for either collecting more details or showing a welcome screen.
  To remove:
    1. Search router.ex for "OnboardingPlug" and delete them
    2. Now users won't have to onboard. However, if a user registers via passwordless auth, they won't have a name.
  """
  use Phoenix.Controller, formats: [:html]
  use MossletWeb, :verified_routes

  import Plug.Conn

  alias MossletWeb.UserAuth

  def init(options), do: options

  def call(conn, _opts) do
    if conn.assigns[:current_user] && !conn.assigns.current_user.is_onboarded? &&
         !onboarding_path?(conn) do
      conn
      |> redirect(to: ~p"/app/users/onboarding?#{[user_return_to: return_to_path(conn)]}")
      |> halt()
    else
      conn
    end
  end

  defp onboarding_path?(conn) do
    conn.request_path == ~p"/app/users/onboarding"
  end

  defp return_to_path(conn) do
    UserAuth.maybe_redirect_to_org_invitations(conn.assigns.current_user) || current_path(conn)
  end
end
