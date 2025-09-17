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
      <%!-- Enhanced liquid metal background matching other pages --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <main class="isolate">
          <%!-- Hero section with liquid effects matching other pages --%>
          <div class="relative isolate">
            <%!-- Background pattern with liquid styling --%>
            <div class="absolute inset-0 -z-10 overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-50/10 via-transparent to-emerald-50/10 dark:from-teal-900/5 dark:via-transparent dark:to-emerald-900/5">
              </div>
              <svg
                class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-slate-200/60 dark:stroke-slate-700/60 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
                aria-hidden="true"
              >
                <defs>
                  <pattern
                    id="features-pattern"
                    width="200"
                    height="200"
                    x="50%"
                    y="-1"
                    patternUnits="userSpaceOnUse"
                  >
                    <path d="M.5 200V.5H200" fill="none" />
                  </pattern>
                </defs>
                <rect width="100%" height="100%" stroke-width="0" fill="url(#features-pattern)" />
              </svg>
            </div>

            <%!-- Floating gradient orbs for liquid metal effect --%>
            <div
              class="absolute left-1/2 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
              aria-hidden="true"
            >
              <div
                class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
              >
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <%!-- Enhanced hero title with liquid metal styling matching other pages --%>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    Social media, unexpected.
                  </h1>

                  <%!-- Enhanced subtitle --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you.
                  </p>

                  <%!-- Decorative accent line matching other pages --%>
                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>

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
              </div>
            </div>
          </div>

          <%!-- Interactive Feature Preview Section --%>
          <.liquid_container max_width="full" class="relative -mt-12 sm:mt-0 xl:-mt-8">
            <div class="mx-auto max-w-7xl px-6 lg:px-8">
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Experience the difference
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  See what social media feels like when it's designed for your wellbeing, not profit.
                </p>
              </div>

              <div class="grid grid-cols-1 gap-8 lg:grid-cols-2 xl:grid-cols-4">
                <%!-- Your Private Timeline Preview --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                        <.phx_icon name="hero-newspaper" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                        Your Private Timeline
                      </span>
                    </div>
                  </:title>

                  <%!-- Mock timeline preview --%>
                  <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-4 mb-4">
                    <div class="space-y-3">
                      <div class="flex items-center gap-3">
                        <div class="w-8 h-8 rounded-full bg-gradient-to-r from-blue-400 to-cyan-400">
                        </div>
                        <div class="flex-1">
                          <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-20 mb-1"></div>
                          <div class="h-1.5 bg-slate-200 dark:bg-slate-700 rounded w-16"></div>
                        </div>
                      </div>
                      <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-full"></div>
                      <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-3/4"></div>
                      <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium">
                        🔒 Private • No ads • No tracking
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    See only posts from people you choose to follow. No algorithms, no ads, no manipulation.
                  </p>
                </.liquid_card>

                <%!-- Secure Messaging Preview --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-blue-500 to-cyan-500">
                        <.phx_icon name="hero-chat-bubble-left-right" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-semibold">
                        Secure Messaging
                      </span>
                    </div>
                  </:title>

                  <%!-- Mock messaging preview --%>
                  <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-4 mb-4">
                    <div class="space-y-3">
                      <div class="flex justify-end">
                        <div class="bg-gradient-to-r from-teal-400 to-emerald-400 rounded-lg p-2 max-w-xs">
                          <div class="h-2 bg-white/80 rounded w-16 mb-1"></div>
                          <div class="h-2 bg-white/80 rounded w-12"></div>
                        </div>
                      </div>
                      <div class="flex justify-start">
                        <div class="bg-slate-200 dark:bg-slate-600 rounded-lg p-2 max-w-xs">
                          <div class="h-2 bg-slate-400 dark:bg-slate-400 rounded w-20 mb-1"></div>
                          <div class="h-2 bg-slate-400 dark:bg-slate-400 rounded w-14"></div>
                        </div>
                      </div>
                      <div class="text-xs text-cyan-600 dark:text-cyan-400 font-medium flex items-center gap-1">
                        <.phx_icon name="hero-lock-closed" class="size-3" /> End-to-end encrypted
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Messages encrypted so only you and your recipient can read them. Even we can't see them.
                  </p>
                </.liquid_card>

                <%!-- Privacy Controls Preview --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-violet-500">
                        <.phx_icon name="hero-shield-check" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-semibold">
                        Privacy Controls
                      </span>
                    </div>
                  </:title>

                  <%!-- Mock privacy settings preview --%>
                  <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-4 mb-4">
                    <div class="space-y-3">
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2">
                          <div class="w-3 h-3 rounded-full bg-emerald-500"></div>
                          <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-16"></div>
                        </div>
                        <div class="w-8 h-4 bg-emerald-500 rounded-full"></div>
                      </div>
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2">
                          <div class="w-3 h-3 rounded-full bg-emerald-500"></div>
                          <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-20"></div>
                        </div>
                        <div class="w-8 h-4 bg-emerald-500 rounded-full"></div>
                      </div>
                      <div class="flex items-center justify-between">
                        <div class="flex items-center gap-2">
                          <div class="w-3 h-3 rounded-full bg-red-500"></div>
                          <div class="h-2 bg-slate-300 dark:bg-slate-600 rounded w-14"></div>
                        </div>
                        <div class="w-8 h-4 bg-slate-300 rounded-full"></div>
                      </div>
                      <div class="text-xs text-purple-600 dark:text-purple-400 font-medium">
                        ✓ Private by default
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Granular privacy controls. Choose exactly what to share and with whom.
                  </p>
                </.liquid_card>

                <%!-- Calm Notifications Preview --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-amber-500 to-orange-500">
                        <.phx_icon name="hero-bell" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-semibold">
                        Calm Notifications
                      </span>
                    </div>
                  </:title>

                  <%!-- Mock notification preview --%>
                  <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-4 mb-4">
                    <div class="space-y-3">
                      <div class="flex items-center gap-3 p-2 bg-teal-50 dark:bg-teal-900/30 rounded border-l-4 border-teal-400">
                        <div class="w-6 h-6 rounded-full bg-gradient-to-r from-teal-400 to-emerald-400">
                        </div>
                        <div class="flex-1">
                          <div class="h-2 bg-teal-600 dark:bg-teal-400 rounded w-24 mb-1"></div>
                          <div class="h-1.5 bg-teal-500 dark:bg-teal-500 rounded w-20"></div>
                        </div>
                      </div>
                      <div class="text-xs text-slate-500 dark:text-slate-400">
                        In-app only • No tracking • Respectful timing
                      </div>
                      <div class="text-xs text-amber-600 dark:text-amber-400 font-medium">
                        🧘 Designed for your peace of mind
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Notifications that respect your time. No addiction tactics, just gentle updates when you choose.
                  </p>
                </.liquid_card>
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

          <%!-- Call to action section matching pricing and in-the-know style --%>
          <.liquid_container max_width="xl" class="mt-32 sm:mt-48">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="text-center bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15 border-teal-200/60 dark:border-emerald-700/30"
              >
                <:title>
                  <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Ready for a better social experience?
                  </span>
                </:title>
                <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                  Join thousands who've already discovered what social media feels like without the stress, tracking, and manipulation.
                </p>

                <%!-- Action buttons with enhanced spacing and layout --%>
                <div class="mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-6">
                  <.liquid_button
                    navigate="/auth/register"
                    size="lg"
                    icon="hero-rocket-launch"
                    color="teal"
                    variant="primary"
                    class="group/btn"
                  >
                    Get Started Today
                  </.liquid_button>
                  <.liquid_button
                    navigate="/pricing"
                    variant="secondary"
                    color="blue"
                    icon="hero-banknotes"
                    size="lg"
                    class="group/btn"
                  >
                    See Pricing Options
                  </.liquid_button>
                </div>

                <%!-- Trust indicator --%>
                <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    Lifetime access • Privacy-first design • Human support team
                  </p>
                </div>
              </.liquid_card>
            </div>
          </.liquid_container>
        </main>

        <%!-- Spacer for proper footer separation --%>
        <div class="pb-24"></div>
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
