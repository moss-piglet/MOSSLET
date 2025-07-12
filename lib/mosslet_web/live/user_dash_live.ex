defmodule MossletWeb.UserDashLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Memories
  alias Mosslet.Timeline

  def render(assigns) do
    ~H"""
    <.layout current_page={:dashboard} current_user={@current_user} key={@key} type="sidebar">
      <.container class="pt-16 pb-6">
        <div :if={is_nil(@current_user.connection.profile) && @current_user.confirmed_at} class="py-8">
          <div class="grow text-center">
            <section aria-labelledby="new-profile-button">
              <.icon
                name="hero-identification"
                class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-200"
              />
              <h3 class="mt-2 text-sm font-semibold text-gray-900 dark:text-gray-100">No profile</h3>
              <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                Get started by creating your profile.
              </p>
              <div class="mt-6">
                <.button
                  type="button"
                  phx-click={JS.navigate(~p"/app/users/edit-profile")}
                  class="rounded-full"
                >
                  <svg
                    class="-ml-0.5 mr-1.5 h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
                  </svg>
                  New Profile
                </.button>
              </div>
            </section>
          </div>
        </div>
        <div :if={
          @current_user.is_subscribed_to_marketing_notifications &&
            !Enum.empty?(@streams.unread_posts.inserts)
        }>
          <%!-- Notifications --%>
          <section aria-labelledby="home-notifications-title" class="flex justify-center w-full">
            <div
              aria-live="assertive"
              class="w-full max-w-xl bg-white dark:bg-gray-800 px-4 py-5 mt-6 shadow dark:shadow-emerald-500/50 rounded-lg sm:px-6"
            >
              <h2
                id="notifications-title-heading"
                class="text-lg font-medium text-gray-900 dark:text-gray-100"
              >
                Notifications
              </h2>
              <div
                id="unread-posts"
                class="flex border-t border-gray-200 w-full flex-col items-center py-4 space-y-2 sm:items-center overflow-y-auto h-48"
                phx-update="stream"
              >
                <div id="unread_posts-empty" class="only:block only:col-span-4 hidden">
                  😌
                </div>
                <div
                  :for={{dom_id, unread_post} <- @streams.unread_posts}
                  id={dom_id}
                  class="bg-background-50 dark:bg-gray-900 shadow dark:shadow-emerald-500/50 pointer-events-auto flex w-full max-w-md rounded-lg shadow-lg ring-1 ring-black/5 mb-2"
                >
                  <div class="w-0 flex-1 p-4">
                    <div class="flex items-start">
                      <div class="shrink-0 pt-0.5">
                        <% user_connection =
                          Accounts.get_user_connection_for_reply_shared_users(
                            unread_post.user_id,
                            @current_user.id
                          ) %>
                        <.phx_avatar
                          :if={user_connection}
                          class="size-10 rounded-full"
                          src={
                            if !show_avatar?(user_connection),
                              do: "",
                              else:
                                maybe_get_avatar_src(
                                  unread_post,
                                  @current_user,
                                  @key,
                                  @streams.unread_posts
                                )
                          }
                          alt="avatar for unread post"
                        />
                      </div>
                      <div class="ml-3 w-0 flex-1">
                        <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
                          {decr_item(
                            unread_post.username,
                            @current_user,
                            get_post_key(unread_post, @current_user),
                            @key,
                            unread_post,
                            "username"
                          )}
                        </p>

                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                          Shared a new Post with you.
                        </p>
                      </div>
                    </div>
                  </div>

                  <div class="flex border-l border-gray-200 dark:border-gray-700">
                    <.link
                      navigate={~p"/app/timeline#timeline-card-#{unread_post.id}"}
                      class="flex w-full items-center justify-center rounded-none rounded-r-lg border border-transparent p-4 text-sm font-medium text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 focus:ring-2 focus:ring-emerald-500 dark:focus:ring-emerald-300 focus:outline-hidden"
                    >
                      View
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>
        <.alert
          :if={is_nil(@current_user.connection.profile) && !@current_user.confirmed_at}
          color="warning"
          class="my-5 max-w-prose"
          heading={gettext("🤫 Unconfirmed account")}
        >
          {gettext(
            "Please check your email for a confirmation link or click the button below to enter your email and send another. Once your email has been confirmed then you can get started creating your profile! 🥳"
          )}
          <.button
            type="button"
            color="secondary"
            class="block mt-4"
            phx-click={JS.patch(~p"/auth/confirm")}
          >
            Confirm my account
          </.button>
        </.alert>
      </.container>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if current_user.connection.profile do
      {:ok, socket |> push_navigate(to: ~p"/app/profile/#{current_user.connection.profile.slug}")}
    else
      if connected?(socket) do
        Accounts.private_subscribe(current_user)
        Groups.private_subscribe(current_user)
        Memories.private_subscribe(current_user)
        Memories.connections_subscribe(current_user)
        Timeline.private_subscribe(current_user)
        Timeline.connections_subscribe(current_user)
      end

      {:ok,
       socket
       |> assign(:page_title, "Home")}
    end
  end

  def handle_params(_params, _url, socket) do
    current_user = socket.assigns.current_user

    unread_posts =
      if current_user.is_subscribed_to_marketing_notifications,
        do: Timeline.unread_posts(current_user),
        else: []

    {:noreply, socket |> stream(:unread_posts, unread_posts, reset: true)}
  end

  def handle_event("onboard", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    key = socket.assigns.key

    case user.is_onboarded? do
      true ->
        {:noreply, socket}

      false ->
        case Accounts.update_user_onboarding(user, %{is_onboarded?: true},
               change_name: false,
               key: key,
               user: user
             ) do
          {:ok, _user} ->
            info = "Welcome! You've been onboarded successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> redirect(to: ~p"/app")}
        end
    end
  end

  def handle_info({:post_created, post}, socket) do
    current_user = socket.assigns.current_user

    if current_user.is_subscribed_to_marketing_notifications do
      unread_post = Timeline.get_unread_post_for_user_and_post(post, current_user)

      {:noreply, stream_insert(socket, :unread_posts, unread_post, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
