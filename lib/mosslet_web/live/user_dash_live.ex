defmodule MossletWeb.UserDashLive do
  use MossletWeb, :live_view

  alias Mosslet.Accounts
  alias Mosslet.Groups
  alias Mosslet.Memories
  alias Mosslet.Timeline

  import MossletWeb.DesignSystem

  def render(assigns) do
    ~H"""
    <.layout current_page={:dashboard} current_scope={@current_scope} type="sidebar">
      <%!-- Calm dashboard with liquid metal styling like the sidebar --%>
      <.liquid_container class="py-8">
        <h1 class="sr-only">Dashboard</h1>
        <%!-- Profile creation section for new users --%>
        <div
          :if={
            is_nil(@current_scope.user.connection.profile.slug) && @current_scope.user.confirmed_at
          }
          class="mb-8"
        >
          <.liquid_card padding="lg" class="max-w-2xl mx-auto">
            <div class="text-center space-y-6">
              <div class="flex size-16 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 mx-auto">
                <.phx_icon name="hero-user-circle" class="size-8 text-white" />
              </div>
              <div>
                <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
                  Create your profile
                </h2>
                <p class="text-slate-600 dark:text-slate-400">
                  Get started by setting up your profile to connect with others.
                </p>
              </div>
              <.liquid_button
                phx-click={JS.navigate(~p"/app/users/edit-profile")}
                variant="primary"
                color="teal"
                size="lg"
                icon="hero-plus"
              >
                Create Profile
              </.liquid_button>
            </div>
          </.liquid_card>
        </div>
        <.alert
          :if={
            is_nil(@current_scope.user.connection.profile.slug) && !@current_scope.user.confirmed_at
          }
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
      </.liquid_container>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    profile = current_user.connection.profile

    if profile && profile.slug do
      {:ok, socket |> push_navigate(to: ~p"/app/profile/#{profile.slug}")}
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
    {:noreply, socket}
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
