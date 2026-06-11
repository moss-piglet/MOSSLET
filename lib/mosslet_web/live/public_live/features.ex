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
      <%!-- Liquid metal background matching landing + other pages --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <%!-- Hero --%>
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-24 pt-36 sm:pt-48 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Everything you need, nothing you don't
                  </h1>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400">
                    Share photos, write privately, and stay close to the people who matter — on a calm, ad-free network. Everything you post is encrypted in your browser before it ever leaves.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>

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
                      See Pricing
                    </.liquid_button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- What you can do — action-led feature rows with real screenshots --%>
          <.liquid_container max_width="full" class="relative py-12 sm:py-16">
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <.section_eyebrow accent="teal">What you can do</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Built for the people who matter
              </h2>

              <div class="mt-16 space-y-20 sm:space-y-28">
                <.feature_row
                  eyebrow="Timeline"
                  icon="hero-photo"
                  accent="teal"
                  title="Share with your people"
                  body="Post photos and updates to friends and family — or keep them just for you. You decide who sees each post, every time. It's encrypted in your browser before it leaves your device."
                  image_light={~p"/images/screenshots/timeline_light.png"}
                  image_dark={~p"/images/screenshots/timeline_dark.png"}
                  image_alt="MOSSLET timeline with posts from friends and family"
                />

                <.feature_row
                  eyebrow="Journal"
                  icon="hero-book-open"
                  accent="violet"
                  title="A private space, just for you"
                  body="Write, track your mood, and reflect in a journal only you can open. Optional AI insights run privately in your browser and are never stored. Even photos of handwritten pages can become searchable text — without leaving your device."
                  image_light={~p"/images/screenshots/journal_light.png"}
                  image_dark={~p"/images/screenshots/journal_dark.png"}
                  image_alt="MOSSLET private encrypted journal"
                  reverse
                />

                <.feature_row
                  eyebrow="Connections"
                  icon="hero-users"
                  accent="emerald"
                  title="Stay close, on your terms"
                  body="Connect only with people you choose. Blind requests let you accept or decline without revealing anything — not even that you have an account. Your profile, your circle, your call."
                  image_light={~p"/images/screenshots/connections_light.png"}
                  image_dark={~p"/images/screenshots/connections_dark.png"}
                  image_alt="MOSSLET connections — choosing who you share with"
                />

                <.feature_row
                  eyebrow="Circles & Messages"
                  icon="hero-chat-bubble-left-right"
                  accent="cyan"
                  title="Talk privately, together"
                  body="Group circles and direct messages are end-to-end encrypted. Every conversation has its own key — we only ever store encrypted blobs. Real-time, private, and yours."
                  image_light={~p"/images/screenshots/circles_chat_light.png"}
                  image_dark={~p"/images/screenshots/circles_chat_dark.png"}
                  image_alt="MOSSLET Circles private group chat"
                  reverse
                />
              </div>
            </div>
          </.liquid_container>

          <%!-- See MOSSLET in action — interactive demos (preserved) --%>
          <.liquid_container max_width="full" class="relative mt-16 sm:mt-24">
            <div class="mx-auto max-w-7xl px-6 lg:px-8">
              <div class="text-center mb-12">
                <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  See MOSSLET in action
                </h2>
                <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                  A real post, the way it looks on your timeline. Try the controls — they actually work.
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
                        <.phx_icon name="hero-shield-check" class="h-3 w-3" />
                        Zero-knowledge encrypted
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

          <%!-- Privacy-first AI — condensed --%>
          <.liquid_container
            max_width="full"
            id="privacy-first-ai"
            class="relative mt-24 sm:mt-32 py-16 sm:py-20"
          >
            <div class="absolute inset-0 bg-gradient-to-b from-violet-50/30 via-purple-50/20 to-transparent dark:from-violet-950/20 dark:via-purple-950/10 dark:to-transparent">
            </div>
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <.section_eyebrow accent="violet">Privacy-first AI</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-violet-500 to-purple-500 bg-clip-text text-transparent">
                Helpful AI that never sees your private life
              </h2>
              <p class="mx-auto mt-4 max-w-2xl text-center text-lg text-slate-600 dark:text-slate-400">
                For your private content, AI runs entirely in your browser — nothing is sent away, nothing is stored, and your content is never used to train anyone's model.
              </p>

              <div class="mt-12 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
                <.simple_feature_card
                  icon="hero-photo"
                  accent="violet"
                  title="On-device image safety"
                  body="A lightweight model checks private images right in your browser to help keep things safe — your photos never leave your device."
                />
                <.simple_feature_card
                  icon="hero-sparkles"
                  accent="purple"
                  title="Optional mood insights"
                  body="Reflect on patterns in your journal with insights that run privately and on demand. Off by default, always your choice."
                />
                <.simple_feature_card
                  icon="hero-pencil-square"
                  accent="cyan"
                  title="Handwriting to text"
                  body="Snap a photo of a handwritten page and turn it into searchable text — transcribed locally, never uploaded."
                />
              </div>
            </div>
          </.liquid_container>

          <%!-- Works with Bluesky — condensed --%>
          <.liquid_container
            max_width="full"
            id="bluesky-interop"
            class="relative mt-16 sm:mt-24 py-16 sm:py-20"
          >
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <.section_eyebrow accent="cyan">Open social</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-cyan-500 to-blue-500 bg-clip-text text-transparent">
                Works with Bluesky
              </h2>
              <p class="mx-auto mt-4 max-w-2xl text-center text-lg text-slate-600 dark:text-slate-400">
                Bring your Bluesky posts in, cross-post out, and stay connected to the wider web — all while your private MOSSLET content stays encrypted and yours.
              </p>

              <div class="mx-auto mt-12 max-w-3xl">
                <.liquid_card padding="lg" class="text-center">
                  <div class="flex flex-col sm:flex-row items-center justify-center gap-6">
                    <img
                      src={~p"/images/landing_page/bluesky_logo.png"}
                      alt="Bluesky logo"
                      class="h-12 w-12 object-contain"
                    />
                    <.phx_icon
                      name="hero-arrows-right-left"
                      class="h-7 w-7 text-cyan-500 dark:text-cyan-400"
                    />
                    <img
                      src={~p"/images/logo.svg"}
                      alt="MOSSLET logo"
                      class="h-12 w-12 object-contain"
                    />
                    <.phx_icon
                      name="hero-arrow-right"
                      class="h-7 w-7 text-emerald-500 hidden sm:block"
                    />
                    <span class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                      You own your data
                    </span>
                  </div>
                  <p class="mt-6 text-slate-600 dark:text-slate-400 leading-relaxed">
                    Import and export run through your own connected account. Public posts can cross-post to Bluesky; everything you keep private on MOSSLET stays zero-knowledge encrypted.
                  </p>
                </.liquid_card>
              </div>
            </div>
          </.liquid_container>

          <%!-- Referral — condensed --%>
          <.liquid_container max_width="xl" class="relative mt-16 sm:mt-24">
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
                    <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-2">
                      Get paid to share what you love
                    </h3>
                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                      When's the last time your social network paid you? Earn commissions when friends join — and they save 20% too. 15% recurring, 20% on lifetime, paid directly via Stripe.
                    </p>
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

          <%!-- Final CTA --%>
          <.liquid_container max_width="xl" class="relative mt-24 sm:mt-32">
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
                  Start sharing in a calm, private space that's genuinely yours. No ads, no algorithms, no one watching.
                </p>

                <div class="mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-6">
                  <.liquid_button
                    navigate="/auth/register"
                    size="lg"
                    icon="hero-rocket-launch"
                    color="teal"
                    variant="primary"
                  >
                    Get Started Today
                  </.liquid_button>
                  <.liquid_button
                    navigate="/pricing"
                    variant="secondary"
                    color="blue"
                    icon="hero-banknotes"
                    size="lg"
                  >
                    See Pricing
                  </.liquid_button>
                </div>

                <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    Free trial • 30-day money-back guarantee • Human support
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

  attr :accent, :string, default: "teal", values: ~w(teal emerald cyan violet)
  slot :inner_block, required: true

  defp section_eyebrow(assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-3">
      <div class={[
        "h-px w-12 bg-gradient-to-r from-transparent",
        eyebrow_line_class(@accent)
      ]}>
      </div>
      <span class={[
        "text-sm font-semibold uppercase tracking-wider",
        eyebrow_text_class(@accent)
      ]}>
        {render_slot(@inner_block)}
      </span>
      <div class={[
        "h-px w-12 bg-gradient-to-l from-transparent",
        eyebrow_line_class(@accent)
      ]}>
      </div>
    </div>
    """
  end

  attr :eyebrow, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :image_light, :string, required: true
  attr :image_dark, :string, required: true
  attr :image_alt, :string, required: true
  attr :accent, :string, default: "teal", values: ~w(teal emerald cyan violet)
  attr :reverse, :boolean, default: false

  defp feature_row(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-10 lg:gap-16 lg:items-center",
      if(@reverse, do: "lg:flex-row-reverse", else: "lg:flex-row")
    ]}>
      <div class="flex-1">
        <div class="flex items-center gap-3 mb-4">
          <div class={[
            "flex h-11 w-11 items-center justify-center rounded-xl shadow-sm bg-gradient-to-br",
            icon_gradient_class(@accent)
          ]}>
            <.phx_icon name={@icon} class="h-6 w-6 text-white" />
          </div>
          <span class={["text-sm font-semibold uppercase tracking-wider", eyebrow_text_class(@accent)]}>
            {@eyebrow}
          </span>
        </div>
        <h3 class="text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-3xl">
          {@title}
        </h3>
        <p class="mt-4 text-lg leading-relaxed text-slate-600 dark:text-slate-400">
          {@body}
        </p>
      </div>

      <div class="flex-1">
        <div class={[
          "rounded-2xl overflow-hidden ring-1 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30",
          ring_class(@accent)
        ]}>
          <img src={@image_light} alt={@image_alt} class="w-full dark:hidden" loading="lazy" />
          <img src={@image_dark} alt={@image_alt} class="w-full hidden dark:block" loading="lazy" />
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :accent, :string, default: "violet", values: ~w(teal emerald cyan violet purple)

  defp simple_feature_card(assigns) do
    ~H"""
    <.liquid_card
      padding="lg"
      class="group hover:scale-105 transition-all duration-300 ease-out h-full"
    >
      <:title>
        <div class="flex items-center gap-3 mb-2">
          <div class={[
            "flex h-10 w-10 shrink-0 items-center justify-center rounded-xl shadow-sm bg-gradient-to-br",
            icon_gradient_class(@accent)
          ]}>
            <.phx_icon name={@icon} class="h-5 w-5 text-white" />
          </div>
          <span class="text-base font-bold text-slate-900 dark:text-slate-100">
            {@title}
          </span>
        </div>
      </:title>
      <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
        {@body}
      </p>
    </.liquid_card>
    """
  end

  defp eyebrow_line_class("teal"), do: "to-teal-400 dark:to-teal-600"
  defp eyebrow_line_class("emerald"), do: "to-emerald-400 dark:to-emerald-600"
  defp eyebrow_line_class("cyan"), do: "to-cyan-400 dark:to-cyan-600"
  defp eyebrow_line_class("violet"), do: "to-violet-400 dark:to-violet-600"

  defp eyebrow_text_class("teal"), do: "text-teal-600 dark:text-teal-400"
  defp eyebrow_text_class("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp eyebrow_text_class("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp eyebrow_text_class("violet"), do: "text-violet-600 dark:text-violet-400"
  defp eyebrow_text_class("purple"), do: "text-purple-600 dark:text-purple-400"

  defp icon_gradient_class("teal"), do: "from-teal-500 to-emerald-500"
  defp icon_gradient_class("emerald"), do: "from-emerald-500 to-cyan-500"
  defp icon_gradient_class("cyan"), do: "from-cyan-500 to-blue-500"
  defp icon_gradient_class("violet"), do: "from-violet-500 to-purple-500"
  defp icon_gradient_class("purple"), do: "from-purple-500 to-pink-500"

  defp ring_class("teal"), do: "ring-teal-200/50 dark:ring-teal-700/40"
  defp ring_class("emerald"), do: "ring-emerald-200/50 dark:ring-emerald-700/40"
  defp ring_class("cyan"), do: "ring-cyan-200/50 dark:ring-cyan-700/40"
  defp ring_class("violet"), do: "ring-violet-200/50 dark:ring-violet-700/40"

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
