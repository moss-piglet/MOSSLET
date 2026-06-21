defmodule MossletWeb.PublicLive.FamilyPlan do
  @moduledoc """
  Public `/family-plan` marketing page.

  Sells the *values* of the Family plan — consent-based guardianship, zero
  knowledge, no master key, mandatory transparency, and an honest pause-sharing
  privacy toggle — mirroring the structure/SEO conventions of
  `MossletWeb.PublicLive.Features` and `MossletWeb.PublicLive.Pricing`. The
  framing follows `docs/GUARDIANSHIP_DESIGN.md`.
  """
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:family_plan}
      container_max_width={@max_width}
      socket={@socket}
    >
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
          <%!-- Hero --%>
          <div class="relative isolate">
            <div class="absolute inset-0 -z-10 overflow-hidden" aria-hidden="true">
              <div class="absolute left-1/2 top-0 -translate-x-1/2 transform-gpu blur-3xl">
                <div
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] bg-gradient-to-tr from-pink-400/30 via-fuchsia-400/20 to-purple-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-16 pt-36 sm:pt-48 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-3xl text-center">
                  <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-pink-50 to-fuchsia-50 dark:from-pink-900/30 dark:to-fuchsia-900/30 border border-pink-200/50 dark:border-pink-700/30 mb-8">
                    <.phx_icon name="hero-heart" class="w-4 h-4 text-pink-500 dark:text-pink-400" />
                    <span class="text-sm font-semibold bg-gradient-to-r from-pink-500 via-fuchsia-500 to-purple-500 bg-clip-text text-transparent">
                      MOSSLET Family
                    </span>
                  </div>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-pink-500 via-fuchsia-500 to-purple-500 bg-clip-text text-transparent">
                    Stay close, without surveillance
                  </h1>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400">
                    A private home for the people you love. Family guardianship lets you look
                    out for each other — built on consent and zero-knowledge encryption, never a
                    master key. Everyone always sees exactly who can read what.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full bg-gradient-to-r from-pink-400 via-fuchsia-400 to-purple-400 shadow-sm shadow-fuchsia-500/30">
                    </div>
                  </div>

                  <div class="mt-12 flex flex-col sm:flex-row gap-4 justify-center">
                    <.liquid_button
                      navigate={~p"/auth/register?#{%{plan: "family", billing: "year"}}"}
                      color="pink"
                      variant="primary"
                      icon="hero-rocket-launch"
                      size="lg"
                    >
                      Start your family
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
              <.section_eyebrow accent="fuchsia">Built on trust, not tracking</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-pink-500 to-fuchsia-500 bg-clip-text text-transparent">
                Care for your family the honest way
              </h2>
              <p class="mx-auto mt-4 max-w-2xl text-center text-lg text-slate-600 dark:text-slate-400">
                Most "family safety" apps are surveillance with a friendly logo. MOSSLET Family
                is the opposite: every protection is consensual, visible, and reversible.
              </p>

              <div class="mt-16 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
                <.value_card
                  icon="hero-hand-raised"
                  accent="amber"
                  title="Consent-based guardianship"
                  body="A guardian can only co-read a family member's content after that member explicitly accepts. Nothing is shared until consent is given, and it can be paused or withdrawn at any time."
                />
                <.value_card
                  icon="hero-lock-closed"
                  accent="teal"
                  title="Zero knowledge, no master key"
                  body="Content is encrypted in the browser before it leaves the device. There is no master key and no silent decryption path — not even MOSSLET can read your family's posts, messages, or journals."
                />
                <.value_card
                  icon="hero-eye"
                  accent="emerald"
                  title="Mandatory transparency"
                  body="Every managed member's screen always shows exactly which guardians can read what. If a guardian can see it, the member can see that they can. No hidden monitoring, ever."
                />
                <.value_card
                  icon="hero-pause-circle"
                  accent="purple"
                  title="An honest privacy toggle"
                  body="Managed members can pause sharing new content with a guardian at any time, right from the family dashboard. Pausing is future-only and never silently undone."
                />
                <.value_card
                  icon="hero-user-group"
                  accent="pink"
                  title="A shared family circle"
                  body="A dedicated, end-to-end encrypted family circle keeps everyone connected — photos, messages, and updates that stay inside the family and never feed an algorithm."
                />
                <.value_card
                  icon="hero-shield-check"
                  accent="fuchsia"
                  title="Safety without overreach"
                  body="Guardianship is for care, not control. Using it to coerce, monitor, or harvest a family member violates our Terms — and our Safety page points anyone who needs it to independent help."
                />
              </div>
            </div>
          </.liquid_container>

          <%!-- How guardianship works --%>
          <.liquid_container max_width="full" class="relative mt-8 sm:mt-12 py-16 sm:py-20">
            <div class="absolute inset-0 bg-gradient-to-b from-amber-50/30 via-orange-50/20 to-transparent dark:from-amber-950/20 dark:via-orange-950/10 dark:to-transparent">
            </div>
            <div class="relative mx-auto max-w-5xl px-6 lg:px-8">
              <.section_eyebrow accent="amber">How guardianship works</.section_eyebrow>
              <h2 class="mt-4 text-center text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent">
                Three steps, fully in the open
              </h2>

              <ol class="mt-12 grid grid-cols-1 gap-6 md:grid-cols-3">
                <.step_card
                  step="1"
                  title="Invite your family"
                  body="Add the people you love to your family org. Each person keeps their own account and their own keys — you're connecting families, not taking them over."
                />
                <.step_card
                  step="2"
                  title="Request consent"
                  body="A guardian asks to co-read a member's content. The member sees a clear request explaining exactly what it means, and chooses to accept or decline."
                />
                <.step_card
                  step="3"
                  title="Stay transparent"
                  body="Once accepted, the member's transparency panel always lists their guardians and what they can see — and the member can pause sharing whenever they want."
                />
              </ol>
            </div>
          </.liquid_container>

          <%!-- Safety reassurance --%>
          <.liquid_container max_width="xl" class="relative mt-16 sm:mt-24">
            <div class="mx-auto max-w-4xl">
              <.liquid_card
                padding="lg"
                class="bg-gradient-to-br from-indigo-50/40 via-blue-50/30 to-emerald-50/40 dark:from-indigo-900/15 dark:via-blue-900/10 dark:to-emerald-900/15 border-indigo-200/60 dark:border-indigo-700/30"
              >
                <div class="flex flex-col lg:flex-row lg:items-center gap-8">
                  <div class="flex-shrink-0">
                    <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gradient-to-br from-indigo-500 to-blue-500 shadow-lg shadow-indigo-500/30">
                      <.phx_icon name="hero-lifebuoy" class="h-8 w-8 text-white" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-2">
                      Care has limits — and help is always reachable
                    </h3>
                    <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                      If a family member ever feels unsafe or controlled, our public
                      <.link
                        navigate={~p"/safety"}
                        class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 underline decoration-emerald-500/30"
                      >Safety page</.link>
                      points to trusted, independent crisis and abuse organizations — a help path
                      MOSSLET can never co-read or interfere with.
                    </p>
                  </div>
                  <div class="flex-shrink-0">
                    <.liquid_button
                      navigate={~p"/safety"}
                      variant="secondary"
                      color="indigo"
                      icon="hero-arrow-right"
                    >
                      Safety resources
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
                class="text-center bg-gradient-to-br from-pink-50/40 via-fuchsia-50/30 to-purple-50/40 dark:from-pink-900/15 dark:via-fuchsia-900/10 dark:to-purple-900/15 border-fuchsia-200/60 dark:border-fuchsia-700/30"
              >
                <:title>
                  <span class="text-2xl font-bold tracking-tight sm:text-3xl lg:text-4xl bg-gradient-to-r from-pink-500 to-fuchsia-500 bg-clip-text text-transparent">
                    Bring your family somewhere calm
                  </span>
                </:title>
                <p class="mt-6 text-lg leading-8 text-slate-700 dark:text-slate-300 max-w-2xl mx-auto">
                  Start a private, ad-free space your whole family owns. Consent-based, transparent,
                  and encrypted end to end.
                </p>

                <div class="mt-10 flex flex-col sm:flex-row sm:items-center sm:justify-center gap-6">
                  <.liquid_button
                    navigate={~p"/auth/register?#{%{plan: "family", billing: "year"}}"}
                    size="lg"
                    icon="hero-rocket-launch"
                    color="pink"
                    variant="primary"
                  >
                    Start your family
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

  attr :accent, :string,
    default: "emerald",
    values: ~w(rose teal emerald cyan violet amber pink fuchsia purple)

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

  attr :accent, :string,
    default: "emerald",
    values: ~w(rose teal emerald cyan violet amber pink fuchsia purple)

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

  attr :step, :string, required: true
  attr :title, :string, required: true
  attr :body, :string, required: true

  defp step_card(assigns) do
    ~H"""
    <li class="relative rounded-2xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 p-6">
      <div class="flex h-10 w-10 items-center justify-center rounded-full bg-gradient-to-br from-amber-500 to-orange-500 text-white font-bold shadow-sm">
        {@step}
      </div>
      <h3 class="mt-4 text-lg font-bold text-slate-900 dark:text-slate-100">{@title}</h3>
      <p class="mt-2 text-sm text-slate-600 dark:text-slate-400 leading-relaxed">{@body}</p>
    </li>
    """
  end

  defp eyebrow_line_class("rose"), do: "to-rose-400 dark:to-rose-600"
  defp eyebrow_line_class("teal"), do: "to-teal-400 dark:to-teal-600"
  defp eyebrow_line_class("emerald"), do: "to-emerald-400 dark:to-emerald-600"
  defp eyebrow_line_class("cyan"), do: "to-cyan-400 dark:to-cyan-600"
  defp eyebrow_line_class("violet"), do: "to-violet-400 dark:to-violet-600"
  defp eyebrow_line_class("amber"), do: "to-amber-400 dark:to-amber-600"
  defp eyebrow_line_class("pink"), do: "to-pink-400 dark:to-pink-600"
  defp eyebrow_line_class("fuchsia"), do: "to-fuchsia-400 dark:to-fuchsia-600"
  defp eyebrow_line_class("purple"), do: "to-purple-400 dark:to-purple-600"

  defp eyebrow_text_class("rose"), do: "text-rose-600 dark:text-rose-400"
  defp eyebrow_text_class("teal"), do: "text-teal-600 dark:text-teal-400"
  defp eyebrow_text_class("emerald"), do: "text-emerald-600 dark:text-emerald-400"
  defp eyebrow_text_class("cyan"), do: "text-cyan-600 dark:text-cyan-400"
  defp eyebrow_text_class("violet"), do: "text-violet-600 dark:text-violet-400"
  defp eyebrow_text_class("amber"), do: "text-amber-600 dark:text-amber-400"
  defp eyebrow_text_class("pink"), do: "text-pink-600 dark:text-pink-400"
  defp eyebrow_text_class("fuchsia"), do: "text-fuchsia-600 dark:text-fuchsia-400"
  defp eyebrow_text_class("purple"), do: "text-purple-600 dark:text-purple-400"

  defp icon_gradient_class("rose"), do: "from-rose-500 to-pink-500"
  defp icon_gradient_class("teal"), do: "from-teal-500 to-emerald-500"
  defp icon_gradient_class("emerald"), do: "from-emerald-500 to-teal-500"
  defp icon_gradient_class("cyan"), do: "from-cyan-500 to-blue-500"
  defp icon_gradient_class("violet"), do: "from-violet-500 to-purple-500"
  defp icon_gradient_class("amber"), do: "from-amber-500 to-orange-500"
  defp icon_gradient_class("pink"), do: "from-pink-500 to-fuchsia-500"
  defp icon_gradient_class("fuchsia"), do: "from-fuchsia-500 to-purple-500"
  defp icon_gradient_class("purple"), do: "from-purple-500 to-fuchsia-500"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Family Plan")
     |> assign_new(:meta_description, fn ->
       "MOSSLET Family: a private, ad-free home for the people you love. Consent-based guardianship with zero-knowledge encryption, no master key, mandatory transparency, and an honest pause-sharing toggle."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/pricing/pricing_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Stay close to family without surveillance — consent-based, zero-knowledge guardianship"
     )}
  end
end
