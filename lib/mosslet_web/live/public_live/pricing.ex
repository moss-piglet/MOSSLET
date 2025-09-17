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
              <div class="mx-auto max-w-4xl text-center">
                <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl">
                  Simple,
                  <span class="italic underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    pay once
                  </span>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    pricing
                  </span>
                </h1>
                <h2 class="mt-6 text-balance text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl text-slate-900 dark:text-white">
                  Pay once, own forever.
                </h2>
                <p class="mt-8 text-pretty text-lg font-medium text-slate-600 dark:text-slate-400 sm:text-xl/8 text-balance max-w-2xl mx-auto">
                  No subscriptions. No recurring fees. No surprises. One simple payment gives you lifetime access to privacy and peace of mind.
                </p>
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
                  disabled={true}
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

          <%!-- Call to action section --%>
          <.liquid_container max_width="xl" class="mt-32 sm:mt-48">
            <div class="mx-auto max-w-2xl text-center">
              <.liquid_card class="p-8 bg-gradient-to-br from-teal-50/60 via-emerald-50/40 to-cyan-50/50 dark:from-teal-900/20 dark:via-emerald-900/15 dark:to-cyan-900/20 border-teal-200 dark:border-emerald-700/30">
                <h3 class="text-2xl font-bold tracking-tight text-pretty bg-gradient-to-r from-teal-600 to-emerald-600 bg-clip-text text-transparent sm:text-3xl">
                  Own your digital life
                </h3>
                <p class="mt-4 text-lg text-slate-700 dark:text-slate-300">
                  Join thousands who've chosen privacy over profit. One payment, lifetime protection.
                </p>
                <div class="mt-8 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-4">
                  <.liquid_button navigate="/auth/register" size="lg" icon="hero-rocket-launch">
                    Get Started
                  </.liquid_button>
                  <.liquid_button
                    navigate="/features"
                    variant="secondary"
                    color="blue"
                    icon="hero-sparkles"
                  >
                    Explore features
                  </.liquid_button>
                </div>
              </.liquid_card>
            </div>
          </.liquid_container>
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
     |> assign(:page_title, "Pricing")
     |> assign_new(:meta_description, fn ->
       "Simple, pay-once pricing. Say goodbye to never-ending subscription fees. Pay once and forget about it. With one, simple payment you get access to our service forever. No hidden fees, no subscriptions, no surprises. We also support lowering your upfront payment with Affirm."
     end)}
  end
end
