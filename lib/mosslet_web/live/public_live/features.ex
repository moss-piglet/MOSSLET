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
          <%!-- Hero section with gradient orbs but cleaner background --%>
          <div class="relative isolate">
            <%!-- Floating gradient orbs for liquid metal effect - responsive and contained --%>
            <div
              class="absolute inset-0 -z-10 overflow-hidden"
              aria-hidden="true"
            >
              <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <%!-- Enhanced hero title focused on wellbeing --%>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    Social media for your wellbeing.
                  </h1>

                  <%!-- Enhanced subtitle focused on mental health --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Tired of feeling anxious, compared, and manipulated? MOSSLET protects your mental health with encryption, privacy, and features designed for calm — not profit.
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

          <%!-- Actual Timeline Feature Preview Section --%>
          <.liquid_container max_width="full" class="relative -mt-12 sm:mt-0 xl:-mt-8">
            <div class="mx-auto max-w-7xl px-6 lg:px-8">
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  See how MOSSLET protects your wellbeing
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Real features designed to give you a calm, private, and healthy social media experience.
                </p>
              </div>

              <%!-- Large centered post mockup matching actual timeline styling --%>
              <div class="max-w-2xl mx-auto mb-12">
                <article class="group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30 hover:border-slate-300/60 dark:hover:border-slate-600/60 transform-gpu will-change-transform">
                  <%!-- Enhanced liquid background on hover --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover:opacity-100 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
                  </div>

                  <%!-- Post content --%>
                  <div class="relative p-6">
                    <%!-- User header --%>
                    <div class="flex items-start gap-4 mb-4">
                      <%!-- Enhanced liquid metal avatar using liquid_avatar component exactly like timeline --%>
                      <.liquid_avatar
                        src={~p"/images/features/meg-aghamyan-unsplash.jpg"}
                        name="Meg Aghamyan"
                        size="md"
                        verified={false}
                        clickable={true}
                      />

                      <%!-- User info matching liquid_timeline_post exactly --%>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-1">
                          <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate">
                            Meg Aghamyan
                          </h3>
                          <%!-- Visibility badge using liquid_badge component exactly like liquid_timeline_post --%>
                          <.liquid_badge
                            variant="soft"
                            color="emerald"
                            size="sm"
                            class="ml-2"
                          >
                            Connections
                          </.liquid_badge>
                        </div>
                        <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                          <span class="truncate">@meg_creates</span>
                          <span class="text-slate-400 dark:text-slate-500">•</span>
                          <time class="flex-shrink-0">12m ago</time>
                        </div>
                      </div>
                    </div>

                    <%!-- Post content matching component --%>
                    <div class="mb-4">
                      <p class="text-slate-900 dark:text-slate-100 leading-relaxed whitespace-pre-wrap text-base">
    Just finished a peaceful coding session without any social media anxiety! 🧘‍♀️

    MOSSLET's design actually helps me focus instead of pulling me into endless scrolling. The content filters are keeping my timeline calm and positive. Finally, a platform that respects my time and mental health! ✨
                      </p>
                    </div>

                    <%!-- Engagement actions exactly matching liquid_timeline_post --%>
                    <div class="flex items-center justify-between pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
                      <%!-- Action buttons with semantic color coding exactly like liquid_timeline_post --%>
                      <div class="flex items-center gap-1">
                        <%!-- Read/Unread toggle action button matching liquid_timeline_post --%>
                        <button class="p-2 rounded-lg transition-all duration-200 ease-out group/read text-slate-400 hover:text-teal-600 dark:hover:text-cyan-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20 active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2">
                          <.phx_icon
                            name="hero-eye-slash"
                            class="h-5 w-5 transition-transform duration-200 group-hover/read:scale-110"
                          />
                          <span class="sr-only">Mark as unread</span>
                        </button>

                        <%!-- Reply action using liquid_timeline_action component --%>
                        <.liquid_timeline_action
                          icon="hero-chat-bubble-oval-left"
                          count={4}
                          label="Reply"
                          color="emerald"
                        />

                        <%!-- Share action using liquid_timeline_action component --%>
                        <.liquid_timeline_action
                          icon="hero-arrow-path"
                          count={0}
                          label="Share"
                          color="emerald"
                        />

                        <%!-- Like action using liquid_timeline_action component (active state) --%>
                        <.liquid_timeline_action
                          icon="hero-heart-solid"
                          count={12}
                          label="Unlike"
                          color="rose"
                          active={true}
                        />
                      </div>

                      <%!-- Bookmark button exactly matching liquid_timeline_post --%>
                      <button class="p-2 rounded-lg transition-all duration-200 ease-out group/bookmark text-amber-600 dark:text-amber-400 bg-amber-50/50 dark:bg-amber-900/20 active:scale-95 focus:outline-none focus:ring-2 focus:ring-amber-500/50 focus:ring-offset-2">
                        <.phx_icon
                          name="hero-bookmark-solid"
                          class="h-5 w-5 transition-transform duration-200 group-hover/bookmark:scale-110"
                        />
                        <span class="sr-only">Bookmark this post</span>
                      </button>
                    </div>
                  </div>
                </article>
              </div>

              <%!-- Three feature cards below the main post with liquid metal styling --%>
              <div class="grid grid-cols-1 gap-8 md:grid-cols-3 max-w-5xl mx-auto">
                <%!-- Privacy Controls Feature with liquid_privacy_selector mockup --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30 shadow-sm">
                        <.phx_icon name="hero-shield-check" class="h-5 w-5 text-purple-700 dark:text-purple-300" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Privacy You Control
                      </span>
                    </div>
                  </:title>

                  <%!-- Mini privacy selector using exact liquid_privacy_selector styling --%>
                  <div class="mb-4">
                    <div class="space-y-3">
                      <div class="text-sm font-medium text-slate-700 dark:text-slate-300">
                        Meg's sharing controls:
                      </div>
                      <div class="flex flex-wrap gap-2">
                        <%!-- Inactive privacy options --%>
                        <div class="relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm bg-slate-100/60 dark:bg-slate-700/60 backdrop-blur-sm border border-slate-200/40 dark:border-slate-600/40 transition-all duration-200 ease-out">
                          <.phx_icon name="hero-lock-closed" class="h-4 w-4 text-slate-500 dark:text-slate-400 flex-shrink-0" />
                          <span class="font-medium text-slate-600 dark:text-slate-400">Private</span>
                        </div>

                        <%!-- Active privacy option with emerald styling --%>
                        <div class="relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm bg-emerald-100/80 dark:bg-emerald-700/80 backdrop-blur-sm border border-emerald-200/60 dark:border-emerald-600/60 transition-all duration-200 ease-out">
                          <.phx_icon name="hero-user-group" class="h-4 w-4 text-emerald-600 dark:text-emerald-300 flex-shrink-0" />
                          <span class="font-medium text-emerald-700 dark:text-emerald-200">Connections</span>
                        </div>

                        <%!-- Inactive privacy option --%>
                        <div class="relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm bg-slate-100/60 dark:bg-slate-700/60 backdrop-blur-sm border border-slate-200/40 dark:border-slate-600/40 transition-all duration-200 ease-out">
                          <.phx_icon name="hero-globe-alt" class="h-4 w-4 text-slate-500 dark:text-slate-400 flex-shrink-0" />
                          <span class="font-medium text-slate-600 dark:text-slate-400">Public</span>
                        </div>
                      </div>
                      <div class="flex items-center gap-2 text-xs text-purple-600 dark:text-purple-400 font-medium">
                        <.phx_icon name="hero-shield-check" class="h-3 w-3" />
                        End-to-end encrypted
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Choose exactly who sees each post. We can't read your content even if we wanted to.
                  </p>
                </.liquid_card>

                <%!-- Content Filtering Feature with actual filter styling --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30 shadow-sm">
                        <.phx_icon name="hero-funnel" class="h-5 w-5 text-amber-700 dark:text-amber-300" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Wellbeing Filters
                      </span>
                    </div>
                  </:title>

                  <%!-- Mini content filter matching actual filter section styling --%>
                  <div class="mb-4">
                    <div class="space-y-3">
                      <div class="flex items-center gap-2">
                        <div class="text-sm font-medium text-slate-700 dark:text-slate-300">Active Filters:</div>
                        <span class="px-2 py-1 text-xs font-medium bg-teal-100 dark:bg-teal-900/30 text-teal-800 dark:text-teal-200 rounded-full">
                          3
                        </span>
                      </div>

                      <div class="flex flex-wrap gap-2">
                        <%!-- Active filter items matching actual filter styling --%>
                        <div class="group relative inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-xl bg-gradient-to-r from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/20 dark:to-rose-900/30 text-rose-800 dark:text-rose-200 border border-rose-200/60 dark:border-rose-700/40 transition-all duration-200 ease-out shadow-sm">
                          <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                          <span class="font-medium">violence</span>
                        </div>

                        <div class="group relative inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-xl bg-gradient-to-r from-amber-100 via-yellow-50 to-amber-100 dark:from-amber-900/30 dark:via-yellow-900/20 dark:to-amber-900/30 text-amber-800 dark:text-amber-200 border border-amber-200/60 dark:border-amber-700/40 transition-all duration-200 ease-out shadow-sm">
                          <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                          <span class="font-medium">politics</span>
                        </div>

                        <div class="group relative inline-flex items-center gap-2 px-3 py-2 text-sm font-medium rounded-xl bg-gradient-to-r from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/20 dark:to-purple-900/30 text-purple-800 dark:text-purple-200 border border-purple-200/60 dark:border-purple-700/40 transition-all duration-200 ease-out shadow-sm">
                          <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                          <span class="font-medium">mental health</span>
                        </div>
                      </div>

                      <div class="flex items-center gap-2 text-xs text-amber-600 dark:text-amber-400 font-medium">
                        <.phx_icon name="hero-sparkles" class="h-3 w-3" />
                        Your timeline, your rules
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Filter out content that harms your mental health. Encrypted preferences only you can see.
                  </p>
                </.liquid_card>

                <%!-- Healthy Usage Feature with actual "You're all caught up" styling --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30 shadow-sm">
                        <.phx_icon name="hero-heart" class="h-5 w-5 text-emerald-700 dark:text-emerald-300" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Healthy by Design
                      </span>
                    </div>
                  </:title>

                  <%!-- Mini "You're all caught up" using actual timeline styling --%>
                  <div class="mb-4">
                    <div class="inline-flex flex-col items-center gap-3 px-4 py-3 rounded-2xl bg-gradient-to-br from-emerald-50/40 via-teal-50/30 to-cyan-50/40 dark:from-emerald-900/10 dark:via-teal-900/5 dark:to-cyan-900/10 border border-emerald-200/40 dark:border-emerald-700/30 w-full">
                      <.phx_icon name="hero-heart" class="h-6 w-6 text-emerald-500" />
                      <div class="text-center">
                        <p class="text-sm font-medium text-emerald-700 dark:text-emerald-300 mb-1">
                          You're all caught up, Meg!
                        </p>
                        <p class="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                          Time to enjoy life offline. Your community will be here when you return.
                        </p>
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Clear boundaries and natural stopping points, no infinite scroll. Get back to living your actual life.
                  </p>
                </.liquid_card>
              </div>
            </div>
          </.liquid_container>

          <%!-- Real Timeline Experience Section --%>
          <.liquid_container max_width="full" class="mt-24 sm:mt-32 lg:mt-40">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Social media that protects your wellbeing
              </h2>
              <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
                Every feature is designed to protect your mental health, privacy, and time — not exploit them for profit.
              </p>
            </div>

            <%!-- Full Timeline Feature Showcase --%>
            <div class="grid max-w-xl mx-auto grid-cols-1 gap-8 lg:max-w-none lg:grid-cols-2 mb-20">
              <%!-- Real-time Updates with Privacy Protection --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 shadow-lg">
                      <.phx_icon name="hero-bolt" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent font-bold">
                      Safe Real-time Connection
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Stay connected with friends in real-time, but only when you want to. No pressure, no FOMO-inducing notifications.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-cyan-600 dark:text-cyan-400 font-medium flex items-center gap-2">
                    <div class="w-2 h-2 bg-cyan-500 rounded-full animate-pulse"></div>
                    Gentle updates • No addiction tactics • Respect your time
                  </div>
                </div>
              </.liquid_card>

              <%!-- Content Protection Features --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 shadow-lg">
                      <.phx_icon name="hero-shield-exclamation" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-bold">
                      Wellbeing-First Content Filters
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Encrypted content warnings and smart filters protect your mental health while respecting others' right to share.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-amber-600 dark:text-amber-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-heart" class="size-3" />
                    Encrypted preferences • Your rules • Mental health protection
                  </div>
                </div>
              </.liquid_card>

              <%!-- Private Bookmark Collections --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-rose-500 to-pink-500 shadow-lg">
                      <.phx_icon name="hero-bookmark" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent font-bold">
                      Your Private Collections
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Save meaningful posts to your private, encrypted collections. No one else knows what you bookmark.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-rose-600 dark:text-rose-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-lock-closed" class="size-3" />
                    Totally private • Encrypted storage • Your personal library
                  </div>
                </div>
              </.liquid_card>

              <%!-- Read Status Without Pressure --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-indigo-500 to-blue-500 shadow-lg">
                      <.phx_icon name="hero-eye" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent font-bold">
                      Pressure-Free Read Tracking
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Keep track of what you've read without the anxiety. Your read status is private and only for your benefit.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-indigo-600 dark:text-indigo-400 font-medium flex items-center gap-2">
                    <div class="w-2 h-2 bg-indigo-500 rounded-full"></div>
                    No pressure • Private tracking • For your convenience only
                  </div>
                </div>
              </.liquid_card>

              <%!-- Encrypted Photo Sharing --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 shadow-lg">
                      <.phx_icon name="hero-photo" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-emerald-500 to-teal-500 bg-clip-text text-transparent font-bold">
                      Truly Private Photo Sharing
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Share photos with complete privacy. Every image is encrypted before leaving your device.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-shield-check" class="size-3" />
                    Military-grade encryption • Your photos, your control • No data harvesting
                  </div>
                </div>
              </.liquid_card>

              <%!-- Anti-Addiction Design --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-purple-500 to-violet-500 shadow-lg">
                      <.phx_icon name="hero-clock" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-bold">
                      Healthy Usage By Design
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Built to respect your time and attention. No infinite scroll, no dark patterns, no addiction mechanics.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-purple-600 dark:text-purple-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-heart" class="size-3" />
                    Natural stopping points • Clear boundaries • Life comes first
                  </div>
                </div>
              </.liquid_card>
            </div>
          </.liquid_container>

          <%!-- Privacy & Encryption Deep Dive --%>
          <.liquid_container max_width="full" class="mt-16">
            <div class="text-center mb-12">
              <h2 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent">
                Privacy that actually works
              </h2>
              <p class="mt-4 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
                Not just promises — real encryption that makes your data unreadable to everyone, including us.
              </p>
            </div>

            <div class="grid max-w-xl mx-auto grid-cols-1 gap-8 lg:max-w-none lg:grid-cols-3">
              <%!-- Asymmetric Encryption --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-red-500 to-rose-500 shadow-lg">
                      <.phx_icon name="hero-key" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-red-500 to-rose-500 bg-clip-text text-transparent font-bold">
                      Asymmetric Encryption
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Your posts, replies, and preferences are encrypted with your personal key pair. Only you can decrypt your content.
                </p>
              </.liquid_card>

              <%!-- Zero Knowledge --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-green-500 to-emerald-500 shadow-lg">
                      <.phx_icon name="hero-eye-slash" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-green-500 to-emerald-500 bg-clip-text text-transparent font-bold">
                      Zero Knowledge
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  We can't read your posts, messages, or even your username. Your data is encrypted before it reaches our servers.
                </p>
              </.liquid_card>

              <%!-- User-Controlled Sharing --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-blue-500 to-cyan-500 shadow-lg">
                      <.phx_icon name="hero-user-group" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-bold">
                      You Control Sharing
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Choose exactly who can see each post: private, connections only, or public. Your encryption keys control access.
                </p>
              </.liquid_card>
            </div>
          </.liquid_container>

          <%!-- Features Section --%>
          <.liquid_container max_width="full" class="mt-24">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                What makes MOSSLET different?
              </h2>
              <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
                While other platforms profit from your data and attention, we protect your wellbeing.
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
