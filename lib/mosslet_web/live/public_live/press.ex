defmodule MossletWeb.PublicLive.Press do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_scope={assigns[:current_scope]}
      current_page={:press}
      container_max_width={@max_width}
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
                  class="aspect-[801/1036] w-[30rem] sm:w-[35rem] lg:w-[40rem] xl:w-[45rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                  style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
                >
                </div>
              </div>
            </div>

            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-3xl text-center">
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    Press & Media
                  </h1>

                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Everything journalists, reviewers, and creators need to cover MOSSLET — the privacy-first social network with an encrypted journal.
                  </p>

                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>

                  <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
                    <.liquid_button
                      href="mailto:press@mosslet.com"
                      color="teal"
                      variant="primary"
                      icon="hero-envelope"
                      size="lg"
                    >
                      Contact Press
                    </.liquid_button>
                    <.liquid_button
                      href="https://github.com/moss-piglet/MOSSLET"
                      color="blue"
                      variant="secondary"
                      icon="hero-code-bracket"
                      size="lg"
                      rel="noopener noreferrer"
                      target="_blank"
                    >
                      View Source Code
                    </.liquid_button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                What is MOSSLET?
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                MOSSLET is a privacy-first social network with a built-in encrypted journal, designed so we can't read your data — only you and the people you choose can.
              </p>
              <p class="mt-4 text-base/7 text-slate-700 dark:text-slate-300">
                Built as an open-source Elixir Phoenix web application, MOSSLET is a zero-knowledge, privacy-first alternative to ad-driven social media. Native desktop and mobile apps are in development. MOSSLET is currently in beta with monthly, annual, and one-time lifetime access options.
              </p>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Key Facts
              </h2>
              <div class="mt-10 grid grid-cols-1 gap-6 sm:grid-cols-2">
                <.press_fact_card
                  icon="hero-shield-check"
                  gradient="from-teal-500 to-emerald-500"
                  title="Zero-Knowledge by Design"
                  description="Posts and journal entries are encrypted using password-derived asymmetric keys. Only you and explicitly chosen recipients can decrypt your content."
                />
                <.press_fact_card
                  icon="hero-lock-closed"
                  gradient="from-blue-500 to-cyan-500"
                  title="Layered Encryption at Rest"
                  description="We use enacl (libsodium, with built-in Argon2id for key derivation) and cloak/cloak_ecto to combine asymmetric public-key cryptography with a second AES-256-GCM layer at rest — designed with future quantum attacks in mind."
                />
                <.press_fact_card
                  icon="hero-key"
                  gradient="from-purple-500 to-violet-500"
                  title="Password-Manager-Style Sessions"
                  description="If your encrypted web session expires, you must re-enter your password to unlock your data — even with a 'remember me' cookie. The cookie alone can't decrypt your content."
                />
                <.press_fact_card
                  icon="hero-code-bracket"
                  gradient="from-amber-500 to-orange-500"
                  title="Open Source"
                  description="Our full codebase is public so anyone can verify we encrypt before processing and don't retain plaintext content. We use redact on schemas to prevent sensitive field leakage."
                />
                <.press_fact_card
                  icon="hero-arrows-right-left"
                  gradient="from-cyan-500 to-teal-500"
                  title="Bluesky Interop"
                  description="Optional Bluesky integration lets you import/export posts and cross-post public MOSSLET updates to your Bluesky account."
                />
                <.press_fact_card
                  icon="hero-currency-dollar"
                  gradient="from-rose-500 to-pink-500"
                  title="Aligned Incentives"
                  description="No ads or behavioral analytics — we use only cookieless, privacy-first Fathom Analytics for aggregate public page views. Access is subscription-based with a privacy-preserving, in-house referral system that shares recurring revenue via anonymous codes."
                />
              </div>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Privacy & Security Details
              </h2>
              <div class="mt-8 space-y-6">
                <.press_detail_section title="Where Data Is Stored">
                  <p>
                    MOSSLET runs on Fly.io with object storage on Tigris, hosted in the United States. All infrastructure communicates over a private, encrypted WireGuard network. Data at rest is protected by layered encryption — asymmetric public-key cryptography wrapped in AES-256-GCM symmetric encryption.
                  </p>
                </.press_detail_section>

                <.press_detail_section title="Encryption Approach">
                  <p>
                    MOSSLET uses password-derived asymmetric key cryptography (via enacl/libsodium, which uses Argon2id internally for key derivation) so that only you — and the people you explicitly share with — can decrypt your content. This is then wrapped in a second layer of AES-256-GCM symmetric encryption at rest (via cloak/cloak_ecto), designed to add protection even against potential future quantum attacks.
                  </p>
                </.press_detail_section>

                <.press_detail_section title="Server Trust & Open Source">
                  <p>
                    Today, asymmetric encryption happens on the server, so there is a theoretical trust assumption: you trust that the server encrypts your data before doing anything with it. We narrow that gap in two ways:
                  </p>
                  <ul class="mt-3 list-disc list-inside space-y-2 text-slate-600 dark:text-slate-400">
                    <li>
                      <strong class="text-slate-800 dark:text-slate-200">Open-source backend:</strong>
                      The full codebase is public so anyone can verify we encrypt before processing and don't retain plaintext.
                    </li>
                    <li>
                      <strong class="text-slate-800 dark:text-slate-200">Redacted schemas:</strong>
                      We use
                      <code class="px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-sm font-mono text-slate-900 dark:text-slate-100">
                        redact
                      </code>
                      at the schema level to minimize the chance of sensitive fields leaking through logs or instrumentation.
                    </li>
                  </ul>
                  <p class="mt-3">
                    Our next major step is native desktop and mobile apps, where encryption moves fully onto the device — so the server only ever sees ciphertext. That's when MOSSLET becomes truly zero-knowledge in the strictest sense.
                  </p>
                </.press_detail_section>

                <.press_detail_section title="What We Don't Collect">
                  <ul class="list-disc list-inside space-y-2 text-slate-600 dark:text-slate-400">
                    <li>
                      No ads, no behavioral analytics, no user profiles built from your activity
                    </li>
                    <li>
                      We use
                      <.link
                        href="https://usefathom.com/ref/6PUHXH"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
                      >
                        Fathom Analytics
                      </.link>
                      (privacy-first, cookieless, GDPR-compliant, honors Do Not Track) for aggregate page view counts on public pages only — all authenticated and private routes are excluded
                    </li>
                    <li>No data sold or shared with third parties</li>
                    <li>We log only what's needed to run the service</li>
                  </ul>
                </.press_detail_section>
              </div>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                About the Team
              </h2>
              <div class="mt-8 space-y-4 text-base/7 text-slate-700 dark:text-slate-300">
                <p>
                  MOSSLET is solo-developed by Mark, with Isabella (pre-K teacher by day, product advisor and chief journal enthusiast by night) shaping the product through ideas and feedback. Mark, John, and Ryan co-founded <strong class="text-slate-900 dark:text-slate-100"><a
                      href="https://mosspiglet.dev"
                      target="_blank"
                      rel="noopener noreferrer"
                    >Moss Piglet Corporation</a></strong>, a family-run public benefit corporation focused on privacy-first, ethical software design. MOSSLET is our flagship service.
                </p>
                <p>
                  John (Mark's dad) serves as advisor and backer — he built and designed GIS systems for NASA and the City of Palo Alto. Ryan (Mark's cousin), a veteran, advises on operations and corporate strategy. Day-to-day development, design, and operations are handled entirely by Mark.
                </p>
                <p>
                  We're bootstrapped and family-funded — no venture capital, no outside investors. We use MOSSLET ourselves and trust it with our own families.
                </p>
              </div>

              <h3 class="mt-12 text-2xl font-bold tracking-tight text-pretty sm:text-3xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                About the Creator
              </h3>
              <div class="mt-6 space-y-4 text-base/7 text-slate-700 dark:text-slate-300">
                <p>
                  I grew up in a family that cared deeply about time together, nature, and tinkering with technology. I built computers with my dad, but I didn't start programming in earnest until I became a father myself. Reading Shoshana Zuboff's
                  <em class="italic text-slate-800 dark:text-slate-200">
                    The Age of Surveillance Capitalism
                  </em>
                  convinced me that the prevailing ad-driven model of technology isn't the future I want for my kids. Mosslet and Moss Piglet Corporation are my attempt to build better options — for my family and for anyone who wants ethical software that is private by design.
                </p>
                <p class="text-sm text-slate-500 dark:text-slate-500 italic">
                  — Mark, Creator of MOSSLET
                </p>
              </div>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Pricing
              </h2>
              <div class="mt-8 space-y-4 text-base/7 text-slate-700 dark:text-slate-300">
                <p>
                  MOSSLET is currently in beta and offers three subscription options:
                </p>
                <ul class="list-disc list-inside space-y-2 text-slate-600 dark:text-slate-400">
                  <li>
                    <strong class="text-slate-800 dark:text-slate-200">Monthly</strong> subscription
                  </li>
                  <li>
                    <strong class="text-slate-800 dark:text-slate-200">Annual</strong> subscription
                  </li>
                  <li>
                    <strong class="text-slate-800 dark:text-slate-200">Lifetime</strong>
                    one-time payment
                  </li>
                </ul>
                <p>
                  See our
                  <.link
                    navigate="/pricing"
                    class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
                  >
                    pricing page
                  </.link>
                  for current rates.
                </p>
              </div>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                For Reviewers
              </h2>
              <div class="mt-8 space-y-4 text-base/7 text-slate-700 dark:text-slate-300">
                <p>
                  We're happy to provide full-access reviewer accounts or redeemable codes for journalists and reviewers. Reach out at
                  <.link
                    href="mailto:press@mosslet.com"
                    class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
                  >
                    press@mosslet.com
                  </.link>
                  and we'll get you set up.
                </p>
              </div>
            </div>
          </div>

          <div class="mx-auto mt-24 max-w-7xl px-6 sm:mt-32 lg:px-8">
            <div class="mx-auto max-w-3xl">
              <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30 transition-all duration-300 ease-out transform-gpu will-change-transform hover:scale-[1.02] hover:shadow-2xl hover:shadow-emerald-500/10">
                <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-300 ease-out bg-gradient-to-br from-teal-50/20 via-emerald-50/10 to-cyan-50/20 dark:from-teal-900/10 dark:via-emerald-900/5 dark:to-cyan-900/10 group-hover:opacity-100">
                </div>
                <div class="absolute inset-0 -z-10 opacity-0 transition-all duration-500 ease-out bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent dark:via-emerald-400/15 group-hover:opacity-100 group-hover:translate-x-full -translate-x-full">
                </div>
                <div class="absolute inset-0 rounded-xl ring-1 transition-all duration-300 ease-out ring-slate-200/60 dark:ring-slate-700/60 group-hover:ring-emerald-500/30 dark:group-hover:ring-emerald-400/30">
                </div>

                <div class="relative p-8 text-center">
                  <div class="mb-4">
                    <span class="inline-flex px-3 py-1.5 rounded-full text-xs font-medium tracking-wide uppercase bg-gradient-to-r from-teal-100 to-emerald-100 text-teal-800 dark:from-teal-900/40 dark:to-emerald-900/40 dark:text-teal-200 border border-teal-300/60 dark:border-teal-600/60">
                      Media Inquiries
                    </span>
                  </div>

                  <h2 class="mb-4 text-xl lg:text-2xl font-bold leading-tight text-slate-900 dark:text-slate-100 transition-all duration-200 ease-out group-hover:text-emerald-700 dark:group-hover:text-emerald-300">
                    <.link href="mailto:press@mosslet.com" class="relative">
                      Get in touch at press@mosslet.com
                      <div class="absolute bottom-0 left-1/2 h-0.5 w-0 transition-all duration-300 ease-out bg-gradient-to-r from-teal-400 to-emerald-400 group-hover:w-full group-hover:left-0">
                      </div>
                    </.link>
                  </h2>

                  <p class="text-base leading-7 text-slate-600 dark:text-slate-400 max-w-lg mx-auto">
                    For press inquiries, review copies, interviews, or additional technical details, email
                    <.link
                      href="mailto:press@mosslet.com"
                      class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 transition-colors duration-200"
                    >
                      press@mosslet.com
                    </.link>
                    and we'll respond promptly.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="pb-24"></div>
    </.layout>
    """
  end

  defp press_fact_card(assigns) do
    ~H"""
    <.liquid_card
      padding="md"
      class="group hover:scale-105 transition-all duration-300 ease-out"
    >
      <:title>
        <div class="flex items-center gap-3">
          <div class={[
            "flex size-10 items-center justify-center rounded-lg bg-gradient-to-r",
            @gradient
          ]}>
            <.phx_icon name={@icon} class="size-6 text-white" />
          </div>
          <span class={[
            "bg-gradient-to-r bg-clip-text text-transparent font-semibold",
            @gradient
          ]}>
            {@title}
          </span>
        </div>
      </:title>
      <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
        {@description}
      </p>
    </.liquid_card>
    """
  end

  defp press_detail_section(assigns) do
    ~H"""
    <div class="group relative overflow-hidden rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm border border-slate-200/60 dark:border-slate-700/60 shadow-lg shadow-slate-900/5 dark:shadow-slate-900/20 p-6 transition-all duration-300 ease-out hover:shadow-xl hover:shadow-emerald-500/5">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-3">
        {@title}
      </h3>
      <div class="text-base/7 text-slate-700 dark:text-slate-300">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Press & Media")
     |> assign_new(:meta_description, fn ->
       "Press and media resources for MOSSLET — the privacy-first social network with an encrypted journal. Find key facts, security details, and contact information for press inquiries."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/press_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "MOSSLET Press & Media — key facts, privacy and security details, and contact information for the privacy-first social network with an encrypted journal"
     )}
  end
end
