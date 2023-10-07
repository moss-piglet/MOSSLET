defmodule MetamorphicWeb.Router do
  use MetamorphicWeb, :router

  import MetamorphicWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MetamorphicWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MetamorphicWeb do
    pipe_through [:browser]

    get "/", PageController, :home

    live_session :public,
      on_mount: [
        {MetamorphicWeb.UserAuth, :mount_current_user},
        {MetamorphicWeb.UserAuth, :mount_current_user_session_key},
        {MetamorphicWeb.UserAuth, :ensure_session_key}
      ] do
      live "/about", PublicLive.About, :about
      live "/privacy", PublicLive.Privacy, :privacy
      live "/public/posts", PostLive.Public, :index
      live "/public/posts/:id", PostLive.PublicShow, :show
    end

    live_session :profile,
      on_mount: [
        {MetamorphicWeb.UserAuth, :mount_current_user},
        {MetamorphicWeb.UserAuth, :mount_current_user_session_key},
        {MetamorphicWeb.UserAuth, :ensure_session_key},
        {MetamorphicWeb.UserAuth, :maybe_ensure_private_profile}
      ] do
      live "/profile/:slug", UserProfileLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MetamorphicWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:metamorphic, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    # import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MetamorphicWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{MetamorphicWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", MetamorphicWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_session_key,
      :maybe_require_connection
    ]

    live_session :require_authenticated_user,
      on_mount: [
        {MetamorphicWeb.UserAuth, :ensure_authenticated},
        {MetamorphicWeb.UserAuth, :ensure_session_key},
        {MetamorphicWeb.UserAuth, :maybe_ensure_connection}
      ] do
      live "/users/dash", UserDashLive, :index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", MetamorphicWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_confirmed_user,
      :require_session_key,
      :maybe_require_private_posts
    ]

    live_session :require_authenticated_and_confirmed_user,
      on_mount: [
        {MetamorphicWeb.UserAuth, :ensure_authenticated},
        {MetamorphicWeb.UserAuth, :ensure_confirmed},
        {MetamorphicWeb.UserAuth, :ensure_session_key},
        {MetamorphicWeb.UserAuth, :maybe_ensure_private_memories},
        {MetamorphicWeb.UserAuth, :maybe_ensure_private_posts}
      ] do
      live "/memories", MemoryLive.Index, :index
      live "/memories/new", MemoryLive.Index, :new
      live "/memories/:id/edit", MemoryLive.Index, :edit
      live "/memories/:id", MemoryLive.Show, :show
      live "/memories/:id/show/edit", MemoryLive.Show, :edit

      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Index, :new
      live "/posts/:id/edit", PostLive.Index, :edit
      live "/posts/:id", PostLive.Show, :show
      live "/posts/:id/show/edit", PostLive.Show, :edit

      live "/users/connections", UserConnectionLive.Index, :index
      live "/users/connections/new", UserConnectionLive.Index, :new
      live "/users/connections/:id/edit", UserConnectionLive.Index, :edit
      live "/users/connections/greet", UserConnectionLive.Index, :greet
      # live "/users/:id/profile", "UserConnectionLive.Show", :show
    end
  end

  scope "/ai", MetamorphicWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_confirmed_user,
      :require_session_key
    ]

    live_session :ai,
      on_mount: [
        {MetamorphicWeb.UserAuth, :ensure_authenticated},
        {MetamorphicWeb.UserAuth, :ensure_confirmed},
        {MetamorphicWeb.UserAuth, :ensure_session_key}
      ] do
      live "/conversations", ConversationLive.Index, :index
      live "/conversations/new", ConversationLive.Index, :new
      live "/conversations/:id/edit", ConversationLive.Index, :edit

      live "/conversations/:id", ConversationLive.Show, :show
      live "/conversations/:id/show/edit", ConversationLive.Show, :edit
      live "/conversations/:id/edit_message/:msg_id", ConversationLive.Show, :edit_message
    end
  end

  scope "/admin", MetamorphicWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_confirmed_user,
      :require_session_key,
      :require_admin_user
    ]

    live_dashboard "/metrics", metrics: MetamorphicWeb.Telemetry

    live_session :require_admin_user,
      on_mount: [
        {MetamorphicWeb.UserAuth, :ensure_authenticated},
        {MetamorphicWeb.UserAuth, :ensure_confirmed},
        {MetamorphicWeb.UserAuth, :ensure_session_key},
        {MetamorphicWeb.UserAuth, :ensure_admin_user}
      ] do
      live "/dash", AdminDashLive, :index
    end
  end

  scope "/", MetamorphicWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{MetamorphicWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
