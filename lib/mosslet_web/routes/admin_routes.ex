defmodule MossletWeb.AdminRoutes do
  @moduledoc false
  import Phoenix.LiveDashboard.Router
  import Oban.Web.Router

  defmacro __using__(_) do
    quote do
      scope "/admin", MossletWeb do
        pipe_through [:browser, :authenticated, :require_admin_user]

        live_dashboard "/server", metrics: MossletWeb.Telemetry

        oban_dashboard("/oban")

        live_session :require_admin_user,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :require_authenticated_user},
            {MossletWeb.UserAuth, :ensure_session_key},
            {MossletWeb.UserOnMountHooks, :require_admin_user}
          ] do
          live "/dash", AdminDashLive, :index
          live "/users", AdminUsersLive, :index
          live "/users/:user_id", AdminUsersLive, :edit
          live "/orgs", AdminOrgsLive, :index
          live "/logs", LogsLive, :index
          live "/jobs", AdminJobsLive
          live "/subscriptions", AdminSubscriptionsLive
        end
      end
    end
  end
end
