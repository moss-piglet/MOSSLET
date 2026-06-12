defmodule MossletWeb.PublicLive.Pricing do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.Plans
  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:pricing}
      container_max_width={@max_width}
      socket={@socket}
    >
      <div class="bg-white dark:bg-slate-950">
        <div class="isolate">
          <div class="relative overflow-hidden">
            <div class="absolute inset-0 pointer-events-none">
              <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
              </div>
              <div
                class="absolute top-1/3 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
                style="animation-delay: -2s;"
              >
              </div>
              <div
                class="absolute bottom-0 right-1/4 h-64 w-64 rounded-full bg-gradient-to-tl from-cyan-400/10 via-teal-500/10 to-emerald-400/15 blur-3xl animate-pulse"
                style="animation-delay: -4s;"
              >
              </div>
            </div>

            <div class="relative z-10 px-4 pt-20 pb-12 sm:px-6 lg:px-8 sm:pt-24 sm:pb-16 lg:pt-20 lg:pb-20">
              <.pricing_header />

              <.family_switcher families={@families} selected_family={@selected_family} />

              <div class="mx-auto max-w-6xl mt-10 sm:mt-12">
                <.pricing_cards
                  one_time_products={@one_time_products}
                  subscription_products={@subscription_products}
                  selected_family={@selected_family}
                />
              </div>

              <div
                :if={@selected_family == "Business"}
                class="mx-auto max-w-4xl mt-12 lg:mt-16"
              >
                <.enterprise_cta />
              </div>

              <.pricing_footer />
            </div>
          </div>

          <.liquid_container max_width="xl" section_padding class="mt-32 sm:mt-40">
            <div class="text-center mb-16">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl text-slate-900 dark:text-white">
                Pay us, not with your privacy
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400 max-w-3xl mx-auto">
                When you pay for MOSSLET, we work for you — no ads, no tracking, no algorithm deciding what you see. The big "free" apps cost you something quieter: your personal data was valued at
                <span class="font-semibold text-slate-900 dark:text-slate-100">$700+ per year</span>
                over three years ago, and it's only climbed since. Here you keep the money and the data.
              </p>
            </div>

            <.liquid_comparison_table />
          </.liquid_container>

          <.liquid_container max_width="xl" section_padding class="mt-24">
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
                    <div class="flex flex-wrap items-center gap-3 mb-2">
                      <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                        Share MOSSLET and earn real money
                      </h3>
                    </div>
                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-4">
                      When's the last time your social network paid you? Earn commissions when friends join. Your friends save 20% too.
                    </p>
                    <div class="flex flex-wrap items-center gap-4 text-sm">
                      <div class="flex items-center gap-2 text-emerald-700 dark:text-emerald-300">
                        <.phx_icon name="hero-arrow-path" class="h-4 w-4" />
                        <span>
                          <span class="font-semibold">15%</span> recurring
                        </span>
                      </div>
                      <div class="flex items-center gap-2 text-amber-700 dark:text-amber-300">
                        <.phx_icon name="hero-bolt" class="h-4 w-4" />
                        <span>
                          <span class="font-semibold">20%</span> lifetime
                        </span>
                      </div>
                      <div class="flex items-center gap-2 text-slate-600 dark:text-slate-400">
                        <.phx_icon name="hero-credit-card" class="h-4 w-4" />
                        <span>Direct Stripe payouts</span>
                      </div>
                    </div>
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

          <.liquid_container max_width="xl" section_padding class="mt-32 sm:mt-48">
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
                  Join others who've chosen privacy over profit. Start with a free trial, go month-to-month, or pay once for lifetime access.
                </p>

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

                <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    30-day money-back guarantee • Human support team • No hidden fees
                  </p>
                </div>
              </.liquid_card>
            </div>
          </.liquid_container>
        </div>

        <div class="pb-24"></div>
      </div>
    </.layout>
    """
  end

  defp pricing_header(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl text-center mb-12 sm:mb-16">
      <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/30 dark:to-teal-900/30 border border-emerald-200/50 dark:border-emerald-700/30 mb-6">
        <.phx_icon name="hero-sparkles" class="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
        <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
          Privacy-first social
        </span>
      </div>

      <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight">
        <span class="bg-gradient-to-r from-slate-800 to-slate-700 dark:from-slate-100 dark:to-slate-200 bg-clip-text text-transparent">
          Simple,
        </span>
        <br class="sm:hidden" />
        <span class="bg-gradient-to-r from-teal-500 via-emerald-500 to-teal-500 dark:from-teal-400 dark:via-emerald-400 dark:to-teal-400 bg-clip-text text-transparent">
          transparent pricing
        </span>
      </h1>

      <p class="mt-6 text-lg sm:text-xl text-slate-600 dark:text-slate-400 max-w-2xl mx-auto leading-relaxed">
        Choose the plan that works best for you. Start with a free trial or pay once for lifetime access.
      </p>
    </div>
    """
  end

  attr :families, :list, required: true
  attr :selected_family, :string, required: true

  defp family_switcher(assigns) do
    selected = Enum.find(assigns.families, &(&1.key == assigns.selected_family))
    assigns = assign(assigns, :selected, selected)

    ~H"""
    <div :if={length(@families) > 1} class="mx-auto max-w-3xl">
      <div class="flex justify-center">
        <div
          role="tablist"
          aria-label="Plan types"
          class="flex w-full max-w-md sm:w-auto sm:max-w-none items-center gap-1 rounded-2xl border border-slate-200/70 dark:border-slate-700/60 bg-white/70 dark:bg-slate-800/60 backdrop-blur-sm p-1.5 shadow-sm"
        >
          <button
            :for={family <- @families}
            type="button"
            role="tab"
            id={"family-tab-#{family.key}"}
            aria-selected={to_string(family.key == @selected_family)}
            phx-click="select_family"
            phx-value-family={family.key}
            class={[
              "group relative flex-1 sm:flex-none inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition-all duration-200 ease-out transform-gpu focus:outline-none focus-visible:ring-2 focus-visible:ring-emerald-500/50",
              if(family.key == @selected_family,
                do:
                  "bg-gradient-to-r from-teal-500 to-emerald-500 text-white shadow-lg shadow-emerald-500/25",
                else:
                  "text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-slate-100 hover:bg-slate-100/70 dark:hover:bg-slate-700/50"
              )
            ]}
          >
            <.phx_icon name={family.icon} class="h-4 w-4" />
            <span>{family.label}</span>
          </button>
        </div>
      </div>

      <p
        :if={@selected && @selected.tagline != ""}
        class="mt-5 text-center text-base text-slate-600 dark:text-slate-400"
      >
        {@selected.tagline}
      </p>
    </div>
    """
  end

  attr :one_time_products, :list, required: true
  attr :subscription_products, :list, required: true
  attr :selected_family, :string, required: true

  defp pricing_cards(assigns) do
    products =
      Enum.filter(
        assigns.subscription_products,
        &(short_name(&1.name) == assigns.selected_family)
      )

    # The one-time/lifetime offer belongs to the Personal family.
    one_time =
      if assigns.selected_family == "Personal", do: assigns.one_time_products, else: []

    assigns =
      assigns
      |> assign(:products, products)
      |> assign(:one_time, one_time)

    ~H"""
    <div
      :if={@products != []}
      class="grid grid-cols-1 md:grid-cols-2 gap-6 lg:gap-8 max-w-3xl mx-auto"
    >
      <%= for product <- @products do %>
        <.pricing_card product={product} />
      <% end %>
    </div>

    <div :if={@one_time != []} class="mt-16 lg:mt-20">
      <div class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-slate-200 dark:border-slate-700/50"></div>
        </div>
        <div class="relative flex justify-center">
          <div class="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-gradient-to-r from-amber-100 via-orange-100 to-amber-100 dark:from-amber-900/40 dark:via-orange-900/30 dark:to-amber-900/40 border border-amber-300/60 dark:border-amber-600/40 shadow-sm">
            <.phx_icon name="hero-fire" class="w-5 h-5 text-amber-600 dark:text-amber-400" />
            <span class="text-sm font-semibold text-amber-800 dark:text-amber-200">
              Or pay once, own forever
            </span>
          </div>
        </div>
      </div>

      <div class="mt-10 mx-auto max-w-4xl">
        <%= for product <- @one_time do %>
          <.one_time_card product={product} />
        <% end %>
      </div>
    </div>
    """
  end

  defp enterprise_cta(assigns) do
    ~H"""
    <div class="relative group">
      <div class="absolute -inset-1 bg-gradient-to-r from-slate-400/10 via-teal-400/10 to-emerald-400/10 rounded-3xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
      </div>

      <.liquid_card
        padding="lg"
        class="relative overflow-hidden bg-gradient-to-br from-slate-50 via-white to-teal-50/40 dark:from-slate-800/90 dark:via-slate-800/70 dark:to-teal-900/10 border-slate-200/70 dark:border-slate-700/50 shadow-xl"
      >
        <div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-teal-200/30 via-emerald-200/20 to-transparent dark:from-teal-500/10 dark:via-emerald-500/5 rounded-bl-full pointer-events-none">
        </div>

        <div class="relative flex flex-col lg:flex-row lg:items-center gap-8">
          <div class="flex-shrink-0">
            <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-slate-700 to-slate-900 dark:from-slate-600 dark:to-slate-800 shadow-lg shadow-slate-900/20">
              <.phx_icon name="hero-building-office-2" class="h-8 w-8 text-white" />
            </div>
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-3 mb-2">
              <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                Enterprise
              </h3>
              <span class="inline-flex items-center rounded-full bg-slate-100 dark:bg-slate-700/60 px-2.5 py-0.5 text-xs font-medium text-slate-600 dark:text-slate-300">
                200+ members
              </span>
            </div>
            <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
              Need more than 200 members, custom onboarding, or a tailored agreement? Our
              Business plan scales to 200 members — beyond that, let's talk. Same
              zero-knowledge, post-quantum encryption, built for your organization.
            </p>
          </div>

          <div class="flex-shrink-0">
            <.liquid_button
              href="mailto:support@mosslet.com?subject=MOSSLET%20Enterprise%20enquiry"
              variant="secondary"
              color="slate"
              size="lg"
              icon="hero-envelope"
            >
              Contact us
            </.liquid_button>
          </div>
        </div>
      </.liquid_card>
    </div>
    """
  end

  attr :product, :map, required: true

  defp one_time_card(assigns) do
    item = List.first(assigns.product.line_items)

    assigns =
      assigns
      |> assign(:item, item)

    ~H"""
    <div class="relative group">
      <div class="absolute -inset-1 bg-gradient-to-r from-amber-400/20 via-orange-400/20 to-yellow-400/20 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500">
      </div>

      <.liquid_card
        padding="lg"
        class="relative overflow-hidden bg-gradient-to-br from-white via-amber-50/30 to-orange-50/40 dark:from-slate-800/90 dark:via-amber-900/10 dark:to-orange-900/10 border-amber-200/70 dark:border-amber-700/40 shadow-xl shadow-amber-500/5"
      >
        <div class="absolute top-0 right-0 w-64 h-64 bg-gradient-to-bl from-amber-200/30 via-orange-200/20 to-transparent dark:from-amber-500/10 dark:via-orange-500/5 rounded-bl-full pointer-events-none">
        </div>

        <div class="relative">
          <div class="flex flex-col lg:flex-row lg:items-start gap-8 lg:gap-12">
            <div class="flex-1 min-w-0">
              <div class="flex flex-wrap items-center gap-3 mb-4">
                <div class="flex items-center justify-center w-12 h-12 rounded-xl bg-gradient-to-br from-amber-500 to-orange-500 shadow-lg shadow-amber-500/30">
                  <.phx_icon name="hero-bolt" class="w-6 h-6 text-white" />
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-slate-900 dark:text-slate-100">
                    {@product.name}
                  </h2>
                  <p class="text-sm text-amber-600 dark:text-amber-400 font-medium">
                    Lifetime Access • No Subscriptions
                  </p>
                </div>
              </div>

              <p class="text-slate-600 dark:text-slate-400 leading-relaxed mb-6">
                {@product.description}
              </p>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <%= for feature <- @product.features do %>
                  <div class="flex items-start gap-2.5">
                    <div class="flex-shrink-0 mt-0.5">
                      <div class="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/50 dark:to-teal-900/50">
                        <.phx_icon
                          name="hero-check"
                          class="w-3 h-3 text-emerald-600 dark:text-emerald-400"
                        />
                      </div>
                    </div>
                    <span class="text-sm text-slate-600 dark:text-slate-400">{feature}</span>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="lg:w-72 flex-shrink-0">
              <div class="bg-white/80 dark:bg-slate-800/80 backdrop-blur-sm rounded-2xl p-6 border border-amber-200/50 dark:border-amber-700/30 shadow-lg">
                <div class="text-center mb-6">
                  <div class="flex items-baseline justify-center gap-1">
                    <span class="text-5xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 dark:from-amber-400 dark:to-orange-400 bg-clip-text text-transparent">
                      {Util.format_money(@item.amount)}
                    </span>
                  </div>
                  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">one-time payment</p>
                </div>

                <.liquid_button
                  navigate={~p"/auth/register?#{%{plan: "personal"}}"}
                  variant="primary"
                  color="amber"
                  size="lg"
                  icon="hero-rocket-launch"
                  class="w-full mb-4"
                >
                  Get Started
                </.liquid_button>

                <div
                  id="affirm-disclosure-one-time"
                  phx-hook="TippyHook"
                  data-tippy-content="Payment options through Affirm are subject to eligibility, may not be available in all states, and are provided by these lending partners: affirm.com/lenders."
                  class="flex items-center justify-center gap-2 text-xs text-blue-600 dark:text-blue-400 cursor-help hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
                >
                  <.phx_icon name="hero-credit-card" class="w-3.5 h-3.5" />
                  <span>Split payments with Affirm</span>
                  <.phx_icon name="hero-information-circle" class="w-3.5 h-3.5" />
                </div>
              </div>

              <div class="mt-4 flex items-center justify-center gap-4 text-xs text-slate-500 dark:text-slate-400">
                <div class="flex items-center gap-1.5">
                  <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
                  <span>30-day guarantee</span>
                </div>
                <div class="flex items-center gap-1.5">
                  <.phx_icon name="hero-lock-closed" class="w-4 h-4 text-emerald-500" />
                  <span>Secure checkout</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </.liquid_card>
    </div>
    """
  end

  attr :product, :map, required: true

  defp pricing_card(assigns) do
    item = List.first(assigns.product.line_items)
    is_most_popular = assigns.product.most_popular
    is_one_time = item.interval == :one_time

    assigns =
      assigns
      |> assign(:item, item)
      |> assign(:is_most_popular, is_most_popular)
      |> assign(:is_one_time, is_one_time)

    ~H"""
    <div class={[
      "relative group",
      @is_most_popular && "lg:-mt-4 lg:mb-4"
    ]}>
      <div
        :if={@is_most_popular}
        class="absolute -top-4 left-1/2 -translate-x-1/2 z-10"
      >
        <.liquid_badge variant="solid" color="emerald" size="md">
          <.phx_icon name="hero-star" class="w-3.5 h-3.5 mr-1" /> Most Popular
        </.liquid_badge>
      </div>

      <.liquid_card
        padding="lg"
        class={[
          "h-full flex flex-col transition-all duration-300 ease-out",
          @is_most_popular &&
            "ring-2 ring-emerald-500 dark:ring-emerald-400 shadow-2xl shadow-emerald-500/20",
          !@is_most_popular &&
            "hover:ring-1 hover:ring-emerald-200 dark:hover:ring-emerald-800 hover:shadow-xl"
        ]}
      >
        <div class="flex-1">
          <div class="flex items-start justify-between gap-4 mb-4">
            <div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100">
                {interval_label(@item)}
              </h3>
              <p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                {@product.description}
              </p>
            </div>
          </div>

          <.price_display item={@item} is_one_time={@is_one_time} />

          <.trial_badge :if={Map.get(@item, :trial_days)} trial_days={@item.trial_days} />

          <div class="mt-6">
            <.action_button item={@item} is_most_popular={@is_most_popular} />
          </div>

          <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
            <h3 class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-4 flex items-center gap-2">
              <.phx_icon name="hero-check-badge" class="w-4 h-4 text-emerald-500" /> What's included
            </h3>
            <ul class="space-y-3">
              <%= for feature <- @product.features do %>
                <li class="flex items-start gap-3">
                  <div class="flex-shrink-0 mt-0.5">
                    <div class="flex h-5 w-5 items-center justify-center rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 dark:from-emerald-900/40 dark:to-teal-900/40">
                      <.phx_icon
                        name="hero-check"
                        class="w-3 h-3 text-emerald-600 dark:text-emerald-400"
                      />
                    </div>
                  </div>
                  <span class="text-sm text-slate-600 dark:text-slate-400">{feature}</span>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      </.liquid_card>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :is_one_time, :boolean, required: true

  defp price_display(assigns) do
    ~H"""
    <div class="mt-6 mb-2">
      <div class="flex items-center gap-3 mb-2">
        <div
          :if={Map.get(@item, :save_percent) && @item.save_percent > 0}
          id={"save-pricing-#{@item.id}-#{@item.interval}"}
          phx-hook="TippyHook"
          data-tippy-content={"Save #{@item.save_percent}% off"}
          class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-700 dark:text-amber-300 text-xs font-semibold cursor-help"
        >
          <.phx_icon name="hero-tag" class="w-3.5 h-3.5" /> Save {@item.save_percent}%
        </div>
      </div>
      <div class="flex items-baseline gap-2">
        <span class="text-4xl sm:text-5xl font-bold bg-gradient-to-r from-teal-600 to-emerald-600 dark:from-teal-400 dark:to-emerald-400 bg-clip-text text-transparent">
          {Util.format_money(@item.amount)}
        </span>
        <div class="flex flex-col">
          <span class="text-base font-medium text-slate-600 dark:text-slate-400">
            <%= cond do %>
              <% @is_one_time -> %>
                once
              <% @item.interval == :year -> %>
                /year
              <% true -> %>
                /month
            <% end %>
          </span>
        </div>
      </div>
      <p
        :if={Plans.seat_based_plan?(@item)}
        class="mt-2 text-sm text-slate-500 dark:text-slate-400"
      >
        for up to {Plans.included_seats(@item)} members
      </p>
    </div>
    """
  end

  attr :trial_days, :integer, required: true

  defp trial_badge(assigns) do
    ~H"""
    <div class="mt-4 p-3 rounded-xl bg-gradient-to-r from-emerald-50 via-teal-50 to-cyan-50 dark:from-emerald-900/20 dark:via-teal-900/15 dark:to-cyan-900/20 border border-emerald-200/60 dark:border-emerald-700/30">
      <div class="flex items-center gap-2">
        <div class="flex items-center justify-center w-8 h-8 rounded-full bg-gradient-to-br from-emerald-500 to-teal-500 shadow-sm">
          <.phx_icon name="hero-gift" class="w-4 h-4 text-white" />
        </div>
        <div>
          <p class="text-sm font-semibold text-emerald-700 dark:text-emerald-300">
            {ngettext("%{count}-day free trial", "%{count}-day free trial", @trial_days,
              count: @trial_days
            )}
          </p>
          <p class="text-xs text-emerald-600/80 dark:text-emerald-400/80">
            No charge until trial ends • Cancel anytime
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :is_most_popular, :boolean, required: true

  defp action_button(assigns) do
    ~H"""
    <.liquid_button
      navigate={register_path(@item)}
      variant={if @is_most_popular, do: "primary", else: "secondary"}
      size="lg"
      class="w-full"
      icon={button_icon(@item)}
    >
      {button_label(@item)}
    </.liquid_button>
    """
  end

  # Maps a plan line-item to the plan-aware registration path. The funnel reads
  # `?plan=` to tailor copy and route the user to the correct post-onboarding
  # step (Task #214). Family/Business per-seat plans carry their plan; everything
  # else (Personal monthly/yearly/lifetime) is the personal plan.
  defp register_path(item) do
    ~p"/auth/register?#{%{plan: plan_param(item)}}"
  end

  defp plan_param(item) do
    cond do
      is_binary(Map.get(item, :id)) and String.starts_with?(item.id, "family") -> "family"
      is_binary(Map.get(item, :id)) and String.starts_with?(item.id, "business") -> "business"
      true -> "personal"
    end
  end

  defp button_icon(%{interval: :one_time}), do: "hero-rocket-launch"

  defp button_icon(%{trial_days: days}) when is_integer(days) and days > 0,
    do: "hero-rocket-launch"

  defp button_icon(_), do: "hero-arrow-right"

  defp button_label(%{interval: :one_time}), do: "Get Started"

  defp button_label(%{trial_days: _days}), do: "Get Started Free"

  defp button_label(%{interval: :month}), do: "Get Started"
  defp button_label(%{interval: :year}), do: "Get Started"
  defp button_label(_), do: "Get Started"

  defp interval_label(%{interval: :month}), do: "Monthly"
  defp interval_label(%{interval: :year}), do: "Yearly"
  defp interval_label(%{interval: :one_time}), do: "Lifetime"
  defp interval_label(_), do: "Plan"

  defp pricing_footer(assigns) do
    ~H"""
    <div class="mt-16 text-center space-y-4">
      <div class="flex flex-wrap items-center justify-center gap-6 text-sm text-slate-500 dark:text-slate-400">
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
          <span>Secure payment</span>
        </div>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-lock-closed" class="w-4 h-4 text-emerald-500" />
          <span>End-to-end encrypted</span>
        </div>
        <div class="flex items-center gap-2">
          <.phx_icon name="hero-heart" class="w-4 h-4 text-emerald-500" />
          <span>Cancel anytime</span>
        </div>
      </div>

      <p class="text-xs text-slate-500 dark:text-slate-400">
        Powered by Stripe. Your payment information is never stored on our servers.
      </p>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    products = Plans.products()

    one_time_products =
      Enum.filter(products, fn product ->
        item = List.first(product.line_items)
        item && item.interval == :one_time
      end)

    subscription_products =
      Enum.filter(products, fn product ->
        item = List.first(product.line_items)
        item && item.interval in [:month, :year]
      end)

    families = build_families(subscription_products)
    default_family = default_family(families)

    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Pricing")
     |> assign(:products, products)
     |> assign(:one_time_products, one_time_products)
     |> assign(:subscription_products, subscription_products)
     |> assign(:families, families)
     |> assign(:selected_family, default_family)
     |> assign_new(:meta_description, fn ->
       "Simple, flexible pricing. Choose monthly, yearly, or lifetime access. With our pay-once lifetime option you get access to our service forever. No hidden fees, no surprises. We also support lowering your upfront lifetime payment with Affirm."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/pricing/pricing_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Pay once, own forever. No subscriptions. No recurring fees. No surprises."
     )}
  end

  @impl true
  def handle_event("select_family", %{"family" => key}, socket) do
    valid? = Enum.any?(socket.assigns.families, &(&1.key == key))
    {:noreply, if(valid?, do: assign(socket, :selected_family, key), else: socket)}
  end

  # Builds the ordered list of plan families from the configured subscription
  # products, preserving first-seen config order. Each family carries marketing
  # metadata used by the switcher and section header.
  defp build_families(subscription_products) do
    subscription_products
    |> Enum.map(&short_name(&1.name))
    |> Enum.uniq()
    |> Enum.map(fn key -> Map.put(family_meta(key), :key, key) end)
  end

  # Default the switcher to the "Family" plan (our most popular) when present,
  # otherwise the first available family.
  defp default_family(families) do
    keys = Enum.map(families, & &1.key)

    cond do
      "Family" in keys -> "Family"
      keys != [] -> List.first(keys)
      true -> nil
    end
  end

  # "MOSSLET (Family)" -> "Family"
  defp short_name(name) do
    case Regex.run(~r/\(([^)]+)\)/, name) do
      [_, inner] -> inner
      _ -> name
    end
  end

  defp family_meta("Personal"),
    do: %{
      label: "Personal",
      icon: "hero-user",
      tagline: "For you. Private by design, owned by you."
    }

  defp family_meta("Family"),
    do: %{
      label: "Family",
      icon: "hero-users",
      tagline: "For the people you love. Stay close without surveillance."
    }

  defp family_meta("Business"),
    do: %{
      label: "Business",
      icon: "hero-building-office-2",
      tagline: "For your team. Private collaboration that scales."
    }

  defp family_meta(other),
    do: %{label: other, icon: "hero-sparkles", tagline: ""}
end
