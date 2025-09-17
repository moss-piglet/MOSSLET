defmodule MossletWeb.PublicLive.Components do
  @moduledoc false
  use MossletWeb, :component

  # Loading skeleton for news source cards (for demonstration)
  def news_card_skeleton(assigns) do
    ~H"""
    <div class="flex flex-col h-full animate-pulse">
      <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-200 dark:bg-gray-800 px-8 pb-8 pt-12 h-full min-h-[300px]">
        <%!-- Category skeleton --%>
        <div class="flex items-center gap-2 mb-3">
          <div class="w-5 h-5 bg-gray-300 dark:bg-gray-700 rounded"></div>
          <div class="h-4 bg-gray-300 dark:bg-gray-700 rounded w-24"></div>
        </div>

        <div class="flex-1">
          <%!-- Title skeleton --%>
          <div class="h-6 bg-gray-300 dark:bg-gray-700 rounded mb-3 w-3/4"></div>

          <%!-- Description skeleton --%>
          <div class="space-y-2">
            <div class="h-3 bg-gray-300 dark:bg-gray-700 rounded"></div>
            <div class="h-3 bg-gray-300 dark:bg-gray-700 rounded w-5/6"></div>
            <div class="h-3 bg-gray-300 dark:bg-gray-700 rounded w-4/6"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def in_the_know(assigns) do
    ~H"""
    <div class="bg-white dark:bg-slate-950">
      <main class="isolate">
        <%!-- Hero section with liquid metal background --%>
        <div class="relative isolate -z-10">
          <%!-- Liquid metal background gradient --%>
          <div
            class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
            aria-hidden="true"
          >
            <div
              class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-300/40 to-cyan-400/30 opacity-40 dark:opacity-20"
              style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
            >
            </div>
          </div>

          <%!-- Additional liquid background effect --%>
          <div
            class="absolute right-1/2 left-0 top-0 -z-10 ml-24 transform-gpu overflow-hidden blur-3xl lg:-ml-24 xl:-ml-48"
            aria-hidden="true"
          >
            <div
              class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tl from-cyan-400/20 via-teal-300/30 to-emerald-400/25 opacity-30 dark:opacity-15"
              style="clip-path: polygon(36.9% 70.5%, 0% 82.9%, 23.4% 97%, 51.6% 100%, 55.4% 95.3%, 45.5% 74.7%, 40.2% 51%, 44.8% 42.2%, 55.6% 42.8%, 72.2% 52.1%, 64.9% 18.5%, 100% 2.3%, 60.8% 0%, 64.8% 18.6%, 2.8% 47.2%, 36.9% 70.5%)"
            >
            </div>
          </div>

          <MossletWeb.DesignSystem.liquid_container
            max_width="xl"
            class="pb-32 pt-36 sm:pt-60 lg:pt-32"
          >
            <div class="mx-auto max-w-2xl text-center">
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                Be in the know
              </h1>
              <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                MOSSLET helps you reclaim the truth. The #1 product of surveillance capitalism is disinformation. You can protect yourself by choosing organizations and sources of information that are factual and on the side of people, not profit.
              </p>

              <%!-- Decorative accent line matching other pages --%>
              <div class="mt-8 flex justify-center">
                <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 shadow-sm shadow-emerald-500/30">
                </div>
              </div>
            </div>
          </MossletWeb.DesignSystem.liquid_container>
        </div>

        <%!-- Why this matters section --%>
        <MossletWeb.DesignSystem.liquid_container max_width="xl" class="-mt-12 sm:mt-0 xl:-mt-8">
          <div class="mx-auto max-w-4xl">
            <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-3">
              <%!-- MOSSLET's Approach --%>
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out border-teal-200/60 dark:border-teal-700/30 bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-white dark:bg-slate-800 shadow-lg border border-slate-200 dark:border-slate-700">
                      <img class="size-8" src={~p"/images/logo.svg"} alt="MOSSLET logo" />
                    </div>
                    <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                      MOSSLET's Promise
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white mb-3">
                  No Algorithm, No Feed
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  You will see the Posts that your friends have shared with you, and that's it. Your friends will see any Posts that you have shared with them. Simple as that.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- News Problem --%>
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out border-rose-200/60 dark:border-rose-700/30 bg-gradient-to-br from-rose-50/40 via-pink-50/30 to-red-50/40 dark:from-rose-900/15 dark:via-pink-900/10 dark:to-red-900/15"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-rose-500 to-pink-500 shadow-lg">
                      <svg class="size-8 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent font-semibold">
                      The Problem
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white mb-3">
                  News is Not Our Business
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  When your social platform decides what is newsworthy, news quickly fades from facts to whatever suits the business. Disinformation arises.
                </p>
              </MossletWeb.DesignSystem.liquid_card>

              <%!-- Solution --%>
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="group hover:scale-105 transition-all duration-300 ease-out border-emerald-200/60 dark:border-emerald-700/30 bg-gradient-to-br from-emerald-50/40 via-cyan-50/30 to-teal-50/40 dark:from-emerald-900/15 dark:via-cyan-900/10 dark:to-teal-900/15"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 shadow-lg">
                      <svg
                        class="size-8 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-emerald-500 to-cyan-500 bg-clip-text text-transparent font-semibold">
                      The Solution
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white mb-3">
                  Trusted News Sources
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We think social platforms should not be news outlets. Here are reputable, truthful sources that will empower you.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </div>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- Big statement section --%>
        <MossletWeb.DesignSystem.liquid_container max_width="xl" class="mt-40 mb-40 sm:mt-56 sm:mb-56">
          <div class="mx-auto max-w-4xl text-center">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl text-slate-900 dark:text-white">
              Big Tech controls who knows and who decides who knows.
              <span class="block mt-4 bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Don't let them control you.
              </span>
            </h2>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- News sources section --%>
        <MossletWeb.DesignSystem.liquid_container max_width="xl" class="mt-32 sm:mt-40">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              General News Sources
            </h2>
            <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
              Reputable organizations that prioritize truth over profit, people over algorithms.
            </p>
          </div>

          <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-2">
            <%!-- Capitol Hill Citizen --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.capitolhillcitizen.com/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                      Independent Journalism
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors mb-3">
                  Capitol Hill Citizen
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Democracy dies in broad daylight. A real newspaper! For as little as $5, you'll receive the best newspaper we've read in years. From tireless public defenders like Ralph Nader.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>

            <%!-- Democracy Now --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.democracynow.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-blue-500 to-cyan-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-semibold">
                      Non-Profit News
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-300 transition-colors mb-3">
                  Democracy Now!
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  A global, daily news hour. Founded in 1996, accepts no government funding, corporate sponsorship, or advertising revenue. You can trust what you hear here.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>

            <%!-- More Perfect Union --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://perfectunion.us/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-violet-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-semibold">
                      Emmy Award-Winning
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-purple-600 dark:group-hover:text-purple-300 transition-colors mb-3">
                  More Perfect Union
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Building power for the working class. Advocacy journalism nonprofit reporting on corporate abuses and wrongdoing. Available in video format on your favorite surveillance network (TikTok, YouTube, Instagram, et al).
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>

            <%!-- ProPublica --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.propublica.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-amber-500 to-orange-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-semibold">
                      Pulitzer Prize Winner
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-amber-600 dark:group-hover:text-amber-300 transition-colors mb-3">
                  ProPublica
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Investigative journalism in the public interest. From privacy to healthcare, ProPublica investigates issues that matter to all of us — no matter who you are or what you believe.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>
          </div>

          <%!-- Public Citizen --%>
          <div class="mx-auto mt-8 max-w-2xl lg:max-w-none">
            <div class="flex flex-col lg:flex-row lg:items-center gap-8">
              <.link
                target="_blank"
                rel="noopener noreferer"
                href="https://www.citizen.org/"
                class="flex-1 group cursor-pointer"
              >
                <MossletWeb.DesignSystem.liquid_card
                  padding="md"
                  class="h-full min-h-[150px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
                >
                  <:title>
                    <div class="flex items-center gap-3">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-emerald-500 to-teal-500">
                        <svg
                          class="size-6 text-white"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"
                          />
                        </svg>
                      </div>
                      <span class="bg-gradient-to-r from-emerald-500 to-teal-500 bg-clip-text text-transparent font-semibold">
                        Consumer Advocacy
                      </span>
                    </div>
                  </:title>
                  <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-emerald-600 dark:group-hover:text-emerald-300 transition-colors mb-3">
                    Public Citizen
                  </h3>
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    The people's advocate. Represents the people in the face of power regardless of your political affiliation. Find current events and resources for taking action.
                  </p>
                </MossletWeb.DesignSystem.liquid_card>
              </.link>
            </div>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- Privacy & Technology section --%>
        <MossletWeb.DesignSystem.liquid_container max_width="xl" class="mt-32 sm:mt-40">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Privacy & Technology News
            </h2>
            <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
              Trusted sources for understanding how technology shapes our world.
            </p>
          </div>

          <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-3">
            <%!-- 404 Media --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.404media.co/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-cyan-500 to-teal-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent font-semibold">
                      Journalist-Funded
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-cyan-600 dark:group-hover:text-cyan-300 transition-colors mb-3">
                  404 Media
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Unparalleled access to hidden worlds both online and IRL. Investigating the hidden worlds of technology, surveillance, and the internet.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>

            <%!-- EFF --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.eff.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-indigo-500 to-blue-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent font-semibold">
                      Since 1990
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-indigo-600 dark:group-hover:text-indigo-300 transition-colors mb-3">
                  Electronic Frontier Foundation
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Defending digital privacy, free speech, and innovation. Leading advocate for the public, providing news, guides and tools to protect you online.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>

            <%!-- The Markup --%>
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://themarkup.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <MossletWeb.DesignSystem.liquid_card
                padding="md"
                class="h-full min-h-[200px] group-hover:scale-105 transition-all duration-300 ease-out hover:shadow-2xl hover:shadow-emerald-500/20 dark:hover:shadow-emerald-500/30"
              >
                <:title>
                  <div class="flex items-center gap-3">
                    <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-rose-500 to-pink-500">
                      <svg
                        class="size-6 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                        />
                      </svg>
                    </div>
                    <span class="bg-gradient-to-r from-rose-500 to-pink-500 bg-clip-text text-transparent font-semibold">
                      Transparent Methods
                    </span>
                  </div>
                </:title>
                <h3 class="text-lg font-semibold leading-6 text-slate-800 dark:text-white group-hover:text-rose-600 dark:group-hover:text-rose-300 transition-colors mb-3">
                  The Markup
                </h3>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Challenging technology to serve the public good. Non-profit investigative journalism with real world impact. They share their methods and datasets publicly.
                </p>
              </MossletWeb.DesignSystem.liquid_card>
            </.link>
          </div>
        </MossletWeb.DesignSystem.liquid_container>

        <%!-- Call to action section matching pricing page style --%>
        <MossletWeb.DesignSystem.liquid_container max_width="xl" class="mt-32 sm:mt-48">
          <div class="mx-auto max-w-4xl">
            <MossletWeb.DesignSystem.liquid_card
              padding="lg"
              class="text-center bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15 border-teal-200/60 dark:border-emerald-700/30"
            >
              <:title>
                <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Break free from Big Tech's control
                </span>
              </:title>
              <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                Once we break free from Big Tech's disinformation silos, we can start fixing problems and making progress again. MOSSLET is here to help you do that.
              </p>

              <%!-- Action buttons with enhanced spacing and layout --%>
              <div class="mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-6">
                <MossletWeb.DesignSystem.liquid_button
                  navigate="/auth/register"
                  size="lg"
                  icon="hero-rocket-launch"
                  color="teal"
                  variant="primary"
                  class="group/btn"
                >
                  Get Started Today
                </MossletWeb.DesignSystem.liquid_button>
                <MossletWeb.DesignSystem.liquid_button
                  navigate="/features"
                  variant="secondary"
                  color="blue"
                  icon="hero-sparkles"
                  size="lg"
                  class="group/btn"
                >
                  Explore All Features
                </MossletWeb.DesignSystem.liquid_button>
              </div>

              <%!-- Trust indicator --%>
              <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                <p class="text-sm text-slate-600 dark:text-slate-400">
                  Privacy-first social network • Human support team • No algorithms
                </p>
              </div>
            </MossletWeb.DesignSystem.liquid_card>
          </div>
        </MossletWeb.DesignSystem.liquid_container>
      </main>

      <%!-- Spacer for proper footer separation --%>
      <div class="pb-24"></div>
    </div>
    """
  end
end
