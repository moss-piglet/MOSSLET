defmodule MetamorphicWeb.UserDashLive do
  use MetamorphicWeb, :live_view

  alias Metamorphic.Accounts

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Welcome home
      <:subtitle>This is your account dashboard.</:subtitle>
      <:actions :if={!@current_user.confirmed_at}>
        <.button type="button" class="bg-brand-500" phx-click={JS.patch(~p"/users/confirm")}>
          Confirm my account
        </.button>
      </:actions>
    </.header>

    <div :if={!@current_user.is_onboarded?} class="w-full sm:w-auto mt-4">
      <figure class="rounded-2xl bg-white shadow-lg shadow-brand-500/50 ring-1 ring-brand-900/5">
        <blockquote class="p-12 text-lg font-light leading-8 tracking-tight text-gray-900 space-y-4">
          <p>
            Hi! We're so happy that you're here!
          </p>
          <p>
            Metamorphic is a place for you to connect and share easily with the people in your life (and the world), free from big tech 👀 — like a tiny, little island of peace and privacy.
          </p>
          <p>
            There's a lot underway, so stay tuned and feel free to use the little "envelope" button in the top banner to reach out with any requests for features that you'd like to see, issues you encounter, or simply to say "hi" and express your support.
          </p>
          <p>
            We appreciate you being here and want to hear from you!
          </p>
          <div class="mt-4">
            <.list>
              <:item title="Connections">
                Go here to add new connections with people and edit or remove existing connections.
              </:item>
              <:item title="Memories">Go here to upload and share Memories.</:item>
              <:item title="Posts">
                Go here to read, write, and share Posts with your self, your connections, or the world.
              </:item>
              <:item title="Settings">
                Go here to update your avatar, email, username (default is your email), password, visibility, profile, and enable/disable the forgot password ability.
              </:item>
            </.list>
          </div>
        </blockquote>
        <figcaption class="flex items-center gap-x-4 border-t border-gray-900/10 px-6 py-4">
          <img
            class="h-10 w-10 flex-none rounded-full bg-gray-50"
            src={~p"/images/logo.svg"}
            alt="Metamorphic egg logo"
          />
          <div class="flex-auto">
            <div class="font-semibold">mark</div>
            <div class="text-gray-600">metamorphic</div>
          </div>
          <.button
            title="Click to no longer see this message"
            phx-click="onboard"
            phx-value-id={@current_user.id}
            phx-disable-with="Onboarding..."
          >
            Got it!
          </.button>
        </figcaption>
      </figure>
    </div>

    <div class="w-full sm:w-auto">
      <div class="mt-10 grid grid-cols-1 gap-x-6 gap-y-4 sm:grid-cols-4">
        <.link
          navigate={~p"/ai/conversations"}
          class="group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6"
        >
          <span class="absolute inset-0 rounded-2xl bg-zinc-50 transition group-hover:bg-zinc-100 sm:group-hover:scale-105">
          </span>
          <span class="relative flex items-center gap-4 sm:flex-col">
            <.icon name="hero-cpu-chip" class="h-6 w-6" /> AI
          </span>
        </.link>
        <.link
          navigate={~p"/users/connections"}
          class="group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6"
        >
          <span class="absolute inset-0 rounded-2xl bg-zinc-50 transition group-hover:bg-zinc-100 sm:group-hover:scale-105">
          </span>
          <span class="relative flex items-center gap-4 sm:flex-col">
            <.icon name="hero-user-group" class="h-6 w-6" /> Connections
          </span>
        </.link>
        <.link
          navigate={~p"/memories/"}
          class="group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6"
        >
          <span class="absolute inset-0 rounded-2xl bg-zinc-50 transition group-hover:bg-zinc-100 sm:group-hover:scale-105">
          </span>
          <span class="relative flex items-center gap-4 sm:flex-col">
            <.icon name="hero-photo" class="h-6 w-6" /> Memories
          </span>
        </.link>
        <.link
          navigate={~p"/posts/"}
          class="group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6"
        >
          <span class="absolute inset-0 rounded-2xl bg-zinc-50 transition group-hover:bg-zinc-100 sm:group-hover:scale-105">
          </span>
          <span class="relative flex items-center gap-4 sm:flex-col">
            <.icon name="hero-chat-bubble-oval-left-ellipsis" class="h-6 w-6" /> Posts
          </span>
        </.link>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Dashboard")}
  end

  def handle_event("onboard", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case user.is_onboarded? do
      true ->
        {:noreply, socket}

      false ->
        case Accounts.update_user_onboarding(user, %{is_onboarded?: true}) do
          {:ok, _user} ->
            info = "Welcome! You've been onboarded successfully."

            {:noreply,
             socket
             |> put_flash(:success, info)
             |> redirect(to: ~p"/users/dash")}
        end
    end
  end
end
