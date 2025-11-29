defmodule MossletWeb.PublicLive.About do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.PublicLive.Blog.Components
  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:about}
      container_max_width={@max_width}
      key={@key}
    >
      <%!-- Enhanced liquid metal background --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <main class="isolate">
          <%!-- Hero section with gradient orbs but cleaner background --%>
          <div class="relative isolate">
            <%!-- Floating gradient orbs for liquid metal effect - responsive and contained --%>
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
                <div class="mx-auto max-w-2xl gap-x-14 lg:mx-0 lg:flex lg:max-w-none lg:items-center">
                  <div class="relative w-full lg:max-w-xl lg:shrink-0 xl:max-w-2xl">
                    <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                      Remember when social was simple?
                    </h1>
                    <p class="mt-8 text-pretty text-lg font-medium text-slate-600 dark:text-slate-400 sm:max-w-md sm:text-xl/8 lg:max-w-none transition-colors duration-300 ease-out">
                      Just connecting with friends and family. No ads, no algorithms, just people. MOSSLET brings back that feeling — a simple way to share moments with the people who matter most, then get back to real life.
                    </p>

                    <%!-- Decorative accent line matching other pages --%>
                    <div class="mt-8 flex justify-start">
                      <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                      </div>
                    </div>

                    <%!-- Call to action buttons using design system --%>
                    <div class="mt-10 flex flex-col sm:flex-row gap-4">
                      <.liquid_button
                        navigate="/auth/register"
                        color="teal"
                        variant="primary"
                        icon="hero-rocket-launch"
                        size="lg"
                      >
                        Get Started
                      </.liquid_button>
                      <.liquid_button
                        navigate="/features"
                        color="blue"
                        variant="secondary"
                        icon="hero-sparkles"
                        size="lg"
                      >
                        Explore Features
                      </.liquid_button>
                    </div>
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
                  <p class="text-xl/8 text-slate-600 dark:text-slate-400">
                    We are part of the growing community for simple and ethical software choices. We think social networks shouldn't operate at the expense of your privacy and dignity. Apparently, that's a hot take for a world accustomed to modern social media.
                  </p>
                  <p class="mt-10 max-w-xl text-base/7 text-slate-700 dark:text-slate-300">
                    The alarming trend of authorities targeting individuals because of their opinions expressed online adds to the concern. The utilization of personal photographs, including those of minors, for the training of AI systems presents serious dangers as well. None of this is inevitable. People make these systems and people can change them. We aim to provide a safer, private online space where you can connect without being monitored or having your humanity sold to the highest bidder.
                  </p>
                </div>
                <div class="lg:flex lg:flex-auto lg:justify-center">
                  <dl class="w-64 space-y-8 xl:w-80">
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-slate-600 dark:text-slate-400">
                        Data brokers thwarted
                      </dt>
                      <dd class="text-5xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        2,230
                      </dd>
                    </div>
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-slate-600 dark:text-slate-400">
                        Protected every 24 hours
                      </dt>
                      <dd class="text-5xl font-semibold tracking-tight bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                        775 mb
                      </dd>
                    </div>
                    <div class="flex flex-col-reverse gap-y-4">
                      <dt class="text-base/7 text-slate-600 dark:text-slate-400">
                        Data collection companies blocked
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

          <%!-- Values section with design system cards --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our values
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                As a small, family-owned public-benefit company, our values are the foundation of everything we do. They guide our decisions, shape our culture, and ensure we stay true to our mission of empowering people while respecting their privacy and the world around us.
              </p>
            </div>
            <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-bold">
                    Privacy-first
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We prioritize our customer privacy and data protection first, then consider everything else.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent font-bold">
                    No Data Selling
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We will never sell or otherwise exploit customer data to third parties.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent font-bold">
                    Customer Control
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We empower our customers to control and manage their data and privacy settings with ease.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent font-bold">
                    Public Benefit
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  As a public-benefit company, we prioritize creating a service that benefits our customers and community.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent font-bold">
                    Ethical Practices
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We promise to adhere to ethical standards in all operations, prioritizing customer well-being over profit.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-indigo-500 to-blue-500 bg-clip-text text-transparent font-bold">
                    Continuous Improvement
                  </span>
                </:title>
                <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                  We strive to continually improve our service and features based on customer feedback.
                </p>
              </.liquid_card>
            </div>
          </div>

          <%!-- Team section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-48 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Our team
              </h2>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                As a small, dedicated team passionate about connection and privacy, we are committed to delivering peace of mind for our customers. We trust MOSSLET for ourselves and hope you will too. Join us on our mission for a better world, today.
              </p>
              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Happily small tech
              </h3>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                We don't chase venture capital or need investors — we're customer-funded and family-owned. We believe in building a sustainable business that puts people first, not profits. Our team is small but mighty, and we take pride in our work.
              </p>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                MOSSLET is run by Mark (developer) and Isabella (marketing). We're located in the United States and take pride in our work. We're always listening to our customers and making decisions for features and improvements based on what you tell us.
              </p>
              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Privacy is our business model
              </h3>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                It's simple, you pay us <em>once</em>
                and we provide you with a service that respects and protects your digital privacy. That's it. We're not in this to get-rich-quick or take the big exit — we're here for the long haul, for you (and us!).
              </p>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                We use MOSSLET and trust it with our own families (unlike the leaders of Big Tech who knowingly forbid their children from using their services). We're tired of data collection business models and their influence on our lives. We're tired of never-ending subscription fees, making the cost for a service increase the longer you use it, yikes! We think you're tired too, which is why you're probably here.
              </p>

              <h3 class="mt-10 font-semibold text-lg font-bold tracking-tight text-pretty sm:text-xl lg:text-2xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Hope for a human future
              </h3>
              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                MOSSLET is our hope for a better internet and a more human future.
              </p>

              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                A future where you are not raw material in a soul-plundering, mind-shredding, behavior-controlling economic pipeline. In this future you are free to think, feel, believe, and behave as yourself. You can share with your loved ones and not watch your credit score, insurace premium, job opportunties, prison sentences, mortage qualifications, and airline prices be negatively affected.
              </p>

              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                It is a future with a shared reality, with empathy and compassion, with critical thinking. It is a future for everyone, for you and me. It is a future necessary for healthy and prosperous societies, a future necessary for life on Earth.
              </p>

              <p class="mt-6 text-lg/8 text-slate-600 dark:text-slate-400">
                MOSSLET is our small step toward this future. We hope you'll join us.
              </p>
              <div class="mt-8 flex flex-col sm:flex-row gap-4 items-start">
                <div class="flex-1">
                  <p class="text-lg/8 text-slate-600 dark:text-slate-400">
                    — Isabella & Mark
                  </p>
                  <p class="mt-2 text-sm text-gray-500 dark:text-gray-500 italic">
                    Say "hello" at support@mosslet.com
                  </p>
                </div>
                <.liquid_button
                  href="mailto:support@mosslet.com"
                  color="teal"
                  variant="secondary"
                  icon="hero-envelope"
                  class="flex-shrink-0"
                >
                  Contact Us
                </.liquid_button>
              </div>
            </div>
          </div>

          <%!-- Blog section with design system integration --%>
          <div id="blog" class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                From the blog
              </h2>
              <p class="mt-2 text-lg/8 text-slate-600 dark:text-slate-400">
                Learn about privacy, our company, and our opinions on the latest privacy news.
              </p>
              <div class="mt-8">
                <.liquid_button
                  navigate="/blog"
                  color="blue"
                  variant="secondary"
                  icon="hero-arrow-right"
                >
                  View All Posts
                </.liquid_button>
              </div>
            </div>
            <div class="mx-auto mt-16 grid max-w-2xl auto-rows-fr grid-cols-1 gap-8 sm:mt-20 lg:mx-0 lg:max-w-none lg:grid-cols-3">
              <.article_preview
                id="blogPostUSPMCTHS"
                img_source={~p"/images/blog/nov_27_2025_usfys.jpg"}
                date="November 27, 2025"
                title="Unlock Sessions: Privacy Meets Convenience This Holiday Season"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/09"}
              />

              <.article_preview
                id="blogPostMLIEWMRUP"
                img_source={~p"/images/blog/nov_7_2025_mlemrp.jpg"}
                date="November 7, 2025"
                title="Meta Layoffs Included Employees Who Monitored Risks to User Privacy"
                author_mark?={true}
                author_isabella?={false}
                link={~p"/blog/articles/08"}
              />

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
            </div>
          </div>
        </main>

        <%!-- Spacer for proper footer separation --%>
        <div class="pb-24"></div>
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
       "We are part of the growing community for simple and ethical software choices. We think social networks shouldn't operate at the expense of your privacy and dignity. Apparently, that's a hot take for a world accustomed to modern social media."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/about/about_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "We are part of the growing community for simple and ethical software"
     )}
  end
end
