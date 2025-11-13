defmodule MossletWeb.UserHomeLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Mosslet.Timeline.Post
  alias Mosslet.Groups
  alias Mosslet.Repo

  @folder "uploads/trix"

  def mount(%{"slug" => slug} = _params, _session, socket) do
    current_user = socket.assigns.current_user
    profile_user = Accounts.get_user_from_profile_slug!(slug)
    profile_owner? = current_user.id === profile_user.id

    socket = stream(socket, :presences, [])

    socket =
      if connected?(socket) do
        if current_user do
          Accounts.private_subscribe(current_user)
          Timeline.private_subscribe(current_user)
          Timeline.connections_subscribe(current_user)

          # PRIVACY-FIRST: Track user presence for cache optimization only
          # No usernames or identifying info shared - just for performance
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

          MossletWeb.Presence.subscribe()

          socket = stream(socket, :presences, MossletWeb.Presence.list_online_users())

          # Privately track user activity for auto-status functionality
          Accounts.track_user_activity(current_user, :general)
          socket
        else
          Accounts.subscribe()
          socket
        end
      else
        socket
      end

    # display the user_home_live.html.heex layout (default)
    {:ok,
     socket
     |> assign(:post_shared_users_result, Phoenix.LiveView.AsyncResult.loading())
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
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    # Calculate activity stats using existing functions
    activity_stats = %{
      posts: get_user_post_count(current_user),
      connections: length(Accounts.get_all_confirmed_user_connections(current_user.id)),
      replies: get_user_reply_count(current_user),
      groups: length(Groups.list_groups(current_user))
    }

    socket =
      socket
      |> assign(:activity_stats, activity_stats)
      |> start_async(:assign_post_shared_users, fn ->
        decrypt_shared_user_connections(
          Accounts.get_all_confirmed_user_connections(current_user.id),
          current_user,
          key,
          :post
        )
      end)

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

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def handle_event("new_post", _params, socket) do
    post_shared_users = socket.assigns.post_shared_users

    socket =
      socket
      |> assign(:live_action, :new_post)
      |> assign(:post_shared_users, post_shared_users)
      |> assign(:post, %Post{})

    {:noreply, socket}
  end

  def handle_event("uploads_in_progress", %{"flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("file_too_large", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("nsfw", %{"message" => message, "flag" => flag}, socket) do
    socket =
      socket
      |> assign(:uploads_in_progress, flag)
      |> put_flash(:warning, message)

    {:noreply, socket}
  end

  def handle_event("remove_files", %{"flag" => flag}, socket) do
    socket =
      socket
      |> clear_flash(:warning)
      |> assign(:uploads_in_progress, flag)

    {:noreply, socket}
  end

  def handle_event("error_uploading", %{"message" => message, "flag" => flag}, socket) do
    socket = assign(socket, :uploads_in_progress, flag)
    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event(
        "error_removing",
        %{"message" => message, "url" => url, "flag" => flag},
        socket
      ) do
    Logger.error("Error removing Trix image in UserHomeLive")
    Logger.debug(inspect(url))
    Logger.error("Error removing Trix image in UserHomeLive: #{url}")
    socket = assign(socket, :uploads_in_progress, flag)

    {:noreply, put_flash(socket, :warning, message)}
  end

  def handle_event("trix_key", _params, socket) do
    current_user = socket.assigns.current_user
    # we check if there's a post assigned to the socket,
    # if so, then we can infer that it's a Reply being
    # created and the trix_key will be the already saved
    # post_key (it'll also already be encrypted as well)
    #
    # In this instance we are working with a live_component,
    # so this may be slightly different than the implementation
    # in TimelineLive.Index.
    post = socket.assigns[:post]

    trix_key = socket.assigns.trix_key

    trix_key = if trix_key, do: trix_key, else: generate_and_encrypt_trix_key(current_user, post)

    socket =
      socket
      |> assign(:trix_key, trix_key)

    {:reply, %{response: "success", trix_key: trix_key}, socket}
  end

  def handle_event(
        "add_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"

    image_urls = socket.assigns.image_urls
    updated_urls = [file_path | image_urls] |> Enum.uniq()

    socket =
      socket
      |> assign(:image_urls, updated_urls)

    {:reply, %{response: "success"}, socket}
  end

  def handle_event(
        "remove_image_urls",
        %{"preview_url" => preview_url, "content_type" => content_type},
        socket
      ) do
    file_ext = ext(content_type)
    file_key = get_file_key_from_remove_event(preview_url)
    file_path = "#{@folder}/#{file_key}.#{file_ext}"

    image_urls = socket.assigns.image_urls

    updated_urls = Enum.reject(image_urls, fn url -> url == file_path end)

    {:reply, %{response: "success"}, assign(socket, :image_urls, updated_urls)}
  end

  def handle_event("log_error", %{"error" => error} = error_message, socket) do
    Logger.warning("Trix Error in UserHomeLive")
    Logger.debug(inspect(error_message))
    Logger.error(error)

    {:noreply, socket}
  end

  def handle_async(:assign_post_shared_users, {:ok, fetched_shared_users}, socket) do
    %{post_shared_users_result: result} = socket.assigns

    socket =
      socket
      |> assign(
        :post_shared_users_result,
        Phoenix.LiveView.AsyncResult.ok(result, fetched_shared_users)
      )
      |> assign(:post_shared_users, fetched_shared_users)

    {:noreply, socket}
  end

  def handle_async(:assign_post_shared_users, {:exit, reason}, socket) do
    %{post_shared_users_result: result} = socket.assigns

    socket =
      socket
      |> assign(
        :post_shared_users_result,
        Phoenix.LiveView.AsyncResult.failed(result, {:exit, reason})
      )

    {:noreply, socket}
  end

  defp get_user_post_count(user) do
    import Ecto.Query

    from(up in Timeline.UserPost,
      inner_join: p in Timeline.Post,
      on: up.post_id == p.id,
      where: up.user_id == ^user.id
    )
    |> Repo.aggregate(:count, :id)
  end

  defp get_user_reply_count(user) do
    import Ecto.Query

    from(r in Timeline.Reply,
      inner_join: p in Timeline.Post,
      on: r.post_id == p.id,
      where: r.user_id == ^user.id
    )
    |> Repo.aggregate(:count, :id)
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp get_file_key(url) do
    url |> String.split("/") |> List.last()
  end

  defp get_file_key_from_remove_event(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split(".")
    |> List.first()
  end

  defp ext(content_type) do
    [ext | _] = MIME.extensions(content_type)
    ext
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
            style={"background-image: url('#{~p"/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}"}')"}
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
                      @current_user.conn_key,
                      @key,
                      @current_user.connection.profile)}"}
                    </h1>

                    <h1
                      :if={!@current_user.connection.profile.show_name?}
                      class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-950 dark:text-white sm:text-white sm:dark:text-white"
                    >
                      {"Profile 🌿"}
                    </h1>
                    <div class="flex items-center justify-center sm:justify-start gap-2 text-lg text-emerald-600 dark:text-emerald-400">
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
                          @current_user.conn_key,
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
            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600" /> About
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
                    <.phx_icon name="hero-share" class="size-5 text-blue-600 flex-shrink-0" />
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

            <%!-- Activity Overview Card --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-chart-bar" class="size-5 text-emerald-600" />
                  Activity Overview
                </div>
              </:title>
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <%!-- Posts --%>
                <div class="text-center p-4 bg-gradient-to-br from-teal-50 to-emerald-100 dark:from-teal-900/20 dark:to-emerald-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-teal-600 dark:text-teal-400">
                    {@activity_stats.posts}
                  </div>
                  <div class="text-sm text-teal-600 dark:text-teal-400 font-medium">Posts</div>
                </div>

                <%!-- Connections --%>
                <div class="text-center p-4 bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                    {@activity_stats.connections}
                  </div>
                  <div class="text-sm text-blue-600 dark:text-blue-400 font-medium">Connections</div>
                </div>

                <%!-- Replies --%>
                <div class="text-center p-4 bg-gradient-to-br from-purple-50 to-violet-100 dark:from-purple-900/20 dark:to-violet-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">
                    {@activity_stats.replies}
                  </div>
                  <div class="text-sm text-purple-600 dark:text-purple-400 font-medium">Replies</div>
                </div>

                <%!-- Groups --%>
                <div class="text-center p-4 bg-gradient-to-br from-indigo-50 to-blue-100 dark:from-indigo-900/20 dark:to-blue-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">
                    {@activity_stats.groups}
                  </div>
                  <div class="text-sm text-indigo-600 dark:text-indigo-400 font-medium">Groups</div>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <%!-- Right Column: Quick Actions & Profile Management --%>
          <div
            :if={@current_user && @current_user.id == @profile_user.id}
            class="lg:col-span-1 space-y-6"
          >
            <%!-- Quick Navigation --%>
            <MossletWeb.DesignSystem.liquid_card class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30">
              <:title>
                <h3 class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-bolt" class="size-5" /> Quick Actions
                </h3>
              </:title>
              <div class="space-y-3">
                <%!-- Timeline --%>
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/app/timeline"}
                  variant="primary"
                  color="teal"
                  icon="hero-newspaper"
                  class="w-full"
                >
                  View Timeline
                </MossletWeb.DesignSystem.liquid_button>

                <%!-- Create Post
            <MossletWeb.DesignSystem.liquid_button
              phx-click="new_post"
              variant="secondary"
              color="emerald"
              icon="hero-plus"
              class="w-full"
            >
              Create Post
            </MossletWeb.DesignSystem.liquid_button>
            --%>

                <%!-- Navigation Links --%>
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

                  <%!--
              <MossletWeb.DesignSystem.liquid_nav_item
                navigate={~p"/app/memories"}
                icon="hero-heart"
                class="rounded-xl group hover:from-rose-50 hover:via-pink-50 hover:to-rose-50 dark:hover:from-rose-900/20 dark:hover:via-pink-900/20 dark:hover:to-rose-900/20"
              >
                Memories
              </MossletWeb.DesignSystem.liquid_nav_item>
              --%>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>

            <%!-- Profile Stats --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-chart-pie" class="size-5 text-purple-600" /> Profile Stats
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
                  <.phx_icon name="hero-shield-check" class="size-5 text-emerald-600" />
                  Privacy & Security
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
      <%!-- Simplified public view - only decrypted public fields --%>
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
            style={"background-image: url('#{~p"/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}"}')"}
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
                    src={get_connection_avatar_src(@user_connection, @current_user, @key)}
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
                    <div class="flex items-center justify-center sm:justify-start gap-2 text-lg text-slate-600 dark:text-slate-400">
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
            <%!-- About Section --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-user" class="size-5 text-teal-600" /> About
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

            <%!-- Activity Overview Card --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-chart-bar" class="size-5 text-emerald-600" />
                  Activity Overview
                </div>
              </:title>
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <%!-- Posts --%>
                <div class="text-center p-4 bg-gradient-to-br from-teal-50 to-emerald-100 dark:from-teal-900/20 dark:to-emerald-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-teal-600 dark:text-teal-400">
                    {@activity_stats.posts}
                  </div>
                  <div class="text-sm text-teal-600 dark:text-teal-400 font-medium">Posts</div>
                </div>

                <%!-- Connections --%>
                <div class="text-center p-4 bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                    {@activity_stats.connections}
                  </div>
                  <div class="text-sm text-blue-600 dark:text-blue-400 font-medium">Connections</div>
                </div>

                <%!-- Replies --%>
                <div class="text-center p-4 bg-gradient-to-br from-purple-50 to-violet-100 dark:from-purple-900/20 dark:to-violet-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">
                    {@activity_stats.replies}
                  </div>
                  <div class="text-sm text-purple-600 dark:text-purple-400 font-medium">Replies</div>
                </div>

                <%!-- Groups --%>
                <div class="text-center p-4 bg-gradient-to-br from-indigo-50 to-blue-100 dark:from-indigo-900/20 dark:to-blue-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">
                    {@activity_stats.groups}
                  </div>
                  <div class="text-sm text-indigo-600 dark:text-indigo-400 font-medium">Groups</div>
                </div>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>

          <%!-- Right Column: Connection Info & Stats --%>
          <div class="lg:col-span-1 space-y-6">
            <%!-- Connection Stats --%>
            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon name="hero-chart-pie" class="size-5 text-purple-600" /> Profile Stats
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

            <%!-- Quick Actions --%>
            <MossletWeb.DesignSystem.liquid_card class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30">
              <:title>
                <h3 class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-bolt" class="size-5" /> Actions
                </h3>
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
        <p>This profile is private or does not exist.</p>
      </div>
    </.layout>
    """
  end
end
