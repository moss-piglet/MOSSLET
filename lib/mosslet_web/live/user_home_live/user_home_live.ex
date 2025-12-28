defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias MossletWeb.Helpers.StatusHelpers
  alias MossletWeb.Helpers.URLPreviewHelpers

  @posts_per_page 10

  def mount(%{"slug" => slug} = _params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    profile_user = Accounts.get_user_from_profile_slug!(slug)
    profile_owner? = current_user.id === profile_user.id

    socket = stream(socket, :presences, [])
    socket = stream(socket, :profile_posts, [])

    socket =
      if connected?(socket) do
        Accounts.subscribe_user_status(current_user)
        Accounts.subscribe_account_deleted()
        Accounts.block_subscribe(current_user)
        Accounts.subscribe_connection_status(current_user)
        Accounts.private_subscribe(current_user)

        # Only track presence when viewing YOUR OWN profile
        if profile_owner? do
          MossletWeb.Presence.track_activity(
            self(),
            %{
              id: current_user.id,
              live_view_name: "home",
              joined_at: System.system_time(:second),
              user_id: current_user.id,
              cache_optimization: true
            }
          )
        end

        MossletWeb.Presence.subscribe()

        socket = stream(socket, :presences, MossletWeb.Presence.list_online_users())

        # Privately track user activity for auto-status functionality
        Accounts.track_user_activity(current_user, :general)
        socket
      else
        socket
      end

    user_connection =
      if profile_owner?, do: nil, else: get_uconn_for_users!(profile_user.id, current_user.id)

    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:page_title, if(profile_owner?, do: "Home", else: "Profile"))
      |> assign(:image_urls, [])
      |> assign(:delete_post_from_cloud_message, nil)
      |> assign(:delete_reply_from_cloud_message, nil)
      |> assign(:uploads_in_progress, false)
      |> assign(:trix_key, nil)
      |> assign(:profile_user, profile_user)
      |> assign(:current_user_is_profile_owner?, profile_owner?)
      |> assign(:user_connection, user_connection)
      |> assign(:posts_page, 1)
      |> assign(:posts_loading, false)
      |> assign(:posts_count, 0)
      |> URLPreviewHelpers.assign_url_preview_defaults()
      |> maybe_load_custom_banner_async(profile_user, profile_owner?)

    socket =
      if connected?(socket) do
        socket
        |> maybe_fetch_website_preview(profile_user, current_user, profile_owner?)
        |> load_profile_posts(profile_user, current_user, user_connection)
      else
        socket
      end

    {:ok, socket}
  end

  defp load_profile_posts(socket, profile_user, current_user, _user_connection) do
    options = %{post_page: socket.assigns.posts_page, post_per_page: @posts_per_page}
    posts = Timeline.list_profile_posts_visible_to(profile_user, current_user, options)
    posts_count = Timeline.count_profile_posts_visible_to(profile_user, current_user)

    socket
    |> assign(:posts_count, posts_count)
    |> stream(:profile_posts, posts, reset: true)
  end

  def render(assigns) do
    case {assigns.current_user_is_profile_owner?, assigns.profile_user.visibility} do
      {true, _} -> render_own_profile(assigns)
      {false, :public} -> render_public_profile(assigns)
      {false, :connections} -> render_connections_profile(assigns)
      {false, :private} -> render_no_access(assigns)
    end
  end

  @doc """
  Handle params. The "profile_user" assigned in the socket
  is the user whose profile is being viewed.

  The "current_user" is the session user (or "nil" if the
  profile is public and the session is not signed in).
  """
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def handle_info({MossletWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({MossletWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_info({_ref, {"get_user_avatar", user_id}}, socket) do
    user = Accounts.get_user_with_preloads(user_id)
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({:status_updated, user}, socket) do
    profile_user = socket.assigns.profile_user

    if user.id == profile_user.id do
      {:noreply, assign(socket, :profile_user, user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:status_visibility_updated, user}, socket) do
    profile_user = socket.assigns.profile_user

    if user.id == profile_user.id do
      {:noreply, assign(socket, :profile_user, user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:uconn_visibility_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)
        {:noreply, assign(socket, :profile_user, user)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)

        if user.connection.profile.visibility in [:connections, :public] do
          {:noreply, assign(socket, :profile_user, user)}
        else
          {:noreply, push_navigate(socket, to: ~p"/app")}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:uconn_avatar_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)
        {:noreply, assign(socket, :profile_user, user)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({:conn_updated, uconn}, socket) do
    profile_owner? = socket.assigns.current_user_is_profile_owner?
    profile_user = socket.assigns.profile_user

    cond do
      # its the reverse_user_id since the current_user is subscribed at the uconn.user_id
      # in their accounts:#{user_id} channel
      !profile_owner? && uconn.reverse_user_id == profile_user.id ->
        user = Accounts.get_user_with_preloads(uconn.reverse_user_id)

        if user.connection.profile.visibility in [:connections, :public] do
          {:noreply, assign(socket, :profile_user, user)}
        else
          {:noreply, push_navigate(socket, to: ~p"/app")}
        end

      true ->
        {:noreply, socket}
    end
  end

  def handle_info({ref, {:website_preview_result, result}}, socket) do
    Process.demonitor(ref, [:flush])
    profile_key = get_profile_key_for_preview(socket)

    case URLPreviewHelpers.handle_preview_result(
           {ref, {:website_preview_result, result}},
           socket,
           profile_key
         ) do
      {:handled, socket} -> {:noreply, socket}
      {:not_handled, socket} -> {:noreply, socket}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason} = msg, socket) do
    case URLPreviewHelpers.handle_preview_result(msg, socket, nil) do
      {:handled, socket} -> {:noreply, socket}
      {:not_handled, socket} -> {:noreply, socket}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp get_profile_key_for_preview(socket) do
    profile_user = socket.assigns.profile_user
    current_user = socket.assigns.current_scope.user
    session_key = socket.assigns.key
    encrypted_profile_key = profile_user.connection.profile.profile_key

    if encrypted_profile_key && profile_user.visibility != :public do
      {:ok, key} =
        URLPreviewHelpers.get_private_profile_key(
          encrypted_profile_key,
          current_user,
          session_key
        )

      key
    else
      URLPreviewHelpers.get_public_profile_key(encrypted_profile_key)
    end
  end

  defp maybe_fetch_website_preview(socket, profile_user, current_user, _profile_owner?) do
    profile = profile_user.connection.profile
    session_key = socket.assigns.key

    {website_url, profile_key} =
      if profile.website_url do
        encrypted_profile_key = profile.profile_key

        if encrypted_profile_key && profile_user.visibility != :public do
          decrypted_url =
            decr_item(
              profile.website_url,
              current_user,
              encrypted_profile_key,
              session_key,
              profile
            )

          {:ok, decrypted_key} =
            URLPreviewHelpers.get_private_profile_key(
              encrypted_profile_key,
              current_user,
              session_key
            )

          {decrypted_url, decrypted_key}
        else
          decrypted_url =
            URLPreviewHelpers.decrypt_public_field(profile.website_url, profile.profile_key)

          decrypted_key = URLPreviewHelpers.get_public_profile_key(profile.profile_key)
          {decrypted_url, decrypted_key}
        end
      else
        {nil, nil}
      end

    connection_id = profile_user.connection.id
    URLPreviewHelpers.maybe_start_preview_fetch(socket, website_url, profile_key, connection_id)
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp render_own_profile(assigns) do
    ~H"""
    <%!-- Enhanced Profile Page with AT Protocol Federation Support --%>
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <%!-- Hero Section with responsive design --%>
      <div class="relative overflow-hidden">
        <%!-- Banner/Cover Image Section --%>
        <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
          <%!-- Custom banner image if available --%>
          <%= cond do %>
            <% @custom_banner_src.loading -> %>
              <div class="absolute inset-0 flex items-center justify-center">
                <div class="w-10 h-10 border-3 border-purple-400 border-t-transparent rounded-full animate-spin">
                </div>
              </div>
            <% get_async_banner_src(@custom_banner_src) -> %>
              <div
                class="absolute inset-0 bg-cover bg-center bg-no-repeat"
                style={"background-image: url('#{get_async_banner_src(@custom_banner_src)}')"}
              >
                <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
              </div>
            <% get_banner_image_for_connection(@profile_user.connection) != "" -> %>
              <div
                class="absolute inset-0 bg-cover bg-center bg-no-repeat"
                style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
              >
                <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
              </div>
            <% true -> %>
          <% end %>

          <%!-- Liquid metal overlay pattern --%>
          <div class="absolute inset-0 opacity-20">
            <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
            </div>
          </div>
        </div>

        <%!-- Profile Header --%>
        <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
          <div class="mx-auto max-w-7xl">
            <div class="relative pb-8">
              <%!-- Avatar and Basic Info --%>
              <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                <%!-- Enhanced Avatar with built-in status support --%>
                <div class="relative flex-shrink-0">
                  <MossletWeb.DesignSystem.liquid_avatar
                    src={
                      if @profile_user.connection.profile.show_avatar?,
                        do: maybe_get_user_avatar(@current_scope.user, @current_scope.key)
                    }
                    name={
                      decr_item(
                        @current_scope.user.connection.profile.name,
                        @current_scope.user,
                        @current_scope.user.conn_key,
                        @current_scope.key,
                        @current_scope.user.connection.profile
                      )
                    }
                    size="xxl"
                    status={to_string(@current_scope.user.status)}
                    status_message={
                      get_user_status_message(
                        @current_scope.user,
                        @current_scope.user,
                        @current_scope.key
                      )
                    }
                    show_status={
                      can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
                    }
                    user_id={@current_scope.user.id}
                    verified={@current_scope.user.connection.profile.visibility == "public"}
                  />
                </div>

                <%!-- Name, username, and actions --%>
                <div class="flex-1 text-center sm:text-left space-y-4">
                  <%!-- Name and username --%>
                  <div class="space-y-1">
                    <h1
                      :if={@current_scope.user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"#{decr_item(@current_scope.user.connection.profile.name,
                      @current_scope.user,
                      @current_scope.user.connection.profile.profile_key,
                      @current_scope.key,
                      @current_scope.user.connection.profile)}"}
                    </h1>

                    <h1
                      :if={!@current_scope.user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"Profile 🌿"}
                    </h1>
                    <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
                      <%!-- username badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color={
                          if(@profile_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        @{decr_item(
                          @current_scope.user.connection.profile.username,
                          @current_scope.user,
                          @current_scope.user.connection.profile.profile_key,
                          @current_scope.key,
                          @current_scope.user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Email badge if show_email? is true --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        :if={
                          @current_scope.user.connection.profile.show_email? &&
                            @current_scope.user.connection.profile.email
                        }
                        variant="soft"
                        color={
                          if(@profile_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                        {decr_item(
                          @current_scope.user.connection.profile.email,
                          @current_scope.user,
                          @current_scope.user.connection.profile.profile_key,
                          @current_scope.key,
                          @current_scope.user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Visibility badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color={
                          if(@profile_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon
                          name={
                            if(@current_scope.user.connection.profile.visibility == "public",
                              do: "hero-globe-alt",
                              else: "hero-lock-closed"
                            )
                          }
                          class="size-3 mr-1"
                        />
                        {String.capitalize(
                          to_string(@current_scope.user.connection.profile.visibility)
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>
                    </div>
                  </div>

                  <%!-- Action buttons --%>
                  <div class="flex flex-col sm:flex-row items-center gap-3">
                    <%!-- Edit Profile --%>
                    <MossletWeb.DesignSystem.liquid_button
                      navigate={~p"/app/users/edit-profile"}
                      variant="primary"
                      color="teal"
                      icon="hero-pencil-square"
                      class="w-full sm:w-auto"
                    >
                      Edit Profile
                    </MossletWeb.DesignSystem.liquid_button>

                    <%!-- Status Settings --%>
                    <MossletWeb.DesignSystem.liquid_button
                      navigate={~p"/app/users/edit-status"}
                      variant="secondary"
                      color="blue"
                      icon="hero-face-smile"
                      size="md"
                      class="w-full sm:w-auto"
                    >
                      Status Settings
                    </MossletWeb.DesignSystem.liquid_button>

                    <%!-- Share Profile

                <MossletWeb.DesignSystem.liquid_button
                  variant="ghost"
                  color="slate"
                  icon="hero-share"
                  size="md"
                  phx-click="share_profile"
                  data-tippy-content="Share your profile"
                  phx-hook="TippyHook"
                >
                  Share
                </MossletWeb.DesignSystem.liquid_button>
                --%>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Main Content --%>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <%!-- New Post Prompt --%>
        <div class="mb-8">
          <MossletWeb.DesignSystem.liquid_new_post_prompt
            id="home-new-post-prompt"
            user_name={
              decr_item(
                @current_scope.user.connection.profile.name,
                @current_scope.user,
                @current_scope.user.conn_key,
                @current_scope.key,
                @current_scope.user.connection.profile
              )
            }
            user_avatar={
              if @profile_user.connection.profile.show_avatar?,
                do: maybe_get_user_avatar(@current_scope.user, @current_scope.key)
            }
            placeholder="Share something meaningful with your community..."
            current_scope={@current_scope}
            show_status={
              can_view_status?(@current_scope.user, @current_scope.user, @current_scope.key)
            }
            status_message={get_current_user_status_message(@current_scope.user, @current_scope.key)}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left Column: Profile Details & Federation --%>
          <div class="lg:col-span-2 space-y-8">
            <%!-- Contact & Links Section --%>
            <MossletWeb.DesignSystem.liquid_card
              :if={has_contact_links?(@current_scope.user.connection.profile)}
              heading_level={2}
            >
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                  Contact & Links
                </div>
              </:title>
              <div class="space-y-4">
                <div
                  :if={@current_scope.user.connection.profile.alternate_email}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                    <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                    <a
                      href={"mailto:#{decr_item(@current_scope.user.connection.profile.alternate_email, @current_scope.user, @current_scope.user.connection.profile.profile_key, @current_scope.key, @current_scope.user.connection.profile)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {decr_item(
                        @current_scope.user.connection.profile.alternate_email,
                        @current_scope.user,
                        @current_scope.user.connection.profile.profile_key,
                        @current_scope.key,
                        @current_scope.user.connection.profile
                      )}
                    </a>
                  </div>
                </div>

                <MossletWeb.DesignSystem.website_url_preview
                  :if={@current_scope.user.connection.profile.website_url}
                  preview={@website_url_preview}
                  loading={@website_url_preview_loading}
                  url={
                    decr_item(
                      @current_scope.user.connection.profile.website_url,
                      @current_scope.user,
                      @current_scope.user.connection.profile.profile_key,
                      @current_scope.key,
                      @current_scope.user.connection.profile
                    )
                  }
                  label={
                    if @current_scope.user.connection.profile.website_label do
                      decr_item(
                        @current_scope.user.connection.profile.website_label,
                        @current_scope.user,
                        @current_scope.user.connection.profile.profile_key,
                        @current_scope.key,
                        @current_scope.user.connection.profile
                      )
                    else
                      "Website"
                    end
                  }
                />
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" /> About
                </div>
              </:title>
              <div
                :if={@current_scope.user.connection.profile.about}
                class="prose prose-slate dark:prose-invert max-w-none"
              >
                <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {decr_item(
                    @current_scope.user.connection.profile.about,
                    @current_scope.user,
                    @current_scope.user.connection.profile.profile_key,
                    @current_scope.key,
                    @current_scope.user.connection.profile
                  )}
                </p>
              </div>
              <div
                :if={!@current_scope.user.connection.profile.about}
                class="text-center py-8"
              >
                <div class="mb-4">
                  <.phx_icon
                    name="hero-chat-bubble-left-right"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    Share something about yourself!
                  </p>
                </div>
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/app/users/edit-profile"}
                  variant="secondary"
                  color="teal"
                  size="sm"
                  icon="hero-plus"
                >
                  Add Bio
                </MossletWeb.DesignSystem.liquid_button>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Posts Section --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center justify-between w-full">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="size-5 text-emerald-600 dark:text-emerald-400"
                    />
                    <span>Posts</span>
                  </div>
                  <MossletWeb.DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                    {@posts_count}
                  </MossletWeb.DesignSystem.liquid_badge>
                </div>
              </:title>
              <div id="profile-posts" phx-update="stream" class="space-y-4">
                <div class="hidden only:block text-center py-8">
                  <.phx_icon
                    name="hero-pencil-square"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
                    No posts yet. Share your thoughts with your community!
                  </p>
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/timeline"}
                    variant="primary"
                    color="emerald"
                    size="sm"
                    icon="hero-plus"
                  >
                    Create Your First Post
                  </MossletWeb.DesignSystem.liquid_button>
                </div>
                <div
                  :for={{dom_id, post} <- @streams.profile_posts}
                  id={dom_id}
                  class="profile-post-container"
                >
                  <MossletWeb.DesignSystem.liquid_timeline_post
                    user_name={
                      get_profile_post_author_name(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_handle={
                      get_profile_post_author_handle(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_avatar={
                      get_profile_post_author_avatar(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_status={nil}
                    user_status_message={nil}
                    show_post_author_status={false}
                    timestamp={format_profile_post_timestamp(post.inserted_at)}
                    verified={false}
                    content_warning?={false}
                    content_warning={nil}
                    content_warning_category={nil}
                    content={
                      get_profile_post_content(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    images={[]}
                    decrypted_url_preview={nil}
                    stats={
                      %{
                        replies: length(post.replies || []),
                        shares: post.reposts_count || 0,
                        likes: post.favs_count || 0
                      }
                    }
                    post_id={post.id}
                    current_user_id={@current_scope.user.id}
                    post_shared_users={[]}
                    removing_shared_user_id={nil}
                    adding_shared_user={nil}
                    post={post}
                    current_scope={@current_scope}
                    is_repost={false}
                    share_note={nil}
                    liked={false}
                    bookmarked={false}
                    can_repost={false}
                    can_reply?={false}
                    can_bookmark?={false}
                    unread?={false}
                    unread_replies_count={0}
                    unread_nested_replies_by_parent={%{}}
                    calm_notifications={@current_scope.user.calm_notifications}
                    class="shadow-md hover:shadow-lg transition-shadow duration-300"
                  />
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <%!-- Right Column: Quick Actions & Profile Management --%>
          <div
            :if={@current_scope.user && @current_scope.user.id == @profile_user.id}
            class="lg:col-span-1 space-y-6"
          >
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card
              heading_level={2}
              class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
            >
              <:title>
                <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                  Quick Actions
                </div>
              </:title>
              <div class="space-y-3">
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/app/timeline"}
                  variant="primary"
                  color="teal"
                  icon="hero-newspaper"
                  class="w-full"
                >
                  View Timeline
                </MossletWeb.DesignSystem.liquid_button>

                <div class="space-y-2 pt-2">
                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/users/connections"}
                    icon="hero-users"
                    class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                  >
                    Manage Connections
                  </MossletWeb.DesignSystem.liquid_nav_item>

                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/circles"}
                    icon="hero-circle-stack"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Circles
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Profile Stats --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-chart-pie"
                    class="size-5 text-purple-600 dark:text-purple-400"
                  /> Profile Stats
                </div>
              </:title>
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Profile views</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {assigns[:profile_views] || "—"}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.inserted_at,
                      do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                      else: "—"}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.last_activity_at,
                      do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                      else: "Now"}
                  </span>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Privacy & Security --%>
            <MossletWeb.DesignSystem.liquid_card
              :if={@current_scope.user && @current_scope.user.id == @profile_user.id}
              heading_level={2}
              class="border-emerald-200/40 dark:border-emerald-700/40"
            >
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-shield-check"
                    class="size-5 text-emerald-600 dark:text-emerald-400"
                  /> Privacy & Security
                </div>
              </:title>
              <div class="space-y-3">
                <div class="flex items-center gap-3 p-3 bg-emerald-50/50 dark:bg-emerald-900/10 rounded-lg">
                  <div class="size-8 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg flex items-center justify-center">
                    <.phx_icon
                      name="hero-lock-closed"
                      class="size-4 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <div class="text-sm">
                    <p class="font-medium text-emerald-800 dark:text-emerald-200">
                      End-to-End Encrypted
                    </p>
                    <p class="text-emerald-600 dark:text-emerald-400">Your data is protected</p>
                  </div>
                </div>

                <div class="space-y-2">
                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/users/two-factor-authentication"}
                    icon="hero-cog-6-tooth"
                    class="rounded-lg text-sm"
                  >
                    Security Settings
                  </MossletWeb.DesignSystem.liquid_nav_item>

                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/users/edit-visibility"}
                    icon="hero-eye-slash"
                    class="rounded-lg text-sm"
                  >
                    Visibility Controls
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  defp render_public_profile(assigns) do
    ~H"""
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <div class="relative overflow-hidden">
        <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
          <div
            :if={get_banner_image_for_connection(@profile_user.connection) != ""}
            class="absolute inset-0 bg-cover bg-center bg-no-repeat"
            style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
          >
            <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
          </div>

          <div class="absolute inset-0 opacity-20">
            <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
            </div>
          </div>
        </div>

        <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
          <div class="mx-auto max-w-7xl">
            <div class="relative pb-8">
              <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                <div class="relative flex-shrink-0">
                  <MossletWeb.DesignSystem.liquid_avatar
                    src={
                      if @profile_user.connection.profile.show_avatar?,
                        do: get_public_avatar(@profile_user, @current_scope.user)
                    }
                    name={
                      decrypt_public_field(
                        @profile_user.connection.profile.name,
                        @profile_user.connection.profile.profile_key
                      )
                    }
                    size="xxl"
                    status={get_public_status(@profile_user)}
                    status_message={get_public_status_message(@profile_user)}
                    show_status={
                      can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                    }
                    user_id={@profile_user.id}
                    verified={false}
                  />
                </div>

                <div class="flex-1 text-center sm:text-left space-y-4">
                  <div class="space-y-1">
                    <h1
                      :if={@profile_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {decrypt_public_field(
                        @profile_user.connection.profile.name,
                        @profile_user.connection.profile.profile_key
                      )}
                    </h1>

                    <h1
                      :if={!@profile_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"Profile 🌿"}
                    </h1>

                    <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color="cyan"
                        size="sm"
                      >
                        @{decrypt_public_field(
                          @profile_user.connection.profile.username,
                          @profile_user.connection.profile.profile_key
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <MossletWeb.DesignSystem.liquid_badge
                        :if={
                          @profile_user.connection.profile.show_email? &&
                            @profile_user.connection.profile.email
                        }
                        variant="soft"
                        color="cyan"
                        size="sm"
                      >
                        <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                        {decrypt_public_field(
                          @profile_user.connection.profile.email,
                          @profile_user.connection.profile.profile_key
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color="cyan"
                        size="sm"
                      >
                        <.phx_icon name="hero-globe-alt" class="size-3 mr-1" /> Public
                      </MossletWeb.DesignSystem.liquid_badge>
                    </div>
                  </div>

                  <div
                    :if={@current_scope.user && !@current_user_is_profile_owner? && !@user_connection}
                    class="flex flex-col sm:flex-row items-center gap-3"
                  >
                    <MossletWeb.DesignSystem.liquid_button
                      navigate={~p"/app/users/connections"}
                      variant="primary"
                      color="teal"
                      icon="hero-user-plus"
                      class="w-full sm:w-auto"
                    >
                      Connect
                    </MossletWeb.DesignSystem.liquid_button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
            <MossletWeb.DesignSystem.liquid_card
              :if={has_contact_links?(@profile_user.connection.profile)}
              heading_level={2}
            >
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                  Contact & Links
                </div>
              </:title>
              <div class="space-y-4">
                <div
                  :if={@profile_user.connection.profile.alternate_email}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                    <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                    <a
                      href={"mailto:#{decrypt_public_field(@profile_user.connection.profile.alternate_email, @profile_user.connection.profile.profile_key)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {decrypt_public_field(
                        @profile_user.connection.profile.alternate_email,
                        @profile_user.connection.profile.profile_key
                      )}
                    </a>
                  </div>
                </div>

                <MossletWeb.DesignSystem.website_url_preview
                  :if={@profile_user.connection.profile.website_url}
                  preview={@website_url_preview}
                  loading={@website_url_preview_loading}
                  url={
                    decrypt_public_field(
                      @profile_user.connection.profile.website_url,
                      @profile_user.connection.profile.profile_key
                    )
                  }
                  label={
                    if @profile_user.connection.profile.website_label do
                      decrypt_public_field(
                        @profile_user.connection.profile.website_label,
                        @profile_user.connection.profile.profile_key
                      )
                    else
                      "Website"
                    end
                  }
                />
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" /> About
                </div>
              </:title>
              <div
                :if={@profile_user.connection.profile.about}
                class="prose prose-slate dark:prose-invert max-w-none"
              >
                <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {decrypt_public_field(
                    @profile_user.connection.profile.about,
                    @profile_user.connection.profile.profile_key
                  )}
                </p>
              </div>
              <div
                :if={!@profile_user.connection.profile.about}
                class="text-center py-8"
              >
                <div class="text-slate-400 dark:text-slate-500 mb-4">
                  <.phx_icon
                    name="hero-chat-bubble-left-right"
                    class="size-12 mx-auto mb-3 opacity-50"
                  />
                  <p class="text-sm">No bio available.</p>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Posts Section --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center justify-between w-full">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="size-5 text-cyan-600 dark:text-cyan-400"
                    />
                    <span>Posts</span>
                  </div>
                  <MossletWeb.DesignSystem.liquid_badge variant="soft" color="cyan" size="sm">
                    {@posts_count}
                  </MossletWeb.DesignSystem.liquid_badge>
                </div>
              </:title>
              <div id="profile-posts-public" phx-update="stream" class="space-y-4">
                <div class="hidden only:block text-center py-8">
                  <.phx_icon
                    name="hero-chat-bubble-bottom-center-text"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    No public posts yet.
                  </p>
                </div>
                <div
                  :for={{dom_id, post} <- @streams.profile_posts}
                  id={dom_id}
                  class="profile-post-container"
                >
                  <MossletWeb.DesignSystem.liquid_timeline_post
                    user_name={
                      decrypt_public_field(
                        @profile_user.connection.profile.name,
                        @profile_user.connection.profile.profile_key
                      )
                    }
                    user_handle={"@" <> decrypt_public_field(
                      @profile_user.connection.profile.username,
                      @profile_user.connection.profile.profile_key
                    )}
                    user_avatar={get_public_avatar(@profile_user, @current_scope.user)}
                    user_status={get_public_status(@profile_user)}
                    user_status_message={get_public_status_message(@profile_user)}
                    show_post_author_status={
                      can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                    }
                    timestamp={format_profile_post_timestamp(post.inserted_at)}
                    verified={false}
                    content_warning?={false}
                    content_warning={nil}
                    content_warning_category={nil}
                    content={decrypt_public_field(post.body, get_post_key(post))}
                    images={[]}
                    decrypted_url_preview={nil}
                    stats={
                      %{
                        replies: length(post.replies || []),
                        shares: post.reposts_count || 0,
                        likes: post.favs_count || 0
                      }
                    }
                    post_id={post.id}
                    current_user_id={@current_scope.user.id}
                    post_shared_users={[]}
                    removing_shared_user_id={nil}
                    adding_shared_user={nil}
                    post={post}
                    current_scope={@current_scope}
                    is_repost={false}
                    share_note={nil}
                    liked={false}
                    bookmarked={false}
                    can_repost={false}
                    can_reply?={false}
                    can_bookmark?={false}
                    unread?={false}
                    unread_replies_count={0}
                    unread_nested_replies_by_parent={%{}}
                    calm_notifications={@current_scope.user.calm_notifications}
                    class="shadow-md hover:shadow-lg transition-shadow duration-300"
                  />
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <div class="lg:col-span-1 space-y-6">
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card
              :if={!@current_user_is_profile_owner?}
              heading_level={2}
              class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
            >
              <:title>
                <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                  Quick Actions
                </div>
              </:title>
              <div class="space-y-3">
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/app/timeline"}
                  variant="primary"
                  color="teal"
                  icon="hero-newspaper"
                  class="w-full"
                >
                  View Timeline
                </MossletWeb.DesignSystem.liquid_button>

                <div class="space-y-2 pt-2">
                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/users/connections"}
                    icon="hero-users"
                    class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                  >
                    Manage Connections
                  </MossletWeb.DesignSystem.liquid_nav_item>

                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/circles"}
                    icon="hero-circle-stack"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Circles
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-chart-pie"
                    class="size-5 text-purple-600 dark:text-purple-400"
                  /> Profile Stats
                </div>
              </:title>
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.inserted_at,
                      do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                      else: "—"}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.last_activity_at,
                      do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                      else: "Recently"}
                  </span>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  defp render_connections_profile(assigns) do
    ~H"""
    <%!-- Connection Profile Page - Current user viewing their connection's profile --%>
    <.layout
      current_page={:home}
      sidebar_current_page={:home}
      current_scope={@current_scope}
      type="sidebar"
    >
      <%!-- Hero Section with responsive design --%>
      <div class="relative overflow-hidden">
        <%!-- Banner/Cover Image Section --%>
        <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
          <%!-- Banner image if available --%>
          <div
            :if={get_banner_image_for_connection(@profile_user.connection) != ""}
            class="absolute inset-0 bg-cover bg-center bg-no-repeat"
            style={"background-image: url('/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}')"}
          >
            <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
          </div>

          <%!-- Liquid metal overlay pattern --%>
          <div class="absolute inset-0 opacity-20">
            <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent transform -skew-x-12 animate-pulse">
            </div>
          </div>
        </div>

        <%!-- Profile Header --%>
        <div class="relative px-4 sm:px-6 lg:px-8 -mt-8 sm:-mt-12 lg:-mt-16">
          <div class="mx-auto max-w-7xl">
            <div class="relative pb-8">
              <%!-- Avatar and Basic Info --%>
              <div class="flex flex-col sm:flex-row items-center sm:items-start gap-6">
                <%!-- Enhanced Avatar --%>
                <div class="relative flex-shrink-0">
                  <MossletWeb.DesignSystem.liquid_avatar
                    src={
                      if @profile_user.connection.profile.show_avatar?,
                        do:
                          get_connection_avatar_src(
                            @user_connection,
                            @current_scope.user,
                            @current_scope.key
                          )
                    }
                    name={
                      decr_item(
                        @profile_user.connection.profile.name,
                        @current_scope.user,
                        @user_connection.key,
                        @current_scope.key,
                        @profile_user.connection.profile
                      )
                    }
                    size="xxl"
                    status={to_string(@profile_user.status)}
                    status_message={
                      get_user_status_message(@profile_user, @current_scope.user, @current_scope.key)
                    }
                    show_status={
                      can_view_status?(@profile_user, @current_scope.user, @current_scope.key)
                    }
                    user_id={@profile_user.id}
                    verified={false}
                  />
                </div>

                <%!-- Name, username, and info --%>
                <div class="flex-1 text-center sm:text-left space-y-4">
                  <%!-- Name and username --%>
                  <div class="space-y-1">
                    <h1
                      :if={@profile_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"#{decr_item(@profile_user.connection.profile.name,
                      @current_scope.user,
                      @user_connection.key,
                      @current_scope.key,
                      @profile_user.connection.profile)}"}
                    </h1>
                    <h1
                      :if={!@profile_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"Profile 🌿"}
                    </h1>
                    <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-slate-600 dark:text-slate-400">
                      <%!-- username badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color={
                          if(@profile_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        @{decr_item(
                          @profile_user.connection.profile.username,
                          @current_scope.user,
                          @user_connection.key,
                          @current_scope.key,
                          @profile_user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Email badge if show_email? is true --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        :if={
                          @profile_user.connection.profile.show_email? &&
                            @profile_user.connection.profile.email
                        }
                        variant="soft"
                        color={
                          if(@profile_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                        {decr_item(
                          @profile_user.connection.profile.email,
                          @current_scope.user,
                          @user_connection.key,
                          @current_scope.key,
                          @profile_user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Connection badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color="emerald"
                        size="sm"
                      >
                        <.phx_icon
                          name="hero-user-group"
                          class="size-3 mr-1"
                        /> Connection
                      </MossletWeb.DesignSystem.liquid_badge>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Main Content --%>
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left Column: Connection Profile Details --%>
          <div class="lg:col-span-2 space-y-8">
            <%!-- Contact & Links Section --%>
            <MossletWeb.DesignSystem.liquid_card
              :if={has_contact_links?(@profile_user.connection.profile)}
              heading_level={2}
            >
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                  Contact & Links
                </div>
              </:title>
              <div class="space-y-4">
                <div
                  :if={@profile_user.connection.profile.alternate_email}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                    <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                    <a
                      href={"mailto:#{decr_uconn(@profile_user.connection.profile.alternate_email, @current_scope.user, @user_connection.key, @current_scope.key)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {decr_uconn(
                        @profile_user.connection.profile.alternate_email,
                        @current_scope.user,
                        @user_connection.key,
                        @current_scope.key
                      )}
                    </a>
                  </div>
                </div>

                <MossletWeb.DesignSystem.website_url_preview
                  :if={@profile_user.connection.profile.website_url}
                  preview={@website_url_preview}
                  loading={@website_url_preview_loading}
                  url={
                    decr_uconn(
                      @profile_user.connection.profile.website_url,
                      @current_scope.user,
                      @user_connection.key,
                      @current_scope.key
                    )
                  }
                  label={
                    if @profile_user.connection.profile.website_label do
                      decr_uconn(
                        @profile_user.connection.profile.website_label,
                        @current_scope.user,
                        @user_connection.key,
                        @current_scope.key
                      )
                    else
                      "Website"
                    end
                  }
                />
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" /> About
                </div>
              </:title>
              <div
                :if={@profile_user.connection.profile.about}
                class="prose prose-slate dark:prose-invert max-w-none"
              >
                <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {decr_uconn(
                    @profile_user.connection.profile.about,
                    @current_scope.user,
                    @user_connection.key,
                    @current_scope.key
                  )}
                </p>
              </div>
              <div
                :if={!@profile_user.connection.profile.about}
                class="text-center py-8"
              >
                <div class="text-slate-400 dark:text-slate-500 mb-4">
                  <.phx_icon
                    name="hero-chat-bubble-left-right"
                    class="size-12 mx-auto mb-3 opacity-50"
                  />
                  <p class="text-sm">This connection hasn't shared a bio yet.</p>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Posts Section --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center justify-between w-full">
                  <div class="flex items-center gap-2">
                    <.phx_icon
                      name="hero-chat-bubble-bottom-center-text"
                      class="size-5 text-emerald-600 dark:text-emerald-400"
                    />
                    <span>Posts</span>
                  </div>
                  <MossletWeb.DesignSystem.liquid_badge variant="soft" color="emerald" size="sm">
                    {@posts_count}
                  </MossletWeb.DesignSystem.liquid_badge>
                </div>
              </:title>
              <div id="profile-posts-connections" phx-update="stream" class="space-y-4">
                <div class="hidden only:block text-center py-8">
                  <.phx_icon
                    name="hero-chat-bubble-bottom-center-text"
                    class="size-12 mx-auto mb-3 text-slate-300 dark:text-slate-600"
                  />
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    No posts shared with you yet.
                  </p>
                </div>
                <div
                  :for={{dom_id, post} <- @streams.profile_posts}
                  id={dom_id}
                  class="profile-post-container"
                >
                  <MossletWeb.DesignSystem.liquid_timeline_post
                    user_name={
                      get_profile_post_author_name(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_handle={
                      get_profile_post_author_handle(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_avatar={
                      get_profile_post_author_avatar(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    user_status={nil}
                    user_status_message={nil}
                    show_post_author_status={false}
                    timestamp={format_profile_post_timestamp(post.inserted_at)}
                    verified={false}
                    content_warning?={false}
                    content_warning={nil}
                    content_warning_category={nil}
                    content={
                      get_profile_post_content(
                        post,
                        @profile_user,
                        @current_scope.user,
                        @current_scope.key,
                        @user_connection
                      )
                    }
                    images={[]}
                    decrypted_url_preview={nil}
                    stats={
                      %{
                        replies: length(post.replies || []),
                        shares: post.reposts_count || 0,
                        likes: post.favs_count || 0
                      }
                    }
                    post_id={post.id}
                    current_user_id={@current_scope.user.id}
                    post_shared_users={[]}
                    removing_shared_user_id={nil}
                    adding_shared_user={nil}
                    post={post}
                    current_scope={@current_scope}
                    is_repost={false}
                    share_note={nil}
                    liked={false}
                    bookmarked={false}
                    can_repost={false}
                    can_reply?={false}
                    can_bookmark?={false}
                    unread?={false}
                    unread_replies_count={0}
                    unread_nested_replies_by_parent={%{}}
                    calm_notifications={@current_scope.user.calm_notifications}
                    class="shadow-md hover:shadow-lg transition-shadow duration-300"
                  />
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <%!-- Right Column: Connection Info & Stats --%>
          <div class="lg:col-span-1 space-y-6">
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card
              heading_level={2}
              class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
            >
              <:title>
                <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-bolt" class="size-5 text-teal-600 dark:text-teal-400" />
                  Quick Actions
                </div>
              </:title>
              <div class="space-y-3">
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/app/timeline"}
                  variant="primary"
                  color="teal"
                  icon="hero-newspaper"
                  class="w-full"
                >
                  View Timeline
                </MossletWeb.DesignSystem.liquid_button>

                <div class="space-y-2 pt-2">
                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/users/connections"}
                    icon="hero-users"
                    class="rounded-xl group hover:from-blue-50 hover:via-cyan-50 hover:to-blue-50 dark:hover:from-blue-900/20 dark:hover:via-cyan-900/20 dark:hover:to-blue-900/20"
                  >
                    Manage Connections
                  </MossletWeb.DesignSystem.liquid_nav_item>

                  <MossletWeb.DesignSystem.liquid_nav_item
                    navigate={~p"/app/circles"}
                    icon="hero-circle-stack"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Circles
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Connection Stats --%>
            <MossletWeb.DesignSystem.liquid_card heading_level={2}>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-chart-pie"
                    class="size-5 text-purple-600 dark:text-purple-400"
                  /> Profile Stats
                </div>
              </:title>
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Joined</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.inserted_at,
                      do: Calendar.strftime(@profile_user.inserted_at, "%B %Y"),
                      else: "—"}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Last active</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {if @profile_user.last_activity_at,
                      do: "#{Calendar.strftime(@profile_user.last_activity_at, "%b %d")}",
                      else: "Now"}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-slate-600 dark:text-slate-400">Status</span>
                  <span class="font-semibold text-slate-900 dark:text-white">
                    {String.capitalize(to_string(@profile_user.status))}
                  </span>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>
        </div>
      </div>
    </.layout>
    """
  end

  defp render_no_access(assigns) do
    ~H"""
    <.layout current_page={:home} sidebar_current_page={:home}>
      <div class="text-center p-8">
        <p>This profile is not viewable or does not exist.</p>
      </div>
    </.layout>
    """
  end

  defp decrypt_public_field(encrypted_value, encrypted_profile_key) do
    URLPreviewHelpers.decrypt_public_field(encrypted_value, encrypted_profile_key)
  end

  defp get_public_avatar(profile_user, current_user) do
    avatar_url = profile_user.connection.profile.avatar_url

    if avatar_url && avatar_url != "" do
      maybe_get_public_profile_user_avatar(
        profile_user,
        profile_user.connection.profile,
        current_user
      )
    end
  end

  defp get_public_status(profile_user) do
    if StatusHelpers.can_view_status?(profile_user, nil, nil) && profile_user.status do
      to_string(profile_user.status)
    else
      nil
    end
  end

  defp get_public_status_message(profile_user) do
    if StatusHelpers.can_view_status?(profile_user, nil, nil) && profile_user.status_message do
      decrypt_public_field(
        profile_user.status_message,
        profile_user.connection.profile.profile_key
      )
    else
      nil
    end
  end

  defp has_contact_links?(profile) do
    profile.alternate_email || profile.website_url
  end

  defp maybe_load_custom_banner_async(socket, profile_user, profile_owner?) do
    profile = Map.get(profile_user.connection, :profile)
    banner_image = if profile, do: profile.banner_image, else: :waves

    if banner_image == :custom && profile && Map.get(profile, :custom_banner_url) do
      key = socket.assigns.key

      if profile_owner? do
        user = socket.assigns.current_scope.user
        connection_id = user.connection.id

        case Mosslet.Extensions.BannerProcessor.get_banner(connection_id) do
          nil ->
            assign_async(socket, :custom_banner_src, fn ->
              result = load_custom_banner(user, profile, key, connection_id)
              {:ok, %{custom_banner_src: result}}
            end)

          cached_encrypted_binary ->
            assign_async(socket, :custom_banner_src, fn ->
              result = decrypt_cached_banner(cached_encrypted_binary, user, key)
              {:ok, %{custom_banner_src: result}}
            end)
        end
      else
        assign(socket, :custom_banner_src, %Phoenix.LiveView.AsyncResult{ok?: true, result: nil})
      end
    else
      assign(socket, :custom_banner_src, %Phoenix.LiveView.AsyncResult{ok?: true, result: nil})
    end
  end

  defp decrypt_cached_banner(encrypted_binary, user, key) do
    {:ok, d_conn_key} =
      Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

    case Mosslet.Encrypted.Utils.decrypt(%{key: d_conn_key, payload: encrypted_binary}) do
      {:ok, decrypted} -> "data:image/webp;base64,#{Base.encode64(decrypted)}"
      {:error, _reason} -> nil
    end
  end

  defp load_custom_banner(user, profile, key, connection_id) do
    if profile && Map.get(profile, :custom_banner_url) do
      d_banner_url =
        decr_banner(
          profile.custom_banner_url,
          user,
          user.conn_key,
          key
        )

      if is_valid_banner_url?(d_banner_url) do
        case fetch_and_decrypt_banner(d_banner_url, user, key, connection_id) do
          {:ok, decrypted_binary} ->
            "data:image/webp;base64,#{Base.encode64(decrypted_binary)}"

          {:error, _reason} ->
            nil
        end
      else
        nil
      end
    else
      nil
    end
  end

  defp is_valid_banner_url?(nil), do: false
  defp is_valid_banner_url?(""), do: false
  defp is_valid_banner_url?("failed_verification"), do: false
  defp is_valid_banner_url?(url) when is_binary(url), do: String.starts_with?(url, "uploads/")
  defp is_valid_banner_url?(_), do: false

  defp fetch_and_decrypt_banner(banner_url, user, key, connection_id) do
    banners_bucket = Mosslet.Encrypted.Session.banners_bucket()
    host = Mosslet.Encrypted.Session.s3_host()
    host_name = "https://#{banners_bucket}.#{host}"

    config = %{
      region: Mosslet.Encrypted.Session.s3_region(),
      access_key_id: Mosslet.Encrypted.Session.s3_access_key_id(),
      secret_access_key: Mosslet.Encrypted.Session.s3_secret_key_access()
    }

    options = [
      virtual_host: true,
      bucket_as_host: true,
      expires_in: 600
    ]

    {:ok, presigned_url} = ExAws.S3.presigned_url(config, :get, host_name, banner_url, options)

    case Req.get(presigned_url,
           retry: :transient,
           retry_delay: fn n -> n * 500 end,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: encrypted_binary}} ->
        Mosslet.Extensions.BannerProcessor.put_banner(connection_id, encrypted_binary)

        {:ok, d_conn_key} =
          Mosslet.Encrypted.Users.Utils.decrypt_user_attrs_key(user.conn_key, user, key)

        case Mosslet.Encrypted.Utils.decrypt(%{key: d_conn_key, payload: encrypted_binary}) do
          {:ok, decrypted} -> {:ok, decrypted}
          error -> error
        end

      {:ok, %{status: status}} ->
        {:error, "Failed to fetch banner: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch banner: #{inspect(reason)}"}
    end
  end

  defp get_async_banner_src(%Phoenix.LiveView.AsyncResult{ok?: true, result: result}), do: result
  defp get_async_banner_src(_), do: nil

  defp get_profile_post_author_name(post, profile_user, current_user, key, user_connection) do
    profile_owner? = current_user.id == profile_user.id

    if profile_owner? or post.user_id == current_user.id do
      case user_name(current_user, key) do
        name when is_binary(name) -> name
        _ -> "Private Author"
      end
    else
      if user_connection && user_connection.connection do
        profile = user_connection.connection.profile

        if profile && profile.show_name? do
          case decr_uconn(user_connection.connection.name, current_user, user_connection.key, key) do
            name when is_binary(name) -> name
            _ -> "Private Author"
          end
        else
          case decr_uconn(
                 user_connection.connection.username,
                 current_user,
                 user_connection.key,
                 key
               ) do
            username when is_binary(username) -> username
            _ -> "Private Author"
          end
        end
      else
        "Private Author"
      end
    end
  end

  defp get_profile_post_author_handle(post, profile_user, current_user, key, user_connection) do
    profile_owner? = current_user.id == profile_user.id

    if profile_owner? or post.user_id == current_user.id do
      profile = current_user.connection.profile

      case decr_item(profile.username, current_user, profile.profile_key, key, profile) do
        username when is_binary(username) -> "@#{username}"
        _ -> "@author"
      end
    else
      if user_connection && user_connection.connection do
        case decr_uconn(
               user_connection.connection.username,
               current_user,
               user_connection.key,
               key
             ) do
          username when is_binary(username) -> "@#{username}"
          _ -> "@author"
        end
      else
        "@author"
      end
    end
  end

  defp get_profile_post_author_avatar(post, profile_user, current_user, key, user_connection) do
    profile_owner? = current_user.id == profile_user.id

    if profile_owner? or post.user_id == current_user.id do
      if current_user.connection.profile.show_avatar? do
        maybe_get_user_avatar(current_user, key) || "/images/logo.svg"
      else
        "/images/logo.svg"
      end
    else
      if user_connection && show_avatar?(user_connection) do
        case maybe_get_avatar_src(post, current_user, key, []) do
          avatar when is_binary(avatar) and avatar != "" -> avatar
          _ -> "/images/logo.svg"
        end
      else
        "/images/logo.svg"
      end
    end
  end

  defp get_profile_post_key(post, _profile_user, current_user, _user_connection) do
    get_post_key(post, current_user)
  end

  defp get_profile_post_content(post, profile_user, current_user, key, user_connection) do
    post_key = get_profile_post_key(post, profile_user, current_user, user_connection)

    if is_nil(post_key) do
      "[Could not decrypt content]"
    else
      case decr_item(post.body, current_user, post_key, key, post, "body") do
        content when is_binary(content) -> content
        rest -> "#{rest}"
      end
    end
  end

  defp format_profile_post_timestamp(naive_datetime)
       when is_struct(naive_datetime, NaiveDateTime) do
    now = NaiveDateTime.utc_now()
    diff_seconds = NaiveDateTime.diff(now, naive_datetime)
    diff_minutes = div(diff_seconds, 60)
    diff_hours = div(diff_minutes, 60)
    diff_days = div(diff_hours, 24)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_minutes < 60 -> "#{diff_minutes}m"
      diff_hours < 24 -> "#{diff_hours}h"
      diff_days < 7 -> "#{diff_days}d"
      true -> Calendar.strftime(naive_datetime, "%b %d")
    end
  end

  defp format_profile_post_timestamp(_), do: ""
end
