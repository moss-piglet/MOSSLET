defmodule MossletWeb.PublicLive.BusinessPlan do
  @moduledoc """
  Public `/business-plan` marketing page.

  Sells the *values* of the Business plan — private, org-scoped business
  circles, zero-knowledge file sharing, per-seat billing, the branding add-on
  (custom subdomain + logo), and a zero-knowledge admin audit log — mirroring
  the structure/SEO conventions of `MossletWeb.PublicLive.Features` and
  `MossletWeb.PublicLive.Pricing`.
  """
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:business_plan}
      container_max_width={@max_width}
      socket={@socket}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-blue-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-indigo-900/10">
        <div class="isolate">
          <%!-- Hero --%>
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] bg-gradient-to-tr from-indigo-400/30 via-blue-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-16 pt-36 sm:pt-48 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-3xl text-center">
                  <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-indigo-50 to-blue-50 dark:from-indigo-900/30 dark:to-blue-900/30 border border-blue-200/50 dark:border-blue-700/30 mb-8">
                    <.phx_icon
                      name="hero-building-office-2"
                      class="w-4 h-4 text-indigo-600 dark:text-indigo-400"
                    />
                    <span class="text-sm font-medium text-indigo-700 dark:text-indigo-300">
                      MOSSLET Business
                    </span>
                  </div>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-indigo-500 via-blue-500 to-cyan-500 bg-clip-text text-transparent">
                    Private collaboration that scales
                  </h1>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400">
                    Give your team a private place to share files, talk, and work together — with
                    the same zero-knowledge, post-quantum encryption that protects everything on
                    MOSSLET. No ads, no data mining, no one reading over your shoulder.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full bg-gradient-to-r from-indigo-400 via-blue-400 to-cyan-400 shadow-sm shadow-blue-500/30">
                    </div>
                  </div>

                  <div class="mt-12 flex flex-col sm:flex-row gap-4 justify-center">
                    <.liquid_button
                      navigate={~p"/auth/register?#{%{plan: "business", billing: "year"}}"}
                      color="indigo"
                      variant="primary"
                      icon="hero-rocket-launch"
                      size="lg"
                    >
                      Start your team
                    </.liquid_button>
                    <.liquid_button
                      navigate="/pricing"
                      color="blue"
                      variant="secondary"
                      icon="hero-banknotes"
                      size="lg"
                    >
                      See pricing
                    </.liquid_button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Core values --%>
          <.liquid_container max_width="full" class="relative py-12 sm:py-16">
            <div class="relative mx-auto max-w-7xl px-6 lg:px-8">
              <.section_eyebrow accent="indigo">Work together, privately</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent">
                Everything your team needs, none of the surveillance
              </h2>
              <p class="mx-auto mt-4 max-w-2xl text-center text-lg text-slate-600 dark:text-slate-400">
                Collaboration tools usually pay for themselves by mining your work. MOSSLET
                Business is encrypted end to end — your files and conversations are yours alone.
              </p>

              <div class="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
                <.value_card
                  icon="hero-user-group"
                  accent="indigo"
                  title="Private business circles"
                  body="Organize your team into private, org-scoped circles. Only members you add can see a circle's files and conversations — membership is enforced server-side, every time."
                />
                <.value_card
                  icon="hero-document-arrow-up"
                  accent="blue"
                  title="Zero-knowledge file sharing"
                  body="Share documents within a circle with files encrypted in the browser before upload. We only ever store encrypted blobs — the server never sees your team's files in the clear."
                />
                <.value_card
                  icon="hero-users"
                  accent="cyan"
                  title="Simple per-seat billing"
                  body="Start with a generous seat allotment and add seats as you grow. Owners manage everything in one place, with clear pricing and no surprise add-ons."
                />
                <.value_card
                  icon="hero-globe-alt"
                  accent="purple"
                  title="Your own branded space"
                  body="The branding add-on gives your org a custom subdomain and your own logo across sign-in and onboarding, so your team feels at home from the first click."
                />
                <.value_card
                  icon="hero-clipboard-document-check"
                  accent="emerald"
                  title="Zero-knowledge audit log"
                  body="An append-only admin audit log records who did what — invites, removals, role and name changes — so admins stay accountable, without ever exposing private content."
                />
                <.value_card
                  icon="hero-shield-check"
                  accent="indigo"
                  title="Post-quantum encryption"
                  body="Everything runs on the same Cat-5 ML-KEM-1024 zero-knowledge architecture as the rest of MOSSLET. Your team's data is protected today and against tomorrow's threats."
                />
              </div>
            </div>
          </.liquid_container>

          <%!-- Branding add-on highlight --%>
          <.liquid_container max_width="full" class="relative mt-8 sm:mt-12 py-16 sm:py-20">
            <div class="absolute inset-0 bg-gradient-to-b from-indigo-50/30 via-blue-50/20 to-transparent dark:from-indigo-950/20 dark:via-blue-950/10 dark:to-transparent">
            </div>
            <div class="relative mx-auto max-w-5xl px-6 lg:px-8">
              <.section_eyebrow accent="purple">Make it yours</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-purple-500 to-indigo-500 bg-clip-text text-transparent">
                Optional branding add-on
              </h2>
              <p class="mx-auto mt-4 max-w-2xl text-center text-lg text-slate-600 dark:text-slate-400">
                Add a polished, on-brand experience for your team — without giving up an ounce
                of privacy.
              </p>

              <div class="mt-12 grid grid-cols-1 gap-6 md:grid-cols-3">
                <.feature_pill
                  icon="hero-link"
                  title="Custom subdomain"
                  body="Your team signs in at your own MOSSLET subdomain — a familiar front door that's unmistakably yours."
                />
                <.feature_pill
                  icon="hero-photo"
                  title="Your logo, encrypted"
                  body="Upload your brand logo with the same zero-knowledge image pipeline used everywhere else on MOSSLET."
                />
                <.feature_pill
                  icon="hero-sparkles"
                  title="Branded onboarding"
                  body="New members see your branding across sign-in, onboarding, and password flows — seamless from day one."
                />
              </div>
            </div>
          </.liquid_container>

          <%!-- Enterprise / scale --%>
          <.liquid_container max_width="xl" class="relative mt-16 sm:mt-24">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="bg-gradient-to-br from-slate-50 via-white to-indigo-50/40 dark:from-slate-800/90 dark:via-slate-800/70 dark:to-indigo-900/10 border-slate-200/70 dark:border-slate-700/50"
              >
                <div class="flex flex-col lg:flex-row lg:items-center gap-8">
                  <div class="flex-shrink-0">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-slate-700 to-slate-900 dark:from-slate-600 dark:to-slate-800 shadow-lg shadow-slate-900/20">
                      <.phx_icon name="hero-building-office-2" class="h-8 w-8 text-white" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-2">
                      Scales to your whole organization
                    </h3>
                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                      Business scales to 200 members on the same zero-knowledge foundation. Need
                      more, or a tailored agreement? Let's talk — we're happy to build a plan that
                      fits your organization.
                    </p>
                  </div>
                  <div class="flex-shrink-0">
                    <.liquid_button
                      href="mailto:support@mosslet.com?subject=MOSSLET%20Business%20enquiry"
                      variant="secondary"
                      color="slate"
                      icon="hero-envelope"
                    >
                      Contact us
                    </.liquid_button>
                  </div>
                </div>
              </.liquid_card>
            </div>
          </.liquid_container>

          <%!-- Final CTA --%>
          <.liquid_container max_width="xl" class="relative mt-24 sm:mt-32">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="text-center bg-gradient-to-br from-indigo-50/40 via-blue-50/30 to-cyan-50/40 dark:from-indigo-900/15 dark:via-blue-900/10 dark:to-cyan-900/15 border-blue-200/60 dark:border-blue-700/30"
              >
                <:title>
                  <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent">
                    Give your team a private workspace
                  </span>
                </:title>
                <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                  Collaborate on files and conversations that stay encrypted end to end. Owned by
                  your organization, never mined for profit.
                </p>

                <div class="mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-6">
                  <.liquid_button
                    navigate={~p"/auth/register?#{%{plan: "business", billing: "year"}}"}
                    size="lg"
                    icon="hero-rocket-launch"
                    color="indigo"
                    variant="primary"
                  >
                    Start your team
                  </.liquid_button>
                  <.liquid_button
                    navigate="/pricing"
                    variant="secondary"
                    color="blue"
                    icon="hero-banknotes"
                    size="lg"
                  >
                    See pricing
                  </.liquid_button>
                </div>

                <div class="mt-8 pt-6 border-t border-slate-200/60 dark:border-slate-700/60">
                  <p class="text-sm text-slate-600 dark:text-slate-400">
                    Free trial • Per-seat pricing • 30-day money-back guarantee
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

  attr :accent, :string, default: "indigo", values: ~w(indigo blue cyan purple emerald)
  slot :inner_block, required: true

  defp section_eyebrow(assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-3">
      <div class={["h-px w-12 bg-gradient-to-r from-transparent", eyebrow_line_class(@accent)]}></div>
      <span class={["text-sm font-semibold uppercase tracking-wider", eyebrow_text_class(@accent)]}>
        {render_slot(@inner_block)}
      </span>
      <div class={["h-px w-12 bg-gradient-to-l from-transparent", eyebrow_line_class(@accent)]}></div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true
  attr :accent, :string, default: "indigo", values: ~w(indigo blue cyan purple emerald)

  defp value_card(assigns) do
    ~H"""
    <.liquid_card
      padding="lg"
      class="group hover:scale-105 transition-all duration-300 ease-out h-full"
    >
      <:title>
        <div class="flex items-center gap-3 mb-2">
          <div class={[
            "flex h-10 w-10 shrink-0 items-center justify-center rounded-xl shadow-sm bg-gradient-to-br",
            icon_gradient_class(@accent)
          ]}>
            <.phx_icon name={@icon} class="h-5 w-5 text-white" />
          </div>
          <span class="text-base font-bold text-slate-900 dark:text-slate-100">
            {@title}
          </span>
        </div>
      </:title>
      <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
        {@body}
      </p>
    </.liquid_card>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true

  defp feature_pill(assigns) do
    ~H"""
    <div class="relative rounded-2xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 p-6">
      <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-purple-500 to-indigo-500 shadow-sm">
        <.phx_icon name={@icon} class="h-5 w-5 text-white" />
      </div>
      <h3 class="mt-4 text-lg font-bold text-slate-900 dark:text-slate-100">{@title}</h3>
      <p class="mt-2 text-sm text-slate-600 dark:text-slate-400 leading-relaxed">{@body}</p>
    </div>
    """
  end

  defp eyebrow_line_class("indigo"), do: "to-indigo-400 dark:to-indigo-600"
  defp eyebrow_line_class("blue"), do: "to-blue-400 dark:to-blue-600"
  defp eyebrow_line_class("cyan"), do: "to-cyan-400 dark:to-cyan-600"
  defp eyebrow_line_class("purple"), do: "to-purple-400 dark:to-purple-600"
  defp eyebrow_line_class("emerald"), do: "to-emerald-400 dark:to-emerald-600"

  defp eyebrow_text_class("indigo"), do: "text-indigo-600 dark:text-indigo-400"
  defp eyebrow_text_class("blue"), do: "text-blue-600 dark:text-blue-400"
  defp eyebrow_text_class("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp eyebrow_text_class("purple"), do: "text-purple-600 dark:text-purple-400"
  defp eyebrow_text_class("emerald"), do: "text-emerald-600 dark:text-emerald-400"

  defp icon_gradient_class("indigo"), do: "from-indigo-500 to-blue-500"
  defp icon_gradient_class("blue"), do: "from-blue-500 to-cyan-500"
  defp icon_gradient_class("cyan"), do: "from-cyan-500 to-blue-500"
  defp icon_gradient_class("purple"), do: "from-purple-500 to-indigo-500"
  defp icon_gradient_class("emerald"), do: "from-emerald-500 to-teal-500"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Business Plan")
     |> assign_new(:meta_description, fn ->
       "MOSSLET Business: private, org-scoped business circles with zero-knowledge file sharing, per-seat billing, an optional branding add-on (custom subdomain + logo), and a zero-knowledge admin audit log. Post-quantum encrypted, never mined."
     end)
     |> assign(
       :og_image,
       MossletWeb.Endpoint.url() <> ~p"/images/business_plan/business_plan_og.png"
     )
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Private team collaboration with zero-knowledge file sharing and post-quantum encryption"
     )}
  end
end
