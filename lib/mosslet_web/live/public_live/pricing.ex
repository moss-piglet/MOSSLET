defmodule MossletWeb.PublicLive.Pricing do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:pricing}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <div class="bg-white dark:bg-slate-950">
        <div class="isolate">
          <%!-- Hero section with liquid metal background --%>
          <div class="relative isolate -z-10">
            <%!-- Liquid metal background gradient --%>
            <div
              class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
              aria-hidden="true"
            >
              <div
                class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-300/40 to-cyan-400/30 opacity-40 dark:opacity-20"
                style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
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

            <.liquid_container max_width="xl" class="pb-32 pt-36 sm:pt-60 lg:pt-32">
              <div class="mx-auto max-w-2xl text-center">
                <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                  Simple, pay once pricing
                </h1>

                <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                  Say goodbye to never-ending subscription fees. One simple payment gives you lifetime access—no hidden costs, no surprises.
                </p>

                <%!-- Decorative accent line matching support/FAQ style --%>
                <div class="mt-8 flex justify-center">
                  <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 shadow-sm shadow-emerald-500/30">
                  </div>
                </div>
              </div>
            </.liquid_container>
          </div>

          <%!-- Pricing card section --%>
          <.liquid_container max_width="xl" class="-mt-12 sm:mt-0 xl:-mt-8">
            <div class="mx-auto max-w-lg">
              <.liquid_card padding="lg" class="overflow-hidden">
                <div class="flex items-center justify-between gap-4 mb-6">
                  <div>
                    <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                      Personal
                    </h2>
                    <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                      Lifetime access
                    </p>
                  </div>
                  <div
                    id="pricing-beta-badge"
                    phx-hook="TippyHook"
                    data-tippy-content="Special price while we're in beta"
                    class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gradient-to-r from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30 border border-amber-200/50 dark:border-amber-700/30"
                  >
                    <.phx_icon name="hero-fire" class="w-4 h-4 text-amber-600 dark:text-amber-400" />
                    <span class="text-sm font-semibold text-amber-700 dark:text-amber-300">
                      Save 40%
                    </span>
                  </div>
                </div>

                <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-8">
                  Own your privacy forever with one simple payment. No subscriptions, no recurring fees – just pure digital freedom.
                </p>

                <div class="flex items-baseline gap-2 mb-8">
                  <span class="text-5xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
                    $59
                  </span>
                  <span class="text-lg text-slate-500 dark:text-slate-400">/ once</span>
                </div>

                <.liquid_button
                  href="/auth/register"
                  size="lg"
                  class="w-full justify-center mb-8"
                  color="teal"
                  variant="primary"
                  icon="hero-rocket-launch"
                >
                  Get Lifetime Access
                </.liquid_button>

                <div class="pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
                  <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-4 flex items-center gap-2">
                    <.phx_icon name="hero-check-badge" class="w-4 h-4 text-emerald-500" />
                    Everything included
                  </h3>
                  <ul class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Unlimited Connections, Circles, and Posts
                      </span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Unlimited new features
                      </span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Streamlined settings
                      </span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Own your data
                      </span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Advanced asymmetric encryption
                      </span>
                    </li>
                    <li class="flex items-start gap-2">
                      <.phx_icon
                        name="hero-check"
                        class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                      />
                      <span class="text-sm text-slate-600 dark:text-slate-400">
                        Email support
                      </span>
                    </li>
                  </ul>
                </div>

                <div class="mt-6 p-4 rounded-xl bg-gradient-to-r from-blue-50/50 to-cyan-50/50 dark:from-blue-900/10 dark:to-cyan-900/10 border border-blue-200/30 dark:border-blue-700/20">
                  <div class="flex items-center gap-3">
                    <div class="flex items-center justify-center w-10 h-10 rounded-full bg-blue-100 dark:bg-blue-900/40">
                      <.phx_icon
                        name="hero-credit-card"
                        class="w-5 h-5 text-blue-600 dark:text-blue-400"
                      />
                    </div>
                    <div
                      id="affirm-disclosure"
                      phx-hook="TippyHook"
                      data-tippy-content="Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders. CA residents: Loans by Affirm Loan Services, LLC are made or arranged pursuant to a California Finance Lenders Law license."
                      class="cursor-help flex-1"
                    >
                      <div class="text-sm font-medium text-blue-800 dark:text-blue-200">
                        Flexible payments available
                      </div>
                      <div class="text-sm text-blue-700 dark:text-blue-300">
                        Split into monthly payments with Affirm
                      </div>
                    </div>
                    <.phx_icon
                      name="hero-information-circle"
                      class="w-5 h-5 text-blue-400 dark:text-blue-500 flex-shrink-0"
                    />
                  </div>
                </div>
              </.liquid_card>

              <div class="mt-8 text-center">
                <p class="text-sm text-slate-500 dark:text-slate-400 flex items-center justify-center gap-2">
                  <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
                  Secure payment powered by Stripe
                </p>
              </div>
            </div>
          </.liquid_container>

          <%!-- Comparison section --%>
          <.liquid_container max_width="xl" class="mt-32 sm:mt-40">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl text-slate-900 dark:text-white">
                <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  $700+ per year
                </span>
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400 max-w-3xl mx-auto">
                That's how much your personal data was worth more than 3 years ago. And it's only going up. This means you are paying more than $700 per year to share a photo on Instagram or Facebook, search on Google, watch a video on YouTube, or dance on TikTok.
              </p>
            </div>

            <.liquid_comparison_table />
          </.liquid_container>

          <%!-- Call to action section with liquid metal design --%>
          <.liquid_container max_width="xl" class="mt-32 sm:mt-48">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="text-center bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15 border-teal-200/60 dark:border-emerald-700/30"
              >
                <:title>
                  <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Own your digital life
                  </span>
                </:title>
                <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                  Join thousands who've chosen privacy over profit. One payment, lifetime protection. No subscriptions, no recurring fees, no surprises.
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
                    navigate="/features"
                    variant="secondary"
                    color="blue"
                    icon="hero-sparkles"
                    size="lg"
                    class="group/btn"
                  >
                    Explore All Features
                  </.liquid_button>
                </div>

                <%!-- Trust indicator --%>
                <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    30-day money-back guarantee • Human support team • No hidden fees
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
     |> assign(:page_title, "Pricing")
     |> assign_new(:meta_description, fn ->
       "Simple, pay-once pricing. Say goodbye to never-ending subscription fees. Pay once and forget about it. With one, simple payment you get access to our service forever. No hidden fees, no subscriptions, no surprises. We also support lowering your upfront payment with Affirm."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/pricing/pricing_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Pay once, own forever. No subscriptions. No recurring fees. No surprises."
     )}
  end
end
