defmodule MossletWeb.SubscriptionRoutes do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      scope "/app", MossletWeb do
        pipe_through [
          :browser,
          :authenticated,
          :require_confirmed_user,
          :require_session_key,
          :subscribed_user
        ]

        live_session :subscription_authenticated_user,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :require_authenticated_user},
            {MossletWeb.UserAuth, :ensure_session_key},
            {MossletWeb.UserAuth, :maybe_ensure_connection},
            {MossletWeb.UserAuth, :maybe_ensure_private_posts},
            {MossletWeb.SubscriptionPlugs, :subscribed_user}
          ] do
          # Dashboard
          live "/", UserDashLive, :index

          # Connections (People)
          live "/users/connections", UserConnectionLive.Index, :index
          live "/users/connections/new", UserConnectionLive.Index, :new
          live "/users/connections/greet", UserConnectionLive.Index, :greet

          live "/users/connections/:id", UserConnectionLive.Show, :show
          live "/users/connections/:id/edit", UserConnectionLive.Show, :edit

          # Groups
          live "/circles", GroupLive.Index, :index
          live "/circles/new", GroupLive.Index, :new
          live "/circles/greet", GroupLive.Index, :greet
          live "/circles/:id/edit", GroupLive.Index, :edit
          live "/circles/:id/join", GroupLive.Index, :join
          live "/circles/:id/join-password", GroupLive.Join, :join_password
          live "/circles/:id", GroupLive.Show, :show

          live "/circles/:id/show/edit", GroupLive.Show, :edit

          live "/circles/:id/edit-group-members",
               GroupLive.GroupSettings.EditGroupMembersLive,
               nil

          live "/circles/user_group/:id/edit-member",
               GroupLive.GroupSettings.EditGroupMembersLive,
               :edit_member

          live "/circles/:id/moderate-members",
               GroupLive.GroupSettings.ModerateGroupMembersLive,
               nil

          live "/circles/user_group/:id/kick-member",
               GroupLive.GroupSettings.ModerateGroupMembersLive,
               :kick_member

          live "/circles/user_group/:id/block-member",
               GroupLive.GroupSettings.ModerateGroupMembersLive,
               :block_member

          # Journal (private, user-only)
          live "/journal", JournalLive.Index, :index
          live "/journal/new", JournalLive.Entry, :new
          live "/journal/books/:book_id", JournalLive.Book, :show
          live "/journal/books/:book_id/edit", JournalLive.Book, :edit
          live "/journal/:id", JournalLive.Entry, :show
          live "/journal/:id/edit", JournalLive.Entry, :edit

          # Posts
          live "/posts/new", PostLive.Index, :new
          live "/posts/:id/edit", PostLive.Show, :edit
          live "/posts/:id", PostLive.Show, :show
          live "/posts/:id/show/edit", PostLive.Show, :edit
          live "/posts/:id/show/reply", PostLive.Show, :reply
          live "/posts/:id/show/:reply_id/edit", PostLive.Show, :reply_edit

          # Timeline
          live "/timeline", TimelineLive.Index

          # Trix File Uploads
          post "/trix-uploads", TrixUploadsController, :create
          delete "/trix-uploads", TrixUploadsController, :delete
          get "/trix-uploads", TrixUploadsController, :get
        end
      end

      # Authenticated profile access (for connections and self)
      scope "/", MossletWeb do
        pipe_through [
          :browser,
          :profile,
          :authenticated,
          :require_confirmed_user,
          :require_session_key,
          :subscribed_user
        ]

        live_session :app_profile,
          on_mount: [
            {MossletWeb.UserAuth, :ensure_authenticated},
            {MossletWeb.UserAuth, :ensure_confirmed},
            {MossletWeb.UserAuth, :ensure_session_key},
            {MossletWeb.UserAuth, :maybe_ensure_private_profile}
          ] do
          live "/app/profile/:slug", UserHomeLive, :show
        end
      end
    end
  end
end
