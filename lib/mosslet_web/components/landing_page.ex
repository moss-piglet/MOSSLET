defmodule MossletWeb.Components.LandingPage do
  @moduledoc """
  A set of components for use in a landing page.
  """
  use Phoenix.Component
  use PetalComponents, except: [:button]
  use MossletWeb, :verified_routes
  # import Phoenix.LiveView.Helpers
  use Gettext, backend: MossletWeb.Gettext
  import MossletWeb.CoreComponents

  alias Phoenix.LiveView.JS
  # alias MossletWeb.Router.Helpers, as: Routes

  def hero(assigns) do
    assigns =
      assigns
      |> assign_new(:logo_cloud_title, fn -> nil end)
      |> assign_new(:cloud_logo, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)
      |> assign_new(:title, fn -> gettext("Welcome") end)
      |> assign_new(:image_src, fn -> nil end)
      |> assign_new(:features, fn ->
        [
          %{
            title: "Groups",
            description:
              "Share and remember with the people in your life, no one else. Your memories are yours.",
            icon: :user_group,
            early_access: true
          },
          %{
            title: "Memories",
            description:
              "Share and remember with the people in your life, no one else. Your memories are yours.",
            icon: :photo,
            early_access: true
          },
          %{
            title: "People",
            description:
              "Your one stop-shop for managing your relationships, complete with a people queue for privacy.",
            icon: :user_group,
            early_access: true
          },
          %{
            title: "Roadmap",
            description:
              "See what's in store, vote, request new features, and help shape the future.",
            icon: :map,
            early_access: true
          },
          %{
            title: "Breach Alerts",
            description:
              "Private and secure checks against the HaveIBeenPwned database, and from your settings, let you know if your email or password has been compromised.",
            icon: :exclamation,
            early_access: false
          },
          %{
            title: "Data Destroyer",
            description:
              "When you delete something, it's gone instantly (and forever after 7 days). Easy and under your control.",
            icon: :trash,
            early_access: false
          },
          %{
            title: "Blind Requests",
            description:
              "Receive the info you need to accept/decline a new relationship without revealing anything, including whether or not you even have an account.",
            icon: :eye_off,
            early_access: false
          },
          %{
            title: "Connections",
            description:
              "Only the people you choose can connect, share, and see information about you.",
            icon: :share,
            early_access: false
          }
        ]
      end)

    ~H"""
    <section id="hero">
      <.beta_banner />
      <.container class="bg-white dark:bg-gray-950">
        <div class="relative isolate px-6 lg:px-8">
          <div
            class="absolute inset-x-0 -top-40 -z-10 transform-gpu overflow-hidden blur-3xl sm:-top-80"
            aria-hidden="true"
          >
            <div
              class="relative left-[calc(50%-11rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 rotate-[30deg] bg-gradient-to-tr from-[#9ACF65] to-[#8BE8E8] opacity-30 sm:left-[calc(50%-30rem)] sm:w-[72.1875rem]"
              style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
            >
            </div>
          </div>
          <div class="mx-auto max-w-2xl pb-32 pt-24 sm:pb-48 sm:pt-32 lg:pb-56">
            <div class="hidden sm:mb-8 sm:flex sm:justify-center">
              <div class="relative rounded-full px-3 py-1 text-sm leading-6 text-gray-600 dark:text-gray-400 ring-1 ring-gray-900/10 dark:ring-gray-100/10 hover:ring-gray-900/20 dark:hover:ring-gray-100/20">
                The fight for democracy in the age of surveillance
                <a
                  href="https://journals.sagepub.com/doi/full/10.1177/26317877221129290"
                  rel="noopener"
                  target="_blank"
                  class="font-semibold text-emerald-600"
                >
                  <span class="absolute inset-0" aria-hidden="true"></span>Read more
                  <span aria-hidden="true">&rarr;</span>
                </a>
              </div>
            </div>
            <div class="text-center">
              <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                A social alternative that's simple and privacy-first
              </h1>
              <p class="mt-6 text-lg leading-8 text-gray-600 text-balance dark:text-gray-400">
                Ditch intrusive and stressful Big Tech social platforms for MOSSLET — an alternative to Facebook, Twitter, and Instagram that's simple and privacy-first. Experience peace of mind.
              </p>
              <div class="mt-10 flex items-center justify-center gap-x-6">
                <.button
                  link_type="live_redirect"
                  to="/auth/register"
                  class="!rounded-full bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-500"
                >
                  Register today
                </.button>
                <.button
                  link_type="live_redirect"
                  to="/auth/sign_in"
                  variant="outline"
                  class="!rounded-full"
                >
                  Sign in
                </.button>
                <%!--
                <.button
                  id="mosslet-demo-video"
                  link_type="a"
                  to="https://www.loom.com/share/f41b37f6c5424dad876847f70298aee9?sid=a73c020a-bb60-4fe6-b49b-947fadee1e21"
                  variant="outline"
                  class="!rounded-full"
                  target="_blank"
                  rel="_noopener"
                  phx-hook="TippyHook"
                  data-tippy-content="Watch a quick 10 minute demo"
                >
                  <svg
                    aria-hidden="true"
                    class="h-3 w-3 flex-none fill-emerald-600 group-active:fill-current"
                  >
                    <path d="m9.997 6.91-7.583 3.447A1 1 0 0 1 1 9.447V2.553a1 1 0 0 1 1.414-.91L9.997 5.09c.782.355.782 1.465 0 1.82Z" />
                  </svg>
                  <span class="ml-3">Watch video</span>
                </.button>
                --%>
              </div>
            </div>
          </div>
          <div
            class="absolute inset-x-0 top-[calc(100%-13rem)] -z-10 transform-gpu overflow-hidden blur-3xl sm:top-[calc(100%-30rem)]"
            aria-hidden="true"
          >
            <div
              class="relative left-[calc(50%+3rem)] aspect-[1155/678] w-[36.125rem] -translate-x-1/2 bg-gradient-to-tr from-[#9ACF65] to-[#8BE8E8] opacity-30 sm:left-[calc(50%+36rem)] sm:w-[72.1875rem]"
              style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
            >
            </div>
          </div>
        </div>

        <%!-- Pricing table --%>
        <.pricing_comparison hero_intro?={true} pricing_link?={true} />
      </.container>
    </section>
    """
  end

  def logo_cloud(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> nil end)
      |> assign_new(:cloud_logo, fn -> nil end)

    ~H"""
    <div id="logo-cloud" class="container px-4 mx-auto">
      <%= if @title do %>
        <h2 class="mb-10 text-2xl text-center text-gray-500 fade-in-animation dark:text-gray-300">
          {@title}
        </h2>
      <% end %>

      <div class="flex flex-wrap justify-center">
        <%= for logo <- @cloud_logo do %>
          <div class="w-full p-4 md:w-1/3 lg:w-1/6">
            <div class="py-4 lg:py-8">
              {render_slot(logo)}
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def beta_banner(assigns) do
    ~H"""
    <div class="relative isolate flex z-10 items-center gap-x-6 overflow-hidden bg-emerald-600 px-6 py-2.5 sm:px-3.5 sm:before:flex-1">
      <div class="flex flex-wrap items-center gap-x-4 gap-y-2 pt-2 lg:pt-0">
        <p class="text-sm/6 text-white">
          <strong class="font-semibold">Special Price</strong><svg
            viewBox="0 0 2 2"
            class="mx-2 inline size-0.5 fill-current"
            aria-hidden="true"
          ><circle cx="1" cy="1" r="1" /></svg>Join us for 40% off while we're in beta and have privacy now for life.
        </p>

        <.button
          link_type="live_redirect"
          to="/auth/register"
          variant="outline"
          class="!rounded-full text-white hover:text-emerald-600 dark:hover:text-white"
        >
          Sign up today <span aria-hidden="true" class="ml-1">&rarr;</span>
        </.button>
      </div>
      <div class="flex flex-1 justify-end"></div>
    </div>
    """
  end

  def features(assigns) do
    assigns =
      assigns
      |> assign_new(:features, fn -> [] end)
      |> assign_new(:grid_classes, fn -> "md:grid-cols-3" end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section id="features">
      <div class="bg-white dark:bg-gray-950 py-24 sm:py-32">
        <div class="mx-auto max-w-7xl px-6 lg:px-8">
          <div class="mx-auto max-w-2xl lg:mx-0">
            <h2 class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400">
              Everything you want to share
            </h2>
            <p class="mt-2 text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl">
              With privacy you need.
            </p>
            <p class="mt-6 text-lg leading-8 text-gray-500 dark:text-gray-400">
              Easily share with people in your life in real-time without thinking twice. Zero
              <.link
                navigate={~p"/#general"}
                class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
              >
                dark patterns
              </.link>
              means you can say goodbye to digital addiction and the anxiety of wondering how your life on the web affects your life outside. MOSSLET is simple and privacy-first.
            </p>
          </div>
          <dl class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 text-base leading-7  text-gray-500 dark:text-gray-400 sm:grid-cols-2 lg:mx-0 lg:max-w-none lg:gap-x-16">
            <div class="relative pl-9">
              <dt class="inline font-semibold text-gray-900 dark:text-gray-100">
                <svg
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M5.5 17a4.5 4.5 0 01-1.44-8.765 4.5 4.5 0 018.302-3.046 3.5 3.5 0 014.504 4.272A4 4 0 0115 17H5.5zm3.75-2.75a.75.75 0 001.5 0V9.66l1.95 2.1a.75.75 0 101.1-1.02l-3.25-3.5a.75.75 0 00-1.1 0l-3.25 3.5a.75.75 0 101.1 1.02l1.95-2.1v4.59z"
                    clip-rule="evenodd"
                  />
                </svg>
                Distributed cloud.
              </dt>
              <dd class="inline">
                Memories and other multimedia are stored on a private, encrypted, and distributed cloud network spread across the world. If Amazon and Facebook go down, your data and your ability to continue sharing and connecting on MOSSLET stays up.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-gray-900 dark:text-gray-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="currentColor"
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                >
                  <path
                    fill-rule="evenodd"
                    d="M8.25 6.75a3.75 3.75 0 1 1 7.5 0 3.75 3.75 0 0 1-7.5 0ZM15.75 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM2.25 9.75a3 3 0 1 1 6 0 3 3 0 0 1-6 0ZM6.31 15.117A6.745 6.745 0 0 1 12 12a6.745 6.745 0 0 1 6.709 7.498.75.75 0 0 1-.372.568A12.696 12.696 0 0 1 12 21.75c-2.305 0-4.47-.612-6.337-1.684a.75.75 0 0 1-.372-.568 6.787 6.787 0 0 1 1.019-4.38Z"
                    clip-rule="evenodd"
                  />
                  <path d="M5.082 14.254a8.287 8.287 0 0 0-1.308 5.135 9.687 9.687 0 0 1-1.764-.44l-.115-.04a.563.563 0 0 1-.373-.487l-.01-.121a3.75 3.75 0 0 1 3.57-4.047ZM20.226 19.389a8.287 8.287 0 0 0-1.308-5.135 3.75 3.75 0 0 1 3.57 4.047l-.01.121a.563.563 0 0 1-.373.486l-.115.04c-.567.2-1.156.349-1.764.441Z" />
                </svg>
                Groups, Memories, Posts, and more.
              </dt>
              <dd class="inline">
                Make Groups to chat live, store photos for yourself or share with others in Memories, and express your thoughts with Posts — always in real-time with the privacy you need. All images are checked for safety against a fine-tuned, pre-trained AI model running on our private servers before being uploaded.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-gray-900 dark:text-gray-100">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0 3.181 3.183a8.25 8.25 0 0 0 13.803-3.7M4.031 9.865a8.25 8.25 0 0 1 13.803-3.7l3.181 3.182m0-4.991v4.99"
                  />
                </svg>
                The right to start over.
              </dt>
              <dd class="inline">
                Empower your personal growth and discovery by starting fresh whenever you want. Easily delete all of your Connections, Posts, Memories, Groups, Remarks and more across our service in real-time without deleting your account. On MOSSLET, you're in control of your identity and free to be any version of your self, every time.
              </dd>
            </div>
            <div class="relative pl-9">
              <dt class="inline font-semibold text-gray-900 dark:text-gray-100">
                <svg
                  class="absolute left-1 top-1 h-5 w-5 text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 1a4.5 4.5 0 00-4.5 4.5V9H5a2 2 0 00-2 2v6a2 2 0 002 2h10a2 2 0 002-2v-6a2 2 0 00-2-2h-.5V5.5A4.5 4.5 0 0010 1zm3 8V5.5a3 3 0 10-6 0V9h6z"
                    clip-rule="evenodd"
                  />
                </svg>
                Asymmetric encryption.
              </dt>
              <dd class="inline">
                Strong public-key cryptography with a password-derived key keeps your data private to you. Only your password can unlock your account, its data, and enable you to share with others. Our databases are on a closed, private network protected with the secure WireGuard protocol.
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </section>
    """
  end

  def solo_feature(assigns) do
    assigns =
      assigns
      |> assign_new(:inverted, fn -> false end)
      |> assign_new(:background_color, fn -> "primary" end)
      |> assign_new(:inner_block, fn -> nil end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="benefits"
      class="overflow-hidden transition duration-500 ease-in-out bg-gray-50 md:pt-0 dark:bg-gray-800 dark:text-white"
      data-offset="false"
    >
      <.container max_width={@max_width}>
        <div class={
          "#{if @inverted, do: "flex-row-reverse", else: ""} flex flex-wrap items-center gap-20 py-32 md:flex-nowrap"
        }>
          <div class="md:w-1/2 stagger-fade-in-animation">
            <div class="mb-5 text-3xl font-bold md:mb-7 fade-in-animation md:text-5xl">
              {@title}
            </div>

            <div class="space-y-4 text-lg font-light md:text-xl md:space-y-5">
              <p class="fade-in-animation">
                {@description}
              </p>
            </div>
            <%= if @inner_block do %>
              <div class="fade-in-animation">
                {render_slot(@inner_block)}
              </div>
            <% end %>
          </div>

          <div class="w-full md:w-1/2 md:mt-0">
            <div class={
              "#{if @background_color == "primary", do: "from-primary-200 to-primary-600 bg-primary-animation"} #{if @background_color == "secondary", do: "from-secondary-200 to-secondary-600 bg-secondary-animation"} relative flex items-center justify-center w-full p-16 bg-gradient-to-r rounded-3xl"
            }>
              <img
                class="z-10 w-full fade-in-animation solo-animation max-h-[500px]"
                src={@image_src}
                alt="Screenshot"
              />
            </div>
          </div>
        </div>
      </.container>
    </section>
    """
  end

  def testimonials_initial(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> gettext("Testimonials") end)
      |> assign_new(:testimonials, fn -> [] end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="testimonials"
      class="relative z-10 transition duration-500 ease-in-out bg-white py-36 dark:bg-gray-900"
    >
      <div class="overflow-hidden content-wrapper">
        <.container max_width={@max_width} class="relative z-10">
          <div class="mb-5 text-center md:mb-12 section-header stagger-fade-in-animation">
            <div class="mb-3 text-3xl font-bold leading-none dark:text-white md:mb-5 fade-in-animation md:text-5xl">
              {@title}
            </div>
          </div>

          <div class="solo-animation fade-in-animation flickity">
            <%= for testimonial <- @testimonials do %>
              <.testimonial_panel {testimonial} />
            <% end %>
          </div>
        </.container>
      </div>
    </section>

    <script phx-update="ignore" id="testimonials-js" type="module">
      // Flickity allows for a touch-enabled slideshow - used for testimonials
      import flickity from 'https://cdn.skypack.dev/flickity@2';

      let el = document.querySelector(".flickity");

      if(el){
        new flickity(el, {
          cellAlign: "left",
          prevNextButtons: false,
          adaptiveHeight: false,
          cellSelector: ".carousel-cell",
        });
      }
    </script>

    <link rel="stylesheet" href="https://unpkg.com/flickity@2/dist/flickity.min.css" />
    <style>
      /* Modify the testimonial slider to go off the page */
      #testimonials .flickity-viewport {
        overflow: unset;
      }

      #testimonials .flickity-page-dots {
        position: relative;
        bottom: unset;
        margin-top: 40px;
        text-align: center;
      }

      #testimonials .flickity-page-dots .dot {
        background: #3b82f6;
        transition: 0.3s all ease;
        opacity: 0.35;
        margin: 0;
        margin-right: 10px;
      }

      #testimonials .flickity-page-dots .dot.is-selected {
        opacity: 1;
      }

      .dark #testimonials .flickity-page-dots .dot {
        background: white;
      }
    </style>
    """
  end

  def testimonial_panel(assigns) do
    ~H"""
    <div class="w-full p-6 mr-10 overflow-hidden transition duration-500 ease-in-out rounded-lg shadow-lg text-gray-700 md:p-8 md:w-8/12 lg:w-5/12 bg-primary-50 dark:bg-gray-700 dark:text-white carousel-cell last:mr-0">
      <blockquote class="mt-6 md:flex-grow md:flex md:flex-col">
        <div class="relative text-lg font-medium md:flex-grow">
          <svg
            class="absolute top-[-20px] left-0 w-8 h-8 transform -translate-x-3 -translate-y-2 text-primary-500"
            fill="currentColor"
            viewBox="0 0 32 32"
            aria-hidden="true"
          >
            <path d="M9.352 4C4.456 7.456 1 13.12 1 19.36c0 5.088 3.072 8.064 6.624 8.064 3.36 0 5.856-2.688 5.856-5.856 0-3.168-2.208-5.472-5.088-5.472-.576 0-1.344.096-1.536.192.48-3.264 3.552-7.104 6.624-9.024L9.352 4zm16.512 0c-4.8 3.456-8.256 9.12-8.256 15.36 0 5.088 3.072 8.064 6.624 8.064 3.264 0 5.856-2.688 5.856-5.856 0-3.168-2.304-5.472-5.184-5.472-.576 0-1.248.096-1.44.192.48-3.264 3.456-7.104 6.528-9.024L25.864 4z">
            </path>
          </svg>
          <p class="relative">
            {@content}
          </p>
        </div>
        <footer class="mt-8">
          <div class="flex items-start">
            <div class="inline-flex flex-shrink-0 border-2 border-white rounded-full">
              <img class="w-12 h-12 rounded-full" src={@image_src} alt="" />
            </div>
            <div class="ml-4">
              <div class="text-base font-medium">{@name}</div>
              <div class="text-base font-semibold">{@title}</div>
            </div>
          </div>
        </footer>
      </blockquote>
    </div>
    """
  end

  def pricing(assigns) do
    assigns =
      assigns
      |> assign_new(:plans, fn -> [] end)
      |> assign_new(:max_width, fn -> "lg" end)

    ~H"""
    <section
      id="pricing"
      class="py-24 transition duration-500 ease-in-out text-gray-700 md:py-32 dark:bg-gray-800 bg-gray-50 dark:text-white stagger-fade-in-animation"
    >
      <.container max_width={@max_width}>
        <div class="mx-auto mb-16 text-center md:mb-20 lg:w-7/12 ">
          <div class="mb-5 text-3xl font-bold md:mb-7 md:text-5xl fade-in-animation">
            {@title}
          </div>
          <div class="text-lg font-light anim md:text-2xl fade-in-animation">
            {@description}
          </div>
        </div>

        <div class="grid items-start max-w-sm gap-8 mx-auto lg:grid-cols-3 lg:gap-6 lg:max-w-none">
          <%= for plan <- @plans do %>
            <.pricing_table {plan} />
          <% end %>
        </div>
      </.container>
    </section>
    """
  end

  def pricing_table(assigns) do
    assigns =
      assigns
      |> assign_new(:most_popular, fn -> false end)
      |> assign_new(:currency, fn -> "$" end)
      |> assign_new(:unit, fn -> "/m" end)

    ~H"""
    <div class="relative flex flex-col h-full p-6 transition duration-500 ease-in-out rounded-lg bg-gray-200 dark:bg-gray-900 fade-in-animation">
      <%= if @most_popular do %>
        <div class="absolute top-0 right-0 mr-6 -mt-4">
          <div class="inline-flex px-3 py-1 mt-px text-sm font-semibold text-green-600 bg-green-200 rounded-full">
            Most Popular
          </div>
        </div>
      <% end %>

      <div class="pb-4 mb-4 transition duration-500 ease-in-out border-b border-gray-300 dark:border-gray-700">
        <div class="mb-1 text-2xl font-bold leading-snug tracking-tight dark:text-primary-500 text-primary-600">
          {@name}
        </div>

        <div class="inline-flex items-baseline mb-2">
          <span class="text-2xl font-medium text-gray-600 dark:text-gray-400">
            {@currency}
          </span>
          <span class="text-3xl font-extrabold leading-tight transition duration-500 ease-in-out text-gray-900 dark:text-gray-50">
            {@price}
          </span>
          <span class="font-medium text-gray-600 dark:text-gray-400">{@unit}</span>
        </div>

        <div class="text-gray-600 dark:text-gray-400">
          {@description}
        </div>
      </div>

      <div class="mb-3 font-medium text-gray-700 dark:text-gray-200">
        Features include:
      </div>

      <ul class="-mb-3 text-gray-600 dark:text-gray-400 grow">
        <%= for feature <- @features do %>
          <li class="flex items-center mb-3">
            <.icon name="hero-check" solid class="w-3 h-3 mr-3 text-green-500 fill-current shrink-0" />
            <span>{feature}</span>
          </li>
        <% end %>
      </ul>

      <div class="p-3 mt-6 ">
        <.button link_type="a" to={@sign_up_path} class="w-full rounded-full" label="Sign up today" />
      </div>
    </div>
    """
  end

  def load_js_animations(assigns) do
    ~H"""
    <script type="module">
      // Use GSAP for animations
      // https://greensock.com/gsap/
      import gsap from 'https://cdn.skypack.dev/gsap@3.10.4';

      // Put it on the window for when you want to try out animations in the console
      window.gsap = gsap;

      // A plugin for GSAP that detects when an element enters the viewport - this helps with timing the animation
      import ScrollTrigger from "https://cdn.skypack.dev/gsap@3.10.4/ScrollTrigger";
      gsap.registerPlugin(ScrollTrigger);

      animateHero();
      setupPageAnimations();

      // This is needed to ensure the animations timings are correct as you scroll
      setTimeout(() => {
        ScrollTrigger.refresh(true);
      }, 1000);

      function animateHero() {

        // A timeline just means you can chain animations together - one after another
        // https://greensock.com/docs/v3/GSAP/gsap.timeline()
        const heroTimeline = gsap.timeline({});

        heroTimeline
          .to("#hero .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
            duration: 1,
          })
          .to("#hero-image", {
            opacity: 1,
            x: 0,
            duration: 0.4
          }, ">-1.3")
          .to("#logo-cloud .fade-in-animation", {
            opacity: 1,
            y: 0,
            stagger: 0.1,
            ease: "power2.out",
          })
      }

      function setupPageAnimations() {

        // This allows us to give any individual HTML element the class "solo-animation"
        // and that element will fade in when scrolled into view
        gsap.utils.toArray(".solo-animation").forEach((item) => {
          gsap.to(item, {
            y: 0,
            opacity: 1,
            duration: 0.5,
            ease: "power2.out",
            scrollTrigger: {
              trigger: item,
            },
          });
        });

        // Add the class "stagger-fade-in-animation" to a parent element, then all elements within it
        // with the class "fade-in-animation" will fade in on scroll in a staggered formation to look
        // more natural than them all fading in at once
        gsap.utils.toArray(".stagger-fade-in-animation").forEach((stagger) => {
          const children = stagger.querySelectorAll(".fade-in-animation");
          gsap.to(children, {
            opacity: 1,
            y: 0,
            ease: "power2.out",
            stagger: 0.15,
            duration: 0.5,
            scrollTrigger: {
              trigger: stagger,
              start: "top 75%",
            },
          });
        });
      }
    </script>
    """
  end

  def render_pricing_feature(assigns) do
    assigns =
      assigns
      |> assign_new(:icon_class, fn -> "" end)

    ~H"""
    <li class="flex items-center w-full py-2 fade-in-animation">
      <svg
        class={"#{@icon_class} flex-shrink-0 mr-3"}
        width="16"
        height="16"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M8 0a8 8 0 100 16A8 8 0 008 0zm4.471 6.471l-5.04 5.04a.666.666 0 01-.942 0L4.187 9.21a.666.666 0 11.942-.942l1.831 1.83 4.569-4.568a.666.666 0 11.942.942z"
          fill="#FFF"
          class="fill-current"
          fill-rule="nonzero"
        />
      </svg>

      <div class="text-left">{@text}</div>
    </li>
    """
  end

  def myob(assigns) do
    assigns = assigns

    ~H"""
    <div id="myob" class="bg-white dark:bg-gray-900 py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="flex flex-col text-sm sm:text-xl sm:font-medium lg:text-2xl/8">
          <p>It's none of our business where you go to school.</p>
          <p>It's none of our business who you go on vacation with.</p>
          <p>It's none of our business where your sister's getting married.</p>
          <p>It's none of our business what your children are struggling with.</p>
          <p>It's none of our business how much you eat in a day.</p>
          <p>It's none of our business what products you use in the shower.</p>
          <p>It's none of our business where you get your groceries.</p>
          <p>It's none of our business what car you drive.</p>
          <p>It's none of our business how you're feeling right now.</p>
          <p>It's none of our business how much student loan debt you have.</p>
          <p>It's none of our business where your favorite restaurants are.</p>
          <p>It's none of our business if you just got divorced.</p>
          <p>It's none of our business what your holiday plans are.</p>
          <p>It's none of our business if you're home or not.</p>
          <p>It's none of our business how much you spent remodeling.</p>
          <p>It's none of our business where your kids go to school.</p>
          <p>It's none of our business what books you read.</p>
          <p>It's none of our business how you get to work.</p>
          <p>It's none of our business if you went to a protest.</p>
          <p>It's none of our business who you voted for.</p>
          <p>It's none of our business what medicine you take.</p>
          <p>It's none of our business which doctor you visit.</p>
          <p>It's none of our business what your credit score is.</p>
          <p>It's none of our business where you were born.</p>
          <div class="relative" aria-hidden="true">
            <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-900 pt-[7%]">
            </div>
          </div>

          <div class="text-xl text-right pt-10 sm:pt-24">
            <h1 class="pb-2 text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              Hey Big Tech,
            </h1>
            <div class="text-sm sm:text-xl sm:font-medium lg:text-2xl/8">
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">which ads I linger on.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">when I go online.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">which search engine I use.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">where I am right now.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">which photos I like.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">who I respond to.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">which articles I read.</strong>
              </p>
              <p>
                It's none of your business <strong class="dark:text-gray-200">who I ignore.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">how many times I watched that video.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">if I'm using a VPN.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">what my home address is.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">what I just said out loud.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">how many tabs I have open.</strong>
              </p>
              <p>
                It's none of your business <strong class="dark:text-gray-200">who I follow.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">what I'm typing right now.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">which apps I download.</strong>
              </p>
              <p>
                It's none of your business
                <strong class="dark:text-gray-200">what's left in my shopping cart.</strong>
              </p>
            </div>
          </div>

          <div class="mx-auto max-w-4xl py-16">
            <h2 class="text-center text-balance text-5xl font-black tracking-tight sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              It's none of our business, so it's not our business
            </h2>
          </div>
          <div class="mx-auto max-w-2xl">
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              <strong class="dark:text-gray-200">
                At MOSSLET, our business model is as basic as it is boring:
              </strong>
              We charge our customers a fair price for our products. That's it. We don't take your personal data as payment, we don't try to monetize your eyeballs, we don't target you, we don't sell, broker, or barter ads. We will never track you, spy on you, or enable others to either. It's absolutely none of their business, and it's none of ours either.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              <strong class="dark:text-gray-200">
                Privacy is personal to us:
              </strong>
              We've been building and using computers for thirty years. We were around in 2000 when Google pioneered the invisible prison of surveillance capitalism and hid behind the thin veil of "Don't Be Evil". We've seen their strategies for collecting, selling, and abusing personal data on an industrial scale spread to every industry. We remember when Facebook rose from The FaceBook to the pusher of algorithmically-engineered traps of attention and worse. The internet didn't use to be like this, and it doesn't have to be like that today either.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              But right now it just is. You have to defend yourself from these Big Tech giants, and the legion of companies following their nasty example. Collect It All has sunk into the ideology of the commercial internet, so most companies don't even think about it. It's just what they do.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              <strong class="dark:text-gray-200">
                MOSSLET doesn't mine your posts for data:
              </strong>
              There are no big AI engines to feed. We don't track what links you click, your interests, your location, who your friends are, what you say. We don't take your your face from your pictures, nothing personal other than the most basic identifying information we need to call you a customer. Everything else is simply none of our business. And because you pay to use MOSSLET, it doesn't need to be. Even then, we encrypt it all in a way so that we couldn't take or track it even if we wanted to — which we don't.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              When you're in the business of "free", like Google, Facebook, Instagram, TikTok, YouTube, and many others, you're in the business of snooping. Tricking. Collecting. Aggregating. Slicing. Dicing. Packaging. Do you really want to be used like that? As a resource to be mined? Do you really want companies secretly deciding and controlling your future? If you're here, and curious about MOSSLET, you probably don't.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              Privacy used to be something exotic and niche. Today it's going mainstream, but it's still early. You can be early on this trend. You can be part of the change. Using MOSSLET is standing up, not giving in.
            </p>
            <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
              <strong class="dark:text-gray-200">
                Your data is none of their business:
              </strong>
              Don't give them what isn't theirs. At MOSSLET, we've got your back without looking over your shoulder.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def landing_features(assigns) do
    ~H"""
    <div id="features" class="bg-white dark:bg-gray-900 py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="mx-auto max-w-2xl text-center">
          <h2 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            Social media, unexpected.
          </h2>
          <p class="font-regular mt-6 text-xl/8 text-gray-600 dark:text-gray-400">
            Tired of feeling anxious and stressed every time you log in? Unlike Facebook and other Big Tech platforms, MOSSLET protects your privacy, is easier to use, and doesn't secretly control you.
          </p>
        </div>
        <div class="relative overflow-hidden pt-16">
          <div class="mx-auto max-w-7xl px-6 lg:px-4">
            <img
              src={~p"/images/landing_page/light-timeline-preview.png"}
              alt="App screenshot light"
              class="mb-[-12%] rounded-xl shadow-2xl shadow-background-500/50 ring-1 ring-background-900/10 color-scheme-light-timeline-preview"
              width="2432"
              height="1442"
            />
            <img
              src={~p"/images/landing_page/dark-timeline-preview.png"}
              alt="App screenshot dark"
              class="mb-[-12%] rounded-xl shadow-2xl dark:shadow-emerald-500/50 ring-1 ring-emerald-900/10 color-scheme-dark-timeline-preview"
              width="2432"
              height="1442"
            />
            <div class="relative" aria-hidden="true">
              <div class="absolute -inset-x-20 bottom-0 bg-gradient-to-t from-white dark:from-gray-900 pt-[7%]">
              </div>
            </div>
          </div>
        </div>
        <div class="mx-auto mt-16 max-w-2xl sm:mt-20 lg:mt-24 lg:max-w-none">
          <dl class="grid max-w-xl grid-cols-1 gap-x-8 gap-y-16 lg:max-w-none lg:grid-cols-3">
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-adjustments-horizontal" class="size-6 text-white" />
                </div>
                Back to basics, please
              </dt>
              <dd class="mt-2">
                MOSSLET gives you the basics for connecting and sharing online without any complicated extras. Get together and live chat? Check. Share thoughts and photos in real time? Check. Two factor authentication? Check. Simple account settings? Check. Delete my account and everything instantly? Check. Privacy-first and secure? Check.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-arrow-path-rounded-square" class="size-6 text-white" />
                </div>
                Goodbye identity graphs
              </dt>
              <dd class="mt-2">
                Meta, Google, and Amazon have created and refined comprehensive identities on each person as they scroll, search, like, shop, and boop around on their services. These identity graphs evolve each time you use their services, changing the way your life unfolds off screen. On MOSSLET, the Post you make or Memory you like is simply just that — gone are the invisible consequences of simply wanting to share.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-sparkles" class="size-6 text-white" />
                </div>
                Free to be you, every time
              </dt>
              <dd class="mt-2">
                Big Tech dictates your identity through their algorithms and their past histories of you, preventing your own growth and discovery. On MOSSLET, you get to decide who you are and who you will be. Easily delete all of your Connections, Posts, Memories, Groups, Remarks and more across our service in real-time without deleting your account. As you change throughout your life, you can come back to MOSSLET free to be you, every time.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-sun" class="size-6 text-white" />
                </div>
                No dark patterns
              </dt>
              <dd class="mt-2">
                Facebook and others design their services to trick and trap you — from disguised ads and difficult-to-cancel subscriptions to buried terms and emotional manipulation. MOSSLET has none of that and is designed to make it as simple as possible for you to share what you want and then get off our platform and back to living your life.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-shield-check" class="size-6 text-white" />
                </div>
                Strong safety
              </dt>
              <dd class="mt-2">
                No one can interact with you on MOSSLET without your permission and you can remove people's ability to interact with you at anytime. Share a Memory or Post with people accidentally? No problem! You can remove it across the entire service in real-time.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-clipboard-document-list" class="size-6 text-white" />
                </div>
                Control your own data
              </dt>
              <dd class="mt-2">
                Unlike the Big Tech platforms, we don't colonize you and your life. There is no sharing, selling, or otherwise using your data — especially against you. Your data on MOSSLET is yours and you can delete it and your account at any time.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-hand-raised" class="size-6 text-white" />
                </div>
                No behavioral manipulation
              </dt>
              <dd class="mt-2">
                Big Tech uses the data it harvests from you to create products that can be bought by others, with the sole purpose of changing how you think, act, and behave in the real world — from extremism to new-boot-goofin. On MOSSLET, you won't be turned into a weapon of mass manipulation. On MOSSLET, you control your experience.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-heart" class="size-6 text-white" />
                </div>
                Calm
              </dt>
              <dd class="mt-2">
                Facebook, Twitter, Instagram, and Tiktok fill your screen with content that keeps your nervous system stressed and your eyes glued to your device. On MOSSLET, you get to leave the manufactured stress and anxiety behind. There are no tricks, algorithms, or business decisions designed to profit off of your emotions. On MOSSLET, you get to experience calm.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-bell-snooze" class="size-6 text-white" />
                </div>
                No notifications
              </dt>
              <dd class="mt-2">
                Drop the pressure of feeling like you have to respond or interact with someone or something online. With no notifications designed to trigger you to action, you are free to make your own decisions on MOSSLET.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-eye-slash" class="size-6 text-white" />
                </div>
                Better privacy
              </dt>
              <dd class="mt-2">
                On MOSSLET, your account starts private unlike Facebook, Twitter, Tiktok, and Instagram. Then you can choose what and who you want to share with. And no one can see your content without you explicitly giving them access, including us. No longer worry about a stranger at a company, malicious individual, or authority looking at or consuming information about you without you knowing.
              </dd>
            </div>
            <div class="relative ">
              <dt class="font-semibold text-gray-900 dark:text-gray-100">
                <div class="mb-6 flex size-10 items-center justify-center rounded-lg bg-emerald-600 dark:bg-emerald-500">
                  <.phx_icon name="hero-lock-closed" class="size-6 text-white" />
                </div>
                Asymmetric encryption
              </dt>
              <dd class="mt-2">
                Your data on MOSSLET is encrypted using strong public-key cryptography and a password-derived key to ensure that only you can access your data. This ensures that no one else can gain access to your data — not even us — while allowing you the ability to share with others. We then further encrypt your data with an extra layer of symmetric encryption when it is stored at-rest in our private and secure database.
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  def testimonials(assigns) do
    ~H"""
    <section
      id="testimonials"
      aria-label="What our customers are saying"
      class="bg-slate-50 dark:bg-slate-900 py-20 sm:py-32"
    >
      <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl md:text-center">
          <h2 class="font-display text-3xl tracking-tight text-slate-900 dark:text-gray-50 sm:text-4xl">
            People are ready for change.
          </h2>
          <p class="mt-4 text-lg tracking-tight text-slate-700 dark:text-slate-300">
            After decades of the status quo, people are excited to take back their lives.
          </p>
        </div>
        <ul
          role="list"
          class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-6 sm:gap-8 lg:mt-20 lg:max-w-none lg:grid-cols-3"
        >
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I'm done with Facebook. I'd like a place where I own the data and that is generally positive vs. all the negativity that gets put into my feed at Facebook.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I like the idea of being able to share stories about the grandchildren in our family with other parents and grandparents. I also appreciate a venue for sharing adventures with my friends without someone I don't know having access to my activities and whereabouts.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Because it's amazing ✨
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Tired of being profiled everywhere, would love to experience something that aint harvesting me.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Having a safe place to share photos of our little bears feels so amazing.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
          <li>
            <ul role="list" class="flex flex-col gap-y-6 sm:gap-y-8">
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      I hate what the internet has become , but I'm dreamer, so I hope we will have a bright future. And I do believe in this kind of initiative. Perhaps I'm not the right person to receive an invitation, because I'm not active on social media, but I want you to know that you have my full support in this initiative.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
              <li>
                <figure class="relative rounded-2xl bg-white dark:bg-slate-950 p-6 shadow-xl shadow-slate-900/10 dark:shadow-emerald-600/60">
                  <svg
                    aria-hidden="true"
                    width="105"
                    height="78"
                    class="absolute top-6 left-6 fill-slate-100 dark:fill-slate-800"
                  >
                    <path d="M25.086 77.292c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622C1.054 58.534 0 53.411 0 47.686c0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C28.325 3.917 33.599 1.507 39.324 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Zm54.24 0c-4.821 0-9.115-1.205-12.882-3.616-3.767-2.561-6.78-6.102-9.04-10.622-2.11-4.52-3.164-9.643-3.164-15.368 0-5.273.904-10.396 2.712-15.368 1.959-4.972 4.746-9.567 8.362-13.786a59.042 59.042 0 0 1 12.43-11.3C82.565 3.917 87.839 1.507 93.564 0l11.074 13.786c-6.479 2.561-11.677 5.951-15.594 10.17-3.767 4.219-5.65 7.835-5.65 10.848 0 1.356.377 2.863 1.13 4.52.904 1.507 2.637 3.089 5.198 4.746 3.767 2.41 6.328 4.972 7.684 7.684 1.507 2.561 2.26 5.5 2.26 8.814 0 5.123-1.959 9.19-5.876 12.204-3.767 3.013-8.588 4.52-14.464 4.52Z">
                    </path>
                  </svg>
                  <blockquote class="relative">
                    <p class="text-lg tracking-tight text-slate-900 dark:text-slate-50">
                      Support a healthier digital ecosystem.
                    </p>
                  </blockquote>
                  <figcaption class="relative mt-6 flex items-center justify-between border-t border-slate-100 pt-6">
                    <div>
                      <div class="font-display text-base text-slate-900 dark:text-slate-50">
                        Private Name
                      </div>
                      <div class="mt-1 text-sm text-slate-500 dark:text-slate-400">
                        Early Access Invitee
                      </div>
                    </div>
                    <div class="overflow-hidden rounded-full bg-slate-50 dark:bg-slate-900">
                      <img
                        alt="MOSSLET icon"
                        src={~p"/images/logo_icon_dark.svg"}
                        width="56"
                        height="56"
                        decoding="async"
                        data-nimg="future"
                        class="h-14 w-14 object-cover"
                        loading="lazy"
                      />
                    </div>
                  </figcaption>
                </figure>
              </li>
            </ul>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  def pricing_cards(assigns) do
    ~H"""
    <section id="pricing" aria-label="Pricing">
      <div class="relative isolate bg-white dark:bg-gray-950 px-6 py-24 sm:py-32 lg:px-8">
        <div
          class="absolute inset-x-0 -top-3 -z-10 transform-gpu overflow-hidden px-36 blur-3xl"
          aria-hidden="true"
        >
          <div
            class="mx-auto aspect-[1155/678] w-[72.1875rem] bg-gradient-to-tr from-[#9ACF65] to-[#8BE8E8] opacity-30"
            style="clip-path: polygon(74.1% 44.1%, 100% 61.6%, 97.5% 26.9%, 85.5% 0.1%, 80.7% 2%, 72.5% 32.5%, 60.2% 62.4%, 52.4% 68.1%, 47.5% 58.3%, 45.2% 34.5%, 27.5% 76.7%, 0.1% 64.9%, 17.9% 100%, 27.6% 76.8%, 76.1% 97.7%, 74.1% 44.1%)"
          >
          </div>
        </div>
        <div class="mx-auto max-w-2xl text-center lg:max-w-4xl">
          <h1 class="mt-2 text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
            Simple,
            <span class="italic underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double text-6xl font-bold tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
              pay once
            </span>
            pricing
          </h1>
        </div>

        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          Say goodbye to never-ending subscription fees.
        </h2>
        <p class="mx-auto mt-6 max-w-2xl text-center text-lg leading-8 text-gray-600 dark:text-gray-400">
          Pay once and forget about it. With one, simple payment you get access to our service forever. No hidden fees, no subscriptions, no surprises. We also support lowering your upfront payment with Affirm.
        </p>
        <div class="mx-auto mt-16 grid max-w-lg grid-cols-1 items-center gap-y-6 sm:mt-20 sm:gap-y-0 lg:max-w-4xl lg:grid-cols-2">
          <div class="rounded-3xl p-8 ring-1 ring-gray-900/10 dark:ring-gray-100/10 sm:p-10 relative bg-white dark:bg-gray-950 shadow-2xl dark:shadow-emerald-500/50">
            <span class="flex justify-between">
              <h3
                id="tier-personal"
                class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400"
              >
                Personal
              </h3>

              <.badge color="warning" label="Save 40%" variant="soft" class="rounded-full" />
            </span>
            <p class="mt-4 flex items-baseline gap-x-2">
              <span class="text-5xl font-bold tracking-tight text-gray-900 dark:text-gray-100">
                $59
              </span>
              <span class="text-base text-gray-500">/once</span>
            </p>
            <p class="mt-6 text-base leading-7 text-gray-600 dark:text-gray-400">
              Pay once to start sharing what you want with the privacy you need — forever. We also support lowering your upfront payment with Affirm.
            </p>
            <ul
              role="list"
              class="mt-8 space-y-3 text-sm leading-6 text-gray-600 dark:text-gray-400 sm:mt-10"
            >
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Unlimited Connections, Groups, and Posts
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Unlimited new features
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Streamlined settings
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Own your data
              </li>
              <li
                id="asymmetric-encryption-pricing-feature"
                class="flex gap-x-3 cursor-help"
                data-tippy-content="Only your account password can decrypt the key to your data — keeping it private to you and unknowable to anyone else."
                phx-hook="TippyHook"
              >
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Advanced asymmetric encryption
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Email support
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Supports Affirm Payment Plans
              </li>
            </ul>
            <a
              href={~p"/auth/register"}
              aria-describedby="tier-personal"
              class="mt-8 block rounded-full py-2.5 px-3.5 text-center text-sm font-semibold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 sm:mt-10 bg-emerald-600 text-white shadow hover:bg-emerald-500"
            >
              Sign up today
            </a>
          </div>
          <div class="rounded-3xl p-8 ring-1 ring-gray-900/10 dark:ring-gray-100/10 sm:p-10 bg-white/60 dark:bg-gray-950/60 sm:mx-8 lg:mx-0 sm:rounded-t-none lg:rounded-tr-3xl lg:rounded-bl-none">
            <h3
              id="tier-team"
              class="text-base font-semibold leading-7 text-emerald-600 dark:text-emerald-400"
            >
              Family
            </h3>
            <p class="mt-4 flex items-baseline gap-x-2">
              <span class="text-5xl font-bold tracking-tight text-gray-900 dark:text-gray-100">
                TBA
              </span>
              <span class="text-base text-gray-500">/once</span>
            </p>
            <p class="mt-6 text-base leading-7 text-gray-600 dark:text-gray-400">
              Coming soon — a plan that supports your whole family.
            </p>
            <ul
              role="list"
              class="mt-8 space-y-3 text-sm leading-6 text-gray-600 dark:text-gray-400 sm:mt-10"
            >
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Priority support
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Multiple accounts
              </li>
              <li class="flex gap-x-3">
                <svg
                  class="h-6 w-5 flex-none text-emerald-600 dark:text-emerald-400"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                >
                  <path
                    fill-rule="evenodd"
                    d="M16.704 4.153a.75.75 0 01.143 1.052l-8 10.5a.75.75 0 01-1.127.075l-4.5-4.5a.75.75 0 011.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 011.05-.143z"
                    clip-rule="evenodd"
                  />
                </svg>
                Admin dashboard
              </li>
            </ul>
            <a
              href="#pricing"
              aria-describedby="tier-team"
              class="mt-8 block rounded-full py-2.5 px-3.5 text-center text-sm font-semibold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 dark:focus-visible:outline-emerald-400 sm:mt-10 text-emerald-600 dark:text-emerald-400 ring-1 ring-inset ring-emerald-200 hover:ring-emerald-300 dark:ring-emerald-800 dark:hover:ring-emerald-700 cursor-none"
            >
              Coming soon
            </a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :hero_intro?, :boolean, default: false
  attr :pricing_link?, :boolean, default: false

  def pricing_comparison(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl pt-16 pb-10">
      <div :if={@hero_intro?}>
        <%!-- Hero Intro --%>
        <h1 class="text-center text-5xl font-black tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          The lawless internet
        </h1>
        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          We looked into how the other guys handle your data, and it's not pretty. <span class="underline underline-offset-4 decoration-emerald-600 dark:decoration-emerald-400 decoration-double">Everyone's tracking you</span>.
        </h2>
        <p class="mt-6 text-center text-lg leading-8 text-gray-600 text-balance dark:text-gray-400">
          So we put together this table to help you get a quick overview of how much tracking is going on, and how we stack up. We sifted through hours of policies, reports, and investigations and came away with one conclusion — it's
          <em>lawless</em>
          out there. Companies are feeding our online behavior into the surveillance industry and it's affecting all of us. The internet doesn't have to be this way.
        </p>

        <div class="mt-10 flex items-center justify-center gap-x-6">
          <.button
            link_type="live_redirect"
            to="/pricing"
            class="!rounded-full bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-500"
          >
            Learn more about our pricing
            <.phx_icon name="hero-arrow-long-right" class="ml-1 inline h-5 w-5" />
          </.button>
        </div>
      </div>

      <div :if={!@hero_intro?}>
        <%!-- Pricing Intro --%>
        <h1 class="text-center text-6xl font-black tracking-tight text-pretty sm:text-7xl lg:text-8xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
          $700+ per year
        </h1>
        <h2 class="mt-4 text-center text-balance text-2xl font-black tracking-tight sm:text-3xl lg:text-4xl text-black dark:text-white">
          That's how much your personal data was worth more than 3 years ago.
        </h2>
        <p class="mt-6 text-center text-lg leading-8 text-gray-600 text-balance dark:text-gray-400">
          And it's only going up. But don't take our word for it, check out this <.link
            target="_blank"
            rel="noopener noreferrer"
            href="https://proton.me/blog/what-is-your-data-worth"
            class="underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
          >analysis conducted by Proton</.link>. This means
          <strong class="dark:text-gray-200">you are paying more than $700 <em>per year</em></strong>
          to share a photo on Instagram or Facebook, search on Google, watch a video on YouTube, or dance on TikTok. Every day, you simply give them this money that is innately yours before it can ever exist in your bank account. It's the greatest heist in history and it's happening right now.
        </p>
      </div>
      <%!-- Table Container --%>
      <div class="bg-background-50 dark:bg-gray-800 sm:py-10 mt-10 rounded-lg shadow-lg dark:shadow-emerald-500/50">
        <h2 class="px-4 text-xl/8 font-semibold text-black dark:text-white sm:px-6 lg:px-8">
          How MOSSLET Compares
        </h2>
        <table class="mt-6 w-full text-left whitespace-wrap">
          <colgroup>
            <col class="w-2/12" />
            <col class="w-2/12 sm:w-4/12 lg:w-full" />
            <col class="w-2/12" />
            <col class="w-1/12" />
            <col class="lg:w-4/12" />
            <col class="w-2/12" />
          </colgroup>
          <thead class="border-b border-background-950/10 dark:border-white/10 text-lg/8 text-black dark:text-white">
            <tr>
              <th scope="col" class="py-2 pr-8 pl-4 font-light sm:pl-6 lg:pl-8">Company</th>
              <th scope="col" class="hidden py-2 pr-8 pl-0 font-light sm:table-cell">
                <span
                  id="sends-data-column"
                  phx-hook="TippyHook"
                  data-tippy-content="The companies that we know are being sent your personal data."
                  class="cursor-help"
                >
                  Sends Data
                </span>
              </th>
              <th
                scope="col"
                class="py-2 pr-4 pl-0 text-right font-light sm:pr-8 sm:text-left lg:pr-20"
              >
                <span
                  id="tracking-column"
                  phx-hook="TippyHook"
                  data-tippy-content="Does this company secretly track, spy, snoop, or otherwise surveil you?"
                  class="cursor-help"
                >
                  Tracking?
                </span>
              </th>
              <th scope="col" class="hidden py-2 pr-4 pl-0 font-light md:table-cell lg:pr-20">
                <span
                  id="features-column"
                  phx-hook="TippyHook"
                  data-tippy-content="Indicates whether the features for the pricing tier are fully available or not."
                  class="cursor-help"
                >
                  Features
                </span>
              </th>
              <th scope="col" class="py-2 pr-4 pl-8 text-right font-light sm:pr-6 lg:pr-8">
                Price
              </th>
              <th
                scope="col"
                class="hidden py-2 pr-4 pl-0 text-right font-light sm:table-cell sm:pr-6 lg:pr-8"
              >
                <span
                  id="the-privacy-report"
                  phx-hook="TippyHook"
                  data-tippy-content="The privacy report we were able to find from either The Markup's Blacklight investigation, California Learning Resource Network, Commonsense Media, Consumer Reports, or Privado."
                  class="cursor-help"
                >
                  Privacy
                </span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-background-950/5 dark:divide-white/5">
            <%!-- Bluesky Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/bluesky_logo.png"}
                    alt="Bluesky logo"
                    class="size-16 object-contain cursor-help"
                    id="bluesky-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Bluesky"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Apple, Blockchain Capital<span class="text-xs align-super ml-1">1</span>
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Bluesky"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
            <%!-- Element --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/element_logo.svg"}
                    alt="Element logo"
                    class="size-16 object-contain cursor-help"
                    id="element-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Element"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alexa, Amazon, CloudFront, HubSpot and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited<span class="text-xs align-super ml-1">2</span>
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                $68 /user/yr
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=element.io"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Facebook --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/facebook_logo.svg"}
                    alt="Facebook logo"
                    class="size-16 object-contain cursor-help"
                    id="facebook-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Facebook (Meta)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Amazon, Apple, Experian, Home Depot<span class="text-xs align-super ml-1">3</span>, LiveRamp, Meta<span class="text-xs align-super ml-1">4</span>, Microsoft, Netflix, Oracle, Royal Bank of Canada, Sony, Spotify, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=facebook.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Instagram Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/instagram_logo.png"}
                    alt="Instagram logo"
                    class="size-16 object-contain cursor-help"
                    id="instagram-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Instagram (Meta)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Amazon, Apple, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/instagram"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
            <%!-- Kin Social Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/kin_logo.png"}
                    alt="Kin logo colour"
                    class="size-16 object-contain cursor-help"
                    id="kin-social-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Kin Social"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">Adobe, Alphabet, Facebook</div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=mobile&force=false&url=kinsocial.app"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- LinkedIn Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/linkedin_logo.png"}
                    alt="LinkedIn logo"
                    class="size-16 object-contain cursor-help"
                    id="linkedin-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="LinkedIn"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Adobe, Alphabet, Comscore, Microsoft, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited<span class="text-xs align-super ml-1 text-gray-400">5</span>
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $30 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=mobile&force=false&url=linkedin.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Mastodon --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/mastodon_logo.png"}
                    alt="Mastodon logo"
                    class="size-16 object-contain cursor-help"
                    id="mastodon-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Mastodon"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Varies by server<span class="text-xs align-super ml-1 text-gray-400">6</span>
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $500 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://www.privado.ai/post/who-actually-holds-your-data-in-mastodon-a-privacy-review"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- MOSSLET Row --%>
            <tr class="border-2 border-emerald-600 dark:border-emerald-400">
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/logo.svg"}
                    alt="Wire Messaging logo"
                    class="size-16 object-contain cursor-help"
                    id="mosslet-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="MOSSLET"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-emerald-600 dark:text-emerald-400">
                    No data sent<span class="text-xs align-super ml-1 text-emerald-600 dark:text-emerald-400">7</span>
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-emerald-600/10 dark:bg-emerald-400/20 p-1 text-emerald-600 dark:text-emerald-400">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-emerald-600 dark:text-emerald-400 ">
                    None
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-emerald-600 dark:text-emerald-400 md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-emerald-600 dark:text-emerald-400 sm:pr-6 lg:pr-8">
                $59 /once
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=mosslet.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Reddit Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/reddit_logo.svg"}
                    alt="Reddit logo"
                    class="size-16 object-contain cursor-help p-1"
                    id="reddit-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Reddit"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Meta, LiveRamp, Tower Data<span class="text-xs align-super ml-1">8</span>, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $5.99 /mo
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?location=us-ca&device=desktop&force=true&url=reddit.com"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- TikTok Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/tiktok_logo.png"}
                    alt="TikTok logo"
                    class="size-16 object-contain cursor-help p-1 dark:bg-white rounded-sm"
                    id="tiktok-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="TikTok"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, Bytedance, Facebook, Mayo Clinic, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/TikTok---Real-Short-Videos"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Telegram --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/telegram_logo.png"}
                    alt="Truth Social logo"
                    class="size-16 object-contain cursor-help"
                    id="telegram-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Telegram"
                  />

                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Buzz Media, Federal Government Agencies, Local Law Enforcement, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
                Full
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"<br /> $59.88 /yr
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://www.clrn.org/how-dangerous-is-telegram/"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Truth Social Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/truth_social_logo.svg"}
                    alt="Truth Social logo"
                    class="size-16 object-contain cursor-help"
                    id="truth-social-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Truth Social"
                  />

                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Adobe, IBM, Innovid, Meta, Oracle, X (Twitter), and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Full
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Truth-Social"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- WhatsApp --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/whatsapp_logo.svg"}
                    alt="WhatsApp logo"
                    class="size-16 object-contain cursor-help"
                    id="whatsapp-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="WhatsApp"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Facebook, Federal Government Agencies, Local Law Enforcement, Meta, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                    <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                      <div class="size-1.5 rounded-full bg-current"></div>
                    </div>
                    <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                      Tracking
                    </div>
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/WhatsApp-Messenger"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- Wire Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/wire_logo.svg"}
                    alt="Wire Messaging logo"
                    class="size-16 object-contain cursor-help bg-gray-800 p-1 rounded-sm"
                    id="wire-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="Wire Messaging"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet, HubSpot, LinkedIn, Microsoft
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>

              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>
              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://themarkup.org/blacklight?url=wire.com&device=mobile&location=us-ca&force=false"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>

            <%!-- X / Twitter Row --%>
            <tr>
              <td class="py-4 pr-8 pl-4 sm:pl-6 lg:pl-8">
                <div class="flex items-center gap-x-4">
                  <img
                    src={~p"/images/landing_page/twitter_x_logo.png"}
                    alt="X Twitter logo"
                    class="size-16 object-contain cursor-help p-1 dark:bg-white rounded-sm"
                    id="x-twitter-company-logo"
                    phx-hook="TippyHook"
                    data-tippy-content="X (Twitter)"
                  />
                  <div class="truncate text-sm/6 font-medium text-black dark:text-white"></div>
                </div>
              </td>
              <td class="hidden py-4 pr-4 pl-0 sm:table-cell sm:pr-8">
                <div class="flex gap-x-3">
                  <div class="font-mono text-sm/6 text-gray-400">
                    Alphabet<span class="text-xs align-super ml-1">9</span>, Amazon, Apple, Comcast, Experian, Facebook, IBM, Microsoft, Oracle, Verizon, and more...
                  </div>
                </div>
              </td>
              <td class="py-4 pr-4 pl-0 text-sm/6 sm:pr-8 lg:pr-20">
                <div class="flex items-center justify-end gap-x-2 sm:justify-start">
                  <div class="flex-none rounded-full bg-rose-600/10 dark:bg-rose-400/20 p-1 text-rose-600 dark:text-rose-400 animate-pulse">
                    <div class="size-1.5 rounded-full bg-current"></div>
                  </div>
                  <div class="text-black sm:block text-rose-600 dark:text-rose-400 animate-pulse">
                    Tracking
                  </div>
                </div>
              </td>
              <td class="hidden py-4 pr-8 pl-0 text-left text-sm/6 text-gray-400 md:table-cell md:pr-6 lg:pr-20">
                Limited
              </td>

              <td class="py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:pr-6 lg:pr-8">
                <span class="line-through">($700 /yr)</span> "Free"
              </td>
              <td class="hidden py-4 pr-4 pl-0 text-right text-sm/6 text-gray-400 sm:table-cell lg:pr-8">
                <.link
                  target="_blank"
                  rel="noopener noreferrer"
                  href="https://privacy.commonsense.org/evaluation/Twitter-X"
                  class="cursor-pointer underline text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-500"
                >
                  Learn more
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
        <div class="flex mx-auto mt-6 py-6 px-4 border-t border-background-950/10 justify-center dark:border-white/10">
          <div class="flex-col leading-8 space-y-6 px-4">
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">1</span>
              Bluesky claims to share/sell data. Some of that sharing is benign, like payment processors (even we have to use Stripe to process the payment for your account). But others are more murky, like "business partners". Some of those business partners are hedge fund founders and venture capital, so their business is inevitably focused on Wall Street and its investors — their
              <em>actual</em>
              customers. It is also known that they link your content, contact information, and other personal identifiers to your account and all of it is accessible by Bluesky, therefore others. In summary: you are being tracked
              <em>and</em>
              they are planning a subscription fee.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">2</span>
              The idea behind Element is positive. But in order to be "free" you have to be able to run their software on your own server, aka <em>self host</em>. This is not realistic for most people and not actually free (you have to factor in the cost of running the service yourself). Additionally, whoever is running the software has the ability to access your encrypted data — Element's privacy policy states that Element engineers
              <em>and contractors</em>
              can access your data from their paid products. This isn't inherently bad, but it is a <em>serious privacy concern</em>. On top of that, you are still being tracked and your data is still being sent through the usual pipelines of surveillance capitalism when you use their services.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">3</span>
              This is incredibly alarming considering the 2025 Immigration and Customs Enforcement (ICE) kidnappings.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">4</span>
              A recent study from Consumer Reports and The Markup discovered that thousands of companies are tracking each individual user on Facebook (Meta). You can
              <.link
                navigate={~p"/blog/articles/01#its-nothing-personal"}
                class="text-gray-800 underline dark:text-gray-200"
              >
                learn more about it
              </.link>
              on our blog.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">5</span>
              The $29.99 /mo pricing tier on LinkedIn, which we rounded to $30, is aimed at individuals and offers a few more of the company's services but the entire feature suite of LinkedIn is still limited and they still continue to monetize your data through the pipelines of surveillance capitalism. Other pricing tiers on LinkedIn range from $99.99-$835 per month.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">6</span>
              On Mastodon, the privacy and data practices can vary significantly depending on the server you choose to join. Some servers may have strong privacy policies, while others may not prioritize user data protection at all — you would have to read and interpret the policies for every server. On mastodon.social there appeared to be no direct data sharing going on, but other Mastodon servers are able to collect your public information without you being aware. Additionally, your data is not asymetrically encrypted so anyone with access to a server's database (where data is stored) can see your information (read this to learn why we believe
              <.link
                target="_blank"
                rel="noopener noreferrer"
                href="https://www.schneier.com/essays/archives/2016/04/the_value_of_encrypt.html"
                class="underline text-gray-800 dark:text-gray-200"
              >
                encryption matters
              </.link>
              to privacy). Lastly, each server is tracking you — including your location.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400 border-1  border-emerald-600 dark:border-emerald-400 p-2">
              <span class="text-xs align-super text-emerald-600 dark:text-emerald-400">7</span>
              We don't share, sell, sneak, trade, barter, or otherwise monetize your data for our business or others. We
              <em>do need</em>
              to use a payment processor to securely process your <em>one-time</em>
              payment, and our provider is
              <.link
                target="_blank"
                rel="noopener noreferrer"
                href="https://support.stripe.com/questions/does-stripe-sell-my-information"
                class="text-gray-800 underline dark:text-gray-200"
              >
                Stripe
              </.link>
              — whose got a policy so good we wish that Big Tech would adopt it. We talk about it in
              <.link navigate={~p"/privacy"} class="text-gray-800 underline dark:text-gray-200">
                our privacy policy
              </.link>
              that we wrote ourselves. At MOSSLET, we are privacy-first.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">8</span>
              Reddit is sending your data <em>everywhere</em>. On top of sending to the usual suspects like Alphabet and Meta (LiveRamp is one of the biggest data brokers), they apparently send your data to Tower Data who openly <em>sells your information to political campaigns</em>. On top of all of this surveillance capitalism, Reddit also offers to charge you $5.99 /mo (an infinitely growing expense) to continue to be tracked and manipulated just beyond your awareness.
            </p>
            <p class="text-left text-sm text-gray-600 dark:text-gray-400">
              <span class="text-xs align-super">9</span>
              Adscape, Calico, Cameyo, CapitalG, Charleston Road Registry, DeepMind, Endoxon, FeedBurner, Google, Google Fiber, GV, ImageAmerica, Intrinsic, Isomorphic Labs, Kaltix, Nest Labs (the thermostat), reCAPTCHA, Verily, Waymo, Wing, YouTube, and ZipDash are all owned by Alphabet Inc. after Google, <em>creator of surveillance capitalism</em>, restructured their business.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def faq(assigns) do
    ~H"""
    <section id="faq" aria-labelledby="faq-title">
      <div class="bg-white dark:bg-gray-950">
        <div class="mx-auto max-w-7xl px-6 py-24 sm:pt-32 lg:px-8 lg:pt-40">
          <div class="lg:grid lg:grid-cols-12 lg:gap-8">
            <div class="lg:col-span-5">
              <h2 class="text-pretty text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl">
                Frequently asked questions
              </h2>
              <p class="mt-4 text-pretty text-base/7 text-gray-600 dark:text-gray-400">
                Can't find the answer you're looking for? Reach out to our
                <.link
                  class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                  href="mailto:support@mosslet.com"
                >
                  customer support
                </.link>
                team.
              </p>
            </div>
            <div class="mt-10 lg:col-span-7 lg:mt-0">
              <dl class="space-y-10">
                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What is MOSSLET?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET is a privacy-first social network designed to protect users' privacy and human dignity from surveillance and the attention economy. We prioritize privacy, data protection, and creating a safe space for meaningful social interactions.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    How does MOSSLET protect my privacy?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET employs asymmetric encryption (end-to-end) to ensure that your data remains private and secure. This means that only you and the intended recipient can access your messages and information, keeping your interactions confidential.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What is the pay once pricing model?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET operates on a pay once pricing model, currently set at $59 during our beta phase. This approach allows us to maintain our service without relying on advertising or data monetization, ensuring that your privacy and experience remains our top priority.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What makes MOSSLET different from other social networks?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET stands out by prioritizing user privacy, employing ethical design practices, and offering a straightforward pricing model. Unlike traditional social networks that rely on advertising and data exploitation, we focus on creating a safe and respectful environment for our users.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    Can I delete my account and data?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    Yes, you can delete your account at any time. When you choose to delete your account, all your data will be permanently removed from our servers, ensuring that your information is no longer accessible.
                  </dd>
                </div>

                <%!-- More questions... --%>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="pb-12">
      <div id="more-faq-show-button-container" class="hidden relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            id="more-faq-show-button"
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-show-button-container")
              |> JS.toggle(to: "#more-faq-hide-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
          >
            <svg
              class="-ml-1 -mr-0.5 size-5 text-gray-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
              data-slot="icon"
            >
              <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
            </svg>
            Show in-depth FAQ
          </button>
        </div>
      </div>

      <div id="more-faq-hide-button-container" class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-hide-button-container")
              |> JS.toggle(to: "#more-faq-show-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-white px-3 py-1.5 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="-ml-1 -mr-0.5 size-5 text-gray-400"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
            </svg>
            Hide in-depth FAQ
          </button>
        </div>
      </div>

      <.more_faq />
    </div>
    """
  end

  def more_faq(assigns) do
    assigns = assigns

    ~H"""
    <section id="more-faq" class="transition-all" aria-labelledby="more-faq-title">
      <div class="bg-white dark:bg-gray-950">
        <div class="mx-auto max-w-7xl px-6 pb-16 sm:pb-24 lg:px-8">
          <div class="mb-12"></div>
          <.faq_section_heading title="General" anchor_tag="general" />
          <div class="mt-12"></div>

          <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                What are dark patterns?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Dark patterns are deceptive design techniques used in websites or apps to manipulate users into making choices they might not otherwise make, often to benefit the company.
              </dd>
            </div>
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                Is there a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Not yet! In the meantime, you can log into your account (or visit any page on the website) from the web browser on your mobile device, click the share icon (<.phx_icon
                  name="hero-arrow-up-on-square"
                  class="inline-flex h-5 w-5"
                />), and then select the "Add to home screen" option to save a MOSSLET shortcut to your device.
              </dd>
            </div>

            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                When will there be a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                TBA. We're a small team and are currently looking into different options for bringing our web app to a native device. Once we know, we'll share the update here.
              </dd>
            </div>
          </dl>

          <div class="mt-20">
            <.faq_section_heading title="Data" anchor_tag="data" />
            <div class="mb-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does MOSSLET do with my data?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  MOSSLET uses your data to power your account and its features for you. For example, it is securely and privately stored for you so that you can access your account, update or delete your data, and share it with others.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET share, sell, or otherwise use my data behind my back?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! And we will never do that. Period. Unlike Facebook and Big Tech, there's nothing sneaky here. You pay for our service and we provide you with privacy-first features for a calmer, better life.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data encrypted?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your personal data is asymmetrically encrypted with a password-derived key, making it so that only you can access and unlock your data. Without your password, no one else can — not even us! We then wrap that encrypted data in an extra layer of symmetric encryption before storing it at rest ("at rest" meaning in the database when you are not using it).
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  In more detail it looks like this: each person has a (1) password-derived key, (2) public-private key pair, and (3) their private key is encrypted with their password-derived key.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data shared with my friends?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you share your data with your friends, they receive an encrypted copy of a unique key specific to that piece of data (think a Post or Memory). Their copy is encrypted with their public key so that they can unlock it and thus access the data you shared with them.
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  This ensures that only the people you choose to share with can access whatever you are sharing. When you delete a friend or stop sharing with them, their access to your data is also removed.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Where is my data stored?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your data is stored in our secure, private database network that is distributed and run by our hardware provider <.link
                    href="https://fly.io"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Fly</.link>. The network is protected with the WireGuard protocol and your personal data is encrypted twice before being stored in the database.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Any media data, like Memories and avatars (photos), are stored with our private, decentralized cloud storage provider <.link
                    href="https://tigrisdata.com"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Tigris</.link>. Your data is asymmetrically encrypted and then sent to Tigris where it is distributed around the world for faster speeds and optimal availability.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET use my image or data to train its AI?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! We are using a pre-trained, open source model from the machine learning community. This means it was trained on other image data (~80,000 images). We then run this model on our own private, internal servers — ensuring your data remains private and secure.
                </dd>
              </div>
            </dl>

            <%!--
            <div class="mb-12"></div>
            <.faq_section_heading title="Memories" anchor_tag="memories" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What are Memories? Can I share them publicly?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Memories are photos. You can share them with anyone you're connected to but not publicly. Publicly sharing a Memory is a feature that we are considering for the future.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do you ensure images are safe?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We currently check all images against an AI model fine-tuned for detecting NSFW images (not safe for work). If an image is deemed NSFW, then it cannot be uploaded. This is not a foolproof system and won't catch everything, but it is a start. Please report to us any harmful images at <.link
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                    href="mailto:support@mosslet.com"
                  >support</.link>.
                </dd>
              </div>
            </dl>

            --%>

            <div class="mb-12"></div>
            <.faq_section_heading title="Password" anchor_tag="password" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div id="irreversibly-hashed">
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does "irreversibly hashed" mean?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Irreversibly hashing a password means converting it into a fixed-length string of characters using a one-way function, making it impossible to retrieve the original password from that string. We use an industry leading method that ensures you can safely log in to your account without risking someone else being able to know your password.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens if I forget my password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you forget your password and have not enabled our forgot password feature in your settings, then you won't be able to regain access to your account. We do not have the ability to reset your password due to the secure encryption of your account and its data.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you have enabled the forgot password feature, then you can simply
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  using your account email. We recommend that you use a password manager or save your password in a secure, private place so that you don't forget it.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What is the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  The forgot password feature gives you the ability to get back into your account should you forget your password. We created this feature to give you the choice between added convenience and increased security. Simply go to your account settings to enable/disable it at any time.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We recommend for most people that you enable the forgot password feature to ensure you don't get locked out of your account — your account and its data will still be protected with strong encryption.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  I enabled the forgot password feature, what happens now?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you enable it, we store a symmetrically encrypted copy of your password-derived key in our private, secure database. This enables the server to use your password-derived key to let you back into your account with a standard
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  request email.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens when I disable the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you disable it, the symmetrically encrypted copy of your password-derived key is deleted from our database. This returns your account to its original asymmetric encryption — meaning only your password can let you back into your account and unlock your data.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do I change my account password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  You can change your password any time from within your settings. Simply log in to your account and go to the "change password" section of your settings to make the change.
                </dd>
              </div>
            </dl>

            <div class="mb-12"></div>
            <.faq_section_heading title="Posts" anchor_tag="posts" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! Simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Post you wish to reply to. All replies are sent, updated, and deleted in real time.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I make a public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  No. This is a feature we are considering for the future.
                </dd>
              </div>

              <%!-- Public Post
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! If you are signed into your MOSSLET account, simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Public Post you wish to reply to. All public replies are sent, updated, and deleted in real time.
                </dd>
              </div>
              --%>
            </dl>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def faq_app(assigns) do
    ~H"""
    <section
      id="faq_app"
      aria-labelledby="faq-title"
      class="mb-10 flex align-middle items-center justify-center transition-all"
    >
      <div class="bg-white dark:bg-gray-800 shadow-md dark:shadow-emerald-500/50">
        <div class="mx-auto max-w-7xl px-6 py-24 sm:pt-32 lg:px-8 lg:pt-40">
          <div class="lg:grid lg:grid-cols-12 lg:gap-8">
            <div class="lg:col-span-5">
              <h2 class="text-pretty text-3xl font-semibold tracking-tight text-gray-900 dark:text-gray-100 sm:text-4xl">
                Frequently asked questions
              </h2>
              <p class="mt-4 text-pretty text-base/7 text-gray-600 dark:text-gray-400">
                Can't find the answer you're looking for? Reach out to our
                <.link
                  class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                  href="mailto:support@mosslet.com"
                >
                  customer support
                </.link>
                team.
              </p>
            </div>
            <div class="mt-10 lg:col-span-7 lg:mt-0">
              <dl class="space-y-10">
                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What is MOSSLET?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET is a privacy-first social network designed to protect users' privacy and human dignity from surveillance and the attention economy. We prioritize privacy, data protection, and creating a safe space for meaningful social interactions.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    How does MOSSLET protect my privacy?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET employs asymmetric encryption (end-to-end) to ensure that your data remains private and secure. This means that only you and the intended recipient can access your messages and information, keeping your interactions confidential.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What is the pay once pricing model?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET operates on a pay once pricing model, currently set at $20 during our beta phase. This approach allows us to maintain our service without relying on advertising or data monetization, ensuring that your privacy and experience remains our top priority.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    What makes MOSSLET different from other social networks?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    MOSSLET stands out by prioritizing user privacy, employing ethical design practices, and offering a straightforward pricing model. Unlike traditional social networks that rely on advertising and data exploitation, we focus on creating a safe and respectful environment for our users.
                  </dd>
                </div>

                <div>
                  <dt class="text-base/7 font-semibold text-gray-900 dark:text-gray-100">
                    Can I delete my account and data?
                  </dt>
                  <dd class="mt-2 text-base/7 text-gray-600 dark:text-gray-400">
                    Yes, you can delete your account at any time. When you choose to delete your account, all your data will be permanently removed from our servers, ensuring that your information is no longer accessible.
                  </dd>
                </div>

                <%!-- More questions... --%>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </section>

    <div class="pb-12">
      <div id="more-faq-show-button-container" class="hidden relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-background-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            id="more-faq-show-button"
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-show-button-container")
              |> JS.toggle(to: "#more-faq-hide-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-background-100 px-3 py-1.5 text-sm font-semibold text-background-900 shadow-sm ring-1 ring-inset ring-background-300 hover:bg-background-50"
          >
            <svg
              class="-ml-1 -mr-0.5 size-5 text-background-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
              data-slot="icon"
            >
              <path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z" />
            </svg>
            Show in-depth FAQ
          </button>
        </div>
      </div>

      <div id="more-faq-hide-button-container" class="relative">
        <div class="absolute inset-0 flex items-center" aria-hidden="true">
          <div class="w-full border-t border-background-300"></div>
        </div>
        <div class="relative flex justify-center">
          <button
            type="button"
            phx-click={
              JS.toggle(to: "#more-faq")
              |> JS.toggle(to: "#more-faq-hide-button-container")
              |> JS.toggle(to: "#more-faq-show-button-container")
            }
            class="inline-flex items-center gap-x-1.5 rounded-full bg-background-100 px-3 py-1.5 text-sm font-semibold text-background-900 shadow-sm ring-1 ring-inset ring-background-300 hover:bg-background-50"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="-ml-1 -mr-0.5 size-5 text-background-400"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
            </svg>
            Hide in-depth FAQ
          </button>
        </div>
      </div>

      <.more_faq_app />
    </div>
    """
  end

  def more_faq_app(assigns) do
    assigns = assigns

    ~H"""
    <section id="more-faq" class="mt-10 transition-all" aria-labelledby="more-faq-title">
      <div class="mx-auto max-w-7xl bg-white dark:bg-gray-800 shadow-md dark:shadow-emerald-500/50">
        <div class="mx-auto max-w-7xl px-4 lg:px-8 pb-16 sm:pb-24">
          <div class="pt-4 mb-12"></div>
          <.faq_section_heading_app title="General" anchor_tag="general" />
          <div class="mt-12"></div>

          <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                What are dark patterns?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Dark patterns are deceptive design techniques used in websites or apps to manipulate users into making choices they might not otherwise make, often to benefit the company.
              </dd>
            </div>
            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                Is there a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                Not yet! In the meantime, you can log into your account (or visit any page on the website) from the web browser on your mobile device, click the share icon (<.phx_icon
                  name="hero-arrow-up-on-square"
                  class="inline-flex h-5 w-5"
                />), and then select the "Add to home screen" option to save a MOSSLET shortcut to your device.
              </dd>
            </div>

            <div>
              <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                When will there be a MOSSLET app for desktop or mobile?
              </dt>
              <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                TBA. We're a small team and are currently looking into different options for bringing our web app to a native device. Once we know, we'll share the update here.
              </dd>
            </div>
          </dl>

          <div class="mt-20">
            <.faq_section_heading_app title="Data" anchor_tag="data" />
            <div class="mb-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does MOSSLET do with my data?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  MOSSLET uses your data to power your account and its features for you. For example, it is securely and privately stored for you so that you can access your account, update or delete your data, and share it with others.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET share, sell, or otherwise use my data behind my back?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! And we will never do that. Period. Unlike Facebook and Big Tech, there's nothing sneaky here. You pay for our service and we provide you with privacy-first features for a calmer, better life.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data encrypted?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your personal data is asymmetrically encrypted with a password-derived key, making it so that only you can access and unlock your data. Without your password, no one else can — not even us! We then wrap that encrypted data in an extra layer of symmetric encryption before storing it at rest ("at rest" meaning in the database when you are not using it).
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  In more detail it looks like this: each person has a (1) password-derived key, (2) public-private key pair, and (3) their private key is encrypted with their password-derived key.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How is my data shared with my friends?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you share your data with your friends, they receive an encrypted copy of a unique key specific to that piece of data (think a Post or Memory). Their copy is encrypted with their public key so that they can unlock it and thus access the data you shared with them.
                </dd>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  This ensures that only the people you choose to share with can access whatever you are sharing. When you delete a friend or stop sharing with them, their access to your data is also removed.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Where is my data stored?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Your data is stored in our secure, private database network that is distributed and run by our hardware provider <.link
                    href="https://fly.io"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Fly</.link>. The network is protected with the WireGuard protocol and your personal data is encrypted twice before being stored in the database.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Any media data, like Memories and avatars (photos), are stored with our private, decentralized cloud storage provider <.link
                    href="https://tigrisdata.com"
                    rel="_noopener"
                    target="_blank"
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    Tigris</.link>. Your data is asymmetrically encrypted and then sent to Tigris where it is distributed around the world for faster speeds and optimal availability.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Does MOSSLET use my image or data to train its AI?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Nope! We are using a pre-trained, open source model from the machine learning community. This means it was trained on other image data (~80,000 images). We then run this model on our own private, internal servers — ensuring your data remains private and secure.
                </dd>
              </div>
            </dl>

            <%!--
            <div class="mb-12"></div>
            <.faq_section_heading title="Memories" anchor_tag="memories" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What are Memories? Can I share them publicly?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Memories are photos. You can share them with anyone you're connected to but not publicly. Publicly sharing a Memory is a feature that we are considering for the future.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do you ensure images are safe?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We currently check all images against an AI model fine-tuned for detecting NSFW images (not safe for work). If an image is deemed NSFW, then it cannot be uploaded. This is not a foolproof system and won't catch everything, but it is a start. Please report to us any harmful images at <.link
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                    href="mailto:support@mosslet.com"
                  >support</.link>.
                </dd>
              </div>
            </dl>

            --%>

            <div class="mb-12"></div>
            <.faq_section_heading_app title="Password" anchor_tag="password" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div id="irreversibly-hashed">
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What does "irreversibly hashed" mean?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Irreversibly hashing a password means converting it into a fixed-length string of characters using a one-way function, making it impossible to retrieve the original password from that string. We use an industry leading method that ensures you can safely log in to your account without risking someone else being able to know your password.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens if I forget my password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you forget your password and have not enabled our forgot password feature in your settings, then you won't be able to regain access to your account. We do not have the ability to reset your password due to the secure encryption of your account and its data.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  If you have enabled the forgot password feature, then you can simply
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  using your account email. We recommend that you use a password manager or save your password in a secure, private place so that you don't forget it.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What is the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  The forgot password feature gives you the ability to get back into your account should you forget your password. We created this feature to give you the choice between added convenience and increased security. Simply go to your account settings to enable/disable it at any time.
                </dd>
                <dd class="mt-4 text-base leading-7 text-gray-600 dark:text-gray-400">
                  We recommend for most people that you enable the forgot password feature to ensure you don't get locked out of your account — your account and its data will still be protected with strong encryption.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  I enabled the forgot password feature, what happens now?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you enable it, we store a symmetrically encrypted copy of your password-derived key in our private, secure database. This enables the server to use your password-derived key to let you back into your account with a standard
                  <.link
                    navigate={~p"/auth/reset-password"}
                    class="text-emerald-600 hover:text-emerald-500 dark:text-emerald-400 dark:hover:text-emerald-300"
                  >
                    reset your password
                  </.link>
                  request email.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  What happens when I disable the forgot password feature?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  When you disable it, the symmetrically encrypted copy of your password-derived key is deleted from our database. This returns your account to its original asymmetric encryption — meaning only your password can let you back into your account and unlock your data.
                </dd>
              </div>
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  How do I change my account password?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  You can change your password any time from within your settings. Simply log in to your account and go to the "change password" section of your settings to make the change.
                </dd>
              </div>
            </dl>

            <div class="mb-12"></div>
            <.faq_section_heading_app title="Posts" anchor_tag="posts" />
            <div class="mt-12"></div>

            <dl class="space-y-16 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:gap-y-16 sm:space-y-0 lg:gap-x-10">
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! Simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Post you wish to reply to. All replies are sent, updated, and deleted in real time.
                </dd>
              </div>

              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I make a public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  No. This is a feature we are considering for the future.
                </dd>
              </div>

              <%!-- Public Post
              <div>
                <dt class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
                  Can I reply to a Public Post?
                </dt>
                <dd class="mt-2 text-base leading-7 text-gray-600 dark:text-gray-400">
                  Yes! If you are signed into your MOSSLET account, simply click on the
                  <.phx_icon name="hero-chat-bubble-left-right" class="inline-flex h-5 w-5" />
                  icon on the bottom of the Public Post you wish to reply to. All public replies are sent, updated, and deleted in real time.
                </dd>
              </div>
              --%>
            </dl>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp faq_section_heading(assigns) do
    ~H"""
    <div id={@anchor_tag} class="border-b border-t border-gray-200 dark:border-gray-700 py-5 my-6">
      <h2 class="text-xl font-semibold tracking-tight sm:text-2xl text-base text-gray-900 dark:text-gray-100 text-center">
        {@title}
      </h2>
    </div>
    """
  end

  defp faq_section_heading_app(assigns) do
    ~H"""
    <div
      id={@anchor_tag}
      class="border-b border-t border-background-200 dark:border-background-700 py-5"
    >
      <h2 class="text-xl font-semibold tracking-tight sm:text-2xl text-base text-background-900 dark:text-background-100 text-center">
        {@title}
      </h2>
    </div>
    """
  end
end
