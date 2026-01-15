defmodule MossletWeb.Components.LandingPage do
  @moduledoc """
  A set of components for use in a landing page.
  """
  use Phoenix.Component
  use PetalComponents
  use MossletWeb, :verified_routes
  use Gettext, backend: MossletWeb.Gettext
  import MossletWeb.CoreComponents
  alias MossletWeb.DesignSystem

  alias Phoenix.LiveView.JS
  # alias MossletWeb.Router.Helpers, as: Routes

  def hero(assigns) do
    assigns =
      assigns
      |> assign_new(:logo_cloud_title, fn -> nil end)
      |> assign_new(:cloud_logo, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)
      |> assign_new(:title, fn -> gettext("Welcome") end)
      |> assign_new(:image_src, fn -> nil end)
      |> assign_new(:features, fn ->
        [
          %{
            title: "Circles",
            description:
              "Share and remember with the people in your life, no one else. Your memories are yours.",
            icon: :user_group,
            early_access: true
          },
          %{
            title: "Memories",
            description:
              "Share and remember with the people in your life, no one else. Your memories are yours.",
            icon: :photo,
            early_access: true
          },
          %{
            title: "People",
            description:
              "Your one stop-shop for managing your relationships, complete with a people queue for privacy.",
            icon: :user_group,
            early_access: true
          },
          %{
            title: "Roadmap",
            description:
              "See what's in store, vote, request new features, and help shape the future.",
            icon: :map,
            early_access: true
          },
          %{
            title: "Breach Alerts",
            description:
              "Private and secure checks against the HaveIBeenPwned database, and from your settings, let you know if your email or password has been compromised.",
            icon: :exclamation,
            early_access: false
          },
          %{
            title: "Data Destroyer",
            description:
              "When you delete something, it's gone instantly (and forever). Easy and under your control.",
            icon: :trash,
            early_access: false
          },
          %{
            title: "Blind Requests",
            description:
              "Receive the info you need to accept/decline a new relationship without revealing anything, including whether or not you even have an account.",
            icon: :eye_off,
            early_access: false
          },
          %{
            title: "Connections",
            description:
              "Only the people you choose can connect, share, and see information about you.",
            icon: :share,
            early_access: false
          }
        ]
      end)

    ~H"""
    <section id="hero" class="relative overflow-hidden">
      <%!-- Liquid Metal Background System --%>
      <div class="absolute inset-0 bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      </div>

      <%!-- Primary Liquid Background Gradient --%>
      <div class="absolute inset-0 bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20">
      </div>

      <%!-- Animated Shimmer Layer --%>
      <div class="absolute inset-0 animate-shimmer-slow bg-gradient-to-r from-transparent via-emerald-200/20 to-transparent dark:via-emerald-400/10">
      </div>

      <DesignSystem.liquid_container max_width="full" class="relative">
        <div class="relative isolate px-6 lg:px-8">
          <%!-- Top Decorative Gradient (Updated to Liquid Metal Colors) --%>
          <div
            class="absolute inset-x-0 -top-40 -z-10 transform-gpu overflow-hidden blur-3xl sm:-top-80"
            aria-hidden="true"
          >
            <div
              class="relative left-[calc(50%-11rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 rotate-[30deg] bg-gradient-to-tr from-teal-500/30 to-emerald-500/30 dark:from-teal-600/20 dark:to-emerald-600/20 sm:left-[calc(50%-30rem)] sm:w-[72.1875rem]"
              style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
            >
            </div>
          </div>
          <div class="mx-auto max-w-2xl pb-16 pt-20 sm:pb-24 sm:pt-20 lg:pb-28">
            <%!-- Liquid Metal Badge with Hover Effects --%>
            <div class="mb-6 sm:mb-8 flex justify-center">
              <div class="group relative overflow-hidden rounded-full px-4 py-2 text-sm leading-6 text-slate-600 dark:text-slate-400 transition-all duration-300 ease-out">
                <%!-- Liquid Background --%>
                <div class="absolute inset-0 bg-gradient-to-r from-slate-100/80 via-slate-50/90 to-slate-100/80 dark:from-slate-800/80 dark:via-slate-700/90 dark:to-slate-800/80 transition-all duration-300 group-hover:from-teal-100/60 group-hover:via-emerald-50/80 group-hover:to-cyan-100/60 dark:group-hover:from-teal-900/30 dark:group-hover:via-emerald-900/25 dark:group-hover:to-cyan-900/30">
                </div>
                <%!-- Ring Border --%>
                <div class="absolute inset-0 rounded-full ring-1 ring-slate-200/60 dark:ring-slate-700/60 transition-all duration-300 group-hover:ring-emerald-300/50 dark:group-hover:ring-emerald-600/30">
                </div>
                <%!-- Shimmer Effect --%>
                <div class="absolute inset-0 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full rounded-full">
                </div>

                <div class="relative flex flex-col sm:flex-row items-center gap-1 sm:gap-0">
                  <span class="text-center sm:text-left">Built for meaningful connections</span>
                  <.link
                    id="mosslet-demo-video-beta"
                    href="https://www.loom.com/share/e088294ed8c043978e239dcca8e82e5f"
                    target="_blank"
                    rel="noopener noreferrer"
                    phx-hook="TippyHook"
                    data-tippy-content="Watch a demo (~20 min)"
                    class="ml-1 font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200 whitespace-nowrap"
                  >
                    View demo
                    <span
                      aria-hidden="true"
                      class="ml-1 transition-transform duration-200 group-hover:translate-x-1"
                    >
                      &rarr;
                    </span>
                  </.link>
                </div>
              </div>
            </div>
            <div class="text-center relative z-10">
              <%!-- Enhanced Heading with Better Liquid Metal Effect --%>
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent drop-shadow-sm">
                A social alternative that's simple and privacy-first
              </h1>
              <%!-- Enhanced Description with Better Typography --%>
              <p class="mt-6 text-lg leading-8 text-slate-600 text-balance dark:text-slate-400 max-w-2xl mx-auto">
                Connect with friends and family — or simply with yourself through our private journal. No ads, no algorithms, just your people and your thoughts. MOSSLET makes it easy to share moments, memories, and reflections with the people who matter most.
              </p>
              <%!-- Liquid Metal CTA Buttons --%>
              <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4 sm:gap-x-6">
                <MossletWeb.DesignSystem.liquid_button
                  navigate="/auth/register"
                  variant="primary"
                  color="teal"
                  icon="hero-user-plus"
                  size="lg"
                  class="w-full sm:w-auto shadow-lg shadow-emerald-500/25 hover:shadow-xl hover:shadow-emerald-500/30 transition-all duration-300"
                >
                  Register today
                </MossletWeb.DesignSystem.liquid_button>
                <MossletWeb.DesignSystem.liquid_button
                  navigate="/auth/sign_in"
                  variant="secondary"
                  color="teal"
                  icon="hero-arrow-right-end-on-rectangle"
                  size="lg"
                  class="w-full sm:w-auto"
                >
                  Sign in
                </MossletWeb.DesignSystem.liquid_button>
                <%!--
                <.button
                  id="mosslet-demo-video"
                  link_type="a"
                  to="https://www.loom.com/share/f41b37f6c5424dad876847f70298aee9?sid=a73c020a-bb60-4fe6-b49b-947fadee1e21"
                  variant="outline"
                  class="!rounded-full"
                  target="_blank"
                  rel="_noopener"
                  phx-hook="TippyHook"
                  data-tippy-content="Watch a quick 10 minute demo"
                >
                  <svg
                    aria-hidden="true"
                    class="h-3 w-3 flex-none fill-emerald-600 group-active:fill-current"
                  >
                    <path d="m9.997 6.91-7.583 3.447A1 1 0 0 1 1 9.447V2.553a1 1 0 0 1 1.414-.91L9.997 5.09c.782.355.782 1.465 0 1.82Z" />
                  </svg>
                  <span class="ml-3">Watch video</span>
                </.button>
                --%>
              </div>
            </div>
          </div>

          <%!-- Hero App Preview Timeline Image --%>
          <div class="relative mt-16 sm:mt-20 mx-auto max-w-5xl px-6 lg:px-8">
            <div class="relative rounded-2xl overflow-hidden shadow-2xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
              <div class="absolute inset-0 bg-gradient-to-tr from-teal-500/5 via-transparent to-emerald-500/5 dark:from-teal-500/10 dark:to-emerald-500/10">
              </div>
              <img
                src={~p"/images/screenshots/timeline_light.png"}
                alt="MOSSLET app preview showing the social feed"
                class="relative w-full h-auto dark:hidden"
              />
              <img
                src={~p"/images/screenshots/timeline_dark.png"}
                alt="MOSSLET app preview showing the social feed"
                class="relative w-full h-auto hidden dark:block"
              />
            </div>
          </div>

          <%!-- Bottom Decorative Gradient (Updated to Liquid Metal Colors) --%>
          <div
            class="absolute inset-x-0 top-[calc(100%-13rem)] -z-10 transform-gpu overflow-hidden blur-3xl sm:top-[calc(100%-30rem)]"
            aria-hidden="true"
          >
            <div
              class="relative left-[calc(50%+3rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 bg-gradient-to-tr from-cyan-500/25 to-teal-500/25 dark:from-cyan-600/15 dark:to-teal-600/15 sm:left-[calc(50%+36rem)] sm:w-[72.1875rem]"
              style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
            >
            </div>
          </div>
        </div>

        <%!-- Social Features Section with Teal Accent --%>
        <MossletWeb.DesignSystem.liquid_container
          max_width="full"
          class="relative mt-16 sm:mt-24 py-16 sm:py-20"
        >
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

            <div class="grid grid-cols-1 gap-8 md:grid-cols-3 max-w-5xl mx-auto">
              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-cyan-500 to-blue-500 shadow-lg">
                      <.phx_icon
                        name="hero-users"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Made for People
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Share photos, updates, and memories with your friends and family. No ads, no algorithms. Simple, genuine connections without the noise.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-purple-500 to-violet-500 shadow-lg">
                      <.phx_icon
                        name="hero-shield-check"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Your Privacy Protected
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Control who sees what with simple privacy settings. Your moments stay between you and the people you choose.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-emerald-500 to-teal-500 shadow-lg">
                      <.phx_icon
                        name="hero-heart"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Calm and Peaceful
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  No endless scroll, no anxiety-inducing algorithms. Just a calm space to stay connected with loved ones.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </div>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- Hero App Preview Journal Image --%>
        <div class="relative mt-16 sm:mt-20 mx-auto max-w-5xl px-6 lg:px-8">
          <div class="relative rounded-2xl overflow-hidden shadow-2xl shadow-slate-900/10 dark:shadow-slate-900/30 ring-1 ring-slate-200/50 dark:ring-slate-700/50">
            <div class="absolute inset-0 bg-gradient-to-tr from-teal-500/5 via-transparent to-emerald-500/5 dark:from-teal-500/10 dark:to-emerald-500/10">
            </div>
            <img
              src={~p"/images/screenshots/journal_light.png"}
              alt="MOSSLET app preview showing the journal home"
              class="relative w-full h-auto dark:hidden"
            />
            <img
              src={~p"/images/screenshots/journal_dark.png"}
              alt="MOSSLET app preview showing the journal home"
              class="relative w-full h-auto hidden dark:block"
            />
          </div>
        </div>

        <%!-- Journal Features Section with Violet/Purple Accent --%>
        <MossletWeb.DesignSystem.liquid_container
          max_width="full"
          class="relative mt-8 py-16 sm:py-20"
        >
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
              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-violet-500 to-purple-500 shadow-lg">
                      <.phx_icon
                        name="hero-lock-closed"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Encrypted & Private
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Your journal entries are encrypted with your personal key. Only you can read them — not even we can access your private thoughts.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-pink-500 to-rose-500 shadow-lg">
                      <.phx_icon
                        name="hero-face-smile"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Mood Tracking
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Record how you're feeling with each entry. Track your emotional journey over time and discover patterns in your well-being.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg">
                      <.phx_icon
                        name="hero-light-bulb"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Privacy-First AI Insights
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Get thoughtful AI-generated reflections while your data stays encrypted. Insights are generated privately and never stored or used to train models.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </div>

            <div class="mt-16 mb-8 text-center">
              <MossletWeb.DesignSystem.liquid_button
                navigate="/features"
                variant="secondary"
                color="teal"
                icon="hero-arrow-right"
                size="lg"
                shimmer="page"
              >
                Explore all features
              </MossletWeb.DesignSystem.liquid_button>
            </div>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- Privacy-First AI Section with Amber/Orange Accent --%>
        <MossletWeb.DesignSystem.liquid_container
          max_width="full"
          class="relative mt-16 sm:mt-24 py-16 sm:py-20"
        >
          <div class="absolute inset-0 bg-gradient-to-b from-amber-50/30 via-orange-50/20 to-transparent dark:from-amber-950/20 dark:via-orange-950/10 dark:to-transparent">
          </div>
          <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
            <div class="flex items-center justify-center gap-3 mb-4">
              <div class="h-px w-12 bg-gradient-to-r from-transparent to-amber-400 dark:to-amber-600">
              </div>
              <span class="text-sm font-semibold uppercase tracking-wider text-amber-600 dark:text-amber-400">
                Privacy-First AI
              </span>
              <div class="h-px w-12 bg-gradient-to-l from-transparent to-amber-400 dark:to-amber-600">
              </div>
            </div>
            <div class="text-center mb-12">
              <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent">
                AI that respects your privacy
              </h2>
              <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                Smart features that enhance your experience without compromising your data. No storage, no training, no surveillance — just helpful AI that works for you.
              </p>
            </div>

            <div class="grid grid-cols-1 gap-8 md:grid-cols-2 lg:grid-cols-3 max-w-5xl mx-auto">
              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-rose-500 to-pink-500 shadow-lg">
                      <.phx_icon
                        name="hero-shield-exclamation"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Image Safety
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Every image is checked for safety via OpenRouter with data collection disabled. A local Bumblebee model serves as fallback — your data is never collected, logged, stored, or used for training and analysis.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-indigo-500 to-violet-500 shadow-lg">
                      <.phx_icon
                        name="hero-chat-bubble-left-right"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Content Moderation
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  Public posts get text and image moderation. Private and connections posts only check images for illegal content — in every case we respect your privacy.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <MossletWeb.DesignSystem.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out h-full"
              >
                <:title>
                  <div class="flex items-center gap-3 mb-4">
                    <div class="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl overflow-hidden bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg">
                      <.phx_icon
                        name="hero-cpu-chip"
                        class="h-5 w-5 text-white"
                      />
                    </div>
                    <span class="text-base font-bold text-slate-900 dark:text-slate-100">
                      Zero Data Collection
                    </span>
                  </div>
                </:title>

                <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                  AI requests pass through OpenRouter with data collection disabled. Your content is never stored or used to train models — then it's asymmetrically encrypted.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </div>

            <div class="mt-12 text-center">
              <MossletWeb.DesignSystem.liquid_button
                navigate="/features#privacy-first-ai"
                variant="secondary"
                color="amber"
                icon="hero-arrow-right"
                size="lg"
                shimmer="page"
              >
                Learn how our AI works
              </MossletWeb.DesignSystem.liquid_button>
            </div>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <.liquid_testimonials />
      </DesignSystem.liquid_container>
    </section>
    """
  end

  def logo_cloud(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:cloud_logo, fn -> nil end)

    ~H"""
    <div id="logo-cloud" class="container px-4 mx-auto">
      <%= if @title do %>
        <h2 class="mb-10 text-2xl text-center text-gray-500 fade-in-animation dark:text-gray-300">
          {@title}
        </h2>
      <% end %>

      <div class="flex flex-wrap justify-center">
        <%= for logo <- @cloud_logo do %>
          <div class="w-full p-4 md:w-1/3 lg:w-1/6">
            <div class="py-4 lg:py-8">
              {render_slot(logo)}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def features(assigns) do
    assigns =
      assigns
      |> assign_new(:features, fn -> [] end)
      |> assign_new(:grid_classes, fn -> "md:grid-cols-3" end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section id="features" class="relative overflow-hidden">
      <%!-- Liquid Metal Background System --%>
      <div class="absolute inset-0 bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-950 dark:to-slate-900">
      </div>

      <%!-- Subtle Liquid Background Accent --%>
      <div class="absolute inset-0 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10">
      </div>

      <div class="relative py-24 sm:py-32">
        <div class="mx-auto max-w-7xl px-6 lg:px-8">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400">
              Everything you want to share
            </h2>
            <p class="mt-2 text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl">
              With privacy you need.
            </p>
            <p class="mt-6 text-lg leading-8 text-slate-600 dark:text-slate-400">
              Easily share with people in your life in real-time without thinking twice. Zero
              <.link
                navigate={~p"/#general"}
                class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
              >
                dark patterns
              </.link>
              means you can say goodbye to digital addiction and the anxiety of wondering how your life on the web affects your life outside. MOSSLET is simple and privacy-first.
            </p>
          </div>
          <dl class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 text-base leading-7 text-slate-600 dark:text-slate-400 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:gap-x-16">
            <div class="relative pl-9">
              <dt class="inline font-semibold text-slate-900 dark:text-slate-100">
                <svg
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M5.5 17a4.5 4.5 0 01-1.44-8.765 4.5 4.5 0 018.302-3.046 3.5 3.5 0 014.504 4.272A4 4 0 0115 17H5.5zm3.75-2.75a.75.75 0 001.5 0V9.66l1.95 2.1a.75.75 0 101.1-1.02l-3.25-3.5a.75.75 0 00-1.1 0l-3.25 3.5a.75.75 0 101.1 1.02l1.95-2.1v4.59z"
                    clip-rule="evenodd"
                  />
                </svg>
                Distributed cloud.
              </dt>
              <dd class="inline">
                Memories and other multimedia are stored on a private, encrypted, and distributed cloud network spread across the world. If Amazon and Facebook go down, your data and your ability to continue sharing and connecting on MOSSLET stays up.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-slate-900 dark:text-slate-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                >
                  <path
                    fill-rule="evenodd"
                    d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                    clip-rule="evenodd"
                  />
                  <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                </svg>
                Circles, Memories, Posts, and more.
              </dt>
              <dd class="inline">
                Make Circles to chat live, store photos for yourself or share with others in Memories, and express your thoughts with Posts — always in real-time with the privacy you need. All images are checked for safety via OpenRouter with data collection disabled, with a local Bumblebee model as fallback.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-slate-900 dark:text-slate-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"
                  />
                </svg>
                The right to start over.
              </dt>
              <dd class="inline">
                Empower your personal growth and discovery by starting fresh whenever you want. Easily delete all of your Connections, Posts, Memories, Circles, Remarks and more across our service in real-time without deleting your account. On MOSSLET, you're in control of your identity and free to be any version of your self, every time.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-slate-900 dark:text-slate-100">
                <svg
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z"
                    clip-rule="evenodd"
                  />
                </svg>
                Asymmetric encryption.
              </dt>
              <dd class="inline">
                Strong public-key cryptography with a password-derived key keeps your data private to you. Only your password can unlock your account, its data, and enable you to share with others. Our databases are on a closed, private network protected with the secure WireGuard protocol.
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </section>
    """
  end

  def solo_feature(assigns) do
    assigns =
      assigns
      |> assign_new(:inverted, fn -> false end)
      |> assign_new(:background_color, fn -> "primary" end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="benefits"
      class="overflow-hidden transition duration-500 ease-in-out bg-gray-50 md:pt-0 dark:bg-gray-800 dark:text-white"
      data-offset="false"
    >
      <.container max_width={@max_width}>
        <div class={
          "#{if @inverted, do: "flex-row-reverse", else: ""} flex flex-wrap items-center gap-20 py-32 md:flex-nowrap"
        }>
          <div class="md:w-1/2 stagger-fade-in-animation">
            <div class="mb-5 text-3xl font-bold md:mb-7 fade-in-animation md:text-5xl">
              {@title}
            </div>

            <div class="space-y-4 text-lg font-light md:text-xl md:space-y-5">
              <p class="fade-in-animation">
                {@description}
              </p>
            </div>
            <%= if @inner_block do %>
              <div class="fade-in-animation">
                {render_slot(@inner_block)}
              </div>
            <% end %>
          </div>

          <div class="w-full md:w-1/2 md:mt-0">
            <div class={
              "#{if @background_color == "primary", do: "from-primary-200 to-primary-600 bg-primary-animation"} #{if @background_color == "secondary", do: "from-secondary-200 to-secondary-600 bg-secondary-animation"} relative flex items-center justify-center w-full p-16 bg-gradient-to-r rounded-3xl"
            }>
              <img
                class="z-10 w-full fade-in-animation solo-animation max-h-[500px]"
                src={@image_src}
                alt="Screenshot"
              />
            </div>
          </div>
        </div>
      </.container>
    </section>
    """
  end

  def testimonials_initial(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> gettext("Testimonials") end)
      |> assign_new(:testimonials, fn -> [] end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="testimonials"
      class="relative z-10 transition duration-500 ease-in-out bg-white py-36 dark:bg-gray-900"
    >
      <div class="overflow-hidden content-wrapper">
        <.container max_width={@max_width} class="relative z-10">
          <div class="mb-5 text-center md:mb-12 section-header stagger-fade-in-animation">
            <div class="mb-3 text-3xl font-bold leading-none dark:text-white md:mb-5 fade-in-animation md:text-5xl">
              {@title}
            </div>
          </div>

          <div class="solo-animation fade-in-animation flickity">
            <%= for testimonial <- @testimonials do %>
              <.testimonial_panel {testimonial} />
            <% end %>
          </div>
        </.container>
      </div>
    </section>

    <script phx-update="ignore" id="testimonials-js" type="module">
      // Flickity allows for a touch-enabled slideshow - used for testimonials
      import flickity from 'https://cdn.skypack.dev/flickity@2';

      let el = document.querySelector(".flickity");

      if(el){
        new flickity(el, {
          cellAlign: "left",
          prevNextButtons: false,
          adaptiveHeight: false,
          cellSelector: ".carousel-cell",
        });
      }
    </script>

    <link rel="stylesheet" href="https://unpkg.com/flickity@2/dist/flickity.min.css" />
    """
  end

  def testimonial_panel(assigns) do
    ~H"""
    <div class="w-full p-6 mr-10 overflow-hidden transition duration-500 ease-in-out rounded-lg shadow-lg text-gray-700 md:p-8 md:w-8/12 lg:w-5/12 bg-primary-50 dark:bg-gray-700 dark:text-white carousel-cell last:mr-0">
      <blockquote class="mt-6 md:flex-grow md:flex md:flex-col">
        <div class="relative text-lg font-medium md:flex-grow">
          <svg
            class="absolute top-[-20px] left-0 w-8 h-8 transform -translate-x-3 -translate-y-2 text-primary-500"
            fill="currentColor"
            viewBox="0 0 32 32"
            aria-hidden="true"
          >
            <path d="M9.352 4C4.456 7.456 1 13.12 1 19.36c0 5.088 3.072 8.064 6.624 8.064 3.36 0 5.856-2.688 5.856-5.856 0-3.168-2.208-5.472-5.088-5.472-.576 0-1.344.096-1.536.192.48-3.264 3.552-7.104 6.624-9.024L9.352 4zm16.512 0c-4.8 3.456-8.256 9.12-8.256 15.36 0 5.088 3.072 8.064 6.624 8.064 3.264 0 5.856-2.688 5.856-5.856 0-3.168-2.304-5.472-5.184-5.472-.576 0-1.248.096-1.44.192.48-3.264 3.456-7.104 6.528-9.024L25.864 4z">
            </path>
          </svg>
          <p class="relative">
            {@content}
          </p>
        </div>
        <footer class="mt-8">
          <div class="flex items-start">
            <div class="inline-flex flex-shrink-0 border-2 border-white rounded-full">
              <img class="w-12 h-12 rounded-full" src={@image_src} alt="" />
            </div>
            <div class="ml-4">
              <div class="text-base font-medium">{@name}</div>
              <div class="text-base font-semibold">{@title}</div>
            </div>
          </div>
        </footer>
      </blockquote>
    </div>
    """
  end

  def pricing(assigns) do
    assigns =
      assigns
      |> assign_new(:plans, fn -> [] end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="pricing"
      class="py-24 transition duration-500 ease-in-out text-gray-700 md:py-32 dark:bg-gray-800 bg-gray-50 dark:text-white stagger-fade-in-animation"
    >
      <.container max_width={@max_width}>
        <div class="mx-auto mb-16 text-center md:mb-20 lg:w-7/12 ">
          <div class="mb-5 text-3xl font-bold md:mb-7 md:text-5xl fade-in-animation">
            {@title}
          </div>
          <div class="text-lg font-light anim md:text-2xl fade-in-animation">
            {@description}
          </div>
        </div>

        <div class="grid items-start max-w-sm gap-8 mx-auto lg:grid-cols-3 lg:gap-6 lg:max-w-none">
          <%= for plan <- @plans do %>
            <.pricing_table {plan} />
          <% end %>
        </div>
      </.container>
    </section>
    """
  end

  def pricing_table(assigns) do
    assigns =
      assigns
      |> assign_new(:most_popular, fn -> false end)
      |> assign_new(:currency, fn -> "$" end)
      |> assign_new(:unit, fn -> "/m" end)

    ~H"""
    <div class="relative flex flex-col h-full p-6 transition duration-500 ease-in-out rounded-lg bg-gray-200 dark:bg-gray-900 fade-in-animation">
      <%= if @most_popular do %>
        <div class="absolute top-0 right-0 mr-6 -mt-4">
          <div class="inline-flex px-3 py-1 mt-px text-sm font-semibold text-green-600 bg-green-200 rounded-full">
            Most Popular
          </div>
        </div>
      <% end %>

      <div class="pb-4 mb-4 transition duration-500 ease-in-out border-b border-gray-300 dark:border-gray-700">
        <div class="mb-1 text-2xl font-bold leading-snug tracking-tight dark:text-primary-500 text-primary-600">
          {@name}
        </div>

        <div class="inline-flex items-baseline mb-2">
          <span class="text-2xl font-medium text-gray-600 dark:text-gray-400">
            {@currency}
          </span>
          <span class="text-3xl font-extrabold leading-tight transition duration-500 ease-in-out text-gray-900 dark:text-gray-50">
            {@price}
          </span>
          <span class="font-medium text-gray-600 dark:text-gray-400">{@unit}</span>
        </div>

        <div class="text-gray-600 dark:text-gray-400">
          {@description}
        </div>
      </div>

      <div class="mb-3 font-medium text-gray-700 dark:text-gray-200">
        Features include:
      </div>

      <ul class="-mb-3 text-gray-600 dark:text-gray-400 grow">
        <%= for feature <- @features do %>
          <li class="flex items-center mb-3">
            <.icon name="hero-check" solid class="w-3 h-3 mr-3 text-green-500 fill-current shrink-0" />
            <span>{feature}</span>
          </li>
        <% end %>
      </ul>

      <div class="p-3 mt-6 ">
        <MossletWeb.DesignSystem.liquid_button
          navigate={@sign_up_path}
          variant="primary"
          color="teal"
          icon="hero-user-plus"
          class="w-full"
        >
          Register today
        </MossletWeb.DesignSystem.liquid_button>
      </div>
    </div>
    """
  end

  def load_js_animations(assigns) do
    ~H"""
    <script type="module">
      // Use GSAP for animations
      // https://greensock.com/gsap/
      import gsap from 'https://cdn.skypack.dev/gsap@3.10.4';

      // Put it on the window for when you want to try out animations in the console
      window.gsap = gsap;

      // A plugin for GSAP that detects when an element enters the viewport - this helps with timing the animation
      import ScrollTrigger from "https://cdn.skypack.dev/gsap@3.10.4/ScrollTrigger";
      gsap.registerPlugin(ScrollTrigger);

      animateHero();
      setupPageAnimations();

      // This is needed to ensure the animations timings are correct as you scroll
      setTimeout(() => {
        ScrollTrigger.refresh(true);
      }, 1000);

      function animateHero() {

        // A timeline just means you can chain animations together - one after another
        // https://greensock.com/docs/v3/GSAP/gsap.timeline()
        const heroTimeline = gsap.timeline({});

        heroTimeline
          .to("#hero .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
            duration: 1,
          })
          .to("#hero-image", {
            opacity: 1,
            x: 0,
            duration: 0.4
          }, ">-1.3")
          .to("#logo-cloud .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
          })
      }

      function setupPageAnimations() {

        // This allows us to give any individual HTML element the class "solo-animation"
        // and that element will fade in when scrolled into view
        gsap.utils.toArray(".solo-animation").forEach((item) => {
          gsap.to(item, {
            y: 0,
            opacity: 1,
            duration: 0.5,
            ease: "power2.out",
            scrollTrigger: {
              trigger: item,
            },
          });
        });

        // Add the class "stagger-fade-in-animation" to a parent element, then all elements within it
        // with the class "fade-in-animation" will fade in on scroll in a staggered formation to look
        // more natural than them all fading in at once
        gsap.utils.toArray(".stagger-fade-in-animation").forEach((stagger) => {
          const children = stagger.querySelectorAll(".fade-in-animation");
          gsap.to(children, {
            opacity: 1,
            y: 0,
            ease: "power2.out",
            stagger: 0.15,
            duration: 0.5,
            scrollTrigger: {
              trigger: stagger,
              start: "top 75%",
            },
          });
        });
      }
    </script>
    """
  end

  def render_pricing_feature(assigns) do
    assigns =
      assigns
      |> assign_new(:icon_class, fn -> "" end)

    ~H"""
    <li class="flex items-center w-full py-2 fade-in-animation">
      <svg
        class={"#{@icon_class} flex-shrink-0 mr-3"}
        width="16"
        height="16"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M8 0a8 8 0 100 16A8 8 0 008 0zm4.471 6.471l-5.04 5.04a.666.666 0 01-.942 0L4.187 9.21a.666.666 0 11.942-.942l1.831 1.83 4.569-4.568a.666.666 0 11.942.942z"
          fill="#FFF"
          class="fill-current"
          fill-rule="nonzero"
        />
      </svg>

      <div class="text-left">{@text}</div>
    </li>
    """
  end

  def myob(assigns) do
    assigns = assigns

    ~H"""
    <div id="myob" class="bg-white dark:bg-gray-950">
      <main class="isolate">
        <%!-- Hero section --%>
        <div class="relative isolate -z-10 overflow-hidden pt-14">
          <svg
            class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-gray-200 dark:stroke-gray-800 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
            aria-hidden="true"
          >
            <defs>
              <pattern
                id="1f932ae7-37de-4c0a-a8b0-a6e3b4d44b84"
                width="200"
                height="200"
                x="50%"
                y="-1"
                patternUnits="userSpaceOnUse"
              >
                <path d="M.5 200V.5H200" fill="none" />
              </pattern>
            </defs>
            <svg x="50%" y="-1" class="overflow-visible fill-gray-50 dark:fill-gray-900">
              <path
                d="M-200 0h201v201h-201Z M600 0h201v201h-201Z M-400 600h201v201h-201Z M200 800h201v201h-201Z"
                stroke-width="0"
              />
            </svg>
            <rect
              width="100%"
              height="100%"
              stroke-width="0"
              fill="url(#1f932ae7-37de-4c0a-a8b0-a6e3b4d44b84)"
            />
          </svg>
          <div
            class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
            aria-hidden="true"
          >
            <div
              class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30"
              style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
            >
            </div>
          </div>

          <%!-- Hero Content --%>
          <div class="mx-auto max-w-7xl px-6 pb-24 pt-10 sm:pb-32 lg:flex lg:px-8 lg:py-40">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-xl lg:flex-shrink-0 lg:pt-8">
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Mind Your Own Business
              </h1>
              <p class="mt-8 text-pretty text-lg font-medium text-gray-500 dark:text-gray-400 sm:text-xl/8">
                Privacy isn't just a feature — it's the foundation of human dignity. Your personal life should stay personal, whether online or offline.
              </p>
              <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-y-4 gap-x-6">
                <.button
                  link_type="live_redirect"
                  to="/auth/register"
                  class="w-full sm:w-auto block rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
                >
                  Get lifetime access
                </.button>
                <.button
                  link_type="live_redirect"
                  to="/features"
                  variant="outline"
                  class="w-full sm:w-auto !rounded-full"
                >
                  Explore features
                </.button>
              </div>
            </div>

            <%!-- Personal Privacy List --%>
            <div class="mx-auto mt-16 flex max-w-2xl lg:ml-10 lg:mr-0 lg:mt-0 lg:max-w-none lg:flex-none xl:ml-32">
              <div class="max-w-3xl flex-none sm:max-w-5xl lg:max-w-none">
                <div class="space-y-2 text-sm text-gray-600 dark:text-gray-400 sm:text-base lg:text-lg">
                  <p>It's none of our business where you go to school.</p>
                  <p>It's none of our business who you go on vacation with.</p>
                  <p>It's none of our business where your sister's getting married.</p>
                  <p>It's none of our business what your children are struggling with.</p>
                  <p>It's none of our business how much you eat in a day.</p>
                  <p>It's none of our business what products you use in the shower.</p>
                  <p>It's none of our business where you get your groceries.</p>
                  <p>It's none of our business what car you drive.</p>
                  <p>It's none of our business how you're feeling right now.</p>
                  <p>It's none of our business how much student loan debt you have.</p>
                  <p>It's none of our business where your favorite restaurants are.</p>
                  <p>It's none of our business if you just got divorced.</p>
                  <p>It's none of our business what your holiday plans are.</p>
                  <p>It's none of our business if you're home or not.</p>
                  <p>It's none of our business how much you spent remodeling.</p>
                  <p>It's none of our business where your kids go to school.</p>
                  <p>It's none of our business what books you read.</p>
                  <p>It's none of our business how you get to work.</p>
                  <p>It's none of our business if you went to a protest.</p>
                  <p>It's none of our business who you voted for.</p>
                  <p>It's none of our business what medicine you take.</p>
                  <p>It's none of our business which doctor you visit.</p>
                  <p>It's none of our business what your credit score is.</p>
                  <p>It's none of our business where you were born.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Big Tech Section --%>
        <div class="mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
          <div class="mx-auto max-w-4xl text-center">
            <h2 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Hey Big Tech,
            </h2>
            <div class="mt-12 space-y-4 text-lg text-gray-600 dark:text-gray-400 sm:text-xl lg:text-2xl">
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">which ads I linger on.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">when I go online.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">which search engine I use.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">where I am right now.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">which photos I like.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">who I respond to.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">which articles I read.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">who I ignore.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">
                  how many times I watched that video.
                </strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">if I'm using a VPN.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">what my home address is.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">what I just said out loud.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">how many tabs I have open.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">who I follow.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">what I'm typing right now.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">which apps I download.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="text-gray-900 dark:text-gray-200">
                  what's left in my shopping cart.
                </strong>
              </p>
            </div>
          </div>
        </div>

        <%!-- Main Content Section --%>
        <div class="mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
          <div class="mx-auto max-w-4xl text-center">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              It's none of our business, so it's not our business
            </h2>
            <p class="mt-8 text-lg text-gray-600 dark:text-gray-400 sm:text-xl/8">
              Unlike the surveillance economy of Big Tech, we've built MOSSLET on the radical idea that your privacy is valuable — and worth protecting.
            </p>
          </div>

          <%!-- Content Grid --%>
          <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 lg:mx-0 lg:max-w-none lg:grid-cols-2 lg:items-start lg:gap-y-10">
            <div class="lg:col-span-2 lg:col-start-1 lg:row-start-1 lg:mx-auto lg:grid lg:w-full lg:max-w-7xl lg:grid-cols-2 lg:gap-x-8 lg:px-8">
              <div class="lg:pr-4">
                <div class="lg:max-w-lg">
                  <h3 class="text-2xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-3xl">
                    Our business model is boring
                  </h3>
                  <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400">
                    <strong class="text-gray-900 dark:text-gray-200">
                      At MOSSLET, our business model is as basic as it is boring:
                    </strong>
                    We charge our customers a fair price for our products. That's it. We don't take your personal data as payment, we don't try to monetize your eyeballs, we don't target you, we don't sell, broker, or barter ads. We will never spy on you or enable others to either. It's absolutely none of their business, and it's none of ours either.
                  </p>
                </div>
              </div>
              <div class="pt-12 lg:pt-0">
                <div class="lg:max-w-lg">
                  <h3 class="text-2xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-3xl">
                    Privacy is personal to us
                  </h3>
                  <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400">
                    <strong class="text-gray-900 dark:text-gray-200">
                      Privacy is personal to us:
                    </strong>
                    We've been building and using computers for thirty years. We were around in 2000 when Google pioneered the invisible prison of surveillance capitalism and hid behind the thin veil of "Don't Be Evil". We've seen their strategies for collecting, selling, and abusing personal data on an industrial scale spread to every industry. We remember when Facebook rose from The FaceBook to the pusher of algorithmically-engineered traps of attention and worse. The internet didn't use to be like this, and it doesn't have to be like that today either.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Additional Content --%>
          <div class="mx-auto mt-16 max-w-2xl lg:max-w-4xl">
            <div class="space-y-8 text-lg leading-8 text-gray-600 dark:text-gray-400">
              <p>
                But right now it just is. You have to defend yourself from these Big Tech giants, and the legion of companies following their nasty example. Collect It All has sunk into the ideology of the commercial internet, so most companies don't even think about it. It's just what they do.
              </p>
              <p>
                <strong class="text-gray-900 dark:text-gray-200">
                  MOSSLET doesn't mine your posts for data:
                </strong>
                There are no big AI engines to feed. We don't analyze what links you click, your interests, your location, who your friends are, what you say. We don't take your your face from your pictures, nothing personal other than the most basic identifying information we need to call you a customer. Everything else is simply none of our business. And because you pay to use MOSSLET, it doesn't need to be. Even then, we encrypt it all in a way so that we couldn't analyze or monetize it even if we wanted to — which we don't.
              </p>
              <p>
                When you're in the business of "free", like Google, Facebook, Instagram, TikTok, YouTube, and many others, you're in the business of snooping. Tricking. Collecting. Aggregating. Slicing. Dicing. Packaging. Do you really want to be used like that? As a resource to be mined? Do you really want companies secretly deciding and controlling your future? If you're here, and curious about MOSSLET, you probably don't.
              </p>
              <p>
                Privacy used to be something exotic and niche. Today it's going mainstream, but it's still early. You can be early on this trend. You can be part of the change. Using MOSSLET is standing up, not giving in.
              </p>
              <p>
                <strong class="text-gray-900 dark:text-gray-200">
                  Your data is none of their business:
                </strong>
                Don't give them what isn't theirs. At MOSSLET, we've got your back without looking over your shoulder.
              </p>
            </div>

            <%!-- Call to Action --%>
            <div class="mt-12 flex flex-col sm:flex-row items-center justify-center gap-y-4 gap-x-6">
              <.button
                link_type="live_redirect"
                to="/auth/register"
                class="w-full sm:w-auto block rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
              >
                Get lifetime access
              </.button>
              <.button
                link_type="live_redirect"
                to="/features"
                variant="outline"
                class="w-full sm:w-auto !rounded-full"
              >
                Explore features
              </.button>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def landing_features(assigns) do
    ~H"""
    <div id="features" class="bg-white dark:bg-gray-950 py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <%!-- Hero Section with better spacing --%>
        <div class="mx-auto max-w-4xl text-center">
          <h1 class="text-4xl font-bold tracking-tight text-pretty sm:text-6xl md:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            Social media, unexpected.
          </h1>
          <p class="font-regular mt-8 text-xl/8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
            Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you.
          </p>

          <%!-- Call-to-action buttons --%>
          <div class="mt-12 flex flex-col sm:flex-row items-center justify-center gap-y-4 gap-x-6">
            <.button
              link_type="live_redirect"
              to="/auth/register"
              class="w-full sm:w-auto block rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
            >
              Get lifetime access
            </.button>
            <.button
              link_type="live_redirect"
              to="/pricing"
              variant="outline"
              class="w-full sm:w-auto !rounded-full"
            >
              See pricing options
            </.button>
          </div>
        </div>

        <%!-- App Screenshot Section --%>
        <div class="relative overflow-hidden pt-20">
          <div class="mx-auto max-w-7xl px-6 lg:px-4">
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />
            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
            <div class="relative" aria-hidden="true">
              <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-900 pt-[7%]">
              </div>
            </div>
          </div>
        </div>
        <div class="z-20 relative" aria-hidden="true">
          <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-950 pt-[7%]">
          </div>
        </div>

        <%!-- Features Grid with improved hierarchy --%>
        <div class="mx-auto mt-24 max-w-2xl sm:mt-32 lg:mt-40 lg:max-w-none">
          <div class="text-center mb-16">
            <h2 class="text-4xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-5xl">
              Why MOSSLET is different
            </h2>
            <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-400 max-w-3xl mx-auto">
              Experience social media as it should be — simple, secure, and designed for your wellbeing.
            </p>
          </div>

          <%!-- Priority Features (First Row) --%>
          <div class="grid max-w-xl grid-cols-1 gap-x-8 gap-y-16 lg:max-w-none lg:grid-cols-3 mb-20">
            <div class="relative bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/50 dark:to-teal-900/50 dark:bg-gray-800/50 p-8 rounded-2xl shadow-lg dark:shadow-emerald-500/20 dark:border dark:border-emerald-700/30">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 shadow-lg">
                  <.phx_icon name="hero-heart" class="size-7 text-white" />
                </div>
                <h3 class="text-xl font-bold">Calm by Design</h3>
              </dt>
              <dd class="mt-4 text-gray-600 dark:text-gray-300">
                No stress, no anxiety, no manipulation. MOSSLET is designed to give you peace of mind, not keep you scrolling endlessly.
              </dd>
            </div>

            <div class="relative bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/50 dark:to-teal-900/50 dark:bg-gray-800/50 p-8 rounded-2xl shadow-lg dark:shadow-emerald-500/20 dark:border dark:border-emerald-700/30">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 shadow-lg">
                  <.phx_icon name="hero-shield-check" class="size-7 text-white" />
                </div>
                <h3 class="text-xl font-bold">Privacy First</h3>
              </dt>
              <dd class="mt-4 text-gray-600 dark:text-gray-300">
                Your data belongs to you. Strong encryption, no spying, no selling your information to advertisers.
              </dd>
            </div>

            <div class="relative bg-gradient-to-br from-emerald-50 to-teal-50 dark:from-emerald-900/50 dark:to-teal-900/50 dark:bg-gray-800/50 p-8 rounded-2xl shadow-lg dark:shadow-emerald-500/20 dark:border dark:border-emerald-700/30">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-teal-500 to-emerald-500 shadow-lg">
                  <.phx_icon name="hero-adjustments-horizontal" class="size-7 text-white" />
                </div>
                <h3 class="text-xl font-bold">Back to Basics</h3>
              </dt>
              <dd class="mt-4 text-gray-600 dark:text-gray-300">
                Just the essentials for connecting and sharing. No complicated features, no overwhelming interfaces.
              </dd>
            </div>
          </div>

          <%!-- Secondary Features Grid --%>
          <dl class="grid max-w-xl grid-cols-1 gap-x-8 gap-y-12 lg:max-w-none lg:grid-cols-2">
            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-chart-pie" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">No Identity Graphs</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                Unlike Meta and Google, we don't build profiles about you. What you share stays just that — no invisible consequences.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-sparkles" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">Free to Be You</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                No algorithms dictating who you are. Delete and start fresh anytime without losing your account.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-sun" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">No Dark Patterns</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                No tricks, traps, or manipulation. Simple design that helps you share and get back to living.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-clipboard-document-list" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">Own Your Data</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                Your data stays yours. Delete everything instantly, anytime. No colonization of your digital life.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-hand-raised" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">No Manipulation</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                You won't be turned into a product or weapon. Control your own experience and thoughts.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-bell-snooze" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">Calm Notifications</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                In-app notifications that don't pressure you. Take your time, respond when you want to.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-eye-slash" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">Private by Default</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                Your account starts private. Choose what to share and with whom. Even we can't see your content.
              </dd>
            </div>

            <div class="relative hover:bg-gray-50 dark:hover:bg-gray-900/50 p-6 rounded-xl transition-colors duration-200">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-4 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-lock-closed" class="size-6 text-white" />
                </div>
                <h4 class="text-lg font-semibold">Military-Grade Encryption</h4>
              </dt>
              <dd class="mt-2 text-gray-600 dark:text-gray-400">
                Strong asymmetric encryption ensures only you can access your data. Double-encrypted for extra security.
              </dd>
            </div>
          </dl>
        </div>

        <%!-- Bottom CTA Section --%>
        <div class="mt-24 text-center bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/60 dark:to-emerald-900/60 dark:bg-gray-800/60 rounded-3xl p-12 dark:border dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
          <h3 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl">
            Ready for a better social experience?
          </h3>
          <p class="mt-6 text-lg leading-8 text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
            Join others who've already discovered what social media feels like without the stress, tracking, and manipulation.
          </p>
          <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-y-4 gap-x-6">
            <.button
              link_type="live_redirect"
              to="/auth/register"
              class="w-full sm:w-auto block rounded-full py-3 px-8 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
            >
              Get lifetime access
            </.button>
            <.button
              link_type="live_redirect"
              to="/pricing"
              variant="outline"
              class="w-full sm:w-auto !rounded-full border-emerald-600 text-emerald-600 hover:bg-emerald-50 dark:border-emerald-400 dark:text-emerald-400 dark:hover:bg-emerald-950/50"
            >
              See pricing options
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def testimonials(assigns) do
    ~H"""
    <section
      id="testimonials"
      aria-label="What our customers are saying"
      class="bg-slate-50 dark:bg-slate-900 py-20 sm:py-32"
    >
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl md:text-center">
          <h2 class="font-display text-3xl tracking-tight text-slate-900 dark:text-gray-50 sm:text-4xl">
            People are ready for change.
          </h2>
          <p class="mt-4 text-lg tracking-tight text-slate-700 dark:text-slate-300">
            After decades of the status quo, people are excited to take back their lives.
          </p>
        </div>
        <ul
          role="list"
          class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-6 sm:gap-8 lg:mt-20 lg:max-w-none lg:grid-cols-3"
        >
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I'm done with Facebook. I'd like a place where I own the data and that is generally positive vs. all the negativity that gets put into my feed at Facebook.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I like the idea of being able to share stories about the grandchildren in our family with other parents and grandparents. I also appreciate a venue for sharing adventures with my friends without someone I don't know having access to my activities and whereabouts.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Because it's amazing ✨
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Tired of being profiled everywhere, would love to experience something that aint harvesting me.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Having a safe place to share photos of our little bears feels so amazing.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I hate what the internet has become , but I'm dreamer, so I hope we will have a bright future. And I do believe in this kind of initiative. Perhaps I'm not the right person to receive an invitation, because I'm not active on social media, but I want you to know that you have my full support in this initiative.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Support a healthier digital ecosystem.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  def pricing_cards(assigns) do
    ~H"""
    <section id="pricing" aria-label="Pricing">
      <div class="relative isolate bg-white dark:bg-gray-950 px-6 py-24 sm:py-32 lg:px-8">
        <div
          class="absolute inset-x-0 -top-3 -z-10 transform-gpu overflow-hidden px-36 blur-3xl"
          aria-hidden="true"
        >
          <div
            class="mx-auto aspect-[1155/678] w-[72.1875rem] bg-gradient-to-tr from-[#9ACF65] to-[#8BE8E8] opacity-30"
            style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
          >
          </div>
        </div>
        <div class="mx-auto max-w-2xl text-center lg:max-w-4xl">
          <h1 class="mt-2 text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            Simple,
            <span class="italic underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              pay once
            </span>
            pricing
          </h1>
        </div>

        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          Pay once, own forever.
        </h2>
        <p class="mx-auto mt-6 max-w-2xl text-center text-lg leading-8 text-gray-600 dark:text-gray-400">
          No subscriptions. No recurring fees. No surprises. One simple payment gives you lifetime access to privacy and peace of mind.
        </p>
        <div class="mx-auto mt-16 grid max-w-lg grid-cols-1 items-center gap-y-6 sm:mt-20 sm:gap-y-0 lg:max-w-4xl lg:grid-cols-2">
          <div class="rounded-3xl p-8 ring-1 ring-gray-900/10 dark:ring-gray-100/10 sm:p-10 relative bg-white dark:bg-gray-950 shadow-2xl dark:shadow-emerald-500/50">
            <span class="flex justify-between items-start">
              <h3
                id="tier-personal"
                class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400"
              >
                Personal
              </h3>
              <.badge color="success" label="Lifetime" variant="outline" class="rounded-full text-xs" />
            </span>
            <p class="mt-4 flex flex-col sm:flex-row sm:items-baseline gap-x-2">
              <span class="flex items-baseline gap-x-2">
                <span class="text-6xl font-bold tracking-tight text-gray-900 dark:text-gray-100">
                  $59
                </span>
                <span class="text-lg text-gray-500 font-medium">/once</span>
                <.badge
                  id="desktop-beta-badge"
                  phx-hook="TippyHook"
                  data-tippy-content="Special price while we're in beta"
                  color="warning"
                  label="Save 40%"
                  variant="soft"
                  class="rounded-full ml-3 hidden sm:inline-flex"
                />
              </span>
              <.badge
                id="mobile-beta-badge"
                phx-hook="TippyHook"
                data-tippy-content="Special price while we're in beta"
                color="warning"
                label="Save 40%"
                variant="soft"
                class="rounded-full mt-2 self-start sm:hidden"
              />
            </p>
            <p class="mt-6 text-base leading-7 text-gray-600 dark:text-gray-400">
              Own your privacy forever with one simple payment. No subscriptions, no recurring fees – just pure digital freedom.
              <small class="text-gray-500">Affirm payment plans available.</small>
            </p>
            <ul
              role="list"
              class="mt-8 space-y-3 text-sm leading-6 text-gray-600 dark:text-gray-400 sm:mt-10"
            >
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Unlimited Connections, Circles, and Posts
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Unlimited new features
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Streamlined settings
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Own your data
              </li>
              <li
                id="asymmetric-encryption-pricing-feature"
                class="flex gap-x-3 cursor-help"
                data-tippy-content="Only your account password can decrypt the key to your data — keeping it private to you and unknowable to anyone else."
                phx-hook="TippyHook"
              >
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Advanced asymmetric encryption
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Email support
              </li>
            </ul>
            <a
              href={~p"/auth/register"}
              aria-describedby="tier-personal"
              class="mt-8 block rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 sm:mt-10 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
            >
              Get lifetime access
            </a>
          </div>
          <div class="rounded-3xl p-8 ring-1 ring-gray-900/10 dark:ring-gray-100/10 sm:p-10 bg-white/60 dark:bg-gray-950/60 sm:mx-8 lg:mx-0 sm:rounded-t-none lg:rounded-tr-3xl lg:rounded-bl-none">
            <h3
              id="tier-team"
              class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400"
            >
              Family
            </h3>
            <p class="mt-4 flex items-baseline gap-x-2">
              <span class="text-5xl font-bold tracking-tight text-gray-900 dark:text-gray-100">
                TBA
              </span>
              <span class="text-base text-gray-500">/once</span>
            </p>
            <p class="mt-6 text-base leading-7 text-gray-600 dark:text-gray-400">
              Coming soon. Privacy and peace of mind for your whole family with one lifetime payment.
            </p>
            <ul
              role="list"
              class="mt-8 space-y-3 text-sm leading-6 text-gray-600 dark:text-gray-400 sm:mt-10"
            >
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Priority support
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Multiple accounts
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Admin dashboard
              </li>
            </ul>
            <button
              aria-describedby="tier-team"
              class="mt-8 block rounded-full py-3 px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 dark:focus-visible:outline-emerald-400 sm:mt-10 text-emerald-600 dark:text-emerald-400 ring-2 ring-inset ring-emerald-300 dark:ring-emerald-700 cursor-not-allowed opacity-75"
              disabled
            >
              Coming soon
            </button>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :hero_intro?, :boolean, default: false
  attr :pricing_link?, :boolean, default: false

  def pricing_comparison(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl pt-16 pb-10">
      <div :if={@hero_intro?}>
        <%!-- Hero Intro --%>
        <h1 class="text-center text-5xl font-black tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          The lawless internet
        </h1>
        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          We looked into how the other guys handle your data, and it's not pretty. <span class="underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double">Everyone's tracking you</span>.
        </h2>
        <p class="mt-6 text-center text-lg leading-8 text-gray-600 text-balance dark:text-gray-400">
          So we put together this table to help you get a quick overview of how much tracking is going on, and how we stack up. We sifted through hours of policies, reports, and investigations and came away with one conclusion — it's
          <em>lawless</em>
          out there. Companies are feeding our online behavior into the surveillance industry and it's affecting all of us. The internet doesn't have to be this way.
        </p>

        <div class="mt-10 flex items-center justify-center gap-x-6">
          <MossletWeb.DesignSystem.liquid_button
            navigate="/pricing"
            variant="primary"
            color="teal"
            icon="hero-arrow-long-right"
            class="py-3 px-6"
          >
            Learn more about our pricing
          </MossletWeb.DesignSystem.liquid_button>
        </div>
      </div>

      <div :if={!@hero_intro?}>
        <%!-- Pricing Intro --%>
        <h1 class="text-center text-6xl font-black tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          $700+ per year
        </h1>
        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          That's how much your personal data was worth more than 3 years ago.
        </h2>
        <p class="mt-6 text-center text-lg leading-8 text-gray-600 text-balance dark:text-gray-400">
          And it's only going up. But don't take our word for it, check out this <.link
            target="_blank"
            rel="noopener noreferrer"
            href="https://proton.me/blog/what-is-your-data-worth"
            class="underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
          >analysis conducted by Proton</.link>. This means
          <strong class="dark:text-gray-200">you are paying more than $700 <em>per year</em></strong>
          to share a photo on Instagram or Facebook, search on Google, watch a video on YouTube, or dance on TikTok. Every day, you simply give them this money that is innately yours before it can ever exist in your bank account. It's the greatest heist in history and it's happening right now.
        </p>
      </div>
      <%!-- Table Container --%>
      <div class="bg-background-50 dark:bg-gray-800 sm:py-10 mt-10 pb-4 rounded-lg shadow-lg dark:shadow-emerald-500/50">
        <div class="text-center mb-8">
          <h2 class="pt-4 text-3xl font-black tracking-tight text-black dark:text-white sm:text-4xl lg:text-5xl">
            How
            <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              MOSSLET
            </span>
            Compares
          </h2>
          <p class="mt-4 mx-1 text-lg text-gray-600 dark:text-gray-400 max-w-3xl sm:mx-auto">
            We don't spy on or monetize your personal data
          </p>
        </div>
        <table class="mt-6 w-full text-left whitespace-wrap">
          <colgroup>
            <col class="w-2/12" />
            <col class="w-2/12 sm:w-4/12 lg:w-full" />
            <col class="w-2/12" />
            <col class="w-1/12" />
            <col class="lg:w-4/12" />
            <col class="w-2/12" />
          </colgroup>
          <thead class="border-b border-background-950/10 dark:border-white/10 text-lg/8 text-black dark:text-white">
            <tr>
              <th
                scope="col"
                class="py-3 pr-8 pl-4 font-semibold text-slate-900 dark:text-slate-100 sm:pl-6 lg:pl-8"
              >
                Company
              </th>
              <th
                scope="col"
                class="hidden py-3 pr-8 pl-0 font-semibold text-slate-900 dark:text-slate-100 sm:table-cell"
              >
                <span
                  id="sends-data-column"
                  phx-hook="TippyHook"
                  data-tippy-content="The companies that we know are being sent your personal data."
                  class="cursor-help"
                >
                  Sends Data
                </span>
              </th>
              <th
                scope="col"
                class="py-3 pr-4 pl-0 text-right font-semibold text-slate-900 dark:text-slate-100 sm:pr-8 sm:text-left lg:pr-20"
              >
                <span
                  id="tracking-column"
                  phx-hook="TippyHook"
                  data-tippy-content="Does this company secretly track, spy, snoop, or otherwise surveil you?"
                  class="cursor-help"
                >
                  Tracking?
                </span>
              </th>
              <th
                scope="col"
                class="hidden py-3 pr-4 pl-0 font-semibold text-slate-900 dark:text-slate-100 md:table-cell lg:pr-20"
              >
                <span
                  id="features-column"
                  phx-hook="TippyHook"
                  data-tippy-content="Indicates whether the features for the pricing tier are fully available or not."
                  class="cursor-help"
                >
                  Features
                </span>
              </th>
              <th
                scope="col"
                class="py-3 pr-4 pl-8 text-right font-semibold text-slate-900 dark:text-slate-100 sm:pr-6 lg:pr-8"
              >
                Price
              </th>
              <th
                scope="col"
                class="hidden py-3 pr-4 pl-0 text-right font-semibold text-slate-900 dark:text-slate-100 sm:table-cell sm:pr-6 lg:pr-8"
              >
                <span
                  id="the-privacy-report"
                  phx-hook="TippyHook"
                  data-tippy-content="The privacy report we were able to find from either The Markup's Blacklight investigation, California Learning Resource Network, Commonsense Media, Consumer Reports, or Privado."
                  class="cursor-help"
                >
                  Privacy
                </span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-200/40 dark:divide-slate-700/40">
            <%!-- Bluesky Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/bluesky_logo.png"}
                    alt="Bluesky logo"
                    class="size-16 object-contain cursor-help"
                    id="bluesky-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Bluesky"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Apple, Blockchain Capital<span class="text-xs align-super ml-1">1</span>
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Bluesky"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
            <%!-- Element --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/element_logo.svg"}
                    alt="Element logo"
                    class="size-16 object-contain cursor-help"
                    id="element-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Element"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alexa, Amazon, CloudFront, HubSpot and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited<span class="text-xs align-super ml-1">2</span>
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                $68 /user/yr
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=element.io"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Facebook --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/facebook_logo.svg"}
                    alt="Facebook logo"
                    class="size-16 object-contain cursor-help"
                    id="facebook-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Facebook (Meta)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Amazon, Apple, Experian, Home Depot<span class="text-xs align-super ml-1">3</span>, LiveRamp, Meta<span class="text-xs align-super ml-1">4</span>, Microsoft, Netflix, Oracle, Royal Bank of Canada, Sony, Spotify, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=facebook.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Instagram Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/instagram_logo.png"}
                    alt="Instagram logo"
                    class="size-16 object-contain cursor-help"
                    id="instagram-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Instagram (Meta)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Amazon, Apple, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/instagram"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
            <%!-- Kin Social Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/kin_logo.png"}
                    alt="Kin logo colour"
                    class="size-16 object-contain cursor-help"
                    id="kin-social-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Kin Social"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">Adobe, Alphabet, Facebook</div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=mobile&force=false&url=kinsocial.app"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- LinkedIn Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/linkedin_logo.png"}
                    alt="LinkedIn logo"
                    class="size-16 object-contain cursor-help"
                    id="linkedin-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="LinkedIn"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Adobe, Alphabet, Comscore, Microsoft, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited<span class="text-xs align-super ml-1 text-gray-400">5</span>
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $30 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=mobile&force=false&url=linkedin.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Mastodon --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/mastodon_logo.png"}
                    alt="Mastodon logo"
                    class="size-16 object-contain cursor-help"
                    id="mastodon-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Mastodon"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Varies by server<span class="text-xs align-super ml-1 text-gray-400">6</span>
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $500 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://www.privado.ai/post/who-actually-holds-your-data-in-mastodon-a-privacy-review"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- MOSSLET Row --%>
            <tr class="relative bg-gradient-to-r from-emerald-50/50 to-teal-50/50 dark:from-emerald-900/20 dark:to-teal-900/20 border-2 border-emerald-500 dark:border-emerald-400 shadow-lg shadow-emerald-100/50 dark:shadow-emerald-900/30 hover:shadow-emerald-200/70 dark:hover:shadow-emerald-800/40 transition-all duration-300">
              <%!-- Highlight accent --%>
              <td class="py-6 pr-8 pl-4 sm:pl-6 lg:pl-8 relative">
                <div class="absolute inset-y-0 left-0 w-1 bg-gradient-to-b from-emerald-500 to-teal-500 rounded-r-md">
                </div>
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/logo.svg"}
                    alt="Wire Messaging logo"
                    class="size-16 object-contain cursor-help"
                    id="mosslet-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="MOSSLET"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-6 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-emerald-600 dark:text-emerald-400 font-semibold">
                    No data sent<span class="text-xs align-super ml-1 text-emerald-600 dark:text-emerald-400">7</span>
                  </div>
                </div>
              </td>
              <td class="py-6 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-emerald-600/20 dark:bg-emerald-400/30 p-2 text-emerald-600 dark:text-emerald-400">
                    <div class="size-2 rounded-full bg-current"></div>
                    <div class="absolute inset-0 rounded-full bg-emerald-600/20 dark:bg-emerald-400/25 animate-pulse">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-emerald-600 dark:text-emerald-400">
                    <span class="font-semibold">Protected</span>
                    <.phx_icon name="hero-shield-check" class="w-4 h-4" />
                  </div>
                </div>
              </td>

              <td class="hidden py-6 pr-8 pl-0 text-left text-sm/6 text-emerald-600 dark:text-emerald-400 font-semibold md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>
              <td class="py-6 pr-4 pl-0 text-right text-sm/6 text-emerald-600 dark:text-emerald-400 font-bold sm:pr-6 lg:pr-8">
                $59 /once
              </td>
              <td class="hidden py-6 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=mosslet.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Reddit Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/reddit_logo.svg"}
                    alt="Reddit logo"
                    class="size-16 object-contain cursor-help p-1"
                    id="reddit-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Reddit"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Meta, LiveRamp, Tower Data<span class="text-xs align-super ml-1">8</span>, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $5.99 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=reddit.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- TikTok Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/tiktok_logo.png"}
                    alt="TikTok logo"
                    class="size-16 object-contain cursor-help p-1 dark:bg-white rounded-sm"
                    id="tiktok-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="TikTok"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Bytedance, Facebook, Mayo Clinic, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/TikTok---Real-Short-Videos"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Telegram --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/telegram_logo.png"}
                    alt="Truth Social logo"
                    class="size-16 object-contain cursor-help"
                    id="telegram-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Telegram"
                  />

                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Buzz Media, Federal Government Agencies, Local Law Enforcement, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $59.88 /yr
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://www.clrn.org/how-dangerous-is-telegram/"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Truth Social Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/truth_social_logo.svg"}
                    alt="Truth Social logo"
                    class="size-16 object-contain cursor-help"
                    id="truth-social-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Truth Social"
                  />

                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Adobe, IBM, Innovid, Meta, Oracle, X (Twitter), and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Truth-Social"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- WhatsApp --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/whatsapp_logo.svg"}
                    alt="WhatsApp logo"
                    class="size-16 object-contain cursor-help"
                    id="whatsapp-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="WhatsApp"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Facebook, Federal Government Agencies, Local Law Enforcement, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                    <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                      <div class="size-2 rounded-full bg-current animate-pulse"></div>
                      <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                      </div>
                    </div>
                    <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                      <span class="font-semibold animate-pulse">Live Tracking</span>
                      <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                    </div>
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/WhatsApp-Messenger"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Wire Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/wire_logo.svg"}
                    alt="Wire Messaging logo"
                    class="size-16 object-contain cursor-help bg-gray-800 p-1 rounded-sm"
                    id="wire-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Wire Messaging"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, HubSpot, LinkedIn, Microsoft
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?url=wire.com&device=mobile&location=us-ca&force=false"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- X / Twitter Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/twitter_x_logo.png"}
                    alt="X Twitter logo"
                    class="size-16 object-contain cursor-help p-1 dark:bg-white rounded-sm"
                    id="x-twitter-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="X (Twitter)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet<span class="text-xs align-super ml-1">9</span>, Amazon, Apple, Comcast, Experian, Facebook, IBM, Microsoft, Oracle, Verizon, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="relative flex-none rounded-full bg-rose-600/20 dark:bg-rose-400/30 p-2 text-rose-600 dark:text-rose-400">
                    <div class="size-2 rounded-full bg-current animate-pulse"></div>
                    <div class="absolute inset-0 rounded-full bg-rose-600/30 dark:bg-rose-400/40 animate-ping">
                    </div>
                  </div>
                  <div class="flex items-center gap-x-1 text-rose-600 dark:text-rose-400">
                    <span class="font-semibold animate-pulse">Live Tracking</span>
                    <.phx_icon name="hero-signal" class="w-4 h-4 animate-bounce" />
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Twitter-X"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
        <%!-- Collapsible Footnotes Section --%>
        <details class="group bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden shadow-sm hover:shadow-md transition-shadow duration-200 mt-6 mx-4 sm:mx-6">
          <summary class="cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-all duration-200 border-b border-gray-100 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="flex-shrink-0 w-8 h-8 bg-emerald-100 dark:bg-emerald-900/50 rounded-full flex items-center justify-center">
                  <.phx_icon
                    name="hero-document-text"
                    class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
                  />
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    Research Footnotes
                  </h3>
                  <p class="text-sm text-gray-500 dark:text-gray-400">
                    Detailed analysis behind the privacy and tracking data
                  </p>
                </div>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-xs text-gray-500 dark:text-gray-400 hidden sm:block group-open:hidden">
                  Click to expand
                </span>
                <span class="text-xs text-gray-500 dark:text-gray-400 hidden sm:group-open:block">
                  Click to close
                </span>
                <.phx_icon
                  name="hero-chevron-down"
                  class="h-5 w-5 text-gray-400 transition-transform duration-200 group-open:rotate-180"
                />
              </div>
            </div>
          </summary>
          <div class="border-t border-gray-100 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/50">
            <div class="p-4 space-y-4">
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded-full flex items-center justify-center text-xs font-medium">
                  1
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Bluesky:</strong>
                  Claims to share/sell data. Some of that sharing is benign, like payment processors (even we have to use Stripe to process the payment for your account). But others are more murky, like "business partners". Some of those business partners are hedge fund founders and venture capital, so their business is inevitably focused on Wall Street and its investors — their
                  <em>actual</em>
                  customers. It is also known that they link your content, contact information, and other personal identifiers to your account and all of it is accessible by Bluesky, therefore others. In summary: you are being tracked
                  <em>and</em>
                  they are planning a subscription fee.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded-full flex items-center justify-center text-xs font-medium">
                  2
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Element:</strong>
                  The idea behind Element is positive. But in order to be "free" you have to be able to run their software on your own server, aka <em>self host</em>. This is not realistic for most people and not actually free (you have to factor in the cost of running the service yourself). Additionally, whoever is running the software has the ability to access your encrypted data — Element's privacy policy states that Element engineers
                  <em>and contractors</em>
                  can access your data from their paid products. This isn't inherently bad, but it is a <em>serious privacy concern</em>. On top of that, you are still being tracked and your data is still being sent through the usual pipelines of surveillance capitalism when you use their services.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-red-100 dark:bg-red-900/50 text-red-600 dark:text-red-400 rounded-full flex items-center justify-center text-xs font-medium">
                  3
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">ICE Concerns:</strong>
                  This is incredibly alarming considering the 2025 Immigration and Customs Enforcement (ICE) kidnappings.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-red-100 dark:bg-red-900/50 text-red-600 dark:text-red-400 rounded-full flex items-center justify-center text-xs font-medium">
                  4
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Facebook/Meta:</strong>
                  A recent study from Consumer Reports and The Markup discovered that thousands of companies are tracking each individual user on Facebook (Meta). You can
                  <.link
                    navigate={~p"/blog/articles/01#its-nothing-personal"}
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 underline font-medium"
                  >
                    learn more about it
                  </.link>
                  on our blog.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-orange-100 dark:bg-orange-900/50 text-orange-600 dark:text-orange-400 rounded-full flex items-center justify-center text-xs font-medium">
                  5
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">LinkedIn:</strong>
                  The $29.99 /mo pricing tier on LinkedIn, which we rounded to $30, is aimed at individuals and offers a few more of the company's services but the entire feature suite of LinkedIn is still limited and they still continue to monetize your data through the pipelines of surveillance capitalism. Other pricing tiers on LinkedIn range from $99.99-$835 per month.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-yellow-100 dark:bg-yellow-900/50 text-yellow-600 dark:text-yellow-400 rounded-full flex items-center justify-center text-xs font-medium">
                  6
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Mastodon:</strong>
                  On Mastodon, the privacy and data practices can vary significantly depending on the server you choose to join. Some servers may have strong privacy policies, while others may not prioritize user data protection at all — you would have to read and interpret the policies for every server. On mastodon.social there appeared to be no direct data sharing going on, but other Mastodon servers are able to collect your public information without you being aware. Additionally, your data is not asymetrically encrypted so anyone with access to a server's database (where data is stored) can see your information (read this to learn why we believe
                  <.link
                    target="_blank"
                    rel="noopener noreferrer"
                    href="https://www.schneier.com/essays/archives/2016/04/the_value_of_encrypt.html"
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 underline font-medium"
                  >
                    encryption matters
                  </.link>
                  to privacy). Lastly, each server is tracking you — including your location.
                </p>
              </div>
              <div class="flex gap-3 p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border border-emerald-200 dark:border-emerald-700">
                <span class="flex-shrink-0 w-6 h-6 bg-emerald-100 dark:bg-emerald-900/50 text-emerald-600 dark:text-emerald-400 rounded-full flex items-center justify-center text-xs font-medium">
                  7
                </span>
                <p class="text-sm text-emerald-700 dark:text-emerald-300">
                  <strong class="text-emerald-800 dark:text-emerald-200">MOSSLET:</strong>
                  We don't share, sell, sneak, trade, barter, or otherwise monetize your data for our business or others. We
                  <em>do need</em>
                  to use a payment processor to securely process your <em>one-time</em>
                  payment, and our provider is
                  <.link
                    target="_blank"
                    rel="noopener noreferrer"
                    href="https://support.stripe.com/questions/does-stripe-sell-my-information"
                    class="text-emerald-700 dark:text-emerald-300 hover:text-emerald-800 dark:hover:text-emerald-200 underline font-medium"
                  >
                    Stripe
                  </.link>
                  — whose got a policy so good we wish that Big Tech would adopt it. We talk about it in
                  <.link
                    navigate={~p"/privacy"}
                    class="text-emerald-700 dark:text-emerald-300 hover:text-emerald-800 dark:hover:text-emerald-200 underline font-medium"
                  >
                    our privacy policy
                  </.link>
                  that we wrote ourselves. At MOSSLET, we are privacy-first.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-red-100 dark:bg-red-900/50 text-red-600 dark:text-red-400 rounded-full flex items-center justify-center text-xs font-medium">
                  8
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Reddit:</strong>
                  Reddit is sending your data <em>everywhere</em>. On top of sending to the usual suspects like Alphabet and Meta (LiveRamp is one of the biggest data brokers), they apparently send your data to Tower Data who openly <em>sells your information to political campaigns</em>. On top of all of this surveillance capitalism, Reddit also offers to charge you $5.99 /mo (an infinitely growing expense) to continue to be tracked and manipulated just beyond your awareness.
                </p>
              </div>
              <div class="flex gap-3">
                <span class="flex-shrink-0 w-6 h-6 bg-purple-100 dark:bg-purple-900/50 text-purple-600 dark:text-purple-400 rounded-full flex items-center justify-center text-xs font-medium">
                  9
                </span>
                <p class="text-sm text-gray-600 dark:text-gray-400">
                  <strong class="text-gray-900 dark:text-gray-100">Alphabet/Google:</strong>
                  Adscape, Calico, Cameyo, CapitalG, Charleston Road Registry, DeepMind, Endoxon, FeedBurner, Google, Google Fiber, GV, ImageAmerica, Intrinsic, Isomorphic Labs, Kaltix, Nest Labs (the thermostat), reCAPTCHA, Verily, Waymo, Wing, YouTube, and ZipDash are all owned by Alphabet Inc. after Google, <em>creator of surveillance capitalism</em>, restructured their business.
                </p>
              </div>
            </div>
          </div>
        </details>
      </div>
    </div>
    """
  end

  def faq(assigns) do
    ~H"""
    <main class="isolate">
      <%!-- Hero section --%>
      <div class="relative isolate -z-10">
        <svg
          class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-gray-200 dark:stroke-gray-800 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
          aria-hidden="true"
        >
          <defs>
            <pattern
              id="faq-pattern"
              width="200"
              height="200"
              x="50%"
              y="-1"
              patternUnits="userSpaceOnUse"
            >
              <path d="M.5 200V.5H200" fill="none" />
            </pattern>
          </defs>
          <svg x="50%" y="-1" class="overflow-visible fill-gray-50 dark:fill-gray-900">
            <path
              d="M-200 0h201v201h-201Z M600 0h201v201h-201Z M-400 600h201v201h-201Z M200 800h201v201h-201Z"
              stroke-width="0"
            />
          </svg>
          <rect
            width="100%"
            height="100%"
            stroke-width="0"
            fill="url(#faq-pattern)"
          />
        </svg>
        <div
          class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
          aria-hidden="true"
        >
          <div
            class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30"
            style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
          >
          </div>
        </div>
        <div class="overflow-hidden">
          <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
            <div class="mx-auto max-w-4xl text-center">
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Frequently Asked Questions
              </h1>
              <h2 class="mt-6 text-balance text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
                Get the answers you need
              </h2>
              <p class="mt-8 text-pretty text-lg font-medium text-gray-600 dark:text-gray-400 sm:text-xl/8 text-balance">
                Everything you need to know about MOSSLET's privacy-first approach, features, and how we protect your data. Can't find what you're looking for? We're here to help.
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Quick answers section --%>
      <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
        <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
          <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-3">
            <%!-- Privacy Focus --%>
            <.link
              href="/privacy"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 px-8 py-8 border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="flex justify-center pb-4">
                  <svg
                    class="size-12 text-emerald-500"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z"
                    />
                  </svg>
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Privacy First
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    End-to-End Encryption
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Your data is encrypted so only you can access it. We can't see it, and neither can anyone else.
                  </p>
                </div>
              </div>
            </.link>

            <%!-- Simple Pricing --%>
            <.link
              href="/pricing"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-orange-50 dark:bg-orange-900/60 dark:bg-gray-800/60 px-8 py-8 border border-orange-200 dark:border-orange-700/30 dark:shadow-xl dark:shadow-orange-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-orange-500/30 dark:group-hover:shadow-orange-500/40">
                <div class="flex justify-center pb-4">
                  <svg
                    class="size-12 text-orange-500"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M12 6v12m-3-2.818.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"
                    />
                  </svg>
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-orange-600 dark:text-orange-400">
                    Fair Pricing
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    Pay Once, Own Forever
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    No subscriptions, no ads, no spying. Just a one-time payment for lifetime access.
                  </p>
                </div>
              </div>
            </.link>

            <%!-- Support --%>
            <.link
              href="/support"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-blue-50 dark:bg-blue-900/60 dark:bg-gray-800/60 px-8 py-8 border border-blue-200 dark:border-blue-700/30 dark:shadow-xl dark:shadow-blue-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-blue-500/30 dark:group-hover:shadow-blue-500/40">
                <div class="flex justify-center pb-4">
                  <svg
                    class="size-12 text-blue-500"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke-width="1.5"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M18 18.72a9.094 9.094 0 0 0 3.741-.479 3 3 0 0 0-4.682-2.72m.94 3.198.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0 1 12 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 0 1 6 18.719m12 0a5.971 5.971 0 0 0-.941-3.197m0 0A5.995 5.995 0 0 0 12 12.75a5.995 5.995 0 0 0-5.058 2.772m0 0a3 3 0 0 0-4.681 2.72 8.986 8.986 0 0 0 3.74.477m.94-3.197a5.971 5.971 0 0 0-.94 3.197M15 6.75a3 3 0 1 1-6 0 3 3 0 0 1 6 0Zm6 3a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Zm-13.5 0a2.25 2.25 0 1 1-4.5 0 2.25 2.25 0 0 1 4.5 0Z"
                    />
                  </svg>
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-blue-600 dark:text-blue-400">
                    Human Support
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    Real People, Real Help
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Questions? Reach out to our support team. We're real people who actually want to help.
                  </p>
                </div>
              </div>
            </.link>
          </div>
        </div>
      </div>

      <%!-- Main FAQ section --%>
      <div class="bg-white dark:bg-gray-950 py-24 sm:py-32">
        <div class="mx-auto max-w-7xl px-6 lg:px-8">
          <div class="lg:grid lg:grid-cols-12 lg:gap-8">
            <div class="lg:col-span-5">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Quick Answers
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                Can't find the answer you're looking for? Reach out to our
                <.link
                  class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                  href="mailto:support@mosslet.com"
                >
                  customer support
                </.link>
                team.
              </p>
            </div>
            <div class="mt-10 lg:col-span-7 lg:mt-0">
              <dl class="space-y-10">
                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What is MOSSLET?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET is a privacy-first social network designed to protect users' privacy and human dignity from surveillance and the attention economy. We prioritize privacy, data protection, and creating a safe space for meaningful social interactions.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    How does MOSSLET protect my privacy?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET employs asymmetric encryption (end-to-end) to ensure that your data remains private and secure. This means that only you and the intended recipient can access your messages and information, keeping your interactions confidential.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What is the pay once pricing model?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET operates on a pay once pricing model, currently set at $59 during our beta phase. This approach allows us to maintain our service without relying on advertising or data monetization, ensuring that your privacy and experience remains our top priority.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What makes MOSSLET different from other social networks?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET stands out by prioritizing user privacy, employing ethical design practices, and offering a straightforward pricing model. Unlike traditional social networks that rely on advertising and data exploitation, we focus on creating a safe and respectful environment for our users.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    Can I delete my account and data?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    Yes, you can delete your account at any time. When you choose to delete your account, all your data will be permanently removed from our servers, ensuring that your information is no longer accessible.
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </main>

    <div class="pb-12">
      <div id="more-faq-show-button-container" class="hidden relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            id="more-faq-show-button"
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-show-button-container")
              |> JS.toggle(to: "#more-faq-hide-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
          >
            <svg
              class="-ml-1 -mr-0.5 size-5 text-gray-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
              data-slot="icon"
            >
              <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
            </svg>
            Show in-depth FAQ
          </button>
        </div>
      </div>

      <div id="more-faq-hide-button-container" class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-hide-button-container")
              |> JS.toggle(to: "#more-faq-show-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="-ml-1 -mr-0.5 size-5 text-gray-400"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
            </svg>
            Hide in-depth FAQ
          </button>
        </div>
      </div>

      <.more_faq />
    </div>
    """
  end

  def more_faq(assigns) do
    assigns = assigns

    ~H"""
    <section id="more-faq" class="transition-all" aria-labelledby="more-faq-title">
      <div class="bg-white dark:bg-gray-950">
        <div class="mx-auto max-w-7xl px-6 pb-16 sm:pb-24 lg:px-8">
          <div class="mb-12"></div>
          <.faq_section_heading title="General" anchor_tag="general" />
          <div class="mt-12"></div>

          <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                What are dark patterns?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Dark patterns are deceptive design techniques used in websites or apps to manipulate users into making choices they might not otherwise make, often to benefit the company.
              </dd>
            </div>
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                Is there a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Not yet! In the meantime, you can log into your account (or visit any page on the website) from the web browser on your mobile device, click the share icon (<.phx_icon
                  name="hero-arrow-up-on-square"
                  class="inline-flex h-5 w-5"
                />), and then select the "Add to home screen" option to save a MOSSLET shortcut to your device.
              </dd>
            </div>

            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                When will there be a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                TBA. We're a small team and are currently looking into different options for bringing our web app to a native device. Once we know, we'll share the update here.
              </dd>
            </div>
          </dl>

          <div class="mt-20">
            <.faq_section_heading title="Data" anchor_tag="data" />
            <div class="mb-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does MOSSLET do with my data?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  MOSSLET uses your data to power your account and its features for you. For example, it is securely and privately stored for you so that you can access your account, update or delete your data, and share it with others.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET share, sell, or otherwise use my data behind my back?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! And we will never do that. Period. Unlike Facebook and Big Tech, there's nothing sneaky here. You pay for our service and we provide you with privacy-first features for a calmer, better life.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data encrypted?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your personal data is asymmetrically encrypted with a password-derived key, making it so that only you can access and unlock your data. Without your password, no one else can — not even us! We then wrap that encrypted data in an extra layer of symmetric encryption before storing it at rest ("at rest" meaning in the database when you are not using it).
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  In more detail it looks like this: each person has a (1) password-derived key, (2) public-private key pair, and (3) their private key is encrypted with their password-derived key.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data shared with my friends?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you share your data with your friends, they receive an encrypted copy of a unique key specific to that piece of data (think a Post or Memory). Their copy is encrypted with their public key so that they can unlock it and thus access the data you shared with them.
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  This ensures that only the people you choose to share with can access whatever you are sharing. When you delete a friend or stop sharing with them, their access to your data is also removed.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Where is my data stored?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your data is stored in our secure, private database network that is distributed and run by our hardware provider <.link
                    href="https://fly.io"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Fly</.link>. The network is protected with the WireGuard protocol and your personal data is encrypted twice before being stored in the database.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Any media data, like Memories and avatars (photos), are stored with our private, decentralized cloud storage provider <.link
                    href="https://tigrisdata.com"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Tigris</.link>. Your data is asymmetrically encrypted and then sent to Tigris where it is distributed around the world for faster speeds and optimal availability.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET use my image or data to train its AI?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! We are using a pre-trained, open source model from the machine learning community. This means it was trained on other image data (~80,000 images). We then run this model on our own private, internal servers — ensuring your data remains private and secure.
                </dd>
              </div>
            </dl>

            <%!--
            <div class="mb-12"></div>
            <.faq_section_heading title="Memories" anchor_tag="memories" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What are Memories? Can I share them publicly?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Memories are photos. You can share them with anyone you're connected to but not publicly. Publicly sharing a Memory is a feature that we are considering for the future.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do you ensure images are safe?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We currently check all images against an AI model fine-tuned for detecting NSFW images (not safe for work). If an image is deemed NSFW, then it cannot be uploaded. This is not a foolproof system and won't catch everything, but it is a start. Please report to us any harmful images at <.link
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                    href="mailto:support@mosslet.com"
                  >support</.link>.
                </dd>
              </div>
            </dl>

            --%>

            <div class="mb-12"></div>
            <.faq_section_heading title="Password" anchor_tag="password" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div id="irreversibly-hashed">
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does "irreversibly hashed" mean?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Irreversibly hashing a password means converting it into a fixed-length string of characters using a one-way function, making it impossible to retrieve the original password from that string. We use an industry leading method that ensures you can safely log in to your account without risking someone else being able to know your password.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens if I forget my password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you forget your password and have not enabled our forgot password feature in your settings, then you won't be able to regain access to your account. We do not have the ability to reset your password due to the secure encryption of your account and its data.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you have enabled the forgot password feature, then you can simply
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  using your account email. We recommend that you use a password manager or save your password in a secure, private place so that you don't forget it.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What is the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  The forgot password feature gives you the ability to get back into your account should you forget your password. We created this feature to give you the choice between added convenience and increased security. Simply go to your account settings to enable/disable it at any time.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We recommend for most people that you enable the forgot password feature to ensure you don't get locked out of your account — your account and its data will still be protected with strong encryption.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  I enabled the forgot password feature, what happens now?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you enable it, we store a symmetrically encrypted copy of your password-derived key in our private, secure database. This enables the server to use your password-derived key to let you back into your account with a standard
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  request email.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens when I disable the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you disable it, the symmetrically encrypted copy of your password-derived key is deleted from our database. This returns your account to its original asymmetric encryption — meaning only your password can let you back into your account and unlock your data.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do I change my account password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  You can change your password any time from within your settings. Simply log in to your account and go to the "change password" section of your settings to make the change.
                </dd>
              </div>
            </dl>

            <div class="mb-12"></div>
            <.faq_section_heading title="Posts" anchor_tag="posts" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! Simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Post you wish to reply to. All replies are sent, updated, and deleted in real time.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I make a public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  No. This is a feature we are considering for the future.
                </dd>
              </div>

              <%!-- Public Post
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! If you are signed into your MOSSLET account, simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Public Post you wish to reply to. All public replies are sent, updated, and deleted in real time.
                </dd>
              </div>
              --%>
            </dl>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def faq_app(assigns) do
    ~H"""
    <main class="isolate">
      <%!-- Hero section --%>
      <div class="relative isolate -z-10">
        <svg
          class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-gray-200 dark:stroke-gray-800 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
          aria-hidden="true"
        >
          <defs>
            <pattern
              id="faq-pattern"
              width="200"
              height="200"
              x="50%"
              y="-1"
              patternUnits="userSpaceOnUse"
            >
              <path d="M.5 200V.5H200" fill="none" />
            </pattern>
          </defs>
          <svg x="50%" y="-1" class="overflow-visible fill-gray-50 dark:fill-gray-900">
            <path
              d="M-200 0h201v201h-201Z M600 0h201v201h-201Z M-400 600h201v201h-201Z M200 800h201v201h-201Z"
              stroke-width="0"
            />
          </svg>
          <rect
            width="100%"
            height="100%"
            stroke-width="0"
            fill="url(#faq-pattern)"
          />
        </svg>
        <div
          class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
          aria-hidden="true"
        >
          <div
            class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30"
            style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
          >
          </div>
        </div>
        <div class="overflow-hidden">
          <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
            <div class="mx-auto max-w-4xl text-center">
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Frequently Asked Questions
              </h1>
              <h2 class="mt-6 text-balance text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
                Get the answers you need
              </h2>
              <p class="mt-8 text-pretty text-lg font-medium text-gray-600 dark:text-gray-400 sm:text-xl/8 text-balance">
                Everything you need to know about MOSSLET's privacy-first approach, features, and how we protect your data. Can't find what you're looking for? We're here to help.
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Quick answers section --%>
      <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
        <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
          <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-3">
            <%!-- Privacy Focus --%>
            <.link
              href="/privacy"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 px-8 py-8 border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="flex justify-center pb-4">
                  <.phx_icon name="hero-lock-closed" class="size-12 text-emerald-500" />
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Privacy First
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    End-to-End Encryption
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Your data is encrypted so only you can access it. We can't see it, and neither can anyone else.
                  </p>
                </div>
              </div>
            </.link>

            <%!-- Simple Pricing --%>
            <.link
              href="/app/billing"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-orange-50 dark:bg-orange-900/60 dark:bg-gray-800/60 px-8 py-8 border border-orange-200 dark:border-orange-700/30 dark:shadow-xl dark:shadow-orange-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-orange-500/30 dark:group-hover:shadow-orange-500/40">
                <div class="flex justify-center pb-4">
                  <.phx_icon name="hero-currency-dollar" class="size-12 text-orange-500" />
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-orange-600 dark:text-orange-400">
                    Fair Pricing
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    Pay Once, Own Forever
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    No subscriptions, no ads, no spying. Just a one-time payment for lifetime access.
                  </p>
                </div>
              </div>
            </.link>

            <%!-- Support --%>
            <.link
              href="/support"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-blue-50 dark:bg-blue-900/60 dark:bg-gray-800/60 px-8 py-8 border border-blue-200 dark:border-blue-700/30 dark:shadow-xl dark:shadow-blue-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-blue-500/30 dark:group-hover:shadow-blue-500/40">
                <div class="flex justify-center pb-4">
                  <.phx_icon name="hero-users" class="size-12 text-blue-500" />
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-blue-600 dark:text-blue-400">
                    Human Support
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    Real People, Real Help
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Questions? Reach out to our support team. We're real people who actually want to help.
                  </p>
                </div>
              </div>
            </.link>
          </div>
        </div>
      </div>

      <%!-- Main FAQ section --%>
      <div class="bg-white dark:bg-gray-950 py-24 sm:py-32">
        <div class="mx-auto max-w-7xl px-6 lg:px-8">
          <div class="lg:grid lg:grid-cols-12 lg:gap-8">
            <div class="lg:col-span-5">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Quick Answers
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                Can't find the answer you're looking for? Reach out to our
                <.link
                  class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                  href="mailto:support@mosslet.com"
                >
                  customer support
                </.link>
                team.
              </p>
            </div>
            <div class="mt-10 lg:col-span-7 lg:mt-0">
              <dl class="space-y-10">
                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What is MOSSLET?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET is a privacy-first social network designed to protect users' privacy and human dignity from surveillance and the attention economy. We prioritize privacy, data protection, and creating a safe space for meaningful social interactions.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    How does MOSSLET protect my privacy?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET employs asymmetric encryption (end-to-end) to ensure that your data remains private and secure. This means that only you and the intended recipient can access your messages and information, keeping your interactions confidential.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What is the pay once pricing model?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET operates on a pay once pricing model, currently set at $59 during our beta phase. This approach allows us to maintain our service without relying on advertising or data monetization, ensuring that your privacy and experience remains our top priority.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    What makes MOSSLET different from other social networks?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET stands out by prioritizing user privacy, employing ethical design practices, and offering a straightforward pricing model. Unlike traditional social networks that rely on advertising and data exploitation, we focus on creating a safe and respectful environment for our users.
                  </dd>
                </div>

                <div>
                  <dt class="text-lg font-bold text-gray-900 dark:text-gray-100">
                    Can I delete my account and data?
                  </dt>
                  <dd class="mt-3 text-base/7 text-gray-600 dark:text-gray-400">
                    Yes, you can delete your account at any time. When you choose to delete your account, all your data will be permanently removed from our servers, ensuring that your information is no longer accessible.
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </main>

    <div class="pb-12">
      <div id="more-faq-show-button-container" class="hidden relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-background-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            id="more-faq-show-button"
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-show-button-container")
              |> JS.toggle(to: "#more-faq-hide-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-background-100 px-3 py-1.5 text-sm font-semibold text-background-900 shadow-sm ring-1 ring-inset ring-background-300 hover:bg-background-50"
          >
            <svg
              class="-ml-1 -mr-0.5 size-5 text-background-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
              data-slot="icon"
            >
              <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
            </svg>
            Show in-depth FAQ
          </button>
        </div>
      </div>

      <div id="more-faq-hide-button-container" class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-background-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-hide-button-container")
              |> JS.toggle(to: "#more-faq-show-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-background-100 px-3 py-1.5 text-sm font-semibold text-background-900 shadow-sm ring-1 ring-inset ring-background-300 hover:bg-background-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="-ml-1 -mr-0.5 size-5 text-background-400"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
            </svg>
            Hide in-depth FAQ
          </button>
        </div>
      </div>

      <.more_faq_app />
    </div>
    """
  end

  def more_faq_app(assigns) do
    assigns = assigns

    ~H"""
    <section id="more-faq" class="mt-10 transition-all" aria-labelledby="more-faq-title">
      <div class="mx-auto max-w-7xl bg-white dark:bg-gray-800 shadow-md dark:shadow-emerald-500/50">
        <div class="mx-auto max-w-7xl px-4 lg:px-8 pb-16 sm:pb-24">
          <div class="pt-4 mb-12"></div>
          <.faq_section_heading_app title="General" anchor_tag="general" />
          <div class="mt-12"></div>

          <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                What are dark patterns?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Dark patterns are deceptive design techniques used in websites or apps to manipulate users into making choices they might not otherwise make, often to benefit the company.
              </dd>
            </div>
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                Is there a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Not yet! In the meantime, you can log into your account (or visit any page on the website) from the web browser on your mobile device, click the share icon (<.phx_icon
                  name="hero-arrow-up-on-square"
                  class="inline-flex h-5 w-5"
                />), and then select the "Add to home screen" option to save a MOSSLET shortcut to your device.
              </dd>
            </div>

            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                When will there be a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                TBA. We're a small team and are currently looking into different options for bringing our web app to a native device. Once we know, we'll share the update here.
              </dd>
            </div>
          </dl>

          <div class="mt-20">
            <.faq_section_heading_app title="Data" anchor_tag="data" />
            <div class="mb-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does MOSSLET do with my data?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  MOSSLET uses your data to power your account and its features for you. For example, it is securely and privately stored for you so that you can access your account, update or delete your data, and share it with others.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET share, sell, or otherwise use my data behind my back?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! And we will never do that. Period. Unlike Facebook and Big Tech, there's nothing sneaky here. You pay for our service and we provide you with privacy-first features for a calmer, better life.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data encrypted?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your personal data is asymmetrically encrypted with a password-derived key, making it so that only you can access and unlock your data. Without your password, no one else can — not even us! We then wrap that encrypted data in an extra layer of symmetric encryption before storing it at rest ("at rest" meaning in the database when you are not using it).
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  In more detail it looks like this: each person has a (1) password-derived key, (2) public-private key pair, and (3) their private key is encrypted with their password-derived key.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data shared with my friends?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you share your data with your friends, they receive an encrypted copy of a unique key specific to that piece of data (think a Post or Memory). Their copy is encrypted with their public key so that they can unlock it and thus access the data you shared with them.
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  This ensures that only the people you choose to share with can access whatever you are sharing. When you delete a friend or stop sharing with them, their access to your data is also removed.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Where is my data stored?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your data is stored in our secure, private database network that is distributed and run by our hardware provider <.link
                    href="https://fly.io"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Fly</.link>. The network is protected with the WireGuard protocol and your personal data is encrypted twice before being stored in the database.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Any media data, like Memories and avatars (photos), are stored with our private, decentralized cloud storage provider <.link
                    href="https://tigrisdata.com"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Tigris</.link>. Your data is asymmetrically encrypted and then sent to Tigris where it is distributed around the world for faster speeds and optimal availability.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET use my image or data to train its AI?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! We are using a pre-trained, open source model from the machine learning community. This means it was trained on other image data (~80,000 images). We then run this model on our own private, internal servers — ensuring your data remains private and secure.
                </dd>
              </div>
            </dl>

            <%!--
            <div class="mb-12"></div>
            <.faq_section_heading title="Memories" anchor_tag="memories" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What are Memories? Can I share them publicly?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Memories are photos. You can share them with anyone you're connected to but not publicly. Publicly sharing a Memory is a feature that we are considering for the future.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do you ensure images are safe?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We currently check all images against an AI model fine-tuned for detecting NSFW images (not safe for work). If an image is deemed NSFW, then it cannot be uploaded. This is not a foolproof system and won't catch everything, but it is a start. Please report to us any harmful images at <.link
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                    href="mailto:support@mosslet.com"
                  >support</.link>.
                </dd>
              </div>
            </dl>

            --%>

            <div class="mb-12"></div>
            <.faq_section_heading_app title="Password" anchor_tag="password" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div id="irreversibly-hashed">
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does "irreversibly hashed" mean?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Irreversibly hashing a password means converting it into a fixed-length string of characters using a one-way function, making it impossible to retrieve the original password from that string. We use an industry leading method that ensures you can safely log in to your account without risking someone else being able to know your password.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens if I forget my password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you forget your password and have not enabled our forgot password feature in your settings, then you won't be able to regain access to your account. We do not have the ability to reset your password due to the secure encryption of your account and its data.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you have enabled the forgot password feature, then you can simply
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  using your account email. We recommend that you use a password manager or save your password in a secure, private place so that you don't forget it.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What is the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  The forgot password feature gives you the ability to get back into your account should you forget your password. We created this feature to give you the choice between added convenience and increased security. Simply go to your account settings to enable/disable it at any time.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We recommend for most people that you enable the forgot password feature to ensure you don't get locked out of your account — your account and its data will still be protected with strong encryption.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  I enabled the forgot password feature, what happens now?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you enable it, we store a symmetrically encrypted copy of your password-derived key in our private, secure database. This enables the server to use your password-derived key to let you back into your account with a standard
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  request email.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens when I disable the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you disable it, the symmetrically encrypted copy of your password-derived key is deleted from our database. This returns your account to its original asymmetric encryption — meaning only your password can let you back into your account and unlock your data.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do I change my account password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  You can change your password any time from within your settings. Simply log in to your account and go to the "change password" section of your settings to make the change.
                </dd>
              </div>
            </dl>

            <div class="mb-12"></div>
            <.faq_section_heading_app title="Posts" anchor_tag="posts" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! Simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Post you wish to reply to. All replies are sent, updated, and deleted in real time.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I make a public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  No. This is a feature we are considering for the future.
                </dd>
              </div>

              <%!-- Public Post
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! If you are signed into your MOSSLET account, simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Public Post you wish to reply to. All public replies are sent, updated, and deleted in real time.
                </dd>
              </div>
              --%>
            </dl>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp faq_section_heading(assigns) do
    ~H"""
    <div id={@anchor_tag} class="border-b border-t border-gray-200 dark:border-gray-700 py-5 my-6">
      <h2 class="text-xl font-semibold tracking-tight sm:text-2xl text-base text-gray-900 dark:text-gray-100 text-center">
        {@title}
      </h2>
    </div>
    """
  end

  defp faq_section_heading_app(assigns) do
    ~H"""
    <div
      id={@anchor_tag}
      class="border-b border-t border-background-200 dark:border-background-700 py-5"
    >
      <h2 class="text-xl font-semibold tracking-tight sm:text-2xl text-base text-background-900 dark:text-background-100 text-center">
        {@title}
      </h2>
    </div>
    """
  end

  @doc """
  A beautiful liquid metal testimonials section that matches the design system.
  """
  def liquid_testimonials(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> "Why people love it here" end)
      |> assign_new(:subtitle, fn ->
        "Join a community that values genuine connections, calm spaces, and putting people first."
      end)
      |> assign_new(:testimonials, fn ->
        [
          %{
            quote:
              "I'm done with Facebook. I'd like a place where I own the data and that is generally positive vs. all the negativity that gets put into my feed.",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "teal"
          },
          %{
            quote:
              "I like the idea of being able to share stories about the grandchildren in our family with other parents and grandparents without someone I don't know having access.",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "emerald"
          },
          %{
            quote: "Because it's amazing ✨",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "cyan"
          },
          %{
            quote:
              "Tired of being profiled everywhere, would love to experience something that ain't harvesting me.",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "violet"
          },
          %{
            quote:
              "Having a safe place to share photos of our little bears feels so amazing. Thank you for creating this.",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "purple"
          },
          %{
            quote:
              "Finally, a social platform that respects my privacy and doesn't try to manipulate me with algorithms.",
            name: "Private Member",
            role: "Early Access Invitee",
            accent: "pink"
          }
        ]
      end)

    ~H"""
    <section
      id="testimonials"
      aria-label="What our members are saying"
      class="relative py-20 sm:py-28 overflow-hidden"
    >
      <div class="absolute inset-0 bg-gradient-to-b from-slate-50/50 via-teal-50/30 to-slate-50/50 dark:from-slate-900/50 dark:via-teal-950/30 dark:to-slate-900/50">
      </div>

      <div class="absolute inset-0 opacity-30">
        <div class="absolute top-0 left-1/4 w-96 h-96 bg-gradient-to-br from-teal-400/20 to-emerald-400/20 dark:from-teal-600/10 dark:to-emerald-600/10 rounded-full blur-3xl">
        </div>
        <div class="absolute bottom-0 right-1/4 w-96 h-96 bg-gradient-to-br from-cyan-400/20 to-teal-400/20 dark:from-cyan-600/10 dark:to-teal-600/10 rounded-full blur-3xl">
        </div>
      </div>

      <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
        <div class="flex items-center justify-center gap-3 mb-4">
          <div class="h-px w-12 bg-gradient-to-r from-transparent to-emerald-400 dark:to-emerald-600">
          </div>
          <span class="text-sm font-semibold uppercase tracking-wider text-emerald-600 dark:text-emerald-400">
            Testimonials
          </span>
          <div class="h-px w-12 bg-gradient-to-l from-transparent to-emerald-400 dark:to-emerald-600">
          </div>
        </div>

        <div class="mx-auto max-w-2xl text-center mb-12">
          <h2 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            {@title}
          </h2>
          <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400">
            {@subtitle}
          </p>
        </div>

        <.featured_testimonial />

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-10">
          <%= for {testimonial, index} <- Enum.with_index(@testimonials) do %>
            <.testimonial_card testimonial={testimonial} index={index} />
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  defp featured_testimonial(assigns) do
    ~H"""
    <figure class="relative mx-auto max-w-4xl">
      <div class="absolute -inset-4 rounded-3xl bg-gradient-to-r from-teal-500/20 via-emerald-500/20 to-cyan-500/20 dark:from-teal-500/10 dark:via-emerald-500/10 dark:to-cyan-500/10 blur-xl">
      </div>

      <div class="relative rounded-2xl bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm p-8 sm:p-10 ring-1 ring-emerald-200/60 dark:ring-emerald-700/40 shadow-2xl shadow-emerald-900/10 dark:shadow-emerald-900/30">
        <div class="absolute -top-4 left-8 sm:left-10">
          <div class="flex h-10 w-10 items-center justify-center rounded-full shadow-lg bg-gradient-to-br from-teal-500 to-emerald-500 ring-4 ring-white dark:ring-slate-800">
            <svg class="h-5 w-5 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z" />
            </svg>
          </div>
        </div>

        <blockquote class="pt-4">
          <p class="text-lg sm:text-xl leading-8 text-slate-700 dark:text-slate-300">
            <span class="font-semibold text-teal-700 dark:text-teal-300">
              I didn't realize how tired I was of the big social apps until I tried Mosslet.
            </span>
            It feels… smaller, in a good way. There's no sense that I'm being watched or pushed to post for likes. I can just share little bits of my life and chat with people without all the noise.
          </p>
          <p class="mt-4 text-lg sm:text-xl leading-8 text-slate-700 dark:text-slate-300">
            My favorite part is
            <span class="font-semibold bg-gradient-to-r from-violet-500 to-purple-500 bg-clip-text text-transparent">
              Journal.
            </span>
            It's this private, encrypted space that's just for me. I use it to brain-dump, track my mood, and sometimes turn on the AI reflections when I'm curious about patterns in how I've been feeling. It feels more like a personal notebook than a “feature.”
          </p>
          <p class="mt-4 text-lg sm:text-xl leading-8 text-slate-700 dark:text-slate-300">
            Mosslet is quiet, kind of cozy, and very intentional. It's privacy-first and built by my partner, but honestly, that's not why I stay. I stay because it already feels more human than any mainstream social app I've used in years.
          </p>
        </blockquote>

        <figcaption class="mt-8 flex items-center gap-4 border-t border-slate-200/60 dark:border-slate-700/60 pt-6">
          <div
            class="relative h-14 w-14 shrink-0 rounded-full ring-2 ring-white dark:ring-slate-800 shadow-lg overflow-hidden select-none"
            oncontextmenu="return false;"
          >
            <img
              src={~p"/images/features/isabella-avatar.jpeg"}
              alt=""
              class="h-full w-full object-cover pointer-events-none"
              draggable="false"
            />
          </div>
          <div>
            <div class="font-semibold text-lg text-slate-900 dark:text-slate-100">
              @justagirl
            </div>
            <div class="text-slate-500 dark:text-slate-400">
              Isabella · Early Member
            </div>
          </div>
        </figcaption>
      </div>
    </figure>
    """
  end

  defp testimonial_card(assigns) do
    accent_colors = %{
      "teal" => %{
        gradient: "from-teal-500 to-emerald-500",
        ring: "ring-teal-200/50 dark:ring-teal-700/50",
        hover_ring: "group-hover:ring-teal-300/70 dark:group-hover:ring-teal-600/70",
        quote_bg: "from-teal-500/10 to-emerald-500/10 dark:from-teal-500/5 dark:to-emerald-500/5",
        icon_bg: "from-teal-500 to-emerald-500"
      },
      "emerald" => %{
        gradient: "from-emerald-500 to-cyan-500",
        ring: "ring-emerald-200/50 dark:ring-emerald-700/50",
        hover_ring: "group-hover:ring-emerald-300/70 dark:group-hover:ring-emerald-600/70",
        quote_bg: "from-emerald-500/10 to-cyan-500/10 dark:from-emerald-500/5 dark:to-cyan-500/5",
        icon_bg: "from-emerald-500 to-cyan-500"
      },
      "cyan" => %{
        gradient: "from-cyan-500 to-teal-500",
        ring: "ring-cyan-200/50 dark:ring-cyan-700/50",
        hover_ring: "group-hover:ring-cyan-300/70 dark:group-hover:ring-cyan-600/70",
        quote_bg: "from-cyan-500/10 to-teal-500/10 dark:from-cyan-500/5 dark:to-teal-500/5",
        icon_bg: "from-cyan-500 to-teal-500"
      },
      "violet" => %{
        gradient: "from-violet-500 to-purple-500",
        ring: "ring-violet-200/50 dark:ring-violet-700/50",
        hover_ring: "group-hover:ring-violet-300/70 dark:group-hover:ring-violet-600/70",
        quote_bg:
          "from-violet-500/10 to-purple-500/10 dark:from-violet-500/5 dark:to-purple-500/5",
        icon_bg: "from-violet-500 to-purple-500"
      },
      "purple" => %{
        gradient: "from-purple-500 to-pink-500",
        ring: "ring-purple-200/50 dark:ring-purple-700/50",
        hover_ring: "group-hover:ring-purple-300/70 dark:group-hover:ring-purple-600/70",
        quote_bg: "from-purple-500/10 to-pink-500/10 dark:from-purple-500/5 dark:to-pink-500/5",
        icon_bg: "from-purple-500 to-pink-500"
      },
      "pink" => %{
        gradient: "from-pink-500 to-rose-500",
        ring: "ring-pink-200/50 dark:ring-pink-700/50",
        hover_ring: "group-hover:ring-pink-300/70 dark:group-hover:ring-pink-600/70",
        quote_bg: "from-pink-500/10 to-rose-500/10 dark:from-pink-500/5 dark:to-rose-500/5",
        icon_bg: "from-pink-500 to-rose-500"
      }
    }

    accent = assigns.testimonial.accent || "teal"
    colors = accent_colors[accent] || accent_colors["teal"]

    assigns = assign(assigns, :colors, colors)

    ~H"""
    <figure class={[
      "group relative rounded-2xl p-6 transition-all duration-300 ease-out",
      "bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm",
      "ring-1 #{@colors.ring} #{@colors.hover_ring}",
      "shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20",
      "hover:shadow-xl hover:shadow-slate-900/10 dark:hover:shadow-emerald-900/20",
      "hover:-translate-y-1 transform-gpu"
    ]}>
      <div class={[
        "absolute inset-0 rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-300",
        "bg-gradient-to-br #{@colors.quote_bg}"
      ]}>
      </div>

      <div class="absolute -top-3 -left-2">
        <div class={[
          "flex h-8 w-8 items-center justify-center rounded-full shadow-lg",
          "bg-gradient-to-br #{@colors.icon_bg}"
        ]}>
          <svg class="h-4 w-4 text-white" fill="currentColor" viewBox="0 0 24 24">
            <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h3.983v10h-9.983z" />
          </svg>
        </div>
      </div>

      <blockquote class="relative pt-4">
        <p class="text-base leading-7 text-slate-700 dark:text-slate-300">
          "{@testimonial.quote}"
        </p>
      </blockquote>

      <figcaption class="relative mt-6 flex items-center gap-4 border-t border-slate-200/60 dark:border-slate-700/60 pt-6">
        <div class={[
          "flex h-12 w-12 shrink-0 items-center justify-center rounded-full",
          "bg-gradient-to-br #{@colors.icon_bg}",
          "ring-2 ring-white dark:ring-slate-800 shadow-md"
        ]}>
          <.phx_icon name="hero-user" class="h-6 w-6 text-white" />
        </div>
        <div>
          <div class="font-semibold text-slate-900 dark:text-slate-100">
            {@testimonial.name}
          </div>
          <div class="text-sm text-slate-500 dark:text-slate-400">
            {@testimonial.role}
          </div>
        </div>
      </figcaption>
    </figure>
    """
  end
end
