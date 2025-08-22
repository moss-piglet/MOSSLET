defmodule MossletWeb.PublicLive.Blog.Blog06 do
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
                  <time datetime="2025-05-14T19:00:00.000Z">August 19, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    Disappearing Keyboard on Apple iOS Safari
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
                      For anyone using Apple's iOS Safari browser, you may have noticed that when you tap into a password input field you get an iOS popup to create a password but the onscreen keyboard never appears. This is a known issue from a security update that was released during iOS 13.
                    </p>

                    <p>
                      This is great if you want Apple to create a password for you, and not so great if you want to create your own password with the onscreen keyboard. We have encountered this annoyance when trying to create a new account, so we thought we'd share some options for a quick workaround:
                      <ul>
                        <li>
                          Disable "Autofill Passwords" in iOS
                        </li>
                        <li>
                          Use our sparkles (<.phx_icon
                            name="hero-sparkles"
                            class="inline-flex size-5"
                          />) button to generate a secure password and simply copy/paste it into the password confirmation field — just make sure you don't forget it!
                        </li>
                        <li>
                          Use Apple's automated suggestion to create a password and then copy/paste it into the password confirmation field
                        </li>
                        <li>
                          Use a different browser
                        </li>
                      </ul>
                      We recommend disabling "Autofill Passwords" in your iOS settings while on MOSSLET, and then using our secure password generator to make one for you. You can learn more about
                      <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.eff.org/dice"
                        class="dark:text-gray-200"
                      >
                        how we generate passwords
                      </.link>
                      based on the Electronic Frontier Foundation's best practices. ✌️
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="quick-ios18-workarounds">
                      <a href="#quick-ios18-workarounds" class="anchor dark:text-gray-200">
                        Quick iOS 18 Workarounds
                      </a>
                    </h2>
                    <p>
                      Disabling auto-filling passwords is the easiet way to ensure you have access to your keyboard when using Safari on your mobile phone. To do this on iOS 18 follow these instructions:
                    </p>
                    <p>
                      <ol>
                        <li>
                          Open <strong class="dark:text-gray-200">Settings</strong> on your iOS device
                        </li>
                        <li>
                          Select <strong class="dark:text-gray-200">General</strong>
                        </li>
                        <li>
                          Select <strong class="dark:text-gray-200">Autofill & Passwords</strong>
                          (you may have to search or scroll to find it)
                        </li>
                        <li>
                          Toggle off <strong class="dark:text-gray-200">Autofill Passwords</strong>
                        </li>
                      </ol>
                    </p>

                    <p>
                      For other iOS versions we recommend searching "disable autofill passwords in iOS" in <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://duckduckgo.com/"
                        class="dark:text-gray-200"
                      >DuckDuckGo</.link>.
                    </p>

                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/aug_19_2025_dkais.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@riswanr_/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Riswan Ratta
                        </.link>
                      </figcaption>
                    </div>

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
       "Blog | Disappearing Keyboard on Apple iOS Safari"
     )
     |> assign_new(:meta_description, fn ->
       "Quick workarounds for the disappearing keyboard on Apple iOS Safari. In this 6th blog post, from privacy-first social alternative MOSSLET, we share quick and easy tips for getting your onscreen keyboard back when using Apple iOS Safari."
     end)}
  end
end
