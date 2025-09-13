defmodule MossletWeb.PublicLive.Components do
  @moduledoc false
  use MossletWeb, :component

  # Loading skeleton for news source cards (for demonstration)
  def news_card_skeleton(assigns) do
    ~H"""
    <div class="flex flex-col h-full animate-pulse">
      <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-200 dark:bg-gray-800 px-8 pb-8 pt-12 h-full min-h-[300px]">
        <!-- Category skeleton -->
        <div class="flex items-center gap-2 mb-3">
          <div class="w-5 h-5 bg-gray-300 dark:bg-gray-700 rounded"></div>
          <div class="h-4 bg-gray-300 dark:bg-gray-700 rounded w-24"></div>
        </div>

        <div class="flex-1">
          <!-- Title skeleton -->
          <div class="h-6 bg-gray-300 dark:bg-gray-700 rounded mb-3 w-3/4"></div>
          
    <!-- Description skeleton -->
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
    <div class="bg-white dark:bg-gray-950">
      <main class="isolate">
        <!-- Hero section -->
        <div class="relative isolate -z-10">
          <svg
            class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-gray-200 dark:stroke-gray-800 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
            aria-hidden="true"
          >
            <defs>
              <pattern
                id="know-pattern"
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
              fill="url(#know-pattern)"
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
                  Be in the know
                </h1>
                <h2 class="mt-6 text-balance text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
                  MOSSLET helps you reclaim the truth
                </h2>
                <p class="mt-8 text-pretty text-lg font-medium text-gray-600 dark:text-gray-400 sm:text-xl/8 text-balance">
                  The #1 product of surveillance capitalism is disinformation. You can protect yourself by choosing organizations and sources of information that are factual and on the side of people, not profit.
                </p>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Why this matters section -->
        <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
          <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
            <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-3">
              <!-- MOSSLET's Approach -->
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 px-8 py-8 border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
                <div class="flex justify-center pb-4">
                  <img class="size-16" src={~p"/images/logo.svg"} />
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    MOSSLET's Promise
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    No Algorithm, No Feed
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    You will see the Posts that your friends have shared with you, and that's it. Your friends will see any Posts that you have shared with them. Simple as that.
                  </p>
                </div>
              </div>
              
    <!-- News Problem -->
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-red-50 dark:bg-red-900/60 dark:bg-gray-800/60 px-8 py-8 border border-red-200 dark:border-red-700/30 dark:shadow-xl dark:shadow-red-500/20">
                <div class="flex justify-center pb-4">
                  <svg
                    class="size-16 text-red-500 dark:text-red-400"
                    fill="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" />
                  </svg>
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-red-600 dark:text-red-400">
                    The Problem
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    News is Not Our Business
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    When your social platform decides what is newsworthy, news quickly fades from facts to whatever suits the business. Disinformation arises.
                  </p>
                </div>
              </div>
              
    <!-- Solution -->
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-emerald-50 dark:bg-emerald-900/60 dark:bg-gray-800/60 px-8 py-8 border border-emerald-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
                <div class="flex justify-center pb-4">
                  <svg
                    class="size-16 text-emerald-500 dark:text-emerald-400"
                    fill="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div class="text-center">
                  <div class="text-sm font-bold tracking-tight text-emerald-600 dark:text-emerald-400">
                    The Solution
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-800 dark:text-white">
                    Trusted News Sources
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    We think social platforms should not be news outlets. Here are reputable, truthful sources that will empower you.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Big statement section -->
        <div class="mx-auto mt-40 mb-40 max-w-7xl px-6 sm:mt-56 sm:mb-56 lg:px-8">
          <div class="mx-auto max-w-4xl text-center">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl text-black dark:text-white">
              Big Tech controls who knows and who decides who knows.
              <span class="block mt-4 bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Don't let them control you.
              </span>
            </h2>
          </div>
        </div>
        
    <!-- News sources section -->
        <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              General News Sources
            </h2>
            <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
              Reputable organizations that prioritize truth over profit, people over algorithms.
            </p>
          </div>

          <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-2">
            <!-- Capitol Hill Citizen -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.capitolhillcitizen.com/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Independent Journalism
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    Capitol Hill Citizen
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Democracy dies in broad daylight. A real newspaper! For as little as $5, you'll receive the best newspaper we've read in years. From tireless public defenders like Ralph Nader.
                  </p>
                </div>
              </div>
            </.link>
            
    <!-- Democracy Now -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.democracynow.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Non-Profit News
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    Democracy Now!
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    A global, daily news hour. Founded in 1996, accepts no government funding, corporate sponsorship, or advertising revenue. You can trust what you hear here.
                  </p>
                </div>
              </div>
            </.link>
            
    <!-- More Perfect Union -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://perfectunion.us/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Emmy Award-Winning
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    More Perfect Union
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Building power for the working class. Advocacy journalism nonprofit reporting on corporate abuses and wrongdoing. Available in written and video format.
                  </p>
                </div>
              </div>
            </.link>
            
    <!-- ProPublica -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.propublica.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Pulitzer Prize Winner
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    ProPublica
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Investigative journalism in the public interest. From privacy to healthcare, ProPublica investigates issues that matter to all of us — no matter who you are or what you believe.
                  </p>
                </div>
              </div>
            </.link>
          </div>
          
    <!-- Public Citizen -->
          <div class="mx-auto mt-8 max-w-2xl lg:max-w-none">
            <div class="flex flex-col lg:flex-row lg:items-center gap-8">
              <.link
                target="_blank"
                rel="noopener noreferer"
                href="https://www.citizen.org/"
                class="flex-1 group cursor-pointer"
              >
                <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[200px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                  <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                  </div>
                  <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                  </div>
                  
    <!-- Category -->
                  <div class="mb-3">
                    <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                      Consumer Advocacy
                    </span>
                  </div>

                  <div class="flex-1">
                    <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                      Public Citizen
                    </h3>
                    <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                      The people's advocate. Represents the people in the face of power regardless of your political affiliation. Find current events and resources for taking action.
                    </p>
                  </div>
                </div>
              </.link>
            </div>
          </div>
        </div>
        
    <!-- Privacy & Technology section -->
        <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Privacy & Technology News
            </h2>
            <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
              Trusted sources for understanding how technology shapes our world.
            </p>
          </div>

          <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-3">
            <!-- 404 Media -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.404media.co/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Journalist-Funded
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    404 Media
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Unparalleled access to hidden worlds both online and IRL. Investigating the hidden worlds of technology, surveillance, and the internet.
                  </p>
                </div>
              </div>
            </.link>
            
    <!-- EFF -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://www.eff.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Since 1990
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    Electronic Frontier Foundation
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Defending digital privacy, free speech, and innovation. Leading advocate for the public, providing news, guides and tools to protect you online.
                  </p>
                </div>
              </div>
            </.link>
            
    <!-- The Markup -->
            <.link
              target="_blank"
              rel="noopener noreferer"
              href="https://themarkup.org/"
              class="flex flex-col h-full group cursor-pointer"
            >
              <div class="relative isolate flex flex-col justify-between overflow-hidden rounded-2xl bg-gray-50 dark:bg-gray-800/60 px-8 pb-8 pt-12 h-full min-h-[300px] border border-gray-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20 transition-all duration-300 ease-out group-hover:scale-105 group-hover:shadow-2xl group-hover:shadow-emerald-500/30 dark:group-hover:shadow-emerald-500/40">
                <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-50 dark:from-gray-900 via-gray-100/40 dark:via-gray-900/40">
                </div>
                <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-200/20 dark:ring-gray-900/10">
                </div>
                
    <!-- Category -->
                <div class="mb-3">
                  <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Transparent Methods
                  </span>
                </div>

                <div class="flex-1">
                  <h3 class="text-lg font-semibold leading-6 text-gray-800 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-300 transition-colors">
                    The Markup
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-600 dark:text-gray-300">
                    Challenging technology to serve the public good. Non-profit investigative journalism with real world impact. They share their methods and datasets publicly.
                  </p>
                </div>
              </div>
            </.link>
          </div>
        </div>
        
    <!-- Call to action section -->
        <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-48 lg:px-8">
          <div class="mx-auto max-w-2xl text-center">
            <div class="p-8 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-3xl border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
              <h3 class="text-2xl font-bold tracking-tight text-pretty bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent sm:text-3xl">
                Break free from Big Tech's control
              </h3>
              <p class="mt-4 text-lg text-gray-700 dark:text-gray-300">
                Once we break free from Big Tech's disinformation silos, we can start fixing problems and making progress again. MOSSLET is here to help you do that.
              </p>
              <div class="mt-8 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-4">
                <.link
                  href="/auth/register"
                  class="inline-flex items-center justify-center rounded-full py-3 px-8 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
                >
                  Join MOSSLET today
                </.link>
                <.link
                  href="/features"
                  class="text-sm font-semibold leading-6 text-teal-600 hover:text-teal-500 transition-colors"
                >
                  Learn about our features <span aria-hidden="true">→</span>
                </.link>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
