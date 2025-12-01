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
                  Pay once, own forever. No subscriptions. No recurring fees. No surprises. One simple payment gives you lifetime access to privacy and peace of mind.
                </p>

                <%!-- Decorative accent line matching support/FAQ style --%>
                <div class="mt-8 flex justify-center">
                  <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 shadow-sm shadow-emerald-500/30">
                  </div>
                </div>
              </div>
            </.liquid_container>
          </div>

          <%!-- Pricing cards section --%>
          <.liquid_container max_width="xl" class="-mt-12 sm:mt-0 xl:-mt-8">
            <div class="mx-auto max-w-lg lg:max-w-4xl">
              <div class="grid grid-cols-1 gap-8 lg:grid-cols-2">
                <%!-- Personal Plan Card --%>
                <.liquid_pricing_card
                  title="Personal"
                  price="$59"
                  period="/once"
                  badge="Lifetime"
                  save_badge="Save 40%"
                  save_tooltip="Special price while we're in beta"
                  description="Own your privacy forever with one simple payment. No subscriptions, no recurring fees – just pure digital freedom."
                  note="Affirm payment plans available."
                  note_disclosure="Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders. CA residents: Loans by Affirm Loan Services, LLC are made or arranged pursuant to a California Finance Lenders Law license."
                  cta_text="Get Lifetime Access"
                  cta_href="/auth/register"
                  cta_icon="hero-rocket-launch"
                  featured={true}
                  features={[
                    "Unlimited Connections, Groups, and Posts",
                    "Unlimited new features",
                    "Streamlined settings",
                    "Own your data",
                    "Advanced asymmetric encryption",
                    "Email support"
                  ]}
                />

                <%!-- Family Plan Card --%>
                <.liquid_pricing_card
                  title="Family"
                  price="TBA"
                  period="/once"
                  badge="Coming Soon"
                  description="Coming soon. Privacy and peace of mind for your whole family with one lifetime payment."
                  cta_text="Notify Me"
                  cta_href="mailto:support@mosslet.com?subject=Family Plan Interest"
                  disabled={false}
                  features={[
                    "Priority support",
                    "Multiple accounts",
                    "Family management tools",
                    "Shared privacy controls",
                    "All Personal features included"
                  ]}
                />
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
