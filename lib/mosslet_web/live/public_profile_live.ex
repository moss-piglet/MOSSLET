defmodule MossletWeb.PublicProfileLive do
  use MossletWeb, :live_view

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Timeline
  alias Mosslet.Groups
  alias Mosslet.Repo
  alias Mosslet.Encrypted

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

          {:ok,
           socket
           |> assign(:profile_user, profile_user)
           |> assign(:is_signed_in?, is_signed_in?)
           |> assign(:is_own_profile?, is_own_profile?)
           |> assign(:page_title, "Public Profile")
           |> assign(:slug, slug)}
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
    profile_user = socket.assigns.profile_user

    activity_stats = %{
      posts: get_user_post_count(profile_user),
      connections: length(Accounts.get_all_confirmed_user_connections(profile_user.id)),
      replies: get_user_reply_count(profile_user),
      groups: length(Groups.list_groups(profile_user))
    }

    {:noreply, assign(socket, :activity_stats, activity_stats)}
  end

  def render(assigns) do
    ~H"""
    <.layout current_page={:home} current_user={@current_user} key={@key} type="public">
      <div class="relative overflow-hidden">
        <div class="relative h-48 sm:h-64 lg:h-80 bg-gradient-to-br from-teal-100 via-emerald-50 to-cyan-100 dark:from-teal-900/40 dark:via-emerald-900/30 dark:to-cyan-900/40">
          <div
            :if={get_banner_image_for_connection(@profile_user.connection) != ""}
            class="absolute inset-0 bg-cover bg-center bg-no-repeat"
            style={"background-image: url('#{~p"/images/profile/#{get_banner_image_for_connection(@profile_user.connection)}"}')"}
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

                    <div class="flex items-center justify-center sm:justify-start gap-2 text-lg text-emerald-600 dark:text-emerald-400">
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

      <main class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-12 mt-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
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

            <MossletWeb.DesignSystem.liquid_card>
              <:title>
                <div class="flex items-center gap-2">
                  <.phx_icon
                    name="hero-chart-bar"
                    class="size-5 text-emerald-600 dark:text-emerald-400"
                  /> Activity Overview
                </div>
              </:title>
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <div class="text-center p-4 bg-gradient-to-br from-teal-50 to-emerald-100 dark:from-teal-900/20 dark:to-emerald-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-teal-600 dark:text-teal-400">
                    {@activity_stats.posts}
                  </div>
                  <div class="text-sm text-teal-600 dark:text-teal-400 font-medium">Posts</div>
                </div>

                <div class="text-center p-4 bg-gradient-to-br from-blue-50 to-cyan-100 dark:from-blue-900/20 dark:to-cyan-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">
                    {@activity_stats.connections}
                  </div>
                  <div class="text-sm text-blue-600 dark:text-blue-400 font-medium">Connections</div>
                </div>

                <div class="text-center p-4 bg-gradient-to-br from-purple-50 to-violet-100 dark:from-purple-900/20 dark:to-violet-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-purple-600 dark:text-purple-400">
                    {@activity_stats.replies}
                  </div>
                  <div class="text-sm text-purple-600 dark:text-purple-400 font-medium">Replies</div>
                </div>

                <div class="text-center p-4 bg-gradient-to-br from-indigo-50 to-blue-100 dark:from-indigo-900/20 dark:to-blue-800/20 rounded-xl">
                  <div class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">
                    {@activity_stats.groups}
                  </div>
                  <div class="text-sm text-indigo-600 dark:text-indigo-400 font-medium">Groups</div>
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
                  Create an account to connect with @{decrypt_public_field(
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
      </main>
    </.layout>
    """
  end

  def handle_info({:uconn_updated, connection}, socket) do
    cond do
      Map.has_key?(connection, :connection) && is_map(connection.connection.profile) &&
          connection.connection.profile.visibility == :public ->
        {:noreply, socket}

      true ->
        info = "This profile is not viewable or does not exist."
        {:noreply, socket |> put_flash(:info, info) |> push_navigate(to: ~p"/")}
    end
  end

  def handle_info(_message, socket) do
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
    if profile_user.show_online_presence && profile_user.status do
      to_string(profile_user.status)
    else
      nil
    end
  end

  defp get_public_status_message(profile_user) do
    if profile_user.show_online_presence && profile_user.status_message do
      decrypt_public_field(
        profile_user.status_message,
        profile_user.connection.profile.profile_key
      )
    else
      nil
    end
  end
end
