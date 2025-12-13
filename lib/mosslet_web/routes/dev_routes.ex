defmodule MossletWeb.DevRoutes do
  @moduledoc """
  Development only routes (don't use route helpers to generate paths for these routes or they'll fail in production)
  eg. instead of `~p"/dev"`, just write `/dev`
  """

  defmacro __using__(_opts \\ []) do
    quote do
      if Mix.env() in [:dev, :test] do
        scope "/" do
          forward "/dev/mailbox", Plug.Swoosh.MailboxPreview
        end

        live_session :dev,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :maybe_assign_user}
          ] do
          scope "/dev", MossletWeb do
            pipe_through :browser

            # live "/", DevDashboardLive
            # live "/resources", DevResourcesLive

            # Show a list of all your apps emails - use this when designing your transactional emails
            scope "/emails" do
              pipe_through([:require_authenticated_user])

              get "/", EmailTestingController, :index
              get "/sent", EmailTestingController, :sent
              get "/preview/:email_name", EmailTestingController, :preview

              post "/send_test_email/:email_name",
                   EmailTestingController,
                   :send_test_email

              get "/show/:email_name", EmailTestingController, :show_html
            end
          end
        end
      end
    end
  end
end
