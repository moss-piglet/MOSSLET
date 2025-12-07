defmodule MossletWeb.Router do
  use MossletWeb, :router

  import MossletWeb.UserAuth
  import MossletWeb.SubscriptionPlugs

  alias MossletWeb.Plugs.{PlugAttack, ProfilePlug}
  alias MossletWeb.OnboardingPlug

  pipeline :browser do
    plug PlugAttack
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MossletWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug :kick_user_if_suspended_or_deleted
    plug Mosslet.SetLocalePlug, gettext: MossletWeb.Gettext
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  pipeline :public_layout do
    plug :put_layout, html: {MossletWeb.Layouts, :public}
  end

  pipeline :authenticated do
    plug :require_authenticated_user
    plug OnboardingPlug
  end

  pipeline :authenticated_not_confirmed do
    plug :require_authenticated_user_not_confirmed
    plug OnboardingPlug
  end

  pipeline :profile do
    plug ProfilePlug
  end

  pipeline :subscribed_entity do
    plug :subscribed_entity_only
  end

  pipeline :subscribed_org do
    plug :subscribed_org_only
  end

  pipeline :subscribed_user do
    plug :subscribed_user_only
  end

  scope "/", MossletWeb do
    pipe_through [:browser]

    live_session :home,
      on_mount: [
        MossletWeb.AllowEctoSandboxHook,
        {MossletWeb.UserAuth, :mount_current_user},
        {MossletWeb.UserAuth, :mount_current_user_session_key},
        {MossletWeb.UserAuth, :ensure_session_key}
      ] do
      live "/", HomeLive, :home
      live "/about", PublicLive.About, :about
      live "/blog", PublicLive.Blog.Index
      live "/blog/articles/01", PublicLive.Blog.Blog01
      live "/blog/articles/02", PublicLive.Blog.Blog02
      live "/blog/articles/03", PublicLive.Blog.Blog03
      live "/blog/articles/04", PublicLive.Blog.Blog04
      live "/blog/articles/05", PublicLive.Blog.Blog05
      live "/blog/articles/06", PublicLive.Blog.Blog06
      live "/blog/articles/07", PublicLive.Blog.Blog07
      live "/blog/articles/08", PublicLive.Blog.Blog08
      live "/blog/articles/09", PublicLive.Blog.Blog09
      live "/faq", PublicLive.Faq, :faq
      live "/support", PublicLive.Support, :support
      live "/features", PublicLive.Features, :features
      live "/pricing", PublicLive.Pricing, :pricing
      live "/privacy", PublicLive.Privacy, :privacy
      live "/terms", PublicLive.Terms, :terms
      live "/updates", PublicLive.Updates, :updates
    end
  end

  scope "/", MossletWeb do
    pipe_through [:browser, :profile]

    live_session :public_profile,
      on_mount: [
        MossletWeb.AllowEctoSandboxHook,
        {MossletWeb.UserAuth, :mount_current_user},
        {MossletWeb.UserAuth, :mount_current_user_session_key},
        {MossletWeb.UserAuth, :ensure_session_key},
        {MossletWeb.UserAuth, :maybe_ensure_connection},
        {MossletWeb.UserAuth, :maybe_ensure_private_profile}
      ] do
      live "/profile/:slug", PublicProfileLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MossletWeb do
  #   pipe_through :api
  # end

  ## Authentication routes

  scope "/app", MossletWeb do
    pipe_through [
      :browser,
      :authenticated,
      :require_confirmed_user,
      :require_session_key,
      :maybe_require_connection
    ]

    # Add controller authenticated routes here
    put "/users/settings/update-password", UserSettingsController, :update_password
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
    get "/users/totp", UserTOTPController, :new
    post "/users/totp", UserTOTPController, :create

    # Timeline image downloads
    get "/timeline/images/download/:token", TimelineImageDownloadController, :download_image

    live_session :require_authenticated_user,
      on_mount: [
        {MossletWeb.UserAuth, :ensure_authenticated},
        {MossletWeb.UserAuth, :ensure_confirmed},
        {MossletWeb.UserAuth, :ensure_session_key},
        {MossletWeb.UserAuth, :maybe_ensure_connection},
        {MossletWeb.SubscriptionPlugs, :subscribed_entity}
      ] do
      # Onboarding
      live "/users/onboarding", UserOnboardingLive

      # invitations
      live "/users/connections/invite/new-invite", UserConnectionLive.Invite, :new_invite

      # Settings
      live "/users/edit-details", EditDetailsLive
      live "/users/edit-profile", EditProfileLive
      live "/users/edit-email", EditEmailLive
      live "/users/edit-visibility", EditVisibilityLive
      live "/users/edit-status", EditStatusLive
      live "/users/manage-data", ManageDataLive
      live "/users/blocked-users", BlockedUsersLive
      live "/users/change-password", EditPasswordLive
      live "/users/change-forgot-password", EditForgotPasswordLive
      live "/users/edit-notifications", EditNotificationsLive
      live "/users/org-invitations", UserOrgInvitationsLive
      live "/users/two-factor-authentication", EditTotpLive

      # moved to subscription routes
    end
  end

  # Billing routes - accessible to authenticated users without subscription
  scope "/app", MossletWeb do
    pipe_through [
      :browser,
      :authenticated,
      :require_confirmed_user,
      :require_session_key,
      :maybe_require_connection
    ]

    live_session :billing_authenticated_user,
      on_mount: [
        {MossletWeb.UserAuth, :ensure_authenticated},
        {MossletWeb.UserAuth, :ensure_confirmed},
        {MossletWeb.UserAuth, :ensure_session_key},
        {MossletWeb.UserAuth, :maybe_ensure_connection}
      ] do
      use MossletWeb.BillingRoutes
    end
  end

  # Routes where the user must be authenticated but does not
  # need to be confirmed via their email.
  scope "/app", MossletWeb do
    pipe_through [
      :browser,
      :require_authenticated_user,
      :require_session_key,
      :maybe_require_connection
    ]

    live_session :require_authenticated_user_not_confirmed,
      on_mount: [
        {MossletWeb.UserAuth, :ensure_authenticated},
        {MossletWeb.UserAuth, :ensure_session_key},
        {MossletWeb.UserAuth, :maybe_ensure_connection},
        {MossletWeb.SubscriptionPlugs, :subscribed_entity}
      ] do
      live "/users/delete-account", DeleteAccountLive
    end
  end

  scope "/" do
    use MossletWeb.AuthRoutes
    use MossletWeb.SubscriptionRoutes
    use MossletWeb.MailblusterRoutes
    use MossletWeb.AdminRoutes

    # DevRoutes must always be last
    use MossletWeb.DevRoutes
  end

  scope "/", MossletWeb do
    pipe_through [:browser]

    get "/wp-admin", HoneypotController, :trap
    get "/wp-admin/*path", HoneypotController, :trap
    get "/wp-login.php", HoneypotController, :trap
    get "/wp-content/*path", HoneypotController, :trap
    get "/administrator", HoneypotController, :trap
    get "/phpmyadmin", HoneypotController, :trap
    get "/phpMyAdmin", HoneypotController, :trap
    get "/.env", HoneypotController, :trap
    get "/.git/*path", HoneypotController, :trap
    get "/config.php", HoneypotController, :trap
    get "/xmlrpc.php", HoneypotController, :trap
  end
end
