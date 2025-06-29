defmodule MossletWeb.SubscriptionRoutes do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      scope "/app", MossletWeb do
        pipe_through [:browser, :authenticated, :subscribed_user]

        live_session :subscription_authenticated_user,
          on_mount: [
            {MossletWeb.UserOnMountHooks, :require_authenticated_user},
            {MossletWeb.UserAuth, :ensure_session_key},
            {MossletWeb.UserAuth, :maybe_ensure_connection},
            {MossletWeb.UserAuth, :maybe_ensure_private_memories},
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
          live "/groups", GroupLive.Index, :index
          live "/groups/new", GroupLive.Index, :new
          live "/groups/greet", GroupLive.Index, :greet
          live "/groups/:id/edit", GroupLive.Index, :edit
          live "/groups/:id/join", GroupLive.Index, :join
          live "/groups/:id/join-password", GroupLive.Join, :join_password
          live "/groups/:id", GroupLive.Show, :show

          live "/groups/:id/show/edit", GroupLive.Show, :edit
          live "/groups/:id/edit-group-members", GroupLive.GroupSettings.EditGroupMembersLive, nil

          live "/groups/user_group/:id/edit-member",
               GroupLive.GroupSettings.EditGroupMembersLive,
               :edit_member

          # Memories
          live "/memories", MemoryLive.Index, :index
          live "/memories/new", MemoryLive.Index, :new
          live "/memories/:id", MemoryLive.Show

          get "/memories/:id/shared/download", MemoryDownloadController, :download_shared_memory,
            as: :memory_download

          get "/memories/:id/download", MemoryDownloadController, :download_memory,
            as: :memory_download

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
    end
  end
end
