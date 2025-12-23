defmodule MossletWeb.PublicLive.Referrals do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.Referrals
  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:referrals}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <div class="relative isolate">
            <div
              class="absolute inset-0 -z-10 overflow-hidden"
              aria-hidden="true"
            >
              <div class="absolute left-1/2 top-0 -translate-x-1/2 lg:translate-x-6 xl:translate-x-12 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-emerald-400/30 via-teal-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-16 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-3xl text-center">
                  <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/30 dark:to-orange-900/30 border border-amber-200/50 dark:border-amber-700/30 mb-6">
                    <.phx_icon
                      name="hero-sparkles"
                      class="w-4 h-4 text-amber-600 dark:text-amber-400"
                    />
                    <span class="text-sm font-medium text-amber-700 dark:text-amber-300">
                      Beta Bonus: Enhanced rates for early supporters!
                    </span>
                  </div>

                  <h1 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl">
                    <span class="bg-gradient-to-r from-slate-800 to-slate-700 dark:from-slate-100 dark:to-slate-200 bg-clip-text text-transparent">
                      When's the last time
                    </span>
                    <br />
                    <span class="bg-gradient-to-r from-emerald-500 via-teal-500 to-emerald-500 dark:from-emerald-400 dark:via-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
                      your social network paid you?
                    </span>
                  </h1>

                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Big tech profits billions from your data. At MOSSLET, we flip the script — share with friends and family, and get paid when they join. All while keeping your privacy intact.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
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
                      Start Earning Today
                    </.liquid_button>
                    <.liquid_button
                      navigate="/features"
                      color="blue"
                      variant="secondary"
                      icon="hero-sparkles"
                      size="lg"
                    >
                      See All Features
                    </.liquid_button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <.liquid_container max_width="xl" class="pb-24">
            <div class="text-center mb-16">
              <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-emerald-500 to-teal-500 bg-clip-text text-transparent">
                How it works
              </h2>
              <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                Three simple steps to start earning while helping friends discover private, meaningful social sharing.
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-20">
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out text-center"
              >
                <:title>
                  <div class="flex flex-col items-center gap-4">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/30 dark:to-teal-900/30 text-emerald-600 dark:text-emerald-400 font-bold text-2xl shadow-lg shadow-emerald-500/20">
                      1
                    </div>
                    <span class="text-lg font-bold text-slate-900 dark:text-slate-100">
                      Share Your Link
                    </span>
                  </div>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Get your unique referral link from your dashboard and share it with friends, family, or your audience.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out text-center"
              >
                <:title>
                  <div class="flex flex-col items-center gap-4">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30 text-amber-600 dark:text-amber-400 font-bold text-2xl shadow-lg shadow-amber-500/20">
                      2
                    </div>
                    <span class="text-lg font-bold text-slate-900 dark:text-slate-100">
                      They Save {@discount}%
                    </span>
                  </div>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Your friends get {@discount}% off their first payment when they sign up using your link. A win for everyone.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out text-center"
              >
                <:title>
                  <div class="flex flex-col items-center gap-4">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-purple-100 to-violet-100 dark:from-purple-900/30 dark:to-violet-900/30 text-purple-600 dark:text-purple-400 font-bold text-2xl shadow-lg shadow-purple-500/20">
                      3
                    </div>
                    <span class="text-lg font-bold text-slate-900 dark:text-slate-100">
                      You Earn Cash
                    </span>
                  </div>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  Earn {@subscription_commission}% on subscriptions (recurring!) and {@one_time_commission}% on lifetime purchases. Real money, not points.
                </p>
              </.liquid_card>
            </div>

            <div class="text-center mb-16">
              <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent">
                Beta rates — limited time
              </h2>
              <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                Early supporters get significantly higher commission rates. Lock in these rates by joining during beta.
              </p>
            </div>

            <div class="max-w-4xl mx-auto mb-20">
              <.liquid_card
                padding="lg"
                class="bg-gradient-to-br from-amber-50/60 via-orange-50/40 to-yellow-50/60 dark:from-amber-900/20 dark:via-orange-900/15 dark:to-yellow-900/20 border-amber-200/60 dark:border-amber-700/30"
              >
                <div class="flex items-center justify-center gap-2 mb-8">
                  <.phx_icon name="hero-sparkles" class="h-5 w-5 text-amber-600 dark:text-amber-400" />
                  <span class="text-sm font-semibold text-amber-700 dark:text-amber-300">
                    Beta Bonus Active
                  </span>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                  <div class="text-center">
                    <p class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">
                      Subscription Commission
                    </p>
                    <div class="flex items-center justify-center gap-3">
                      <span class="text-2xl text-slate-400 line-through">
                        {@prod_subscription_commission}%
                      </span>
                      <span class="text-4xl font-bold bg-gradient-to-r from-emerald-600 to-teal-600 dark:from-emerald-400 dark:to-teal-400 bg-clip-text text-transparent">
                        {@subscription_commission}%
                      </span>
                    </div>
                    <p class="mt-1 text-xs text-emerald-600 dark:text-emerald-400 font-medium">
                      Recurring on every payment
                    </p>
                  </div>

                  <div class="text-center">
                    <p class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">
                      Lifetime Purchase Commission
                    </p>
                    <div class="flex items-center justify-center gap-3">
                      <span class="text-2xl text-slate-400 line-through">
                        {@prod_one_time_commission}%
                      </span>
                      <span class="text-4xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 dark:from-amber-400 dark:to-orange-400 bg-clip-text text-transparent">
                        {@one_time_commission}%
                      </span>
                    </div>
                    <p class="mt-1 text-xs text-amber-600 dark:text-amber-400 font-medium">
                      One-time payout
                    </p>
                  </div>

                  <div class="text-center">
                    <p class="text-sm font-medium text-slate-500 dark:text-slate-400 mb-2">
                      Friend's Discount
                    </p>
                    <div class="flex items-center justify-center">
                      <span class="text-4xl font-bold bg-gradient-to-r from-purple-600 to-violet-600 dark:from-purple-400 dark:to-violet-400 bg-clip-text text-transparent">
                        {@discount}%
                      </span>
                    </div>
                    <p class="mt-1 text-xs text-purple-600 dark:text-purple-400 font-medium">
                      Off their first payment
                    </p>
                  </div>
                </div>

                <div class="mt-8 pt-6 border-t border-amber-200/60 dark:border-amber-700/30">
                  <p class="text-sm text-slate-600 dark:text-slate-400 text-center">
                    <span class="font-medium text-amber-700 dark:text-amber-300">Beta example:</span>
                    If 10 friends subscribe monthly at $10/month, you'd earn ~$24/month in recurring commissions — that's $288/year just for sharing something you love.
                    <span class="text-slate-500 dark:text-slate-500">
                      (After beta: ~$12/month)
                    </span>
                  </p>
                </div>
              </.liquid_card>
            </div>

            <div class="text-center mb-16">
              <h2 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 sm:text-4xl bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent">
                Why our referral program is different
              </h2>
              <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-400 max-w-2xl mx-auto">
                Built with the same privacy-first principles as the rest of MOSSLET.
              </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-20">
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-emerald-500 to-teal-500 shadow-lg">
                      <.phx_icon name="hero-banknotes" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-emerald-500 to-teal-500 bg-clip-text text-transparent font-bold">
                      Real Money, Not Points
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  No confusing reward points or credits. You earn actual cash deposited directly to your bank via Stripe. Set up payouts in minutes.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-purple-500 to-violet-500 shadow-lg">
                      <.phx_icon name="hero-shield-check" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-bold">
                      Privacy-First Design
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Your referral code is encrypted just like everything else. We track referrals without compromising anyone's privacy. No creepy tracking pixels.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 shadow-lg">
                      <.phx_icon name="hero-arrow-path" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-bold">
                      Recurring Commissions
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  Earn {@subscription_commission}% on every subscription payment your referrals make — not just the first one. The gift that keeps on giving.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <div class="flex items-center gap-4">
                    <div class="flex size-12 items-center justify-center rounded-xl bg-gradient-to-r from-cyan-500 to-blue-500 shadow-lg">
                      <.phx_icon name="hero-clock" class="size-7 text-white" />
                    </div>
                    <span class="bg-gradient-to-r from-cyan-500 to-blue-500 bg-clip-text text-transparent font-bold">
                      Fast Payouts
                    </span>
                  </div>
                </:title>
                <p class="text-gray-600 dark:text-gray-300 leading-relaxed">
                  After an initial 35-day hold to allow for cancellations and refunds, earnings are available immediately. Monthly automatic payouts when you reach $15.
                </p>
              </.liquid_card>
            </div>

            <.liquid_container max_width="xl" class="mt-16">
              <div class="mx-auto max-w-4xl">
                <.liquid_card
                  padding="lg"
                  class="text-center bg-gradient-to-br from-teal-50/40 via-emerald-50/30 to-cyan-50/40 dark:from-teal-900/15 dark:via-emerald-900/10 dark:to-cyan-900/15 border-teal-200/60 dark:border-emerald-700/30"
                >
                  <:title>
                    <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                      Ready to start earning?
                    </span>
                  </:title>
                  <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                    Join MOSSLET and get your referral link. Share meaningful connections while earning real money — all without compromising anyone's privacy.
                  </p>

                  <div class="mt-6 inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-amber-100 to-orange-100 dark:from-amber-900/40 dark:to-orange-900/40 border border-amber-200/60 dark:border-amber-700/40">
                    <.phx_icon
                      name="hero-sparkles"
                      class="h-4 w-4 text-amber-600 dark:text-amber-400"
                    />
                    <span class="text-sm font-medium text-amber-700 dark:text-amber-300">
                      Lock in {@subscription_commission}% beta rates before they drop to {@prod_subscription_commission}%
                    </span>
                  </div>

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
                      See Pricing
                    </.liquid_button>
                  </div>

                  <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                    <p class="text-sm text-slate-600 dark:text-slate-400">
                      Available to all active subscribers • Direct bank deposits via Stripe • No minimum referrals required
                    </p>
                  </div>
                </.liquid_card>
              </div>
            </.liquid_container>
          </.liquid_container>
        </div>
      </div>
    </.layout>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    config = Application.get_env(:mosslet, :referral_program)
    beta_rates = config[:beta]
    prod_rates = config[:production]

    subscription_commission =
      Decimal.new(beta_rates[:commission_rate]) |> Decimal.mult(100) |> Decimal.to_integer()

    one_time_commission =
      Decimal.new(beta_rates[:one_time_commission_rate])
      |> Decimal.mult(100)
      |> Decimal.to_integer()

    prod_subscription_commission =
      Decimal.new(prod_rates[:commission_rate]) |> Decimal.mult(100) |> Decimal.to_integer()

    prod_one_time_commission =
      Decimal.new(prod_rates[:one_time_commission_rate])
      |> Decimal.mult(100)
      |> Decimal.to_integer()

    discount = beta_rates[:referee_discount_percent]

    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Referral Program")
     |> assign(:subscription_commission, subscription_commission)
     |> assign(:one_time_commission, one_time_commission)
     |> assign(:prod_subscription_commission, prod_subscription_commission)
     |> assign(:prod_one_time_commission, prod_one_time_commission)
     |> assign(:discount, discount)
     |> assign_new(:meta_description, fn ->
       "Earn real money sharing MOSSLET with friends. Beta bonus: #{subscription_commission}% recurring commissions on subscriptions (normally #{prod_subscription_commission}%) and #{one_time_commission}% on lifetime purchases. Privacy-first referral program with direct bank payouts."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/referrals/referrals_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Share the love, get paid."
     )}
  end
end
