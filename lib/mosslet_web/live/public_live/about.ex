defmodule MossletWeb.PublicLive.About do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.PublicLive.Blog.Components

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:about}
      container_max_width={@max_width}
      key={@key}
    >
      <MossletWeb.Components.LandingPage.beta_banner />
      <div class="bg-white dark:bg-gray-950">
        <main class="isolate">
          <%!-- Hero section --%>
          <div class="relative isolate -z-10">
            <svg
              class="absolute inset-x-0 top-0 -z-10 h-[64rem] w-full stroke-gray-200 dark:stroke-gray-800 [mask-image:radial-gradient(32rem_32rem_at_center,white,transparent)]"
              aria-hidden="true"
            >
              <defs>
                <pattern
                  id="1f932ae7-37de-4c0a-a8b0-a6e3b4d44b84"
                  width="200"
                  height="200"
                  x="50%"
                  y="-1"
                  patternUnits="userSpaceOnUse"
                >
                  <path d="M.5 200V.5H200" fill="none" />
                </pattern>
              </defs>
              <svg x="50%" y="-1" class="overflow-visible fill-gray-50 dark:fill-gray-900">
                <path
                  d="M-200 0h201v201h-201Z M600 0h201v201h-201Z M-400 600h201v201h-201Z M200 800h201v201h-201Z"
                  stroke-width="0"
                />
              </svg>
              <rect
                width="100%"
                height="100%"
                stroke-width="0"
                fill="url(#1f932ae7-37de-4c0a-a8b0-a6e3b4d44b84)"
              />
            </svg>
            <div
              class="absolute left-1/2 right-0 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
              aria-hidden="true"
            >
              <div
                class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-[#ff80b5] to-[#9089fc] opacity-30"
                style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
              >
              </div>
            </div>
            <div class="overflow-hidden">
              <div class="mx-auto max-w-7xl px-6 pb-32 pt-36 sm:pt-60 lg:px-8 lg:pt-32">
                <div class="mx-auto max-w-2xl gap-x-14 lg:mx-0 lg:flex lg:max-w-none lg:items-center">
                  <div class="relative w-full lg:max-w-xl lg:shrink-0 xl:max-w-2xl">
                    <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                      We're going back to the future
                    </h1>
                    <p class="mt-8 text-pretty text-lg font-medium text-gray-500 dark:text-gray-400 sm:max-w-md sm:text-xl/8 lg:max-w-none">
                      Social networking has become overwhelming, transformed from a fun connection space into a marketplace filled with cheap ads and less authentic content from friends. We're not interested in selling or harvesting your data. We care about making a service that feels good, keeps you connected to your people, and then lets you get back to real life. No addiction required.
                    </p>
                  </div>
                  <div class="mt-14 flex justify-end gap-8 sm:-mt-44 sm:justify-start sm:pl-20 lg:mt-0 lg:pl-0">
                    <div class="ml-auto w-44 flex-none space-y-8 pt-32 sm:ml-0 sm:pt-80 lg:order-last lg:pt-36 xl:order-none xl:pt-80">
                      <div class="relative">
                        <img
                          src={~p"/images/about/people_in_nature.jpg"}
                          alt="people in nature illustration"
                          class="aspect-[2/3] w-full rounded-xl bg-gray-900/5 object-cover shadow-lg"
                        />
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-gray-900/10">
                        </div>
                      </div>
                    </div>
                    <div class="mr-auto w-44 flex-none space-y-8 sm:mr-0 sm:pt-52 lg:pt-36">
                      <div class="relative">
                        <img
                          src={~p"/images/about/person_in_nature.jpg"}
                          alt="person in nature illustration"
                          class="aspect-[2/3] w-full rounded-xl bg-gray-900/5 object-cover shadow-lg"
                        />
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-gray-900/10">
                        </div>
                      </div>
                      <div class="relative">
                        <img
                          src={~p"/images/about/people_on_computer.jpg"}
                          alt="people on a computer illustration"
                          class="aspect-[2/3] w-full rounded-xl bg-gray-900/5 object-cover shadow-lg"
                        />
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-gray-900/10">
                        </div>
                      </div>
                    </div>
                    <div class="w-44 flex-none space-y-8 pt-32 sm:pt-0">
                      <div class="relative">
                        <img
                          src={~p"/images/about/people_watering_plants.jpg"}
                          alt="people watering plants illustration"
                          class="aspect-[2/3] w-full rounded-xl bg-gray-900/5 object-cover shadow-lg"
                        />
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-gray-900/10">
                        </div>
                      </div>
                      <div class="relative">
                        <img
                          src={~p"/images/about/person_reading.jpg"}
                          alt="person reading illustration"
                          class="aspect-[2/3] w-full rounded-xl bg-gray-900/5 object-cover shadow-lg"
                        />
                        <div class="pointer-events-none absolute inset-0 rounded-xl ring-1 ring-inset ring-gray-900/10">
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Content section --%>
          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our mission
              </h2>
              <div class="mt-6 flex flex-col gap-x-8 gap-y-20 lg:flex-row">
                <div class="lg:w-full lg:max-w-2xl lg:flex-auto">
                  <p class="text-xl/8 text-gray-600 dark:text-gray-400">
                    We are part of the growing movement for simple and ethical software choices. We think social networks shouldn't operate at the expense of your privacy and dignity. Apparently, that's a hot take for a world accustomed to modern social media.
                  </p>
                  <p class="mt-10 max-w-xl text-base/7 text-gray-700 dark:text-gray-300">
                    The alarming trend of authorities targeting individuals because of their opinions expressed online adds to the concern. The utilization of personal photographs, including those of minors, for the training of AI systems presents serious dangers as well. None of this is inevitable. People make these systems and people can change them. We aim to provide a safer, private online space where you can connect without being monitored or having your humanity sold to the highest bidder.
                  </p>
                </div>
                <div class="lg:flex lg:flex-auto lg:justify-center">
                  <dl class="w-64 space-y-8 xl:w-80">
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-gray-600 dark:text-gray-400">
                        Data brokers thwarted
                      </dt>
                      <dd class="text-5xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        2,230
                      </dd>
                    </div>
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-gray-600 dark:text-gray-400">
                        Protected every 24 hours
                      </dt>
                      <dd class="text-5xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        775 mb
                      </dd>
                    </div>
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-gray-600 dark:text-gray-400">
                        Surveillance capitalists blocked
                      </dt>
                      <dd class="text-5xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        186,892
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <%!-- Image section --%>
          <div class="mt-32 sm:mt-40 xl:mx-auto xl:max-w-7xl xl:px-8">
            <img
              src={~p"/images/about/people_at_sunrise.jpg"}
              alt="people watching the sunrise on a mountain illustration"
              class="aspect-[5/2] w-full object-cover xl:rounded-3xl"
            />
          </div>

          <%!-- Values section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our values
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                As a small, family-owned public-benefit company, our values are the foundation of everything we do. They guide our decisions, shape our culture, and ensure we stay true to our mission of empowering people while respecting their privacy and the world around us.
              </p>
            </div>
            <dl class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 text-base/7 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Privacy-first
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We prioritize our customer privacy and data protection first, then consider everything else.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  No Data Selling
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We will never sell or otherwise exploit customer data to third parties.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Customer Control
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We empower our customers to control and manage their data and privacy settings with ease.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Public Benefit
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  As a public-benefit company, we prioritize creating a service that benefits our customers and community.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Ethical Practices
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We promise to adhere to ethical standards in all operations, prioritizing customer well-being over profit.
                </dd>
              </div>
              <div>
                <dt class="font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Continuous Improvement
                </dt>
                <dd class="mt-1 text-gray-600 dark:text-gray-400">
                  We strive to continually improve our service and features based on customer feedback.
                </dd>
              </div>
            </dl>
          </div>

          <%!-- Logo cloud
          <div class="relative isolate -z-10 mt-32 sm:mt-48">
            <div class="absolute inset-x-0 top-1/2 -z-10 flex -translate-y-1/2 justify-center overflow-hidden [mask-image:radial-gradient(50%_45%_at_50%_55%,white,transparent)]">
              <svg class="h-[40rem] w-[80rem] flex-none stroke-gray-200" aria-hidden="true">
                <defs>
                  <pattern
                    id="e9033f3e-f665-41a6-84ef-756f6778e6fe"
                    width="200"
                    height="200"
                    x="50%"
                    y="50%"
                    patternUnits="userSpaceOnUse"
                    patternTransform="translate(-100 0)"
                  >
                    <path d="M.5 200V.5H200" fill="none" />
                  </pattern>
                </defs>
                <svg x="50%" y="50%" class="overflow-visible fill-gray-50">
                  <path d="M-300 0h201v201h-201Z M300 200h201v201h-201Z" stroke-width="0" />
                </svg>
                <rect
                  width="100%"
                  height="100%"
                  stroke-width="0"
                  fill="url(#e9033f3e-f665-41a6-84ef-756f6778e6fe)"
                />
              </svg>
            </div>

            <div class="mx-auto max-w-7xl px-6 lg:px-8">
              <h2 class="text-center text-lg/8 font-semibold text-gray-900 dark:text-gray-100">
                Trusted by our friends and family
              </h2>
              <div class="mx-auto mt-10 grid max-w-lg grid-cols-4 items-center gap-x-8 gap-y-10 sm:max-w-xl sm:grid-cols-6 sm:gap-x-10 lg:mx-0 lg:max-w-none lg:grid-cols-5">
                <img
                  class="col-span-2 max-h-12 w-full object-contain lg:col-span-1"
                  src="https://tailwindcss.com/plus-assets/img/logos/158x48/transistor-logo-gray-900.svg"
                  alt="Transistor"
                  width="158"
                  height="48"
                />
                <img
                  class="col-span-2 max-h-12 w-full object-contain lg:col-span-1"
                  src="https://tailwindcss.com/plus-assets/img/logos/158x48/reform-logo-gray-900.svg"
                  alt="Reform"
                  width="158"
                  height="48"
                />
                <img
                  class="col-span-2 max-h-12 w-full object-contain lg:col-span-1"
                  src="https://tailwindcss.com/plus-assets/img/logos/158x48/tuple-logo-gray-900.svg"
                  alt="Tuple"
                  width="158"
                  height="48"
                />
                <img
                  class="col-span-2 max-h-12 w-full object-contain sm:col-start-2 lg:col-span-1"
                  src="https://tailwindcss.com/plus-assets/img/logos/158x48/savvycal-logo-gray-900.svg"
                  alt="SavvyCal"
                  width="158"
                  height="48"
                />
                <img
                  class="col-span-2 col-start-2 max-h-12 w-full object-contain sm:col-start-auto lg:col-span-1"
                  src="https://tailwindcss.com/plus-assets/img/logos/158x48/statamic-logo-gray-900.svg"
                  alt="Statamic"
                  width="158"
                  height="48"
                />
              </div>
            </div>


          </div>
          --%>

          <%!-- Team section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-48 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our team
              </h2>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                As a small, dedicated team passionate about connection and privacy, we are committed to delivering peace of mind for our customers. We trust MOSSLET for ourselves and hope you will too. Join us on our mission for a better world, today.
              </p>
              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Happily small tech
              </h3>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                We don't chase venture capital or need investors — we're customer-funded and family-owned. We believe in building a sustainable business that puts people first, not profits. Our team is small but mighty, and we take pride in our work.
              </p>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                MOSSLET is run by Mark (developer) and Isabella (marketing). We're located in the United States and take pride in our work. We're always listening to our customers and making decisions for features and improvements based on what you tell us.
              </p>
              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Privacy is our business model
              </h3>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                It's simple, you pay us <em>once</em>
                and we provide you with a service that respects and protects your digital privacy. That's it. We're not in this to get-rich-quick or take the big exit — we're here for the long haul, for you (and us!).
              </p>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                We use MOSSLET and trust it with our own families (unlike the leaders of Big Tech who knowingly forbid their children from using their services). We're tired of surveillance capitalism and its secret control of our lives. We're tired of never-ending subscription fees, making the cost for a service increase the longer you use it, yikes! We think you're tired too, which is why you're probably here.
              </p>

              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Hope for a human future
              </h3>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                MOSSLET is our hope for a better internet and a more human future.
              </p>

              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                A future where you are not raw material in a soul-plundering, mind-shredding, behavior-controlling economic pipeline. In this future you are free to think, feel, believe, and behave as yourself. You can share with your loved ones and not watch your credit score, insurace premium, job opportunties, prison sentences, mortage qualifications, and airline prices be negatively affected.
              </p>

              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                It is a future with a shared reality, with empathy and compassion, with critical thinking. It is a future for everyone, for you and me. It is a future necessary for healthy and prosperous societies, a future necessary for life on Earth.
              </p>

              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                MOSSLET is our small step toward this future. We hope you'll join us.
              </p>
              <p class="mt-6 text-lg/8 text-gray-600 dark:text-gray-400">
                — Isabella & Mark<br />
                <span class="text-xs sm:text-sm bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent italic">
                  Say "hello" at <.link
                    target="_blank"
                    rel="noopener noreferrer"
                    href="mailto:support@mosslet.com"
                  >support@mosslet.com</.link>.
                </span>
              </p>
            </div>
          </div>

          <%!-- Blog section --%>
          <div id="blog" class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                From the blog
              </h2>
              <p class="mt-2 text-lg/8 text-gray-600 dark:text-gray-400">
                Learn about privacy, our company, and our opinions on the latest privacy news.
              </p>
            </div>
            <div class="mx-auto mt-16 grid max-w-2xl auto-rows-fr grid-cols-1 gap-8 sm:mt-20 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <.article_preview
                id="blogPostDBSIC"
                img_source={~p"/images/blog/sept_04_2025_dbsic.jpg"}
                date="September 4, 2025"
                title="Smart Doorbells Spying for Insurance Companies"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/07"}
              />

              <.article_preview
                id="blogPostDKAIS"
                img_source={~p"/images/blog/aug_19_2025_dkais.jpg"}
                date="August 19, 2025"
                title="Disappearing Keyboard on Apple iOS Safari"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/06"}
              />

              <.article_preview
                id="blogPostAUGP"
                img_source={~p"/images/blog/aug_13_2025_augp.jpg"}
                date="August 13, 2025"
                title="Companies Selling AI to Geolocate Your Social Media Photos"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/05"}
              />

              <.article_preview
                id="blogPostHMKYS"
                img_source={~p"/images/blog/june_26_2025_mkys.jpg"}
                date="June 26, 2025"
                title="How MOSSLET Keeps You Safe"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/04"}
              />

              <.article_preview
                id="blogPostMASYDHS"
                img_source={~p"/images/blog/june_10_2025_asdf.jpg"}
                date="June 10, 2025"
                title="Major Airlines Sold Your Data to Homeland Security"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/03"}
              />

              <.article_preview
                id="blogPostAINYCA"
                img_source={~p"/images/blog/may_20_2025_ainy.jpg"}
                date="May 20, 2025"
                title="AI Algorithm Deciding Which Families Are Under Watch For Child Abuse"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/02"}
              />

              <.article_preview
                id="blogPostCFBP"
                img_source={~p"/images/blog/may_14_2025_cfpb.jpg"}
                date="May 14, 2025"
                title="U.S. Government Abandons Rule to Shield Consumers from Data Brokers"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/01"}
              />

              <%!-- More posts... --%>
            </div>
          </div>
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
     |> assign(:page_title, "About")
     |> assign_new(:meta_description, fn ->
       "We are part of the growing movement for simple and ethical software choices. We think social networks shouldn't operate at the expense of your privacy and dignity. Apparently, that's a hot take for a world accustomed to modern social media."
     end)}
  end
end
