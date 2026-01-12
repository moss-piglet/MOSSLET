defmodule MossletWeb.PublicLive.Features do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:features}
      container_max_width={@max_width}
      socket={@socket}
    >
      <%!-- Enhanced liquid metal background matching other pages --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
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
                  <%!-- Enhanced hero title focused on connection --%>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    Built for meaningful sharing
                  </h1>

                  <%!-- Enhanced subtitle focused on connection --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Share moments with the people who matter most. MOSSLET keeps your connections private, your experience calm, and puts you in control.
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

          <%!-- Social Features Section with Timeline Screenshot --%>
          <.liquid_container max_width="full" class="relative mt-16 sm:mt-24 py-16 sm:py-20">
            <div class="absolute inset-0 bg-gradient-to-b from-teal-50/30 via-emerald-50/20 to-transparent dark:from-teal-950/20 dark:via-emerald-950/10 dark:to-transparent">
            </div>
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <div class="flex items-center justify-center gap-3 mb-4">
                <div class="h-px w-12 bg-gradient-to-r from-transparent to-teal-400 dark:to-teal-600">
                </div>
                <span class="text-sm font-semibold uppercase tracking-wider text-teal-600 dark:text-teal-400">
                  Social
                </span>
                <div class="h-px w-12 bg-gradient-to-l from-transparent to-teal-400 dark:to-teal-600">
                </div>
              </div>
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Connect simply with friends and family
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Share moments and memories with the people who matter most. Private, calm, and beautifully simple.
                </p>
              </div>

              <div class="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3 max-w-6xl mx-auto">
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-cyan-500 to-blue-500 shadow-lg">
                        <.phx_icon name="hero-users" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Made for People
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Share photos, updates, and memories with your friends and family. No ads, no algorithms. Simple, genuine connections without the noise.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-purple-500 to-violet-500 shadow-lg">
                        <.phx_icon name="hero-shield-check" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Your Privacy Protected
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Control who sees what with simple privacy settings. Your moments stay between you and the people you choose.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-emerald-500 to-teal-500 shadow-lg">
                        <.phx_icon name="hero-heart" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Calm and Peaceful
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    No endless scroll, no anxiety-inducing algorithms. Just a calm space to stay connected with loved ones.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-rose-500 to-pink-500 shadow-lg">
                        <.phx_icon name="hero-shield-exclamation" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Community Health
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Privacy-first moderation keeps our community healthy. Public posts are checked for content and images, while non-public posts have image-only checks. AI-generated images are clearly labeled.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-indigo-500 to-violet-500 shadow-lg">
                        <.phx_icon name="hero-sparkles" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        AI Transparency
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    We automatically detect AI-generated imagery and display a clear badge so you always know what's real. Authenticity matters in meaningful connections.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg">
                        <.phx_icon name="hero-cpu-chip" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Privacy-First AI
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Our AI checks never store or train on your content. Requests pass through OpenRouter with all data retention disabled, then your content stays asymmetrically encrypted. Safety without surveillance.
                  </p>
                </.liquid_card>
              </div>

              <%!-- Timeline Screenshot --%>
              <div class="relative mt-12 mx-auto max-w-5xl">
                <div class="relative rounded-2xl overflow-hidden shadow-2xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-teal-500/5 via-transparent to-emerald-500/5 dark:from-teal-500/10 dark:to-emerald-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/timeline_light.png"}
                    alt="MOSSLET timeline showing social posts from friends and family"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/timeline_dark.png"}
                    alt="MOSSLET timeline showing social posts from friends and family"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
              </div>
            </div>
          </.liquid_container>

          <%!-- Actual Timeline Feature Preview Section --%>
          <.liquid_container max_width="full" class="relative mt-16 sm:mt-24">
            <div class="mx-auto max-w-7xl px-6 lg:px-8">
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  See MOSSLET in action
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Simple, thoughtful features designed for genuine connection and peace of mind.
                </p>
              </div>

              <%!-- Large centered post mockup matching actual timeline styling --%>
              <div class="max-w-2xl mx-auto mb-12">
                <article
                  id="features-demo-post"
                  class="group relative rounded-2xl overflow-hidden transition-all duration-300 ease-out bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-slate-900/30 hover:border-slate-300/60 dark:hover:border-slate-600/60 transform-gpu will-change-transform"
                >
                  <%!-- Enhanced liquid background on hover --%>
                  <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out group-hover:opacity-100 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
                  </div>

                  <%!-- Left-side shared indicator - "Shared with you" (someone shared TO Meg) --%>
                  <button
                    type="button"
                    id="demo-left-indicator"
                    phx-click={
                      JS.show(
                        to: "#demo-share-overlay",
                        transition:
                          {"ease-out duration-200", "opacity-0 -translate-x-4",
                           "opacity-100 translate-x-0"}
                      )
                    }
                    class="absolute left-0 top-4 bottom-4 w-1 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full opacity-70 hover:opacity-100 hover:w-1.5 transition-all duration-200 cursor-pointer group/left z-10"
                    aria-label="View shared message"
                  >
                    <span class="absolute left-3 top-1/2 -translate-y-1/2 opacity-0 group-hover/left:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-emerald-200/50 dark:border-emerald-700/50">
                      Shared with you
                    </span>
                  </button>

                  <%!-- Right-side indicator - Group visibility (non-interactive since Meg is recipient, not owner) --%>
                  <div
                    id="demo-right-indicator"
                    class="absolute right-0 top-4 bottom-4 w-1 bg-gradient-to-b from-purple-400 via-violet-400 to-purple-400 dark:from-purple-500 dark:via-violet-500 dark:to-purple-500 rounded-l-full opacity-50 transition-all duration-200 group/right z-10"
                    aria-label="Group post visibility"
                  >
                    <span class="absolute right-3 top-1/2 -translate-y-1/2 opacity-0 group-hover/right:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-purple-600 dark:text-purple-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-purple-200/50 dark:border-purple-700/50">
                      Groups
                    </span>
                  </div>

                  <%!-- Left overlay: Share note from someone who shared with Meg --%>
                  <div
                    id="demo-share-overlay"
                    class="hidden absolute inset-0 z-20 bg-white/98 dark:bg-slate-800/98 backdrop-blur-sm rounded-2xl overflow-hidden"
                  >
                    <div class="absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b from-emerald-400 via-teal-400 to-emerald-400 dark:from-emerald-500 dark:via-teal-500 dark:to-emerald-500 rounded-r-full shadow-[0_0_8px_rgba(52,211,153,0.4)] dark:shadow-[0_0_8px_rgba(52,211,153,0.3)]">
                    </div>
                    <div class="h-full flex flex-col p-4 pl-5 overflow-hidden">
                      <div class="flex items-center gap-3 mb-3 shrink-0">
                        <div class="flex items-center justify-center w-9 h-9 rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50 shadow-sm">
                          <.phx_icon
                            name="hero-paper-airplane-solid"
                            class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                          />
                        </div>
                        <div class="flex-1 min-w-0">
                          <p class="text-sm font-semibold text-slate-900 dark:text-slate-100">
                            Shared by Poppy
                          </p>
                        </div>
                        <button
                          type="button"
                          phx-click={
                            JS.hide(
                              to: "#demo-share-overlay",
                              transition:
                                {"ease-in duration-150", "opacity-100 translate-x-0",
                                 "opacity-0 -translate-x-4"}
                            )
                          }
                          class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition-colors duration-200"
                          aria-label="Close"
                        >
                          <.phx_icon name="hero-x-mark" class="h-4 w-4" />
                        </button>
                      </div>
                      <div class="flex-1 min-h-0 overflow-y-auto">
                        <p class="text-sm text-slate-700 dark:text-slate-300 leading-relaxed break-words whitespace-pre-wrap">
                          Hey Meg! 💜 Thought you'd love this — it's exactly what we were talking about last week. Finally a place where we can share without the noise!
                        </p>
                      </div>
                      <button
                        type="button"
                        phx-click={
                          JS.hide(
                            to: "#demo-share-overlay",
                            transition:
                              {"ease-in duration-150", "opacity-100 translate-x-0",
                               "opacity-0 -translate-x-4"}
                          )
                        }
                        class="mt-3 inline-flex items-center gap-1.5 self-start text-xs font-medium text-emerald-600 dark:text-emerald-400 bg-emerald-50/80 dark:bg-emerald-900/30 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 px-3 py-1.5 rounded-lg border border-emerald-200/50 dark:border-emerald-700/50 transition-colors duration-200 shrink-0"
                      >
                        <.phx_icon name="hero-arrow-left-mini" class="h-3.5 w-3.5" /> Back to post
                      </button>
                    </div>
                  </div>

                  <%!-- Post content --%>
                  <div class="relative p-6">
                    <%!-- User header --%>
                    <div class="flex items-start gap-4 mb-4">
                      <.liquid_avatar
                        src={~p"/images/features/meg-aghamyan-unsplash.jpg"}
                        name="Meg Aghamyan"
                        size="md"
                        verified={false}
                        clickable={true}
                      />

                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-1">
                          <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 truncate">
                            Meg Aghamyan
                          </h3>
                        </div>
                        <div class="flex items-center gap-2 text-sm text-slate-500 dark:text-slate-400">
                          <span class="truncate">@meg_creates</span>
                          <span class="text-slate-400 dark:text-slate-500">•</span>
                          <time class="flex-shrink-0">12m ago</time>
                        </div>
                      </div>
                    </div>

                    <%!-- Post content --%>
                    <div class="mb-4">
                      <p class="text-slate-900 dark:text-slate-100 leading-relaxed text-base">
                        Just finished sharing peacefully with my close ones! 🧘‍♀️
                      </p>
                      <p class="text-slate-900 dark:text-slate-100 leading-relaxed text-base mt-4">
                        MOSSLET's clean design helps me focus on what matters — connecting with the people I love. The simple timeline keeps things calm and positive. Finally, social sharing that feels like it should! ✨
                      </p>
                    </div>

                    <%!-- Engagement actions --%>
                    <div class="flex items-center justify-between pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
                      <div class="flex items-center gap-1">
                        <button class="p-2 rounded-lg transition-all duration-200 ease-out group/read text-slate-400 hover:text-teal-600 dark:hover:text-cyan-400 hover:bg-teal-50/50 dark:hover:bg-teal-900/20 active:scale-95 focus:outline-none focus:ring-2 focus:ring-teal-500/50 focus:ring-offset-2">
                          <.phx_icon
                            name="hero-eye-slash"
                            class="h-5 w-5 transition-transform duration-200 group-hover/read:scale-110"
                          />
                          <span class="sr-only">Mark as unread</span>
                        </button>

                        <.liquid_timeline_action
                          icon="hero-chat-bubble-oval-left"
                          count={4}
                          label="Reply"
                          color="emerald"
                        />

                        <.liquid_timeline_action
                          icon="hero-paper-airplane"
                          count={2}
                          label="Share"
                          color="emerald"
                        />

                        <.liquid_timeline_action
                          icon="hero-heart-solid"
                          count={12}
                          label="Unlike"
                          color="rose"
                          active={true}
                        />
                      </div>

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
              <div class="grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-3 max-w-5xl mx-auto">
                <%!-- Privacy Controls Feature with liquid_privacy_selector mockup --%>
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30 shadow-sm">
                        <.phx_icon
                          name="hero-shield-check"
                          class="h-5 w-5 text-purple-700 dark:text-purple-300"
                        />
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
                          <.phx_icon
                            name="hero-lock-closed"
                            class="h-4 w-4 text-slate-500 dark:text-slate-400 flex-shrink-0"
                          />
                          <span class="font-medium text-slate-600 dark:text-slate-400">Private</span>
                        </div>

                        <%!-- Active privacy option with emerald styling --%>
                        <div class="relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm bg-emerald-100/80 dark:bg-emerald-700/80 backdrop-blur-sm border border-emerald-200/60 dark:border-emerald-600/60 transition-all duration-200 ease-out">
                          <.phx_icon
                            name="hero-user-group"
                            class="h-4 w-4 text-emerald-600 dark:text-emerald-300 flex-shrink-0"
                          />
                          <span class="font-medium text-emerald-700 dark:text-emerald-200">
                            Connections
                          </span>
                        </div>

                        <%!-- Inactive privacy option --%>
                        <div class="relative inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-sm bg-slate-100/60 dark:bg-slate-700/60 backdrop-blur-sm border border-slate-200/40 dark:border-slate-600/40 transition-all duration-200 ease-out">
                          <.phx_icon
                            name="hero-globe-alt"
                            class="h-4 w-4 text-slate-500 dark:text-slate-400 flex-shrink-0"
                          />
                          <span class="font-medium text-slate-600 dark:text-slate-400">Public</span>
                        </div>
                      </div>
                      <div class="flex items-center gap-2 text-xs text-purple-600 dark:text-purple-400 font-medium">
                        <.phx_icon name="hero-shield-check" class="h-3 w-3" /> End-to-end encrypted
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Choose exactly who sees each post — just you, your connections, or everyone. Simple and secure.
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
                        <.phx_icon
                          name="hero-funnel"
                          class="h-5 w-5 text-amber-700 dark:text-amber-300"
                        />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Wellbeing Filters
                      </span>
                    </div>
                  </:title>

                  <div class="mb-4 space-y-3">
                    <%!-- Keyword filters preview --%>
                    <div class="flex flex-wrap gap-1.5">
                      <div class="inline-flex items-center gap-1.5 px-2 py-1 text-xs font-medium rounded-lg bg-gradient-to-r from-purple-100 to-violet-100 dark:from-purple-900/30 dark:to-violet-900/30 text-purple-700 dark:text-purple-300 border border-purple-200/60 dark:border-purple-700/40">
                        <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                        <span>spoilers</span>
                      </div>
                      <div class="inline-flex items-center gap-1.5 px-2 py-1 text-xs font-medium rounded-lg bg-gradient-to-r from-amber-100 to-yellow-100 dark:from-amber-900/30 dark:to-yellow-900/30 text-amber-700 dark:text-amber-300 border border-amber-200/60 dark:border-amber-700/40">
                        <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                        <span>politics</span>
                      </div>
                      <div class="inline-flex items-center gap-1.5 px-2 py-1 text-xs font-medium rounded-lg bg-gradient-to-r from-sky-100 to-blue-100 dark:from-sky-900/30 dark:to-blue-900/30 text-sky-700 dark:text-sky-300 border border-sky-200/60 dark:border-sky-700/40">
                        <.phx_icon name="hero-hashtag" class="h-3 w-3 opacity-70" />
                        <span>news</span>
                      </div>
                    </div>

                    <%!-- Content warning mockup matching liquid_timeline_post --%>
                    <div class="relative rounded-xl overflow-hidden border border-slate-200/60 dark:border-slate-700/40">
                      <div
                        id="cw-overlay-demo"
                        class="absolute inset-0 z-10 bg-teal-50/95 dark:bg-slate-800/98 transition-all duration-300 ease-out"
                      >
                        <div class="absolute inset-0 bg-gradient-to-b from-teal-100/50 via-teal-50/30 to-teal-100/50 dark:from-teal-900/40 dark:via-slate-800/20 dark:to-teal-900/40">
                        </div>
                        <div class="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500 opacity-60">
                        </div>
                        <div class="relative h-full flex items-center gap-3 p-3">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-gradient-to-br from-teal-100 to-cyan-100 dark:from-teal-800/60 dark:to-cyan-800/60 border border-teal-200 dark:border-teal-700 shadow-sm">
                            <.phx_icon
                              name="hero-hand-raised"
                              class="h-4 w-4 text-teal-600 dark:text-teal-400"
                            />
                          </div>
                          <div class="flex-1 min-w-0">
                            <div class="flex flex-wrap items-center gap-1.5 mb-0.5">
                              <span class="text-xs font-semibold text-teal-700 dark:text-teal-300">
                                Content Warning
                              </span>
                              <span class="text-[10px] px-1.5 py-0.5 rounded-full bg-teal-100 dark:bg-teal-800/50 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-700">
                                Spoilers
                              </span>
                            </div>
                            <p class="text-xs text-teal-600 dark:text-teal-400 leading-relaxed line-clamp-2">
                              Movie ending discussion
                            </p>
                          </div>
                          <button
                            aria-label="Show hidden content"
                            phx-click={
                              JS.hide(
                                to: "#cw-overlay-demo",
                                transition:
                                  {"ease-in duration-200", "opacity-100 translate-y-0",
                                   "opacity-0 -translate-y-4"}
                              )
                              |> JS.show(
                                to: "#cw-bar-demo",
                                transition:
                                  {"ease-out duration-200", "opacity-0 translate-y-4",
                                   "opacity-100 translate-y-0"}
                              )
                            }
                            class="flex-shrink-0 inline-flex items-center justify-center w-7 h-7 text-white bg-gradient-to-r from-teal-500 to-cyan-500 rounded-lg shadow-sm hover:from-teal-600 hover:to-cyan-600 transition-all duration-200"
                          >
                            <.phx_icon name="hero-eye" class="h-4 w-4" />
                          </button>
                        </div>
                      </div>
                      <button
                        id="cw-bar-demo"
                        class="hidden absolute left-2 right-2 top-0 h-1 rounded-b-lg bg-gradient-to-r from-teal-400 via-cyan-400 to-teal-400 dark:from-teal-500 dark:via-cyan-500 dark:to-teal-500 opacity-70 hover:opacity-100 hover:h-1.5 transition-all duration-200 cursor-pointer group/cw z-20"
                        aria-label="Hide content"
                        phx-click={
                          JS.hide(
                            to: "#cw-bar-demo",
                            transition:
                              {"ease-in duration-150", "opacity-100 translate-y-0",
                               "opacity-0 -translate-y-4"}
                          )
                          |> JS.show(
                            to: "#cw-overlay-demo",
                            transition:
                              {"ease-out duration-200", "opacity-0 translate-y-4",
                               "opacity-100 translate-y-0"}
                          )
                        }
                      >
                        <span class="absolute left-1/2 -translate-x-1/2 top-3 opacity-60 group-hover/cw:opacity-100 transition-opacity duration-200 whitespace-nowrap text-xs font-medium text-teal-600 dark:text-teal-400 bg-white/90 dark:bg-slate-800/90 px-2 py-1 rounded-md shadow-sm border border-teal-200/50 dark:border-teal-700/50">
                          Hide content
                        </span>
                      </button>
                      <div class="p-3 pt-6 bg-white/95 dark:bg-slate-800/95">
                        <p class="text-xs text-slate-700 dark:text-slate-300 leading-relaxed">
                          Just finished watching that movie everyone's been talking about. The ending where the hero turns out to be the villain's long-lost sibling was mind-blowing! 🎬✨
                        </p>
                        <p class="text-xs text-slate-500 dark:text-slate-400 mt-2">
                          10/10 would recommend. Has anyone else seen it?
                        </p>
                      </div>
                    </div>
                  </div>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Authors can add content warnings to help readers prepare. Keyword filters let you customize your feed. Your timeline, your rules.
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
                        <.phx_icon
                          name="hero-heart"
                          class="h-5 w-5 text-emerald-700 dark:text-emerald-300"
                        />
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
                    Natural stopping points help you stay present. Catch up with loved ones, then get back to living.
                  </p>
                </.liquid_card>
              </div>
            </div>
          </.liquid_container>

          <%!-- Journal Features Section with Violet/Purple Accent --%>
          <.liquid_container max_width="full" class="relative mt-24 sm:mt-32 py-16 sm:py-20">
            <div class="absolute inset-0 bg-gradient-to-b from-violet-50/30 via-purple-50/20 to-transparent dark:from-violet-950/20 dark:via-purple-950/10 dark:to-transparent">
            </div>
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <div class="flex items-center justify-center gap-3 mb-4">
                <div class="h-px w-12 bg-gradient-to-r from-transparent to-violet-400 dark:to-violet-600">
                </div>
                <span class="text-sm font-semibold uppercase tracking-wider text-violet-600 dark:text-violet-400">
                  Journal
                </span>
                <div class="h-px w-12 bg-gradient-to-l from-transparent to-violet-400 dark:to-violet-600">
                </div>
              </div>
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-violet-500 to-purple-500 bg-clip-text text-transparent">
                  Connect with yourself
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Your private space for reflection. Our encrypted journal helps you capture thoughts, track your mood, and gain insights — just for you.
                </p>
              </div>

              <div class="grid grid-cols-1 gap-8 md:grid-cols-3 max-w-5xl mx-auto">
                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-violet-500 to-purple-500 shadow-lg">
                        <.phx_icon name="hero-lock-closed" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Encrypted & Private
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Your journal entries are encrypted with your personal key. Only you can read them — not even we can access your private thoughts.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-pink-500 to-rose-500 shadow-lg">
                        <.phx_icon name="hero-face-smile" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Mood Tracking
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Record how you're feeling with each entry. Track your emotional journey over time and discover patterns in your well-being.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="lg"
                  class="group hover:scale-105 transition-all duration-300 ease-out h-full"
                >
                  <:title>
                    <div class="flex items-center gap-3 mb-4">
                      <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg">
                        <.phx_icon name="hero-light-bulb" class="h-5 w-5 text-white" />
                      </div>
                      <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                        Privacy-First AI Insights
                      </span>
                    </div>
                  </:title>

                  <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    Get thoughtful AI reflections on your journal entries to help you understand patterns and gain perspective. Disabled by default — toggle on or off anytime.
                  </p>
                </.liquid_card>
              </div>

              <%!-- Journal Screenshot --%>
              <div class="relative mt-12 mx-auto max-w-5xl">
                <div class="relative rounded-2xl overflow-hidden shadow-2xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-violet-500/5 via-transparent to-purple-500/5 dark:from-violet-500/10 dark:to-purple-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/journal_light.png"}
                    alt="MOSSLET private journal for personal reflection and mood tracking"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/journal_dark.png"}
                    alt="MOSSLET private journal for personal reflection and mood tracking"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
              </div>

              <%!-- Additional Journal Screenshots Grid --%>
              <div class="mt-12 grid grid-cols-1 md:grid-cols-2 gap-8 max-w-5xl mx-auto">
                <div class="relative rounded-2xl overflow-hidden shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-violet-500/5 via-transparent to-purple-500/5 dark:from-violet-500/10 dark:to-purple-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/journal_book_light.png"}
                    alt="MOSSLET journal books for organizing your thoughts"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/journal_book_dark.png"}
                    alt="MOSSLET journal books for organizing your thoughts"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
                <div class="relative rounded-2xl overflow-hidden shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-violet-500/5 via-transparent to-purple-500/5 dark:from-violet-500/10 dark:to-purple-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/journal_new_entry_light.png"}
                    alt="MOSSLET new journal entry with mood tracking"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/journal_new_entry_dark.png"}
                    alt="MOSSLET new journal entry with mood tracking"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
              </div>
            </div>
          </.liquid_container>

          <%!-- Real Timeline Experience Section --%>
          <.liquid_container max_width="full" class="mt-24 sm:mt-32 lg:mt-40">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Features that put you in control
              </h2>
              <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
                Simple, thoughtful tools to share moments and stay connected with the people who matter most.
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
                      <.phx_icon name="hero-bell" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent font-bold">
                      Gentle Notifications
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Stay updated without the overwhelm. In-app notifications appear only while you're using MOSSLET, with optional daily email digests.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-cyan-600 dark:text-cyan-400 font-medium flex items-center gap-2">
                    <div class="w-2 h-2 bg-cyan-500 rounded-full animate-pulse"></div>
                    Simple alerts • Private • Respect your time
                  </div>
                </div>
              </.liquid_card>

              <%!-- Email Notifications Feature --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 shadow-lg">
                      <.phx_icon name="hero-envelope" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-cyan-500 to-blue-500 bg-clip-text text-transparent font-bold">
                      Daily Email Digests
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Stay connected without inbox clutter. Get a simple daily summary of what's new from your connections.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-cyan-600 dark:text-cyan-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-calendar-days" class="size-3" />
                    Max 1 email/day • Your choice • No spam
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
                      <.phx_icon name="hero-funnel" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-bold">
                      Content Preferences
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Customize your feed to see what matters to you. Simple filters help create a positive experience.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-amber-600 dark:text-amber-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-heart" class="size-3" />
                    Your preferences • Private settings • Positive feed
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
                      Personal Bookmarks
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Save posts that matter to you. Your bookmarks are private — only you can see what you've saved.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-rose-600 dark:text-rose-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-lock-closed" class="size-3" />
                    Private • Organized • Your personal library
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
                      Simple Read Tracking
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Keep track of what you've seen. Read status is just for your convenience — totally private.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-indigo-600 dark:text-indigo-400 font-medium flex items-center gap-2">
                    <div class="w-2 h-2 bg-indigo-500 rounded-full"></div>
                    Your convenience • Private • Easy to manage
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
                      Private Photo Sharing
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Share photos with the people you choose. Your memories stay between you and your connections.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-emerald-600 dark:text-emerald-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-shield-check" class="size-3" />
                    Private • Secure • Your photos, your choice
                  </div>
                </div>
              </.liquid_card>

              <%!-- Private Journal --%>
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-amber-500 to-yellow-500 shadow-lg">
                      <.phx_icon name="hero-book-open" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-yellow-500 bg-clip-text text-transparent font-bold">
                      Private Journal
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Capture your thoughts in encrypted journals. Organize entries into books and reflect on your journey — completely private.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-amber-600 dark:text-amber-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-lock-closed" class="size-3" />
                    Unlimited entries • Unlimited books • End-to-end encrypted
                  </div>
                </div>
              </.liquid_card>

              <%!-- Healthy Design --%>
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
                      Thoughtful Design
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed mb-4">
                  Built to respect your time. Clear endings, no endless scroll — just catch up and get back to life.
                </p>
                <div class="bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-800 dark:to-slate-700 rounded-lg p-3">
                  <div class="text-xs text-purple-600 dark:text-purple-400 font-medium flex items-center gap-2">
                    <.phx_icon name="hero-heart" class="size-3" />
                    Natural stopping points • Simple • Life comes first
                  </div>
                </div>
              </.liquid_card>
            </div>

            <%!-- Connections & Profile Screenshots --%>
            <div class="mt-16 mx-auto max-w-7xl px-6 lg:px-8">
              <div class="flex items-center justify-center gap-3 mb-4">
                <div class="h-px w-12 bg-gradient-to-r from-transparent to-cyan-400 dark:to-cyan-600">
                </div>
                <span class="text-sm font-semibold uppercase tracking-wider text-cyan-600 dark:text-cyan-400">
                  Connections
                </span>
                <div class="h-px w-12 bg-gradient-to-l from-transparent to-cyan-400 dark:to-cyan-600">
                </div>
              </div>
              <div class="text-center mb-12">
                <h3 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-3xl bg-gradient-to-r from-cyan-500 to-blue-500 bg-clip-text text-transparent">
                  Your people, your way
                </h3>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Manage your connections and share your profile with the people who matter most.
                </p>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-5xl mx-auto">
                <div class="relative rounded-2xl overflow-hidden shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-cyan-500/5 via-transparent to-blue-500/5 dark:from-cyan-500/10 dark:to-blue-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/connections_light.png"}
                    alt="MOSSLET connections - manage who you share with"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/connections_dark.png"}
                    alt="MOSSLET connections - manage who you share with"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
                <div class="relative rounded-2xl overflow-hidden shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-cyan-500/5 via-transparent to-blue-500/5 dark:from-cyan-500/10 dark:to-blue-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/profile_light.png"}
                    alt="MOSSLET profile - your personal space"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/profile_dark.png"}
                    alt="MOSSLET profile - your personal space"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
              </div>
            </div>
          </.liquid_container>

          <%!-- Privacy & Encryption Deep Dive --%>
          <.liquid_container max_width="full" class="mt-16">
            <div class="text-center mb-12">
              <h2 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent">
                Privacy built in from the start
              </h2>
              <p class="mt-4 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
                Strong encryption keeps your moments between you and the people you choose.
              </p>
            </div>

            <div class="grid max-w-xl mx-auto grid-cols-1 gap-8 lg:max-w-none lg:grid-cols-3">
              <%!-- Strong Encryption --%>
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
                      Strong Encryption
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Your posts and messages are encrypted with password-derived keys. SHA-512 hashing for searchable data and AES-GCM encryption at rest add extra layers of protection.
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
                      Your Data, Your Eyes Only
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  We designed MOSSLET so we can't read your posts, messages, or username. You control who sees what — that's how it should be.
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
                      Share On Your Terms
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Choose who sees each post: private, connections, or public. Set expiration dates for posts, and when you delete something, it's gone everywhere — instantly and completely.
                </p>
              </.liquid_card>
            </div>

            <%!-- Circles Chat Screenshots --%>
            <div class="mt-16 mx-auto max-w-7xl px-6 lg:px-8">
              <div class="flex items-center justify-center gap-3 mb-4">
                <div class="h-px w-12 bg-gradient-to-r from-transparent to-rose-400 dark:to-rose-600">
                </div>
                <span class="text-sm font-semibold uppercase tracking-wider text-rose-600 dark:text-rose-400">
                  Circles
                </span>
                <div class="h-px w-12 bg-gradient-to-l from-transparent to-rose-400 dark:to-rose-600">
                </div>
              </div>
              <div class="text-center mb-12">
                <h3 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-3xl bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent">
                  Private group conversations
                </h3>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  Create Circles for your closest groups — family, friends, or any community you choose.
                </p>
              </div>

              <div class="relative mx-auto max-w-4xl">
                <div class="relative rounded-2xl overflow-hidden shadow-2xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
                  <div class="absolute inset-0 bg-gradient-to-tr from-rose-500/5 via-transparent to-pink-500/5 dark:from-rose-500/10 dark:to-pink-500/10">
                  </div>
                  <img
                    src={~p"/images/screenshots/circles_chat_light.png"}
                    alt="MOSSLET Circles - private group chat with your closest people"
                    class="relative w-full h-auto dark:hidden"
                  />
                  <img
                    src={~p"/images/screenshots/circles_chat_dark.png"}
                    alt="MOSSLET Circles - private group chat with your closest people"
                    class="relative w-full h-auto hidden dark:block"
                  />
                </div>
              </div>
            </div>
          </.liquid_container>

          <%!-- Features Section --%>
          <.liquid_container max_width="full" class="mt-24">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                What makes MOSSLET different?
              </h2>
              <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
                Social sharing built around what matters — genuine connection with the people you care about.
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
                      Calm and Simple
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  A peaceful experience designed around you. Share moments with loved ones, then get back to living.
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
                  Your moments stay between you and the people you choose. Strong encryption and simple privacy controls.
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
                  Just the essentials for connecting and sharing. Simple, intuitive, no clutter.
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
                      No Tracking
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  We don't build profiles or track behavior. Your activity stays private and isn't used to target you.
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
                      Fresh Start Anytime
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Clear your history and start fresh whenever you want without losing your account.
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
                      Honest Design
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Clear, straightforward interface. No tricks or hidden complexity — just simple sharing.
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
                      You Own Your Data
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Your data is yours. Delete everything instantly, anytime — no questions asked.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                      <.phx_icon name="hero-hand-raised" class="size-6 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                      Your Experience, Your Way
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Full control over what you see and share. Customize your experience to fit your life.
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
                      Gentle Notifications
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  In-app notifications that don't interrupt your day. Optional daily email digest — max 1 per day.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-violet-500">
                      <.phx_icon name="hero-lock-closed" class="size-6 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-semibold">
                      Private by Default
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Your account starts private. Choose what to share and with whom on your terms.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-amber-500 to-orange-500">
                      <.phx_icon name="hero-shield-check" class="size-6 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-semibold">
                      Strong Encryption
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-400 leading-relaxed">
                  Multiple layers of encryption protect your content. Your data stays secure and private.
                </p>
              </.liquid_card>
            </div>
          </.liquid_container>

          <%!-- Referral Program Section --%>
          <.liquid_container max_width="xl" class="mt-24">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="bg-gradient-to-br from-emerald-50/40 via-teal-50/30 to-cyan-50/40 dark:from-emerald-900/15 dark:via-teal-900/10 dark:to-cyan-900/15 border-emerald-200/60 dark:border-emerald-700/30"
              >
                <div class="flex flex-col lg:flex-row lg:items-center gap-8">
                  <div class="flex-shrink-0">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 shadow-lg shadow-emerald-500/30">
                      <.phx_icon name="hero-banknotes" class="h-8 w-8 text-white" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <div class="flex flex-wrap items-center gap-3 mb-2">
                      <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                        Get paid to share what you love
                      </h3>
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold">
                        <.phx_icon name="hero-sparkles" class="w-3.5 h-3.5" /> Beta Bonus
                      </span>
                    </div>
                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                      When's the last time your social network paid you? With MOSSLET's referral program, you earn real money when friends join — all while maintaining our privacy-first encryption architecture.
                    </p>
                    <div class="flex flex-wrap items-center gap-4 text-sm">
                      <div class="flex items-center gap-2 text-emerald-700 dark:text-emerald-300">
                        <.phx_icon name="hero-arrow-path" class="h-4 w-4" />
                        <span>
                          <span class="line-through text-slate-400 mr-1">15%</span>
                          <span class="font-semibold">30%</span> recurring on subscriptions
                        </span>
                      </div>
                      <div class="flex items-center gap-2 text-amber-700 dark:text-amber-300">
                        <.phx_icon name="hero-bolt" class="h-4 w-4" />
                        <span>
                          <span class="line-through text-slate-400 mr-1">20%</span>
                          <span class="font-semibold">35%</span> on lifetime purchases
                        </span>
                      </div>
                    </div>
                  </div>
                  <div class="flex-shrink-0">
                    <.liquid_button
                      navigate="/referrals"
                      variant="primary"
                      color="emerald"
                      icon="hero-arrow-right"
                    >
                      Learn More
                    </.liquid_button>
                  </div>
                </div>
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
                    Ready to connect with the people who matter?
                  </span>
                </:title>
                <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                  Join people who've found a simpler, more meaningful way to stay connected with friends and family.
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
        </div>

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
       "Simple social sharing with people who matter most. MOSSLET makes it easy to connect with friends and family — private, calm, and beautifully simple."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/features/features_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Simple, thoughtful features designed for genuine connection and peace of mind"
     )}
  end
end
