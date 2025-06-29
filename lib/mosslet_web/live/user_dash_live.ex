defmodule MossletWeb.UserDashLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Memories
  alias Mosslet.Timeline

  def render(assigns) do
    ~H"""
    <.layout current_page={:dashboard} current_user={@current_user} key={@key} type="sidebar">
      <.container class="py-16">
        <div :if={is_nil(@current_user.connection.profile) && @current_user.confirmed_at} class="py-8">
          <div class="text-center">
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
          </div>
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

    if connected?(socket) do
      Accounts.private_subscribe(current_user)
      Groups.private_subscribe(current_user)
      Memories.private_subscribe(current_user)
      Memories.connections_subscribe(current_user)
      Timeline.private_subscribe(current_user)
      Timeline.connections_subscribe(current_user)
    end

    if current_user.connection.profile do
      {:ok, socket |> push_navigate(to: ~p"/profile/#{current_user.connection.profile.slug}")}
    else
      {:ok, socket |> assign(:page_title, "Profile")}
    end
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
