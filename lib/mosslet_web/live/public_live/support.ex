defmodule MossletWeb.PublicLive.Support do
  @moduledoc false
  use MossletWeb, :live_view
  
  import MossletWeb.DesignSystem

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
      <%!-- Enhanced liquid metal background --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <main class="isolate">
          <%!-- Hero section with liquid effects --%>
          <div class="relative isolate">
            <%!-- Background pattern with liquid styling --%>
            <div class="absolute inset-0 -z-10 overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-br from-teal-50/10 via-transparent to-emerald-50/10 dark:from-teal-900/5 dark:via-transparent dark:to-emerald-900/5"></div>
              <svg
                class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-slate-200/60 dark:stroke-slate-700/60 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
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
                <rect width="100%" height="100%" stroke-width="0" fill="url(#support-pattern)" />
              </svg>
            </div>

            <%!-- Floating gradient orbs for liquid metal effect --%>
            <div class="absolute left-1/2 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48" aria-hidden="true">
              <div
                class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
              ></div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl text-center">
                  <%!-- Enhanced hero title with liquid metal styling --%>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    We're here to help
                  </h1>

                  <%!-- Enhanced subtitle --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Have a question, need help, or want to share feedback? Our small team is committed to providing personal, helpful support to every MOSSLET member.
                  </p>

                  <%!-- Decorative accent line --%>
                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30"></div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Enhanced support options section --%>
          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <div class="mt-6 grid grid-cols-1 gap-8 lg:grid-cols-2">
                <%!-- Email Support Card with liquid styling --%>
                <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out transform-gpu will-change-transform hover:scale-[1.02] hover:shadow-2xl hover:shadow-emerald-500/10">
                  <%!-- Liquid background effects --%>
                  <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100"></div>

                  <%!-- Shimmer effect --%>
                  <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"></div>

                  <%!-- Card border with liquid accent --%>
                  <div class="absolute inset-0 rounded-xl ring-1 transition-all duration-300 ease-out ring-slate-200/60 dark:ring-slate-700/60 group-hover:ring-emerald-500/30 dark:group-hover:ring-emerald-400/30"></div>

                  <%!-- Background image with overlay --%>
                  <div class="relative h-64 sm:h-48 lg:h-64">
                    <img
                      src={~p"/images/about/person_reading.jpg"}
                      alt="Support illustration"
                      class="absolute inset-0 h-full w-full object-cover rounded-t-xl"
                    />
                    <div class="absolute inset-0 bg-gradient-to-t from-slate-900/80 via-slate-900/40 to-transparent rounded-t-xl"></div>
                  </div>

                  <%!-- Content --%>
                  <div class="relative p-8">
                    <div class="mb-3">
                      <span class="inline-flex px-3 py-1.5 rounded-full text-xs font-medium tracking-wide uppercase bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-800 dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-200 border border-teal-300/60 dark:border-teal-600/60">
                        Email Support
                      </span>
                    </div>

                    <h3 class="mb-4 text-xl lg:text-2xl font-bold leading-tight text-slate-900 dark:text-slate-100 transition-all duration-200 ease-out group-hover:text-emerald-700 dark:group-hover:text-emerald-300">
                      <.link
                        href="mailto:support@mosslet.com"
                        class="relative"
                      >
                        support@mosslet.com
                        <%!-- Subtle underline effect --%>
                        <div class="absolute bottom-0 left-0 h-0.5 w-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 group-hover:w-full"></div>
                      </.link>
                    </h3>

                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                      Email us directly for personalized help. We typically respond within 24 hours, often much sooner. Our team reads every message personally.
                    </p>
                  </div>
                </div>

                <%!-- FAQ Card with liquid styling --%>
                <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out transform-gpu will-change-transform hover:scale-[1.02] hover:shadow-2xl hover:shadow-emerald-500/10">
                  <%!-- Liquid background effects --%>
                  <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100"></div>

                  <%!-- Shimmer effect --%>
                  <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"></div>

                  <%!-- Card border with liquid accent --%>
                  <div class="absolute inset-0 rounded-xl ring-1 transition-all duration-300 ease-out ring-slate-200/60 dark:ring-slate-700/60 group-hover:ring-emerald-500/30 dark:group-hover:ring-emerald-400/30"></div>

                  <%!-- Background image with overlay --%>
                  <div class="relative h-64 sm:h-48 lg:h-64">
                    <img
                      src={~p"/images/about/people_on_computer.jpg"}
                      alt="FAQ illustration"
                      class="absolute inset-0 h-full w-full object-cover rounded-t-xl"
                    />
                    <div class="absolute inset-0 bg-gradient-to-t from-slate-900/80 via-slate-900/40 to-transparent rounded-t-xl"></div>
                  </div>

                  <%!-- Content --%>
                  <div class="relative p-8">
                    <div class="mb-3">
                      <span class="inline-flex px-3 py-1.5 rounded-full text-xs font-medium tracking-wide uppercase bg-gradient-to-r from-cyan-100 to-teal-100 text-cyan-800 dark:from-cyan-900/40 dark:to-teal-900/40 dark:text-cyan-200 border border-cyan-300/60 dark:border-cyan-600/60">
                        Self-Service
                      </span>
                    </div>

                    <h3 class="mb-4 text-xl lg:text-2xl font-bold leading-tight text-slate-900 dark:text-slate-100 transition-all duration-200 ease-out group-hover:text-emerald-700 dark:group-hover:text-emerald-300">
                      <.link href={~p"/faq"} class="relative">
                        Frequently Asked Questions
                        <%!-- Subtle underline effect --%>
                        <div class="absolute bottom-0 left-0 h-0.5 w-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 group-hover:w-full"></div>
                      </.link>
                    </h3>

                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                      Find quick answers to common questions about MOSSLET, privacy, accounts, and features. Updated regularly based on user questions.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Enhanced "What we help with" section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                What we help with
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                Our support team can assist you with any aspect of using MOSSLET. Here are some common areas we help with:
              </p>
            </div>

            <%!-- Enhanced help topics grid --%>
            <dl class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 text-base/7 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Account Setup
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  Getting started with your MOSSLET account, profile setup, and initial configuration.
                </dd>
              </div>
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Privacy Settings
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  Understanding and configuring your privacy controls to match your comfort level.
                </dd>
              </div>
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Technical Issues
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  Troubleshooting any technical problems you encounter while using MOSSLET.
                </dd>
              </div>
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Feature Questions
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  How to use specific features, understanding capabilities, and making the most of MOSSLET.
                </dd>
              </div>
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Billing & Accounts
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  Questions about your subscription, billing, account management, and payment issues.
                </dd>
              </div>
              <div class="group">
                <dt class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                  Feedback & Suggestions
                </dt>
                <dd class="mt-1 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                  We love hearing your ideas for improving MOSSLET and making it work better for you.
                </dd>
              </div>
            </dl>
          </div>

          <%!-- Enhanced commitment section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-48 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our commitment to you
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                As a small, family-owned company, we take personal pride in providing excellent customer support. Here's what you can expect when you reach out to us:
              </p>

              <div class="mt-10 space-y-8">
                <div class="group">
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                    Personal attention
                  </h3>
                  <p class="mt-2 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                    Every email is read and responded to by a real person on our team - Mark or Isabella. No bots, no outsourced support centers.
                  </p>
                </div>

                <div class="group">
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                    Fast response times
                  </h3>
                  <p class="mt-2 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                    We aim to respond to all support emails within 24 hours, but often respond much faster. Most emails get a response within a few hours during business days.
                  </p>
                </div>

                <div class="group">
                  <h3 class="text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-200 ease-out group-hover:from-teal-400 group-hover:to-emerald-400">
                    Genuine care
                  </h3>
                  <p class="mt-2 text-slate-600 dark:text-slate-400 transition-colors duration-200 ease-out group-hover:text-slate-700 dark:group-hover:text-slate-300">
                    We genuinely care about your experience with MOSSLET. Your success and satisfaction are our top priorities.
                  </p>
                </div>
              </div>

              <%!-- Enhanced CTA section --%>
              <div class="relative mt-10 overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 p-8">
                <%!-- Liquid background effects --%>
                <div class="absolute inset-0 -z-10 bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10"></div>

                <h3 class="text-lg font-bold tracking-tight text-pretty bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Ready to get help?
                </h3>
                <p class="mt-2 text-slate-700 dark:text-slate-300">
                  Don't hesitate to reach out. Whether you have a simple question or need detailed assistance, we're here to help make your MOSSLET experience great.
                </p>
                <div class="mt-4 flex flex-col sm:flex-row sm:items-center gap-y-3 gap-x-4">
                  <%!-- Primary button using design system --%>
                  <.liquid_button
                    href="mailto:support@mosslet.com"
                    color="teal"
                    variant="primary"
                    size="md"
                  >
                    Email us at support@mosslet.com
                  </.liquid_button>
                  <%!-- Secondary link with proper styling --%>
                  <.link
                    href={~p"/faq"}
                    class="text-sm font-semibold leading-6 text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-300 transition-colors duration-200 ease-out text-center sm:text-left"
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
