defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Encrypted
  alias MossletWeb.Helpers.StatusHelpers

  def mount(%{"slug" => slug} = _params, _session, socket) do
    current_user = socket.assigns.current_user
    profile_user = Accounts.get_user_from_profile_slug!(slug)
    profile_owner? = current_user.id === profile_user.id

    socket = stream(socket, :presences, [])

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

    # display the user_home_live.html.heex layout (default)
    {:ok,
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
     |> assign(
       :user_connection,
       if(profile_owner?, do: nil, else: get_uconn_for_users!(profile_user.id, current_user.id))
     )}
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
        raise "HERE HERE HERE"
        {:noreply, socket}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp render_own_profile(assigns) do
    ~H"""
    <%!-- Enhanced Profile Page with AT Protocol Federation Support --%>
    <.layout current_page={:home} current_user={@current_user} key={@key} type="sidebar">
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
                <%!-- Enhanced Avatar with built-in status support --%>
                <div class="relative flex-shrink-0">
                  <MossletWeb.DesignSystem.liquid_avatar
                    src={maybe_get_user_avatar(@current_user, @key)}
                    name={
                      decr_item(
                        @current_user.connection.profile.name,
                        @current_user,
                        @current_user.conn_key,
                        @key,
                        @current_user.connection.profile
                      )
                    }
                    size="xxl"
                    status={to_string(@current_user.status)}
                    status_message={get_user_status_message(@current_user, @current_user, @key)}
                    show_status={can_view_status?(@current_user, @current_user, @key)}
                    user_id={@current_user.id}
                    verified={@current_user.connection.profile.visibility == "public"}
                  />
                </div>

                <%!-- Name, username, and actions --%>
                <div class="flex-1 text-center sm:text-left space-y-4">
                  <%!-- Name and username --%>
                  <div class="space-y-1">
                    <h1
                      :if={@current_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"#{decr_item(@current_user.connection.profile.name,
                      @current_user,
                      @current_user.connection.profile.profile_key,
                      @key,
                      @current_user.connection.profile)}"}
                    </h1>

                    <h1
                      :if={!@current_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"Profile 🌿"}
                    </h1>
                    <div class="flex items-center justify-center sm:justify-start gap-2 flex-wrap text-lg text-emerald-600 dark:text-emerald-400">
                      <%!-- username badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color={
                          if(@current_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        @{decr_item(
                          @current_user.connection.profile.username,
                          @current_user,
                          @current_user.connection.profile.profile_key,
                          @key,
                          @current_user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Email badge if show_email? is true --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        :if={
                          @current_user.connection.profile.show_email? &&
                            @current_user.connection.profile.email
                        }
                        variant="soft"
                        color={
                          if(@current_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                        {decr_item(
                          @current_user.connection.profile.email,
                          @current_user,
                          @current_user.connection.profile.profile_key,
                          @key,
                          @current_user.connection.profile
                        )}
                      </MossletWeb.DesignSystem.liquid_badge>

                      <%!-- Visibility badge --%>
                      <MossletWeb.DesignSystem.liquid_badge
                        variant="soft"
                        color={
                          if(@current_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon
                          name={
                            if(@current_user.connection.profile.visibility == "public",
                              do: "hero-globe-alt",
                              else: "hero-lock-closed"
                            )
                          }
                          class="size-3 mr-1"
                        />
                        {String.capitalize(to_string(@current_user.connection.profile.visibility))}
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
      <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left Column: Profile Details & Federation --%>
          <div class="lg:col-span-2 space-y-8">
            <%!-- Contact & Links Section --%>
            <MossletWeb.DesignSystem.liquid_card :if={
              has_contact_links?(@current_user.connection.profile)
            }>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-link" class="size-5 text-violet-600 dark:text-violet-400" />
                  Contact & Links
                </div>
              </:title>
              <div class="space-y-4">
                <div
                  :if={@current_user.connection.profile.alternate_email}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-teal-100 to-emerald-100 dark:from-teal-900/30 dark:to-emerald-900/30">
                    <.phx_icon name="hero-envelope" class="size-5 text-teal-600 dark:text-teal-400" />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">Contact Email</p>
                    <a
                      href={"mailto:#{decr_item(@current_user.connection.profile.alternate_email, @current_user, @current_user.connection.profile.profile_key, @key, @current_user.connection.profile)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {decr_item(
                        @current_user.connection.profile.alternate_email,
                        @current_user,
                        @current_user.connection.profile.profile_key,
                        @key,
                        @current_user.connection.profile
                      )}
                    </a>
                  </div>
                </div>

                <div
                  :if={@current_user.connection.profile.website_url}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30">
                    <.phx_icon
                      name="hero-globe-alt"
                      class="size-5 text-violet-600 dark:text-violet-400"
                    />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      {if @current_user.connection.profile.website_label do
                        decr_item(
                          @current_user.connection.profile.website_label,
                          @current_user,
                          @current_user.connection.profile.profile_key,
                          @key,
                          @current_user.connection.profile
                        )
                      else
                        "Website"
                      end}
                    </p>
                    <a
                      href={
                        decr_item(
                          @current_user.connection.profile.website_url,
                          @current_user,
                          @current_user.connection.profile.profile_key,
                          @key,
                          @current_user.connection.profile
                        )
                      }
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-slate-900 dark:text-white hover:text-violet-600 dark:hover:text-violet-400 transition-colors"
                    >
                      {decr_item(
                        @current_user.connection.profile.website_url,
                        @current_user,
                        @current_user.connection.profile.profile_key,
                        @key,
                        @current_user.connection.profile
                      )}
                    </a>
                  </div>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600 dark:text-teal-400" /> About
                </div>
              </:title>
              <div
                :if={@current_user.connection.profile.about}
                class="prose prose-slate dark:prose-invert max-w-none"
              >
                <p class="text-slate-700 dark:text-slate-300 leading-relaxed">
                  {decr_item(
                    @current_user.connection.profile.about,
                    @current_user,
                    @current_user.connection.profile.profile_key,
                    @key,
                    @current_user.connection.profile
                  )}
                </p>
              </div>
              <div
                :if={!@current_user.connection.profile.about}
                class="text-center py-8"
              >
                <div class="text-slate-400 dark:text-slate-500 mb-4">
                  <.phx_icon
                    name="hero-chat-bubble-left-right"
                    class="size-12 mx-auto mb-3 opacity-50"
                  />
                  <p class="text-sm">Share something about yourself!</p>
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

            <%!-- AT Protocol Federation Card --%>
            <MossletWeb.DesignSystem.liquid_card class="border-blue-200/40 dark:border-blue-700/40">
              <:title>
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-2">
                  <div class="flex items-center gap-2 min-w-0">
                    <.phx_icon
                      name="hero-share"
                      class="size-5 text-blue-600 dark:text-blue-400 flex-shrink-0"
                    />
                    <span class="truncate sm:truncate">AT Protocol Federation</span>
                  </div>
                  <div class="flex items-center gap-2 flex-wrap justify-start sm:justify-end w-full sm:w-auto">
                    <MossletWeb.DesignSystem.liquid_badge
                      variant="soft"
                      color={if(assigns[:federation_enabled], do: "amber", else: "slate")}
                      size="sm"
                    >
                      {"Under construction 🚧"}
                    </MossletWeb.DesignSystem.liquid_badge>
                    <MossletWeb.DesignSystem.liquid_badge
                      variant="soft"
                      color={if(assigns[:federation_enabled], do: "blue", else: "slate")}
                      size="sm"
                    >
                      {if(assigns[:federation_enabled], do: "Connected", else: "Not Connected")}
                    </MossletWeb.DesignSystem.liquid_badge>
                  </div>
                </div>
              </:title>

              <div
                :if={!assigns[:federation_enabled]}
                class="text-center py-6"
              >
                <div class="mb-4">
                  <div class="size-16 mx-auto bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-900/20 rounded-2xl flex items-center justify-center mb-3">
                    <.phx_icon name="hero-cloud" class="size-8 text-blue-600 dark:text-blue-400" />
                  </div>
                  <h3 class="text-lg font-semibold text-slate-900 dark:text-white mb-2">
                    Connect to the AT Protocol Network
                  </h3>
                  <p class="text-sm text-slate-600 dark:text-slate-400 max-w-md mx-auto">
                    Share your Mosslet posts with Bluesky and other AT Protocol networks while keeping your privacy controls.
                  </p>
                </div>

                <div class="space-y-3">
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/users/edit-profile#federation"}
                    variant="primary"
                    color="blue"
                    icon="hero-link"
                    class="w-full sm:w-auto"
                  >
                    Connect AT Protocol Account
                  </MossletWeb.DesignSystem.liquid_button>

                  <div class="text-xs text-slate-500 dark:text-slate-400">
                    <.phx_icon name="hero-shield-check" class="size-3 inline mr-1" />
                    Your Mosslet data stays encrypted and private
                  </div>
                </div>
              </div>

              <div
                :if={assigns[:federation_enabled]}
                class="space-y-4"
              >
                <%!-- Connected Account Info --%>
                <div class="flex items-center gap-3 p-3 bg-blue-50/50 dark:bg-blue-900/10 rounded-xl border border-blue-200/40 dark:border-blue-700/40">
                  <div class="size-10 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center">
                    <.phx_icon
                      name="hero-check-circle"
                      class="size-5 text-blue-600 dark:text-blue-400"
                    />
                  </div>
                  <div class="flex-1">
                    <p class="font-medium text-blue-900 dark:text-blue-100">
                      Connected to {assigns[:at_protocol_handle] || "Bluesky"}
                    </p>
                    <p class="text-sm text-blue-600 dark:text-blue-400">
                      Last synced: {assigns[:last_sync] || "Never"}
                    </p>
                  </div>
                  <MossletWeb.DesignSystem.liquid_button
                    variant="ghost"
                    color="blue"
                    size="sm"
                    icon="hero-arrow-top-right-on-square"
                    phx-click="view_at_protocol_profile"
                    data-tippy-content="View on AT Protocol"
                    phx-hook="TippyHook"
                  >
                    View
                  </MossletWeb.DesignSystem.liquid_button>
                </div>

                <%!-- Federation Stats --%>
                <div class="grid grid-cols-2 gap-3">
                  <div class="text-center p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg">
                    <div class="text-xl font-bold text-slate-900 dark:text-white">
                      {assigns[:federated_posts] || 0}
                    </div>
                    <div class="text-xs text-slate-600 dark:text-slate-400">
                      Posts Shared
                    </div>
                  </div>
                  <div class="text-center p-3 bg-slate-50 dark:bg-slate-800/50 rounded-lg">
                    <div class="text-xl font-bold text-slate-900 dark:text-white">
                      {assigns[:at_followers] || 0}
                    </div>
                    <div class="text-xs text-slate-600 dark:text-slate-400">
                      AT Followers
                    </div>
                  </div>
                </div>

                <%!-- Management Actions --%>
                <div class="flex flex-col sm:flex-row gap-2">
                  <MossletWeb.DesignSystem.liquid_button
                    navigate={~p"/app/users/edit-profile#federation"}
                    variant="secondary"
                    color="blue"
                    size="sm"
                    icon="hero-cog-6-tooth"
                    class="flex-1"
                  >
                    Manage Federation
                  </MossletWeb.DesignSystem.liquid_button>

                  <MossletWeb.DesignSystem.liquid_button
                    variant="ghost"
                    color="slate"
                    size="sm"
                    icon="hero-arrow-down-tray"
                    phx-click="export_federation_data"
                    class="flex-1"
                    data-tippy-content="Export your federation data"
                    phx-hook="TippyHook"
                  >
                    Export Data
                  </MossletWeb.DesignSystem.liquid_button>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <%!-- Right Column: Quick Actions & Profile Management --%>
          <div
            :if={@current_user && @current_user.id == @profile_user.id}
            class="lg:col-span-1 space-y-6"
          >
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30">
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
                    navigate={~p"/app/groups"}
                    icon="hero-user-group"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Groups
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Profile Stats --%>
            <MossletWeb.DesignSystem.liquid_card>
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
              :if={@current_user && @current_user.id == @profile_user.id}
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
      </main>
    </.layout>
    """
  end

  defp render_public_profile(assigns) do
    ~H"""
    <.layout current_page={:home} current_user={@current_user} key={@key} type="sidebar">
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
                        do: get_public_avatar(@profile_user, @current_user)
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
                    show_status={can_view_status?(@profile_user, @current_user, @key)}
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
                    :if={@current_user && !@current_user_is_profile_owner? && !@user_connection}
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

      <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
            <MossletWeb.DesignSystem.liquid_card :if={
              has_contact_links?(@profile_user.connection.profile)
            }>
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

                <div
                  :if={@profile_user.connection.profile.website_url}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30">
                    <.phx_icon
                      name="hero-globe-alt"
                      class="size-5 text-violet-600 dark:text-violet-400"
                    />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      {if @profile_user.connection.profile.website_label do
                        decrypt_public_field(
                          @profile_user.connection.profile.website_label,
                          @profile_user.connection.profile.profile_key
                        )
                      else
                        "Website"
                      end}
                    </p>
                    <a
                      href={
                        decrypt_public_field(
                          @profile_user.connection.profile.website_url,
                          @profile_user.connection.profile.profile_key
                        )
                      }
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-slate-900 dark:text-white hover:text-violet-600 dark:hover:text-violet-400 transition-colors"
                    >
                      {decrypt_public_field(
                        @profile_user.connection.profile.website_url,
                        @profile_user.connection.profile.profile_key
                      )}
                    </a>
                  </div>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <MossletWeb.DesignSystem.liquid_card>
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
          </div>

          <div class="lg:col-span-1 space-y-6">
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card
              :if={!@current_user_is_profile_owner?}
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
                    navigate={~p"/app/groups"}
                    icon="hero-user-group"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Groups
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <MossletWeb.DesignSystem.liquid_card>
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
      </main>
    </.layout>
    """
  end

  defp render_connections_profile(assigns) do
    ~H"""
    <%!-- Connection Profile Page - Current user viewing their connection's profile --%>
    <.layout current_page={:home} current_user={@current_user} key={@key} type="sidebar">
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
                        do: get_connection_avatar_src(@user_connection, @current_user, @key)
                    }
                    name={
                      decr_item(
                        @profile_user.connection.profile.name,
                        @current_user,
                        @user_connection.key,
                        @key,
                        @profile_user.connection.profile
                      )
                    }
                    size="xxl"
                    status={to_string(@profile_user.status)}
                    status_message={get_user_status_message(@profile_user, @current_user, @key)}
                    show_status={can_view_status?(@profile_user, @current_user, @key)}
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
                      @current_user,
                      @user_connection.key,
                      @key,
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
                          if(@current_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        @{decr_item(
                          @profile_user.connection.profile.username,
                          @current_user,
                          @user_connection.key,
                          @key,
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
                          if(@current_user.connection.profile.visibility == "public",
                            do: "cyan",
                            else: "emerald"
                          )
                        }
                        size="sm"
                      >
                        <.phx_icon name="hero-envelope" class="size-3 mr-1" />
                        {decr_item(
                          @profile_user.connection.profile.email,
                          @current_user,
                          @user_connection.key,
                          @key,
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
      <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <%!-- Left Column: Connection Profile Details --%>
          <div class="lg:col-span-2 space-y-8">
            <%!-- Contact & Links Section --%>
            <MossletWeb.DesignSystem.liquid_card :if={
              has_contact_links?(@profile_user.connection.profile)
            }>
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
                      href={"mailto:#{decr_uconn(@profile_user.connection.profile.alternate_email, @current_user, @user_connection.key, @key)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {decr_uconn(
                        @profile_user.connection.profile.alternate_email,
                        @current_user,
                        @user_connection.key,
                        @key
                      )}
                    </a>
                  </div>
                </div>

                <div
                  :if={@profile_user.connection.profile.website_url}
                  class="flex items-center gap-3"
                >
                  <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-100 to-purple-100 dark:from-violet-900/30 dark:to-purple-900/30">
                    <.phx_icon
                      name="hero-globe-alt"
                      class="size-5 text-violet-600 dark:text-violet-400"
                    />
                  </div>
                  <div>
                    <p class="text-sm text-slate-500 dark:text-slate-400">
                      {if @profile_user.connection.profile.website_label do
                        decr_uconn(
                          @profile_user.connection.profile.website_label,
                          @current_user,
                          @user_connection.key,
                          @key
                        )
                      else
                        "Website"
                      end}
                    </p>
                    <a
                      href={
                        decr_uconn(
                          @profile_user.connection.profile.website_url,
                          @current_user,
                          @user_connection.key,
                          @key
                        )
                      }
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-slate-900 dark:text-white hover:text-violet-600 dark:hover:text-violet-400 transition-colors"
                    >
                      {decr_uconn(
                        @profile_user.connection.profile.website_url,
                        @current_user,
                        @user_connection.key,
                        @key
                      )}
                    </a>
                  </div>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card>
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
                    @current_user,
                    @user_connection.key,
                    @key
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
          </div>

          <%!-- Right Column: Connection Info & Stats --%>
          <div class="lg:col-span-1 space-y-6">
            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30">
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
                    navigate={~p"/app/groups"}
                    icon="hero-user-group"
                    class="rounded-xl group hover:from-purple-50 hover:via-violet-50 hover:to-purple-50 dark:hover:from-purple-900/20 dark:hover:via-violet-900/20 dark:hover:to-purple-900/20"
                  >
                    Join Groups
                  </MossletWeb.DesignSystem.liquid_nav_item>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Connection Stats --%>
            <MossletWeb.DesignSystem.liquid_card>
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
      </main>
    </.layout>
    """
  end

  defp render_no_access(assigns) do
    ~H"""
    <.layout current_page={:home}>
      <div class="text-center p-8">
        <p>This profile is not viewable or does not exist.</p>
      </div>
    </.layout>
    """
  end

  defp decrypt_public_field(encrypted_value, encrypted_profile_key) do
    case Encrypted.Users.Utils.decrypt_public_item(encrypted_value, encrypted_profile_key) do
      value when is_binary(value) -> value
      _ -> ""
    end
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
end
