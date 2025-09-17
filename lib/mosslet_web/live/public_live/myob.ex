defmodule MossletWeb.PublicLive.Myob do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:myob}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <%!-- Enhanced liquid metal background --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <main class="isolate">
          <%!-- Hero section with liquid effects matching other pages --%>
          <div class="relative isolate overflow-hidden pt-14">
            <%!-- Floating gradient orbs for liquid metal effect --%>
            <div
              class="absolute left-1/2 top-0 -z-10 -ml-24 transform-gpu overflow-hidden blur-3xl lg:ml-24 xl:ml-48"
              aria-hidden="true"
            >
              <div
                class="aspect-[801/1036] w-[50.0625rem] bg-gradient-to-tr from-teal-400/30 via-emerald-400/20 to-cyan-400/30 opacity-40 dark:opacity-20"
                style="clip-path: polygon(63.1% 29.5%, 100% 17.1%, 76.6% 3%, 48.4% 0%, 44.6% 4.7%, 54.5% 25.3%, 59.8% 49%, 55.2% 57.8%, 44.4% 57.2%, 27.8% 47.9%, 35.1% 81.5%, 0% 97.7%, 39.2% 100%, 35.2% 81.4%, 97.2% 52.8%, 63.1% 29.5%)"
              >
              </div>
            </div>

            <%!-- Hero Content --%>
            <div class="mx-auto max-w-7xl px-6 pb-24 pt-10 sm:pb-32 lg:flex lg:px-8 lg:py-40">
              <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-xl lg:flex-shrink-0 lg:pt-8">
                <%!-- Enhanced hero title with liquid metal styling matching other pages --%>
                <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                  Mind Your Own Business
                </h1>
                <p class="mt-8 text-pretty text-lg font-medium text-slate-600 dark:text-slate-400 sm:text-xl/8 transition-colors duration-300 ease-out">
                  Privacy isn't just a feature — it's the foundation of human dignity. Your personal life should stay personal, whether online or offline.
                </p>

                <%!-- Decorative accent line matching other pages --%>
                <div class="mt-8 flex justify-start">
                  <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                  </div>
                </div>

                <%!-- CTA buttons using design system --%>
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

              <%!-- Personal Privacy List --%>
              <div class="mx-auto mt-16 flex max-w-2xl lg:ml-10 lg:mr-0 lg:mt-0 lg:max-w-none lg:flex-none xl:ml-32">
                <div class="max-w-3xl flex-none sm:max-w-5xl lg:max-w-none">
                  <.liquid_card
                    padding="lg"
                    class="space-y-2 text-sm text-slate-600 dark:text-slate-400 sm:text-base lg:text-lg"
                  >
                    <:title>
                      <span class="bg-gradient-to-r from-purple-500 to-violet-500 bg-clip-text text-transparent">
                        None of Our Business
                      </span>
                    </:title>
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
                  </.liquid_card>
                </div>
              </div>
            </div>
          </div>

          <%!-- Big Tech Section --%>
          <div class="mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
            <div class="mx-auto max-w-4xl text-center">
              <h2 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                Hey Big Tech,
              </h2>

              <%!-- Big Tech list in card format --%>
              <.liquid_card padding="lg" class="mt-12">
                <:title>
                  <span class="bg-gradient-to-r from-amber-500 to-orange-500 bg-clip-text text-transparent">
                    None of Your Business Either
                  </span>
                </:title>
                <div class="space-y-4 text-lg text-slate-600 dark:text-slate-400 sm:text-xl lg:text-2xl">
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">which ads I linger on.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">when I go online.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      which search engine I use.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">where I am right now.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">which photos I like.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">who I respond to.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">which articles I read.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">who I ignore.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      how many times I watched that video.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">if I'm using a VPN.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      what my home address is.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      what I just said out loud.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      how many tabs I have open.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">who I follow.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      what I'm typing right now.
                    </strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">which apps I download.</strong>
                  </p>
                  <p>
                    It's none of your business
                    <strong class="text-slate-900 dark:text-slate-200">
                      what's left in my shopping cart.
                    </strong>
                  </p>
                </div>
              </.liquid_card>
            </div>
          </div>

          <%!-- Main Content Section --%>
          <div class="mx-auto max-w-7xl px-6 py-24 sm:py-32 lg:px-8">
            <div class="mx-auto max-w-4xl text-center">
              <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                It's none of our business, so it's not our business
              </h2>
              <p class="mt-8 text-lg text-slate-600 dark:text-slate-400 sm:text-xl/8">
                Unlike the surveillance economy of Big Tech, we've built MOSSLET on the radical idea that your privacy is valuable — and worth protecting.
              </p>
            </div>

            <%!-- Content Grid using liquid cards --%>
            <div class="mx-auto mt-16 grid max-w-2xl grid-cols-1 gap-8 lg:mx-0 lg:max-w-none lg:grid-cols-2">
              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                    Our business model is boring
                  </span>
                </:title>
                <p class="text-lg leading-8 text-slate-600 dark:text-slate-400">
                  <strong class="text-slate-900 dark:text-slate-200">
                    At MOSSLET, our business model is as basic as it is boring:
                  </strong>
                  We charge our customers a fair price for our products. That's it. We don't take your personal data as payment, we don't try to monetize your eyeballs, we don't target you, we don't sell, broker, or barter ads. We will never spy on you or enable others to either. It's absolutely none of their business, and it's none of ours either.
                </p>
              </.liquid_card>

              <.liquid_card
                padding="lg"
                class="group hover:scale-105 transition-all duration-300 ease-out"
              >
                <:title>
                  <span class="bg-gradient-to-r from-blue-500 to-cyan-500 bg-clip-text text-transparent">
                    Privacy is personal to us
                  </span>
                </:title>
                <p class="text-lg leading-8 text-slate-600 dark:text-slate-400">
                  <strong class="text-slate-900 dark:text-slate-200">
                    Privacy is personal to us:
                  </strong>
                  We've been building and using computers for thirty years. We were around in 2000 when Google pioneered the invisible prison of surveillance capitalism and hid behind the thin veil of "Don't Be Evil". We've seen their strategies for collecting, selling, and abusing personal data on an industrial scale spread to every industry. We remember when Facebook rose from The FaceBook to the pusher of algorithmically-engineered traps of attention and worse. The internet didn't use to be like this, and it doesn't have to be like that today either.
                </p>
              </.liquid_card>
            </div>

            <%!-- Additional Content in card format --%>
            <.liquid_card padding="lg" class="mx-auto mt-16 max-w-2xl lg:max-w-4xl">
              <:title>
                <span class="bg-gradient-to-r from-cyan-500 to-teal-500 bg-clip-text text-transparent">
                  Your Privacy, Our Promise
                </span>
              </:title>
              <div class="space-y-8 text-lg leading-8 text-slate-600 dark:text-slate-400">
                <p>
                  But right now it just is. You have to defend yourself from these Big Tech giants, and the legion of companies following their nasty example. Collect It All has sunk into the ideology of the commercial internet, so most companies don't even think about it. It's just what they do.
                </p>
                <p>
                  <strong class="text-slate-900 dark:text-slate-200">
                    MOSSLET doesn't mine your posts for data:
                  </strong>
                  There are no big AI engines to feed. We don't analyze what links you click, your interests, your location, who your friends are, what you say. We don't take your your face from your pictures, nothing personal other than the most basic identifying information we need to call you a customer. Everything else is simply none of our business. And because you pay to use MOSSLET, it doesn't need to be. Even then, we encrypt it all in a way so that we couldn't analyze or monetize it even if we wanted to — which we don't.
                </p>
                <p>
                  When you're in the business of "free", like Google, Facebook, Instagram, TikTok, YouTube, and many others, you're in the business of snooping. Tricking. Collecting. Aggregating. Slicing. Dicing. Packaging. Do you really want to be used like that? As a resource to be mined? Do you really want companies secretly deciding and controlling your future? If you're here, and curious about MOSSLET, you probably don't.
                </p>
                <p>
                  Privacy used to be something exotic and niche. Today it's going mainstream, but it's still early. You can be early on this trend. You can be part of the change. Using MOSSLET is standing up, not giving in.
                </p>
                <p>
                  <strong class="text-slate-900 dark:text-slate-200">
                    Your data is none of their business:
                  </strong>
                  Don't give them what isn't theirs. At MOSSLET, we've got your back without looking over your shoulder.
                </p>
              </div>

              <%!-- Call to Action using design system --%>
              <div class="mt-12 flex flex-col sm:flex-row gap-4 justify-center">
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
                  Explore features
                </.liquid_button>
              </div>
            </.liquid_card>
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
     |> assign(:page_title, "Mind Your Own Business")
     |> assign_new(:meta_description, fn ->
       "At MOSSLET, our business model is as basic as it is boring: We charge our customers a fair price for our products. That's it. We don't take your personal data as payment, we don't try to monetize your eyeballs, we don't target you, we don't sell, broker, or barter ads. We will never track you, spy on you, or enable others to either. It's absolutely none of their business, and it's none of ours either."
     end)}
  end
end
