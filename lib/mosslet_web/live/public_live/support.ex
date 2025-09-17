defmodule MossletWeb.PublicLive.Support do
  @moduledoc false
  use MossletWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:support}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
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
                  id="support-pattern"
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
                fill="url(#support-pattern)"
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
                <div class="mx-auto max-w-2xl text-center">
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    We're here to help
                  </h1>
                  <p class="mt-8 text-pretty text-lg font-medium text-gray-600 dark:text-gray-400 sm:text-xl/8">
                    Have a question, need help, or want to share feedback? Our small team is committed to providing personal, helpful support to every MOSSLET member.
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Support options section -->
          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-2">
                <!-- Email Support -->
                <div class="relative isolate flex flex-col justify-end overflow-hidden rounded-2xl bg-gray-900 px-8 pb-8 pt-80 sm:pt-48 lg:pt-80">
                  <img
                    src={~p"/images/about/person_reading.jpg"}
                    alt="Support illustration"
                    class="absolute inset-0 -z-10 h-full w-full object-cover"
                  />
                  <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-900 via-gray-900/40">
                  </div>
                  <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-900/10">
                  </div>

                  <div class="flex flex-wrap items-center gap-y-1 overflow-hidden text-sm leading-6 text-gray-300">
                    <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-300 to-emerald-300 bg-clip-text text-transparent">
                      Email Support
                    </span>
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-white">
                    <.link
                      href="mailto:support@mosslet.com"
                      class="hover:text-teal-300 transition-colors"
                    >
                      <span class="absolute inset-0"></span> support@mosslet.com
                    </.link>
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-300">
                    Email us directly for personalized help. We typically respond within 24 hours, often much sooner. Our team reads every message personally.
                  </p>
                </div>
                
    <!-- FAQ -->
                <div class="relative isolate flex flex-col justify-end overflow-hidden rounded-2xl bg-gray-900 px-8 pb-8 pt-80 sm:pt-48 lg:pt-80">
                  <img
                    src={~p"/images/about/people_on_computer.jpg"}
                    alt="FAQ illustration"
                    class="absolute inset-0 -z-10 h-full w-full object-cover"
                  />
                  <div class="absolute inset-0 -z-10 bg-gradient-to-t from-gray-900 via-gray-900/40">
                  </div>
                  <div class="absolute inset-0 -z-10 rounded-2xl ring-1 ring-inset ring-gray-900/10">
                  </div>

                  <div class="flex flex-wrap items-center gap-y-1 overflow-hidden text-sm leading-6 text-gray-300">
                    <span class="text-sm font-bold tracking-tight bg-gradient-to-r from-teal-300 to-emerald-300 bg-clip-text text-transparent">
                      Self-Service
                    </span>
                  </div>
                  <h3 class="mt-3 text-lg font-semibold leading-6 text-white">
                    <.link href={~p"/faq"} class="hover:text-teal-300 transition-colors">
                      <span class="absolute inset-0"></span> Frequently Asked Questions
                    </.link>
                  </h3>
                  <p class="mt-3 text-sm leading-6 text-gray-300">
                    Find quick answers to common questions about MOSSLET, privacy, accounts, and features. Updated regularly based on user questions.
                  </p>
                </div>
              </div>
            </div>
          </div>
          
    <!-- What we help with section -->
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                What we help with
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                Our support team can assist you with any aspect of using MOSSLET. Here are some common areas we help with:
              </p>
            </div>
            <dl class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 text-base/7 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Account Setup
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  Getting started with your MOSSLET account, profile setup, and initial configuration.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Privacy Settings
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  Understanding and configuring your privacy controls to match your comfort level.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Technical Issues
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  Troubleshooting any technical problems you encounter while using MOSSLET.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Feature Questions
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  How to use specific features, understanding capabilities, and making the most of MOSSLET.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Billing & Accounts
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  Questions about your subscription, billing, account management, and payment issues.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Feedback & Suggestions
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We love hearing your ideas for improving MOSSLET and making it work better for you.
                </dd>
              </div>
            </dl>
          </div>
          
    <!-- Our commitment section -->
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-48 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our commitment to you
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                As a small, family-owned company, we take personal pride in providing excellent customer support. Here's what you can expect when you reach out to us:
              </p>

              <div class="mt-10 space-y-8">
                <div>
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Personal attention
                  </h3>
                  <p class="mt-2 text-gray-600 dark:text-gray-400">
                    Every email is read and responded to by a real person on our team - Mark or Isabella. No bots, no outsourced support centers.
                  </p>
                </div>

                <div>
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Fast response times
                  </h3>
                  <p class="mt-2 text-gray-600 dark:text-gray-400">
                    We aim to respond to all support emails within 24 hours, but often respond much faster. Most emails get a response within a few hours during business days.
                  </p>
                </div>

                <div>
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Genuine care
                  </h3>
                  <p class="mt-2 text-gray-600 dark:text-gray-400">
                    We genuinely care about your experience with MOSSLET. Your success and satisfaction are our top priorities.
                  </p>
                </div>
              </div>

              <div class="mt-10 p-6 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-2xl border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
                <h3 class="text-lg font-bold tracking-tight text-pretty bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent">
                  Ready to get help?
                </h3>
                <p class="mt-2 text-gray-700 dark:text-gray-300">
                  Don't hesitate to reach out. Whether you have a simple question or need detailed assistance, we're here to help make your MOSSLET experience great.
                </p>
                <div class="mt-4 flex flex-col sm:flex-row sm:items-center gap-y-3 gap-x-4">
                  <.link
                    href="mailto:support@mosslet.com"
                    class="inline-flex items-center justify-center rounded-full py-3 px-4 sm:px-6 text-center text-sm font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg transform hover:scale-105 transition-all duration-200"
                  >
                    Email us at support@mosslet.com
                  </.link>
                  <.link
                    href={~p"/faq"}
                    class="text-sm font-semibold leading-6 text-teal-600 hover:text-teal-500 transition-colors text-center sm:text-left"
                  >
                    Or check our FAQ <span aria-hidden="true">→</span>
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Support")
     |> assign_new(:meta_description, fn ->
       "Get help with MOSSLET. Contact our support team at support@mosslet.com for personalized assistance with your privacy-first social network. We're here to help with account setup, privacy settings, technical issues, and more."
     end)}
  end
end
