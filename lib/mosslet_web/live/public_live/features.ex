defmodule MossletWeb.PublicLive.Features do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:features}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <div class="bg-white dark:bg-gray-950 py-24 sm:py-32">
        <%!-- Hero Section --%>
        <.liquid_container max_width="full">
          <div class="mx-auto max-w-4xl text-center">
            <h1 class="text-4xl font-bold tracking-tight text-pretty sm:text-6xl md:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Social media, unexpected.
            </h1>
            <p class="font-regular mt-8 text-xl/8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
              Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you.
            </p>

            <%!-- Call-to-action buttons using design system --%>
            <div class="mt-12 flex flex-col sm:flex-row gap-4 justify-center">
              <.liquid_button
                navigate="/auth/register"
                color="teal"
                variant="primary"
                icon="hero-rocket-launch"
                size="lg"
              >
                Get Started
              </.liquid_button>
              <.liquid_button
                navigate="/pricing"
                color="blue"
                variant="secondary"
                icon="hero-banknotes"
                size="lg"
              >
                See Pricing Options
              </.liquid_button>
            </div>
          </div>
        </.liquid_container>

        <%!-- App Screenshot Section --%>
        <.liquid_container max_width="full" class="relative overflow-hidden pt-20">
          <div class="mx-auto max-w-7xl px-6 lg:px-4">
            <%!-- Light theme screenshot --%>
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 block dark:hidden"
              width="2432"
              height="1442"
            />
            <%!-- Dark theme screenshot --%>
            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-emerald-500/50 ring-1 ring-emerald-900/10 hidden dark:block"
              width="2432"
              height="1442"
            />
            <div class="relative" aria-hidden="true">
              <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-900 pt-[7%]">
              </div>
            </div>
          </div>
          <div class="z-20 relative" aria-hidden="true">
            <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-950 pt-[7%]">
            </div>
          </div>
        </.liquid_container>

        <%!-- Features Section --%>
        <.liquid_container max_width="full" class="mt-24 sm:mt-32 lg:mt-40">
          <div class="text-center mb-16">
            <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Why MOSSLET is different
            </h2>
            <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
              Experience social media as it should be — simple, secure, and designed for your wellbeing.
            </p>
          </div>

          <%!-- Priority Features using liquid cards --%>
          <div class="grid max-w-xl mx-auto grid-cols-1 gap-8 lg:max-w-none lg:grid-cols-3 mb-20">
            <.liquid_card
              padding="lg"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-4">
                  <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 shadow-lg">
                    <.phx_icon name="hero-heart" class="size-7 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-bold">
                    Calm by Design
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                No stress, no anxiety, no manipulation. MOSSLET is designed to give you peace of mind, not keep you scrolling endlessly.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="lg"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-4">
                  <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-blue-500 to-cyan-500 shadow-lg">
                    <.phx_icon name="hero-shield-check" class="size-7 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-bold">
                    Privacy First
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                Your data belongs to you. Strong encryption, no spying, no selling your information to advertisers.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="lg"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-4">
                  <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-purple-500 to-violet-500 shadow-lg">
                    <.phx_icon name="hero-adjustments-horizontal" class="size-7 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-bold">
                    Back to Basics
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                Just the essentials for connecting and sharing. No complicated features, no overwhelming interfaces.
              </p>
            </.liquid_card>
          </div>

          <%!-- Secondary Features Grid using liquid cards --%>
          <div class="grid max-w-xl mx-auto grid-cols-1 gap-8 lg:max-w-none lg:grid-cols-2">
            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-amber-500 to-orange-500">
                    <.phx_icon name="hero-chart-pie" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-semibold">
                    No Identity Graphs
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                Unlike Meta and Google, we don't build profiles about you. What you share stays just that — no invisible consequences.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-cyan-500 to-teal-500">
                    <.phx_icon name="hero-sparkles" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent font-semibold">
                    Free to Be You
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                No algorithms dictating who you are. Delete and start fresh anytime without losing your account.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-rose-500 to-pink-500">
                    <.phx_icon name="hero-sun" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent font-semibold">
                    No Dark Patterns
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                No tricks, traps, or manipulation. Simple design that helps you share and get back to living.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-indigo-500 to-blue-500">
                    <.phx_icon name="hero-user" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent font-semibold">
                    Own Your Data
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                Your data stays yours. Delete everything instantly, anytime. No colonization of your digital life.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                    <.phx_icon name="hero-no-symbol" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                    No Manipulation
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                You won't be turned into a product or weapon. Control your own experience and thoughts.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-blue-500 to-cyan-500">
                    <.phx_icon name="hero-bell" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-semibold">
                    Calm Notifications
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                In-app notifications that don't pressure you. Take your time, respond when you want to.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-violet-500">
                    <.phx_icon name="hero-eye-slash" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-semibold">
                    Private by Default
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                Your account starts private. Choose what to share and with whom. Even we can't see your content.
              </p>
            </.liquid_card>

            <.liquid_card
              padding="md"
              class="group hover:scale-105 transition-all duration-300 ease-out"
            >
              <:title>
                <div class="flex items-center gap-3">
                  <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-amber-500 to-orange-500">
                    <.phx_icon name="hero-lock-closed" class="size-6 text-white" />
                  </div>
                  <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-semibold">
                    Military-Grade Encryption
                  </span>
                </div>
              </:title>
              <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                Strong asymmetric encryption ensures only you can access your data. Double-encrypted for extra security.
              </p>
            </.liquid_card>
          </div>
        </.liquid_container>

        <%!-- Bottom CTA Section using liquid card --%>
        <.liquid_container max_width="full" class="mt-24">
          <.liquid_card padding="lg" class="text-center max-w-4xl mx-auto">
            <:title>
              <span class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Ready for a better social experience?
              </span>
            </:title>
            <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
              Join thousands who've already discovered what social media feels like without the stress, tracking, and manipulation.
            </p>
            <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <.liquid_button
                navigate="/auth/register"
                color="teal"
                variant="primary"
                icon="hero-rocket-launch"
                size="lg"
              >
                Get Started
              </.liquid_button>
              <.liquid_button
                navigate="/pricing"
                color="blue"
                variant="secondary"
                icon="hero-banknotes"
                size="lg"
              >
                See Pricing Options
              </.liquid_button>
            </div>
          </.liquid_card>
        </.liquid_container>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Features")
     |> assign_new(:meta_description, fn ->
       "Social media, unexpected. Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you."
     end)}
  end
end
