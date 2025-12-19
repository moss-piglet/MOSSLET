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
    plug :maybe_desktop_auth
  end

  defp maybe_desktop_auth(conn, _opts) do
    if Mosslet.Platform.native?() do
      MossletWeb.Plugs.DesktopAuth.call(conn, [])
    else
      conn
    end
  end

  pipeline :api do
    plug PlugAttack
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug MossletWeb.Plugs.APIAuth
  end

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
      live "/blog/articles/10", PublicLive.Blog.Blog10
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
  scope "/api", MossletWeb.API do
    pipe_through :api

    post "/auth/login", AuthController, :login
    post "/auth/register", AuthController, :register
    post "/auth/totp/verify", AuthController, :verify_totp
    post "/auth/remember-me/refresh", AuthController, :refresh_from_remember_me

    post "/auth/password/reset-request", AuthController, :request_password_reset
    post "/auth/password/verify-token", AuthController, :verify_password_reset_token
    post "/auth/password/reset", AuthController, :reset_password_with_token

    post "/auth/confirmation/resend", AuthController, :resend_confirmation
    post "/auth/confirmation/confirm", AuthController, :confirm_email
  end

  scope "/api", MossletWeb.API do
    pipe_through [:api, :api_auth]

    post "/auth/refresh", AuthController, :refresh
    post "/auth/logout", AuthController, :logout
    get "/auth/me", AuthController, :me

    get "/auth/totp/status", AuthController, :totp_status
    post "/auth/totp/setup", AuthController, :setup_totp
    post "/auth/totp/enable", AuthController, :enable_totp
    post "/auth/totp/disable", AuthController, :disable_totp
    post "/auth/totp/backup-codes/regenerate", AuthController, :regenerate_backup_codes

    get "/sync/user", SyncController, :user
    get "/sync/posts", SyncController, :posts
    get "/sync/connections", SyncController, :connections
    get "/sync/groups", SyncController, :groups
    get "/sync/full", SyncController, :full_sync

    resources "/posts", PostController, only: [:index, :show, :create, :update, :delete]

    # User account management
    put "/users/name", UserController, :update_name
    put "/users/username", UserController, :update_username
    put "/users/profile", UserController, :update_profile
    put "/users/visibility", UserController, :update_visibility
    put "/users/password", UserController, :update_password
    put "/users/avatar", UserController, :update_avatar
    put "/users/notifications", UserController, :update_notifications
    put "/users/onboarding", UserController, :update_onboarding
    post "/users/profile", UserController, :create_profile
    delete "/users/profile", UserController, :delete_profile
    post "/users/delete-data", UserController, :delete_data
    get "/users/deletable-data", UserController, :get_deletable_data
    post "/users/reset-password", UserController, :reset_password
    put "/users/onboarding-profile", UserController, :update_onboarding_profile
    put "/users/tokens", UserController, :update_tokens

    put "/users/email-notification-received-at",
        UserController,
        :update_email_notification_received_at

    put "/users/reply-notification-received-at",
        UserController,
        :update_reply_notification_received_at

    put "/users/replies-seen-at", UserController, :update_replies_seen_at
    post "/users/visibility-groups", UserController, :create_visibility_group
    put "/users/visibility-groups/:id", UserController, :update_visibility_group
    delete "/users/visibility-groups/:id", UserController, :delete_visibility_group
    put "/users/forgot-password", UserController, :update_forgot_password
    put "/users/oban-reset-token-id", UserController, :update_oban_reset_token_id
    post "/users/block", UserController, :block_user
    delete "/users/block/:user_id", UserController, :unblock_user
    get "/users/blocked", UserController, :list_blocked

    delete "/users/account", UserController, :delete_account
    post "/users/email/change-request", UserController, :request_email_change
    post "/users/email/change-confirm", UserController, :confirm_email_change

    # Bulk delete operations (for user data management - zero knowledge)
    delete "/users/:user_id/connections", UserController, :delete_all_connections
    delete "/users/:user_id/groups", UserController, :delete_all_groups
    delete "/users/:user_id/memories", UserController, :delete_all_memories
    delete "/users/:user_id/posts", UserController, :delete_all_posts
    delete "/users/:user_id/remarks", UserController, :delete_all_remarks
    delete "/users/:user_id/replies", UserController, :delete_all_replies
    delete "/users/:user_id/bookmarks", UserController, :delete_all_bookmarks
    get "/users/:user_id/all-memories", UserController, :get_all_memories
    get "/users/:user_id/all-posts", UserController, :get_all_posts
    get "/users/:user_id/all-replies", UserController, :get_all_replies
    post "/users/cleanup-shared-users", UserController, :cleanup_shared_users

    # Connection-scoped delete operations
    delete "/connections/:id/memories", ConnectionController, :delete_all_memories
    delete "/connections/:id/posts", ConnectionController, :delete_all_posts

    # User connections (friends)
    get "/connections", ConnectionController, :index
    get "/connections/arrivals", ConnectionController, :arrivals
    get "/connections/:id", ConnectionController, :show
    post "/connections", ConnectionController, :create
    put "/connections/:id", ConnectionController, :update
    put "/connections/:id/label", ConnectionController, :update_label
    put "/connections/:id/zen", ConnectionController, :update_zen
    put "/connections/:id/photos", ConnectionController, :update_photos
    post "/connections/:id/confirm", ConnectionController, :confirm
    delete "/connections/:id", ConnectionController, :delete
    delete "/connections/:id/both", ConnectionController, :delete_both
  end

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
        {MossletWeb.SubscriptionPlugs, :subscribed_entity},
        MossletWeb.SyncStatusHook
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
        {MossletWeb.UserAuth, :maybe_ensure_connection},
        MossletWeb.SyncStatusHook
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
        {MossletWeb.SubscriptionPlugs, :subscribed_entity},
        MossletWeb.SyncStatusHook
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
