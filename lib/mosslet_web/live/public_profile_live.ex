defmodule MossletWeb.PublicProfileLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias MossletWeb.Helpers.StatusHelpers
  alias MossletWeb.Helpers.URLPreviewHelpers

  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
    end

    case Accounts.get_user_from_profile_slug(slug) do
      %Accounts.User{} = profile_user ->
        if profile_user.connection.profile.visibility == :public do
          current_user = socket.assigns[:current_user]
          is_signed_in? = !is_nil(current_user)
          is_own_profile? = current_user && current_user.id == profile_user.id

          socket =
            socket
            |> assign(:profile_user, profile_user)
            |> assign(:is_signed_in?, is_signed_in?)
            |> assign(:is_own_profile?, is_own_profile?)
            |> assign(:page_title, "Public Profile")
            |> assign(:slug, slug)
            |> URLPreviewHelpers.assign_url_preview_defaults()

          socket =
            if connected?(socket) do
              maybe_fetch_website_preview(socket, profile_user)
            else
              socket
            end

          {:ok, socket}
        else
          {:ok,
           socket
           |> put_flash(:info, "This profile is not viewable or does not exist.")
           |> redirect(to: ~p"/auth/sign_in")}
        end

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Profile not found.")
         |> redirect(to: ~p"/")}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.layout current_page={:home} current_user={@current_user} key={@key} type="public">
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
                    src={get_public_avatar(@profile_user, @current_user)}
                    name={
                      URLPreviewHelpers.decrypt_public_field(
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
                      {URLPreviewHelpers.decrypt_public_field(
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
                        @{URLPreviewHelpers.decrypt_public_field(
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
                        {URLPreviewHelpers.decrypt_public_field(
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
                    :if={@is_signed_in? && !@is_own_profile?}
                    class="flex flex-col sm:flex-row items-center gap-3"
                  >
                    <MossletWeb.DesignSystem.liquid_button
                      navigate={~p"/app/users/connections/invite/new-invite"}
                      variant="primary"
                      color="teal"
                      icon="hero-user-plus"
                      class="w-full sm:w-auto"
                    >
                      Connect
                    </MossletWeb.DesignSystem.liquid_button>
                  </div>

                  <div
                    :if={@is_own_profile?}
                    class="flex flex-col sm:flex-row items-center gap-3"
                  >
                    <MossletWeb.DesignSystem.liquid_button
                      navigate={~p"/app/profile/#{@slug}"}
                      variant="primary"
                      color="teal"
                      icon="hero-arrow-right"
                      class="w-full sm:w-auto"
                    >
                      View Full Profile
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
                      href={"mailto:#{URLPreviewHelpers.decrypt_public_field(@profile_user.connection.profile.alternate_email, @profile_user.connection.profile.profile_key)}"}
                      class="text-slate-900 dark:text-white hover:text-teal-600 dark:hover:text-teal-400 transition-colors"
                    >
                      {URLPreviewHelpers.decrypt_public_field(
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
                    URLPreviewHelpers.decrypt_public_field(
                      @profile_user.connection.profile.website_url,
                      @profile_user.connection.profile.profile_key
                    )
                  }
                  label={
                    if @profile_user.connection.profile.website_label do
                      URLPreviewHelpers.decrypt_public_field(
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
                  {URLPreviewHelpers.decrypt_public_field(
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

            <MossletWeb.DesignSystem.liquid_card
              :if={!@is_signed_in?}
              class="bg-gradient-to-br from-teal-50/80 to-emerald-50/60 dark:from-teal-900/20 dark:to-emerald-900/20 border-teal-200/60 dark:border-emerald-700/30"
            >
              <:title>
                <div class="text-lg font-bold tracking-tight bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent flex items-center gap-2">
                  <.phx_icon name="hero-user-plus" class="size-5 text-teal-600 dark:text-teal-400" />
                  Join Mosslet
                </div>
              </:title>
              <div class="space-y-3">
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Create an account to connect with @{URLPreviewHelpers.decrypt_public_field(
                    @profile_user.connection.profile.username,
                    @profile_user.connection.profile.profile_key
                  ) || "this user"} and protect your privacy online.
                </p>
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/auth/register"}
                  variant="primary"
                  color="teal"
                  icon="hero-sparkles"
                  class="w-full"
                >
                  Sign Up
                </MossletWeb.DesignSystem.liquid_button>
                <MossletWeb.DesignSystem.liquid_button
                  navigate={~p"/auth/sign_in"}
                  variant="secondary"
                  color="emerald"
                  icon="hero-arrow-right-on-rectangle"
                  class="w-full"
                >
                  Sign In
                </MossletWeb.DesignSystem.liquid_button>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>
        </div>
      </div>
    </.layout>
    """
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

  def handle_info({:conn_visibility_updated, conn}, socket) do
    slug = socket.assigns.slug
    profile_user = socket.assigns.profile_user

    if conn.user_id == profile_user.id do
      {:noreply, push_navigate(socket, to: ~p"/profile/#{slug}")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:uconn_updated, uconn}, socket) do
    profile_user = socket.assigns.profile_user

    if uconn.user_id == profile_user.id do
      user = Accounts.get_user_with_preloads(uconn.user_id)

      if user.connection.profile.visibility == :public do
        {:noreply, assign(socket, :profile_user, user)}
      else
        {:noreply, push_navigate(socket, to: ~p"/")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info(message, socket) do
    profile_key = get_profile_key(socket.assigns.profile_user)

    case URLPreviewHelpers.handle_preview_result(message, socket, profile_key) do
      {:handled, socket} -> {:noreply, socket}
      {:not_handled, socket} -> {:noreply, socket}
    end
  end

  defp maybe_fetch_website_preview(socket, profile_user) do
    profile = profile_user.connection.profile

    website_url =
      if profile.website_url do
        URLPreviewHelpers.decrypt_public_field(profile.website_url, profile.profile_key)
      end

    profile_key = URLPreviewHelpers.get_public_profile_key(profile.profile_key)
    connection_id = profile_user.connection.id

    URLPreviewHelpers.maybe_start_preview_fetch(socket, website_url, profile_key, connection_id)
  end

  defp get_profile_key(profile_user) do
    URLPreviewHelpers.get_public_profile_key(profile_user.connection.profile.profile_key)
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
    if profile_user.show_online_presence && profile_user.status do
      to_string(profile_user.status)
    else
      nil
    end
  end

  defp get_public_status_message(profile_user) do
    if StatusHelpers.can_view_status?(profile_user, nil, nil) && profile_user.status_message do
      URLPreviewHelpers.decrypt_public_field(
        profile_user.connection.status_message,
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
