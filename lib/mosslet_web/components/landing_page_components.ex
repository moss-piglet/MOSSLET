defmodule MossletWeb.LandingPageComponents do
  @moduledoc """
  A set of components for use in a landing page.
  """
  use Phoenix.Component
  use PetalComponents

  alias MossletWeb.BillingComponents

  attr :image_src, :string, required: true
  attr :logo_cloud_title, :string, default: nil
  attr :max_width, :string, default: "xl", values: ["sm", "md", "lg", "xl", "full"]
  slot :title
  slot :description
  slot :cloud_logo
  slot :action_buttons

  def hero(assigns) do
    ~H"""
    <section id="hero" class="overflow-hidden bg-white dark:bg-gray-950">
      <.particles_animation quantity={30} class="fade-in-animation" />
      <.container max_width={@max_width} class="relative z-10 stagger-fade-in-animation xl:pt-32">
        <div
          class="fade-in-animation absolute left-[calc(50%-4rem)] top-10 -z-10 transform-gpu blur-3xl sm:left-[calc(50%-18rem)] lg:-left-[calc(10%-5rem)] lg:top-[calc(50%-28rem)] xl:top-[calc(50%-26rem)] xl:left-[calc(50%-22rem)]"
          aria-hidden="true"
        >
          <div
            class="aspect-[1108/632] w-[69rem] bg-gradient-to-r from-primary-300 to-primary-500 opacity-25"
            style="clip-path: polygon(25.9% 0%, 200% 25%, 60% 100%, 5% 75%)"
          >
          </div>
        </div>
        <div class="flex flex-wrap items-center -mx-3 overflow-hidden">
          <div class="w-full gap-4 px-3 xl:w-1/3">
            <div class="py-12">
              <div class="max-w-lg mx-auto mb-8 text-center lg:max-w-md xl:mx-0 lg:text-left">
                <.h1 class="font-bold leading-tight fade-in-animation">
                  {render_slot(@title)}
                </.h1>

                <p class="mt-8 text-lg leading-relaxed text-gray-500 dark:text-gray-400 fade-in-animation">
                  {render_slot(@description)}
                </p>
              </div>
              <div class="mt-12 space-x-2 text-center xl:text-left fade-in-animation">
                {render_slot(@action_buttons)}
              </div>
            </div>
          </div>
          <div class="w-full px-3 mb-12 xl:pl-16 xl:w-2/3 lg:mb-0">
            <div class="flex items-center justify-center lg:h-128">
              <img
                id="hero-image"
                class="fade-in-from-right-animation w-[76rem] rounded-md bg-white/5 shadow-3xl ring-1 ring-white/10"
                src={@image_src}
                alt="Hero image"
              />
            </div>
          </div>
        </div>

        <%= if length(@cloud_logo) > 0 do %>
          <div class="mt-40">
            <.logo_cloud title={@logo_cloud_title} cloud_logo={@cloud_logo} />
          </div>
        <% end %>
      </.container>
    </section>
    """
  end

  attr :title, :string
  attr :cloud_logo, :list, default: [], doc: "List of slots"

  def logo_cloud(assigns) do
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

  attr :title, :string, required: true
  attr :description, :string
  attr :id, :string, default: nil

  attr :features, :list,
    default: [],
    doc:
      "A list of features, which are maps with the keys :icon (a HeroiconV1), :title and :description"

  attr :grid_classes, :string,
    default: "grid-cols-1 lg:grid-cols-3 md:grid-cols-2",
    doc: "Tailwind grid cols class to specify how many columns you want"

  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  def features(assigns) do
    ~H"""
    <section
      id="features"
      class="relative z-10 py-16 mt-24 overflow-hidden text-center transition duration-500 ease-in-out bg-white md:pt-16 md:pb-32 dark:bg-gray-950 dark:text-white"
    >
      <.container max_width={@max_width} class="relative z-10 stagger-fade-in-animation">
        <.particles_animation class="fade-in-animation" />
        <div class="mx-auto mb-16 md:mb-20 lg:w-7/12">
          <div class="mb-5 text-3xl font-bold leading-tight tracking-tight text-transparent sm:leading-tight lg:leading-relaxed md:mb-7 md:text-5xl fade-in-animation bg-clip-text bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white/5 dark:via-gray-300 dark:to-white">
            {@title}
          </div>
          <div class="text-lg font-light leading-relaxed text-gray-500 dark:text-gray-400 md:text-2xl fade-in-animation">
            {@description}
          </div>
        </div>

        <div
          class={[
            "grid fade-in-animation gap-8 group place-items-center",
            @grid_classes
          ]}
          data-highlighter
        >
          <%= for feature <- @features do %>
            <div
              id={feature.id}
              class="fade-in-animation flex h-full flex-col justify-between relative bg-gray-200 dark:bg-gray-800 shadow-3xl rounded-3xl p-px before:absolute before:w-96 before:h-96 before:-left-48 before:-top-48 dark:before:bg-primary-500 before:rounded-full before:opacity-0 before:pointer-events-none before:transition-opacity before:duration-500 before:translate-x-[var(--mouse-x)] before:translate-y-[var(--mouse-y)] before:hover:opacity-20 before:z-30 before:blur-[100px] after:absolute after:inset-0 after:rounded-[inherit] after:opacity-0 after:transition-opacity after:duration-500 after:[background:_radial-gradient(250px_circle_at_var(--mouse-x)_var(--mouse-y),theme(colors.gray.400),transparent)] after:group-hover:opacity-100 after:z-10 overflow-hidden"
            >
              <div class="relative flex flex-col h-full justify-between bg-gray-50 dark:bg-gray-950/90 rounded-[inherit] z-20 overflow-hidden">
                <div class="flex flex-col items-center justify-between h-full p-12">
                  <div class="flex justify-center mb-4 md:mb-6">
                    <div class="relative flex items-center justify-center w-16 h-16 border border-transparent shadow-2xl rounded-2xl [background:linear-gradient(theme(colors.gray.50),_theme(colors.gray.50))_padding-box,_conic-gradient(theme(colors.gray.200),_theme(colors.gray.100)_25%,_theme(colors.gray.100)_75%,_theme(colors.gray.200)_100%)_border-box] dark:[background:linear-gradient(theme(colors.gray.900),_theme(colors.gray.900))_padding-box,_conic-gradient(theme(colors.gray.400),_theme(colors.gray.700)_25%,_theme(colors.gray.700)_75%,_theme(colors.gray.400)_100%)_border-box] before:absolute before:inset-0 dark:before:bg-gray-800/30 before:rounded-2xl">
                      <.icon
                        name={feature.icon}
                        class="relative w-6 h-6 text-gray-900 fill-gray-900 dark:fill-gray-200 dark:text-gray-200"
                      />
                    </div>
                  </div>
                  <!-- Text -->
                  <div class="pt-0 md:pt-2">
                    <div class="mb-5">
                      <div>
                        <h3 class="inline-flex pb-2 text-xl font-bold text-transparent bg-clip-text bg-gradient-to-r dark:from-gray-200/60 dark:via-gray-200 dark:to-gray-200/60 from-gray-900 via-gray-700/80 to-gray-900">
                          {feature.title}
                        </h3>
                        <p class="leading-normal text-gray-600 dark:text-gray-400">
                          {feature.description}
                        </p>
                      </div>
                    </div>
                  </div>
                  <div>
                    <a
                      class="relative text-gray-500 transition duration-150 ease-in-out dark:text-gray-300 hover:text-gray-400 dark:hover:text-white group before:absolute before:inset-0 dark:before:bg-gray-800/30 before:rounded-full before:pointer-events-none"
                      href="#0"
                    >
                      <span class="relative inline-flex items-center">
                        Learn more
                        <.icon
                          solid
                          name={:arrow_small_right}
                          class="text-primary-600 dark:text-primary-500 w-4 h-4 ml-1 group-hover:translate-x-0.5 transition-transform duration-150 ease-in-out"
                        />
                      </span>
                    </a>
                  </div>
                </div>
              </div>
            </div>

            <%!-- <div class="px-8 mb-10 border-gray-200 md:px-16 fade-in-animation last:border-0">
              <div class="flex justify-center mb-4 md:mb-6">
                <span class="flex items-center justify-center w-12 h-12 rounded-md bg-primary-600">
                  <.icon name={feature.icon} class="w-6 h-6 text-white" />
                </span>
              </div>
              <div class="mb-2 text-lg font-medium md:text-2xl">
                <%= feature.title %>
              </div>
              <p class="font-light leading-normal md:text-lg">
                <%= feature.description %>
              </p>
            </div> --%>
          <% end %>
        </div>
      </.container>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :image_src, :string, required: true
  attr :inverted, :boolean, default: false
  attr :blur_color, :any, default: "primary", values: ["primary", "secondary", false]
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  slot :inner_block

  def solo_feature(assigns) do
    ~H"""
    <section
      id="benefits"
      class="relative z-10 py-16 overflow-hidden transition duration-500 ease-in-out bg-white md:pt-24 md:pb-40 dark:bg-gray-950 dark:text-white"
      data-offset="false"
    >
      <.container max_width={@max_width} class="relative z-10 stagger-fade-in-animation">
        <.particles_animation class="fade-in-animation" />

        <div class={
          "#{if @inverted, do: "flex-row-reverse", else: ""} relative isolate px-6 sm:px-10 sm:py-24 lg:py-24 lg:px-0 flex flex-wrap items-center gap-20 py-32 md:flex-nowrap"
        }>
          <div class="md:w-1/3 fade-in-animation">
            <div class="flex items-center justify-center w-16 h-16 mb-4 overflow-hidden rounded-full shadow-lg bg-gradient-to-tr dark:from-primary-600/50 via-primary-800 dark:to-primary-400 dark:highlight-white/10 shadow-primary-400/50 ring ring-white dark:ring-primary-400/80">
              <.icon solid name={:cube} class="w-8 h-8 text-primary-200" />
            </div>
            <div class="mb-5 text-3xl font-bold leading-tight tracking-tight text-transparent sm:leading-tight lg:leading-relaxed md:mb-7 fade-in-animation md:text-5xl bg-clip-text bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white/50 dark:via-gray-300 dark:to-white">
              {@title}
            </div>

            <div class="space-y-4 text-lg md:text-xl md:space-y-5">
              <p class="mt-8 leading-relaxed text-gray-500 dark:text-gray-400 fade-in-animation">
                {@description}
              </p>
            </div>
            <%= if render_slot(@inner_block) do %>
              <div class="fade-in-animation">
                {render_slot(@inner_block)}
              </div>
            <% end %>
          </div>
          <div
            :if={@blur_color}
            class={"#{if @inverted, do: "rotate-180 lg:right-1/3 md:-top-1/8 -z-10 -translate-y-1/2 lg:bottom-0 lg:top-auto lg:translate-y-0", else: "lg:left-1/3 md:-left-1/6 -left-1/4 top-72 md:top-0 -z-10 -translate-y-1/2 lg:top-20 lg:bottom-auto lg:translate-y-0"} blur-3xl fade-in-animation pointer-events-none absolute transform-gpu overflow-hidden"}
            aria-hidden="true"
          >
            <div
              class={
              "#{if @blur_color == "primary", do: "from-primary-200 to-primary-600 bg-primary-animation"} #{if @blur_color == "secondary", do: "from-secondary-200 to-secondary-600 bg-secondary-animation"} relative flex items-center justify-center aspect-[1155/678] w-[72.1875rem] bg-gradient-to-tr opacity-25"
            }
              style={"#{if @inverted, do: "clip-path: polygon(25.9% 0%, 100% 25%, 60% 100%, 5% 75%)", else: "clip-path: polygon(25.9% 0%, 100% 0%, 50% 100%, 0% 50%)"}"}
            >
            </div>
          </div>
          <div class="w-full lg:w-2/3 md:mt-0">
            <img
              class="z-10 w-full rounded-md shadow-2xl bg-white/5 ring-1 ring-white/10 fade-in-animation"
              src={@image_src}
              alt="Screenshot"
            />
          </div>
        </div>
      </.container>
    </section>
    """
  end

  attr :title, :string, default: "Testimonials"
  attr :testimonials, :list, doc: "A list of maps with the keys: content, image_src, name, title"
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]

  def testimonials(assigns) do
    ~H"""
    <section
      id="testimonials"
      class="relative z-10 bg-white stagger-fade-in-animation dark:bg-gray-950"
    >
      <div class="relative overflow-hidden py-36 isolate content-wrapper">
        <!-- Blur Gradient -->
        <div class="absolute overflow-hidden -translate-y-1/2 pointer-events-none left-1/3 -z-10 top-10 lg:top-20 lg:bottom-auto lg:translate-y-0 blur-3xl fade-in-animation transform-gpu">
          <div
            class="from-primary-200 to-primary-600 bg-primary-animation relative flex items-center justify-center aspect-[1155/678] w-[72.1875rem] bg-gradient-to-tr opacity-25"
            style="clip-path: polygon(55.9% 10%, 20% 0%, 50% 70%, 0% 50%)"
          >
          </div>
        </div>
        <.particles_animation class="fade-in-animation" />
        <div class="mb-5 text-center md:mb-12 section-header">
          <div class="mb-5 text-3xl font-bold leading-tight tracking-tight text-transparent sm:leading-tight lg:leading-relaxed md:mb-7 md:text-5xl fade-in-animation bg-clip-text bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white/5 dark:via-gray-300 dark:to-white">
            {@title}
          </div>
        </div>
        <.container max_width={@max_width} class="relative z-10">
          <div class="relative before:absolute isolate before:inset-0 before:-translate-x-full before:z-20 before:bg-gradient-to-l before:from-transparent dark:before:to-gray-950 before:to-20% after:absolute after:inset-0 after:translate-x-full after:z-20 after:bg-gradient-to-r after:from-transparent dark:after:to-gray-950 before:to-white after:to-white  after:to-20%">
            <div class="solo-animation fade-in-animation flickity group">
              <div data-highlighter>
                <%= for testimonial <- @testimonials do %>
                  <.testimonial_panel {testimonial} />
                <% end %>
              </div>
            </div>
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

    <link
      rel="stylesheet"
      href="https://cdnjs.cloudflare.com/ajax/libs/flickity/2.3.0/flickity.min.css"
      integrity="sha512-B0mpFwHOmRf8OK4U2MBOhv9W1nbPw/i3W1nBERvMZaTWd3+j+blGbOyv3w1vJgcy3cYhzwgw1ny+TzWICN35Xg=="
      crossorigin="anonymous"
      referrerpolicy="no-referrer"
    />
    """
  end

  attr :content, :string, required: true
  attr :image_src, :string, required: true
  attr :name, :string, required: true
  attr :title, :string, required: true

  def testimonial_panel(assigns) do
    ~H"""
    <div class="fade-in-animation relative w-full mr-10 overflow-hidden text-gray-700 shadow-lg rounded-3xl dark:shadow-3xl  md:w-8/12 lg:w-5/12 bg-primary-50 dark:bg-gray-800 dark:text-white carousel-cell last:mr-0 before:absolute before:w-96 before:h-96 before:-left-48 before:-top-48 dark:before:bg-primary-500 before:rounded-full before:opacity-0 before:pointer-events-none before:transition-opacity before:duration-500 before:translate-x-[var(--mouse-x)] before:translate-y-[var(--mouse-y)] before:hover:opacity-20 before:z-30 before:blur-[100px] after:absolute after:inset-0 after:rounded-[inherit] after:opacity-0 after:transition-opacity after:duration-500 after:[background:_radial-gradient(250px_circle_at_var(--mouse-x)_var(--mouse-y),theme(colors.gray.400),transparent)] after:group-hover:opacity-100 after:z-10">
      <div class="relative flex flex-col h-full justify-between bg-gray-50 dark:bg-gray-900 rounded-[inherit] z-20 overflow-hidden md:p-8 p-6">
        <blockquote class="mt-6 md:flex-grow md:flex md:flex-col">
          <div class="relative text-lg font-medium md:flex-grow">
            <svg
              class="absolute top-[-20px] left-0 w-8 h-8 transform -translate-x-3 -translate-y-2 text-primary-500 opacity-40"
              fill="currentColor"
              viewBox="0 0 32 32"
              aria-hidden="true"
            >
              <path d="M9.352 4C4.456 7.456 1 13.12 1 19.36c0 5.088 3.072 8.064 6.624 8.064 3.36 0 5.856-2.688 5.856-5.856 0-3.168-2.208-5.472-5.088-5.472-.576 0-1.344.096-1.536.192.48-3.264 3.552-7.104 6.624-9.024L9.352 4zm16.512 0c-4.8 3.456-8.256 9.12-8.256 15.36 0 5.088 3.072 8.064 6.624 8.064 3.264 0 5.856-2.688 5.856-5.856 0-3.168-2.304-5.472-5.184-5.472-.576 0-1.248.096-1.44.192.48-3.264 3.456-7.104 6.528-9.024L25.864 4z">
              </path>
            </svg>
            <p class="relative font-light leading-relaxed text-gray-500 dark:text-gray-400">
              {@content}
            </p>
          </div>
          <footer class="mt-8">
            <div class="flex items-start">
              <div class="inline-flex flex-shrink-0 border-2 border-white rounded-full">
                <img class="w-12 h-12 rounded-full" src={@image_src} alt="" />
              </div>
              <div class="ml-4">
                <div class="text-base font-semibold text-gray-900 dark:text-gray-100">
                  {@name}
                </div>
                <div class="text-base font-normal text-gray-700 dark:text-gray-300">
                  {@title}
                </div>
              </div>
            </div>
          </footer>
        </blockquote>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :max_width, :string, default: "lg", values: ["sm", "md", "lg", "xl", "full"]
  attr :products, :map, default: Mosslet.Billing.Plans.products()
  attr :button_label, :string, default: "Sign up now"

  def pricing(assigns) do
    ~H"""
    <section
      id="pricing"
      class="relative py-24 overflow-hidden text-gray-700 transition duration-500 ease-in-out md:py-32 dark:text-white stagger-fade-in-animation"
    >
      <.particles_animation class="fade-in-animation z-99" />
      <.container max_width={@max_width}>
        <div class="mx-auto mb-16 text-center md:mb-20 lg:w-7/12 ">
          <div class="mb-5 text-3xl font-bold leading-tight tracking-tight text-transparent sm:leading-tight lg:leading-relaxed md:mb-7 md:text-5xl fade-in-animation bg-clip-text bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white/5 dark:via-gray-300 dark:to-white">
            {@title}
          </div>
          <div class="text-lg font-light leading-relaxed text-gray-500 dark:text-gray-400 md:text-2xl fade-in-animation">
            {@description}
          </div>
        </div>

        <div class="pb-32 fade-in-animation">
          <div class="relative hidden w-full max-w-xs -z-50 dark:block md:max-w-5xl xl:max-w-7xl">
            <div class="absolute lg:top-0 top-[5rem] rounded-full bg-primary-400 lg:-left-4 w-[30rem] h-[30rem] blur-3xl filter opacity-10 animate-blob mix-blend-lighten">
            </div>
            <div class="absolute rounded-full lg:top-4 top-[40rem] bg-primary-600 lg:left-32 w-[40rem] h-[40rem] filter blur-3xl opacity-10 animate-blob mix-blend-lighten animation-delay-1000">
            </div>
            <div class="absolute rounded-full bg-primary-500 top-[60rem] lg:top-16 lg:-right-4 w-[30rem] h-[30rem] blur-3xl filter opacity-10 animate-blob mix-blend-lighten animation-delay-2000">
            </div>
            <div class="absolute rounded-full bg-secondary-600 top-[10rem] right-[5rem] lg:top-12 blur-3xl lg:right-56 w-[40rem] h-[40rem] filter opacity-10 animate-blob mix-blend-lighten animation-delay-3000">
            </div>
            <div class="absolute rounded-full bg-secondary-500 blur-3xl top-[80rem] lg:top-8 lg:left-96 w-[25rem] h-[25rem] filter opacity-10 animate-blob mix-blend-lighten animation-delay-4000">
            </div>
          </div>

          <BillingComponents.pricing_panels_container panels={length(@products)} interval_selector>
            <%= for product <- @products do %>
              <BillingComponents.pricing_panel
                label={product.name}
                description={product.description}
                features={product.features}
                most_popular={Map.get(product, :most_popular)}
                class="fade-in-animation"
              >
                <%= for plan <- product.plans do %>
                  <BillingComponents.item_price
                    id={"pricing-plan-#{plan.id}"}
                    interval={plan.interval}
                    amount={plan.amount}
                    button_label={@button_label}
                    is_public
                  />
                <% end %>
              </BillingComponents.pricing_panel>
            <% end %>
          </BillingComponents.pricing_panels_container>
        </div>
      </.container>
    </section>
    """
  end

  attr :quantity, :integer, default: 25
  attr :class, :string, default: nil

  def particles_animation(assigns) do
    ~H"""
    <div class={["absolute inset-0 mx-auto", @class]}>
      <div class="absolute inset-0 -z-10" aria-hidden="true">
        <canvas data-particle-animation data-particle-quantity={@quantity}></canvas>
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
end
