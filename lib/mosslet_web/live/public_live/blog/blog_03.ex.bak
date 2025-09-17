defmodule MossletWeb.PublicLive.Blog.Blog03 do
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
                  <time datetime="2025-05-14T19:00:00.000Z">June 10, 2025</time>
                </div>
                <div class="mb-6 px-4 lg:px-2 xl:mb-16 relative before:absolute before:top-0 before:h-px before:w-[200vw] before:-left-[100vw] after:absolute after:bottom-0 after:h-px after:w-[200vw] after:-left-[100vw]">
                  <h1 class="inline-block max-w-(--breakpoint-md) text-[2.5rem]/10 font-bold tracking-tight text-pretty text-gray-950 lg:text-6xl dark:text-gray-200">
                    Major Airlines Sold Your Data to Homeland Security
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
                      With the summer months upon us and a sense of travel in the air, it's disappointing to learn about a secretive contract between the Customs and Border Patrol (CBP) and the Airlines Reporting Corporation (ARC) that began in June of 2024 and could extend to 2029.
                    </p>

                    <p>
                      If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security.
                    </p>

                    <p>
                      Thanks to this <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www.404media.co/airlines-dont-want-you-to-know-they-sold-your-flight-data-to-dhs/"
                        class="dark:text-gray-200"
                      >
                      investigation by 404 Media</a>, and the <.link
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://en.wikipedia.org/wiki/Freedom_of_Information_Act_(United_States)"
                        class="dark:text-gray-200"
                      >Freedom of Information Act (FOIA)</.link>, we have proof of this
                      <em>corporate data trickery</em>
                      and can take steps to correct this violation of American civil liberties.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="who-is-the-arc">
                      <a href="#who-is-the-arc" class="anchor dark:text-gray-200">
                        Who is the ARC?
                      </a>
                    </h2>
                    <p>
                      The Airlines Reporting Corporation
                      <a
                        target="_blank"
                        rel="noopener noreferrer"
                        href="https://www2.arccorp.com/about-us/leadership-governance?utm_source=Global_Navigation#board-of-directors"
                        class="dark:text-gray-200"
                      >
                        board of directors
                      </a>
                      is made up of executives from the major airlines: Air Canada, Air France, Alaska Airlines, American Airlines, Delta Air Lines, JetBlue Airways, Lufthansa, and Southwest Airlines. They are a
                      <em>data broker</em>
                      that collects and monetizes the data on all of their airline passengers (see <.link
                        navigate={~p"/blog/articles/01"}
                        class="dark:text-gray-200"
                      >our article on data brokers</.link>).
                    </p>
                    <p>
                      The ARC also facilitates business between the airlines and travel agencies like Expedia. The sale of passenger data to the United States government is part of the data broker's Travel Intelligence Program (TIP). This TIP program updates the travel data of passengers every single day and "contains more than
                      <em>1 billion records</em>
                      spanning 39 months of past and future travel."
                    </p>

                    <p>
                      Anyone with access to the TIP program can search for airline passengers by name, credit card, or airline.
                    </p>

                    <div data-media="true">
                      <div class="not-prose relative overflow-hidden rounded-xl">
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-slate-950/10 ring-inset dark:ring-white/10">
                        </div>
                        <img src={~p"/images/blog/june_10_2025_asdf.jpg"} />
                      </div>
                      <figcaption class="flex justify-end">
                        artwork by
                        <.link
                          target="_blank"
                          rel="noopener noreferrer"
                          href="https://unsplash.com/@mylenecaneso/illustrations"
                          class="ml-1 dark:text-gray-200"
                        >
                          Mylene Cañeso
                        </.link>
                      </figcaption>
                    </div>

                    <hr class="dark:border-gray-700" />
                    <h2 id="loophole-for-surveillance">
                      <a href="#loophole-for-surveillance" class="anchor dark:text-gray-200">
                        A loophole for surveillance
                      </a>
                    </h2>

                    <p>
                      We mentioned earlier our
                      <.link navigate={~p"/blog/articles/01"} class="dark:text-gray-200">
                        first blog article
                      </.link>
                      covering the government's refusal to protect Americans from data brokers, a decision that functions to keep alive a loophole for surveillance — legally outsourcing the spying on American citizens to private corporations.
                    </p>
                    <p>
                      Not too long ago the American public rejected this kind of mass surveillance, then along came the tragedy on 9/11 and our leaders found a new argument to passify the public as they began bypassing our civil liberties and legal protections afforded us by the Constitution of the United States of America.
                    </p>

                    <hr class="dark:border-gray-700" />
                    <h2 id="what-you-can-do">
                      <a href="#what-you-can-do" class="anchor dark:text-gray-200">
                        What you can do
                      </a>
                    </h2>
                    <p>
                      As far as we know, the data in the ARC's Travel Intelligence Program is collected from third party travel agencies like Expedia. So,
                      <strong class="dark:text-gray-200">
                        book your flights directly with the airline
                      </strong>
                      to possibly avoid this spying.
                    </p>
                    <p>
                      Here are your steps for change:
                      <ol>
                        <li>
                          Write and call your congressmembers (try <.link
                            target="_blank"
                            rel="noopener noreferrer"
                            href="https://5calls.org/"
                            class="dark:text-gray-200"
                          >5calls.org</.link>).
                        </li>
                        <li>
                          Contact your airline and tell them to stop selling your data to the government.
                        </li>
                        <li>Book your air travel directly with the airline.</li>
                        <li>
                          Read the Electronic Frontier Foundation's
                          <.link
                            target="_blank"
                            rel="noopener noreferrer"
                            href="https://www.eff.org/press/releases/digital-privacy-us-border-new-how-guide-eff"
                            class="dark:text-gray-200"
                          >
                            privacy tips
                          </.link>
                          at the border.
                        </li>
                      </ol>
                      Lastly, you can further protect your rights and your information by deleting your Big Tech social accounts and
                      <.link navigate={~p"/"} class="dark:text-gray-200">switching to MOSSLET</.link>
                      today.
                    </p>

                    <p>
                      Thank you for being here and your interest in the growing movement for simple and ethical software. I look forward to writing about something happier next time — like all the ways MOSSLET keeps you safe.
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
       "Blog | Major Airlines Sold Your Data to Homeland Security"
     )
     |> assign_new(:meta_description, fn ->
       "If flying on a major airline wasn't trouble enough, with increasing prices and crashes (due to faulty Boeing airplanes and understaffed and outdated air traffic control systems), the airlines have also been secretly selling passenger data to the Department of Homeland Security."
     end)}
  end
end
