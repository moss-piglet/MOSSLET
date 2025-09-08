defmodule MossletWeb.PublicLive.Blog.Blog07 do
  @moduledoc false
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:blog}
      container_max_width={@max_width}
      key={@key}
    >
      <MossletWeb.Components.LandingPage.beta_banner />
      <div class="max-w-screen overflow-x-hidden">
        <div class="grid min-h-dvh grid-cols-1 grid-rows-[1fr_1px_auto_1px_auto] justify-center pt-14.25 [--gutter-width:2.5rem] lg:grid-cols-[var(--gutter-width)_minmax(0,var(--breakpoint-2xl))_var(--gutter-width)]">
          <div class="col-start-1 row-span-full row-start-1 hidden lg:block"></div>
          <div class="text-gray-950 dark:text-white">
            <div hidden=""></div>
            <div class="grid grid-cols-1 xl:grid-cols-[22rem_2.5rem_auto] xl:grid-rows-[1fr_auto]">
              <div class="col-start-2 row-span-2 max-xl:hidden"></div>
              <div class="max-xl:mx-auto max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="mt-16 px-4 text-sm/7 font-medium tracking-widest text-gray-500 dark:text-gray-400 uppercase lg:px-2">
                  <time datetime="2025-05-14T19:00:00.000Z">September 4, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    Smart Doorbells Spying for Insurance Companies
                  </h1>
                </div>
              </div>
              <div class="max-xl:mx-auto max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="flex flex-col gap-4">
                  <div class="flex items-center px-4 py-2 font-medium whitespace-nowrap max-xl:before:-left-[100vw]! max-xl:after:-left-[100vw]! xl:px-2 xl:before:hidden relative before:absolute before:top-0 before:h-px before:w-[200vw] before:right-0 after:absolute after:bottom-0 after:h-px after:w-[200vw] after:right-0">
                    <div class="flex gap-4">
                      <img
                        alt=""
                        loading="lazy"
                        width="36"
                        height="36"
                        decoding="async"
                        data-nimg="1"
                        class="size-12 rounded-full"
                        src={~p"/images/about/mark_photo.jpg"}
                        style="color: transparent;"
                      />
                      <div class="flex flex-col justify-center gap-1 text-sm font-semibold">
                        <div class="text-gray-950 dark:text-white">Mark</div>
                        <div>
                          <.link
                            navigate={~p"/"}
                            class="text-emerald-500 hover:text-emerald-600 dark:text-emerald-400"
                          >
                            MOSSLET
                          </.link>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="max-xl:mx-auto max-xl:mt-16 max-xl:w-full max-xl:max-w-(--breakpoint-md)">
                <div class="px-4 py-2 lg:px-2 relative before:absolute before:top-0 before:h-px before:w-[200vw]  before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <article class="prose prose-blog max-w-(--breakpoint-md) dark:text-gray-400">
                    <p>
                      Ding Dong! Who is it? Surveillance capitalism! Troubling reports reveal that insurance companies are using smart doorbell footage and other home surveillance devices to deny claims, increase premiums, and monitor homeowners' daily activities without their explicit knowledge or consent.
                    </p>

                    <p>
                      What began as a convenient security device to protect your family, and packages, has morphed into a corporate (and state) surveillance tool that fundamentally changes the relationship between you and your insurance provider. When you install a smart doorbell, you're not just protecting your home — you're potentially giving insurance companies (and authorities) a 24/7 window into your private life.
                    </p>
                    <p>
                      Gadget Review recently published an article detailing how smart doorbells are
                      <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.gadgetreview.com/privacy-nightmare-your-doorbell-camera-is-snitching-to-insurance-companies"
                        class="dark:text-gray-200"
                      >
                        snitching to insurance companies
                      </.link>
                      to determine homeowner policy rates without your awareness or consent.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="surveillance-ringing">
                      <a href="#surveillance-ringing" class="anchor dark:text-gray-200">
                        Surveillance ringing
                      </a>
                    </h2>
                    <p>
                      "But it just shows the outside of my house, who cares?" Despite being pointed away from your home, by analyzing the behavior of your visitors, insurance companies (and others) can determine quite a lot about your private life inside. Let's see how it works in terms of insurance:
                      <ul>
                        <li>
                          <strong class="dark:text-gray-200">Data harvesting:</strong>
                          Every visitor, delivery, and daily routine is recorded and analyzed
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Insurance partnerships:</strong>
                          Companies share footage with insurers who use AI to assess "risk factors" in your behavior
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Algorithmic bias:</strong>
                          AI systems may flag normal activities as "suspicious" or "high-risk," leading to unfair treatment
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Privacy erosion:</strong>
                          Your home, once your private sanctuary, becomes a monitored corporate asset
                        </li>
                      </ul>
                      The most insidious part? Many homeowners don't realize they've signed away their privacy rights until it's too late — often when filing a claim.
                    </p>

                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/sept_04_2025_dbsic.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@triwiranto/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Tri Wiranto
                        </.link>
                      </figcaption>
                    </div>

                    <p>
                      Did you have too many parties? Are there frequent visitors? Do you leave packages on your doorstep? All of these normal human behaviors can now be weaponized against you in the form of higher premiums or denied claims.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="beyond-doorbells">
                      <a href="#beyond-doorbells" class="anchor dark:text-gray-200">
                        Beyond doorbells: The expanding web
                      </a>
                    </h2>

                    <p>
                      Smart doorbells are just one thread of an expanding web of surveillance. Insurance companies are increasingly interested in all forms of home surveillance and IoT devices:
                      <ul>
                        <li>Smart thermostats that reveal when you're home (among other things)</li>
                        <li>Security cameras that monitor your daily routines</li>
                        <li>Smart locks that track who enters and leaves</li>
                        <li>Water sensors and smoke detectors that report maintenance issues</li>
                        <li>Connected appliances that reveal usage patterns</li>
                      </ul>
                      Each device represents another data point in an insurance company's risk assessment algorithm, and another way for them to justify raising your rates or denying coverage.
                    </p>
                    <p>
                      These devices could simply be used to provide convenience, security, and support to our life. We already pay once for them at checkout, why do we have to continue to pay with our behavioral data and privacy? Companies could sell a great product to us and let that be it! Why do they have to commodotize our humanity along with it?
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="protecting-your-home-privacy">
                      <a href="#protecting-your-home-privacy" class="anchor dark:text-gray-200">
                        Protecting your home privacy
                      </a>
                    </h2>
                    <p>
                      While the surveillance web is expanding, you still have options to protect your privacy:
                      <ul>
                        <li>
                          <strong class="dark:text-gray-200">Read the fine print:</strong>
                          Understand what data your devices collect and who they share it with
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Choose local storage:</strong>
                          Use security systems that store footage locally rather than in the cloud
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Limit connectivity:</strong>
                          Use devices that don't require internet connections for basic functionality
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Review insurance policies:</strong>
                          Understand how your insurer uses surveillance data in claims decisions
                        </li>
                        <li>
                          <strong class="dark:text-gray-200">Consider alternatives:</strong>
                          Traditional security measures like good lighting and sturdy locks are often just as effective
                        </li>
                      </ul>
                    </p>

                    <p>
                      The rise of smart home surveillance represents a fundamental shift in the balance of power between individuals and corporations. What was once your private domain is increasingly becoming corporate territory, monitored and analyzed for profit.
                    </p>

                    <p>
                      And it doesn't just affect you — it impacts your neighbors, visitors, delivery workers, and anyone who steps within range of these devices. Buying a smart doorbell (eg. Nest, Ring, et al) helps companies create surveillance neighborhoods, where privacy becomes a luxury no one on the street can afford.
                    </p>

                    <p>
                      At <.link
                        navigate={~p"/"}
                        class="dark:text-gray-200"
                      >MOSSLET</.link>, we believe your home should remain your sanctuary. That's why we're committed to building privacy-first services that put you in control, not the other way around. Your private moments should remain private, whether they happen at home or on social media.
                    </p>

                    <p>
                      Thank you for being here and your interest in the growing movement for simple and ethical software. Tell a friend and
                      <.link navigate={~p"/auth/register"} class="dark:text-gray-200">
                        switch to MOSSLET
                      </.link>
                      today to start getting the privacy and protection you deserve.
                    </p>
                  </article>
                </div>
              </div>
            </div>
          </div>
          <div class="row-span-full row-start-1 hidden lg:col-start-3 lg:block"></div>
        </div>
      </div>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(
       :page_title,
       "Blog | Smart Doorbells Spying for Insurance Companies"
     )
     |> assign_new(:meta_description, fn ->
       "Smart doorbells are spying for insurance companies. In this 7th blog post from privacy-first social alternative MOSSLET, we explore how insurance companies are using smart doorbell footage and home surveillance devices to monitor homeowners, deny claims, and increase premiums without explicit consent."
     end)}
  end
end
