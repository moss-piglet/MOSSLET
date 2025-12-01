defmodule MossletWeb.PublicLive.Privacy do
  @moduledoc false
  use MossletWeb, :live_view

  import MossletWeb.DesignSystem

  @impl true
  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:privacy}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <%!-- Enhanced liquid metal background --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <div class="isolate">
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
                <div class="mx-auto max-w-2xl text-center">
                  <%!-- Enhanced hero title with liquid metal styling matching other pages --%>
                  <h1 class="text-5xl font-bold tracking-tight text-pretty sm:text-6xl lg:text-7xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent transition-all duration-300 ease-out">
                    Privacy is the standard
                  </h1>

                  <%!-- Enhanced subtitle --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    We do not log or share personal information. Your privacy isn't a feature to us — it's a fundamental right that guides everything we do.
                  </p>

                  <%!-- Decorative accent line matching other pages --%>
                  <div class="mt-8 flex justify-center">
                    <div class="h-1 w-24 rounded-full transition-all duration-500 ease-out bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <%!-- Privacy features section with liquid metal cards --%>
          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-none">
              <div class="mt-6 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-4">
                <.liquid_card
                  padding="md"
                  class="group hover:scale-105 transition-all duration-300 ease-out transform-gpu"
                >
                  <:title>
                    <div class="flex items-center gap-3">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-teal-500 to-emerald-500">
                        <.phx_icon name="hero-lock-closed" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent font-semibold">
                        Asymmetric
                      </span>
                    </div>
                  </:title>
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    Your data is encrypted to your account password so that only you can access it.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="md"
                  class="group hover:scale-105 transition-all duration-300 ease-out transform-gpu"
                >
                  <:title>
                    <div class="flex items-center gap-3">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-emerald-500 to-cyan-500">
                        <.phx_icon name="hero-banknotes" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-emerald-500 to-cyan-500 bg-clip-text text-transparent font-semibold">
                        Ownership
                      </span>
                    </div>
                  </:title>
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    You own your data and can delete your account, and all of its data, at any time.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="md"
                  class="group hover:scale-105 transition-all duration-300 ease-out transform-gpu"
                >
                  <:title>
                    <div class="flex items-center gap-3">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-blue-500 to-violet-500">
                        <.phx_icon name="hero-beaker" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-blue-500 to-violet-500 bg-clip-text text-transparent font-semibold">
                        Guinea Pig Free
                      </span>
                    </div>
                  </:title>
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    We adore our furry friends, but you won't find any here. No user experiments ever.
                  </p>
                </.liquid_card>

                <.liquid_card
                  padding="md"
                  class="group hover:scale-105 transition-all duration-300 ease-out transform-gpu"
                >
                  <:title>
                    <div class="flex items-center gap-3">
                      <div class="flex size-10 items-center justify-center rounded-lg bg-gradient-to-r from-purple-500 to-pink-500">
                        <.phx_icon name="hero-finger-print" class="size-6 text-white" />
                      </div>
                      <span class="bg-gradient-to-r from-purple-500 to-pink-500 bg-clip-text text-transparent font-semibold">
                        Autonomy
                      </span>
                    </div>
                  </:title>
                  <p class="text-slate-600 dark:text-slate-400 leading-relaxed">
                    Connect and share free from fingerprints, spyware and trackers.
                  </p>
                </.liquid_card>
              </div>
            </div>
          </div>

          <%!-- Privacy Policy section --%>
          <div class="mx-auto mt-32 max-w-7xl px-6 sm:mt-40 lg:px-8">
            <div class="mx-auto max-w-4xl">
              <div class="text-center mb-16">
                <h2 class="text-4xl font-bold tracking-tight text-pretty sm:text-5xl lg:text-6xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Privacy Policy
                </h2>
                <p class="mt-4 text-lg text-gray-600 dark:text-gray-400">
                  Originally published November 9, 2021
                </p>
                <p class="text-sm text-rose-600 dark:text-rose-400">
                  (updated September 17, 2025)
                </p>
                <p class="mt-8 text-xl text-gray-600 dark:text-gray-400 leading-8">
                  We do not log or share personal information. That is our privacy policy in a nutshell. The rest of this policy tries to explain what information we may have, why we have it, how we protect it, and why you should care.
                </p>
              </div>

              <%!-- Overview Section --%>
              <div class="mb-12 p-6 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-2xl border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
                <h3 class="text-xl font-bold text-teal-800 dark:text-teal-200 mb-6">
                  Why Privacy Matters
                </h3>
                <div class="space-y-6 text-gray-700 dark:text-gray-300">
                  <p class="text-lg leading-relaxed">
                    Privacy is <strong>essential to a free life</strong>. MOSSLET is an alternative destination for social connection online, free of surveillance capitalism and psychometric profiling.
                  </p>

                  <%!-- Key Benefits Grid --%>
                  <div class="bg-white dark:bg-gray-800/80 rounded-xl p-6 border border-teal-100 dark:border-teal-800">
                    <h4 class="font-semibold text-teal-800 dark:text-teal-200 mb-4 text-center">
                      What MOSSLET Guarantees
                    </h4>
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-check-badge"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">You own 100% of your data</span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-check-badge"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">Your data is encrypted</span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-check-badge"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">
                          You are <strong>not</strong> manipulated
                        </span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-check-badge"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">
                          Your data is <strong>not</strong> shared
                        </span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center sm:col-span-2 lg:col-span-1">
                        <.icon
                          name="hero-check-badge"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">You are <strong>not</strong> spied on</span>
                      </div>
                    </div>
                  </div>

                  <p>
                    MOSSLET is designed so that you can connect and share with the people in your life, on your terms. At MOSSLET, being human doesn't come at the expense of your humanity.
                  </p>

                  <%!-- Academic Context - Collapsible for those interested --%>
                  <details class="group">
                    <summary class="cursor-pointer text-teal-700 dark:text-teal-300 hover:text-teal-600 dark:hover:text-teal-200 font-medium flex items-center">
                      <span>Learn more about surveillance capitalism</span>
                      <.icon
                        name="hero-chevron-down"
                        class="h-4 w-4 ml-2 transition-transform group-open:rotate-180"
                      />
                    </summary>
                    <div class="mt-3 space-y-3 text-sm leading-relaxed text-gray-600 dark:text-gray-400 pl-4 border-l-2 border-teal-200 dark:border-teal-700">
                      <p>
                        Renowned author and CEW Professor Emerita at Harvard Business School, Shoshana Zuboff, dedicated 12 years to unmasking and naming the "emergence of a fundamentally anti-democratic economic logic" that she calls <.link
                          navigate="https://shoshanazuboff.com/book/about/"
                          target="_blank"
                          rel="_noopener"
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300"
                        >surveillance capitalism</.link>. Thanks to her we now have a framework around which to guide our efforts at preserving a more human future.
                      </p>
                      <p>
                        The recent
                        <.link
                          navigate="https://bookshop.org/a/14891/9781984854636"
                          target="_blank"
                          rel="_noopener"
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300"
                        >
                          book
                        </.link>
                        from Cambridge Analytica whistleblower Christopher Wylie, reveals how the systems of surveillance capitalism are being weaponized against an unsuspecting public.
                      </p>
                    </div>
                  </details>
                </div>
              </div>

              <%!-- Collapsible Sections --%>
              <div class="space-y-4">
                <%!-- What is your data? --%>
                <div class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden">
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200 group"
                    phx-click={
                      JS.toggle(to: "#privacy-section-1")
                      |> JS.toggle_class("rotate-180", to: "#chevron-1")
                    }
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        What is your data?
                      </h3>
                      <.icon
                        id="chevron-1"
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                      />
                    </div>
                  </button>
                  <div
                    id="privacy-section-1"
                    class="hidden px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      Your data on MOSSLET is information specific to your account.
                    </p>
                    <p>
                      This information includes sign up or registration information: name, pseudonym, email, and password (<.link
                        navigate={~p"/#password"}
                        class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                      >irreversibly hashed</.link>).
                    </p>
                    <p>
                      This information may also include data from: Connections and Posts.
                    </p>
                    <p>
                      When we add new features to MOSSLET, then your list of data may expand to include any new features you use.
                    </p>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-lg border-l-4 border-teal-500 dark:border-emerald-500">
                      <p class="font-semibold text-teal-800 dark:text-teal-200">
                        It is important to know that you may delete any or all of your data at any time from within your account.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Where is your data stored? --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Where is your data stored?
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <div class="pt-4">
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-2">
                        Object Data (avatars, files)
                      </h4>
                      <p>
                        Your <em>object data</em>
                        (think avatars) is stored on a decentralized cloud network by <.link
                          navigate="https://tigrisdata.com"
                          target="_blank"
                          rel="_noopener"
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                        >Tigris</.link>. It is asymmetrically encrypted to your password-derived key and then encrypted again at rest with Tigris' AES 256-bit symmetric encryption. Each file is then split into 80 pieces and stored on different nodes — all with different operators, power supplies, networks, and geographies.
                      </p>
                    </div>
                    <div>
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-2">
                        Text Data (messages, profiles)
                      </h4>
                      <p>
                        Your <em>non-object data</em>
                        (think text, messages, email, name, etc.) is currently stored on databases managed by our hosting provider on an internal and private network encrypted with <.link
                          navigate="https://en.wikipedia.org/wiki/WireGuard"
                          target="_blank"
                          rel="_noopener"
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                        >WireGuard</.link>. This data is first asymmetrically encrypted (your email is also hashed as well for look-up functionality), then wrapped in another layer of symmetric encryption by our server, before being stored in the database.
                      </p>
                    </div>
                    <p>
                      By asymmetrically encrypting your data, we ensure that your data remains private and protected — only you can unlock your data with your password.
                    </p>
                    <p>
                      Your
                      <span class="font-medium text-gray-900 dark:text-gray-50">
                        <em>non-personal data</em>
                      </span>
                      (like when your account was confirmed) is symmetrically encrypted by us and stored with your non-object data. It is not asymmetrically encrypted because it doesn't reveal anything to us about your account accept that it was confirmed, which is used for the functioning of the service.
                    </p>
                    <p>
                      The only data not explicitly encrypted by our servers, but still encrypted at rest in the database by our storage providers, is boolean data that does not reveal your identity nor provide any meaningful information outside the functioning of the service.
                    </p>
                    <div class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border-l-4 border-blue-500">
                      <p class="font-semibold text-blue-800 dark:text-blue-200">
                        It is important to know that your data is asymmetrically encrypted before it is uploaded to any cloud storage locations, is only decryptable by you (the person who knows your password), and is deleted from the cloud location when you delete the file on your end. Data that is not asymmetrically encrypted nor simple boolean data (true/false), is still encrypted with strong symmetric encryption and would be protected against data breaches.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Data Ownership --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        You own 100% of your data
                        <span class="text-sm opacity-70 line-through ml-2">data harvesting</span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      This means that you are in full control of your account information on MOSSLET and can even delete your account, and all of its information, at any time from within your account settings.
                    </p>
                    <div class="p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border-l-4 border-yellow-500">
                      <p class="font-semibold text-yellow-800 dark:text-yellow-200 mb-2">
                        Limited exceptions to your control:
                      </p>
                      <ul class="space-y-1 text-sm">
                        <li>
                          (a) if you are in violation of our
                          <.link
                            navigate={~p"/terms"}
                            class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          >
                            terms of use
                          </.link>
                        </li>
                        <li>
                          (b) if our company were to go out of business and all accounts were thus deleted
                        </li>
                        <li>(c) in compliance with a court-ordered legal request</li>
                      </ul>
                    </div>
                    <p>
                      In the case of (a), depending on the severity of the violation, we will contact you before taking an action against your account (such as deleting it and all of its information). In the case of (b), we will do our best to provide reasonable notice of our impending shutdown so that you can prepare for it. And in the case of (c), we don't have access to any meaningful data due to the in-app asymmetric encryption. It would look something like this: "pJL3R8c2uGKLqJ1NUOTjL7u0er..." And even then, we will do our best to defend that meaningless information to the fullest extent of the law.
                    </p>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-lg border-l-4 border-teal-500 dark:border-emerald-500">
                      <p class="font-semibold text-teal-800 dark:text-teal-200">
                        In all cases: we will never share, sell, or otherwise transfer your data, and/or personal information, to third parties (except for the
                        <.link
                          navigate="#privacy_policy_metadata"
                          class="text-emerald-600 dark:text-emerald-400"
                        >
                          metadata
                        </.link>
                        required by Stripe to handle your account payments and a court-ordered legal request that we cannot successfully defend against).
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Encryption & Security --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Your data is encrypted
                        <span class="text-sm opacity-70 line-through ml-2">backdoors</span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      We use encryption algorithms that are recommended by leading security and cryptography experts like Matthew Green, Niels Ferguson, and Bruce Schneier.
                    </p>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
                        <h4 class="font-semibold text-blue-800 dark:text-blue-200 mb-2">
                          Data Encryption
                        </h4>
                        <p class="text-sm">
                          Your data is asymmetrically encrypted in-app by your password-derived key. This means that only you can ever decrypt your data (for sharing or for yourself). We then wrap that encryption in a second layer of symmetric encryption before sending it to the database for storage, and those encryption keys are stored separately and rotated periodically.
                        </p>
                      </div>
                      <div class="p-4 bg-purple-50 dark:bg-purple-900/20 rounded-lg">
                        <h4 class="font-semibold text-purple-800 dark:text-purple-200 mb-2">
                          Password Security
                        </h4>
                        <p class="text-sm">
                          Your account password, and any password used for securing your content, is protected with an industry leading hashing algorithm that makes it virtually impossible to ever know your password. You may see this concept being referred to as an "irreversible password hash".
                        </p>
                      </div>
                    </div>
                    <div class="p-4 bg-green-50 dark:bg-green-900/20 rounded-lg border-l-4 border-green-500">
                      <p class="font-semibold text-green-800 dark:text-green-200">
                        In the event of a data breach, your data would still be protected by very strong encryption.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- No Manipulation --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        You are not manipulated
                        <span class="text-sm opacity-70 line-through ml-2">
                          algorithmic manipulation
                        </span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      We do not participate in the surveilling and profiling of our customers (or anyone). We do not create psychometric profiles on you (or anyone). We do not conduct "invisible" (just outside of your awareness) experiments on you (or anyone).
                    </p>
                    <div class="p-4 bg-red-50 dark:bg-red-900/20 rounded-lg border-l-4 border-red-500">
                      <p class="font-bold text-red-800 dark:text-red-200">
                        There is no algorithm running experiments on you and deciding what you should think and feel.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- No Data Sharing --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Your data is not shared
                        <span class="text-sm opacity-70 line-through ml-2">
                          behavior modification
                        </span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      We do not share, sell, or otherwise transfer your data to anyone outside of our company ever. Your data is used only in the service of your account (support & troubleshooting), to address a
                      <.link
                        navigate={~p"/terms"}
                        class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                      >
                        terms of use
                      </.link>
                      violation, or to comply with a court-ordered legal request.
                    </p>
                  </div>
                </div>

                <%!-- No Tracking --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        You are not spied on
                        <span class="text-sm opacity-70 line-through ml-2">
                          surveillance capitalism
                        </span>
                        <span class="text-sm text-rose-600 dark:text-rose-400 ml-2">(updated)</span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <p class="pt-4">
                      We do not use behavioral tracking technologies like advertising cookies or
                      <.link
                        navigate="https://spreadprivacy.com/browser-fingerprinting/"
                        class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                        target="_blank"
                        rel="_noopener"
                      >
                        fingerprinting
                      </.link>
                      to spy on you across the internet or build advertising profiles.
                    </p>
                    <div class="p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border-l-4 border-yellow-500">
                      <p class="font-semibold text-yellow-800 dark:text-yellow-200 mb-2">
                        Minimal operational data collection:
                      </p>
                      <ul class="space-y-1 text-sm">
                        <li>
                          • <strong>Your personal content:</strong>
                          Profile, posts, messages, and connections (asymmetrically encrypted - only you can decrypt)
                        </li>
                        <li>
                          • <strong>Payment information:</strong>
                          Processed and stored by Stripe, not by us (we only store your asymmetrically encrypted Stripe customer ID so you can view your billing page - we can't decrypt it ourselves)
                        </li>
                        <li>
                          • <strong>Security logs:</strong>
                          Minimal login events and 2FA security changes (automatically deleted after 7 days)
                        </li>
                        <li>
                          • <strong>Service operation data:</strong>
                          Non-sensitive UI preferences and account status flags (e.g., "account confirmed: true")
                        </li>
                      </ul>
                      <p class="text-sm mt-2">
                        All asymmetrically encrypted data (your personal content) is wrapped in a second layer of symmetric encryption when stored in our database. Service operation data consists of non-sensitive boolean flags and UI preferences needed for the app to function - things like your preferred number of posts per page or whether your account is confirmed.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Metadata & Payment Information --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  id="privacy_policy_metadata"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Metadata & Payments
                        <span class="text-sm text-rose-600 dark:text-rose-400 ml-2">(updated)</span>
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-6 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <div class="pt-4">
                      <p class="mb-4">
                        To the best of our knowledge, the extent of the possible information that could leak about your account (metadata) is all related to paying for your account. And in this regard, the information provided is your email address, name, card information, and device IP address.
                      </p>
                      <p>
                        This information is handled and stored by Stripe, an industry leader in payments and security. The only information kept in our database is related to the Stripe payment plans we offer, Stripe products, a Stripe ID for the customer and
                        <span class="px-2 py-1 bg-rose-200 dark:bg-rose-300 text-rose-900 rounded text-sm">
                          subscription or payment
                        </span>
                        to synchronize with Stripe (<span class="px-2 py-1 bg-rose-200 dark:bg-rose-300 text-rose-900 rounded text-sm">asymmetrically encrypted - only you can decrypt them, not us</span> and deterministically hashed for lookups on our end), and subscription information (like dates and status).
                      </p>
                      <div class="p-4 bg-orange-50 dark:bg-orange-900/20 rounded-lg border-l-4 border-orange-500 mt-4">
                        <p class="font-semibold text-orange-800 dark:text-orange-200">
                          This metadata does not provide access to your MOSSLET account nor its content, though it may be used to leak metadata about your account.
                        </p>
                      </div>
                    </div>

                    <div>
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-3">Why Stripe?</h4>
                      <p>
                        We have chosen
                        <a
                          href="https://stripe.com"
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          target="_blank"
                          rel="_noopener"
                        >
                          Stripe
                        </a>
                        as our current payment processor due to their world-class security, great <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          href="https://stripe.com/climate"
                          target="_blank"
                          rel="_noopener"
                        >climate initiative</a>, and strong <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          href="https://stripe.com/privacy"
                          target="_blank"
                          rel="_noopener"
                        >data policies</a>.
                      </p>
                      <p class="mt-2">
                        Stripe maintains industry leading security of your payment information, we do not process or store your payment information. And this goes without saying: we do not share, rent, sell, or otherwise transfer your payment information to anyone ever. It is only and always handled by Stripe.
                      </p>
                    </div>

                    <div>
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-3">
                        Ways to minimize metadata
                      </h4>
                      <p class="mb-4">
                        It's important to understand what information might be able to be gleaned about your MOSSLET account through this Stripe metadata:
                      </p>
                      <div class="space-y-4">
                        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                          <h5 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
                            1. Database Analysis Risk
                          </h5>
                          <p class="text-sm mb-3">
                            It may be possible, with legal court orders, to sift through our database records, in conjunction with Stripe's, and determine if you are using MOSSLET.
                            <span class="px-2 py-1 bg-rose-200 dark:bg-rose-300 text-rose-900 rounded text-xs">
                              However, we have made this even more difficult by asymmetrically encrypting any Stripe IDs in our database, meaning that even we cannot see what your Stripe ID is in our MOSSLET database.
                            </span>
                          </p>
                          <div class="pl-4 border-l-2 border-blue-300">
                            <p class="text-sm font-medium text-blue-800 dark:text-blue-200">
                              Mitigation: This can be minimized by using an anonymous email address for your MOSSLET account, although you will still have to enter a payment card which could be used to identify you.
                            </p>
                          </div>
                        </div>

                        <div class="border border-gray-200 dark:border-gray-700 rounded-lg p-4">
                          <h5 class="font-medium text-gray-900 dark:text-gray-100 mb-2">
                            2. Payment Transaction Risk
                          </h5>
                          <p class="text-sm mb-3">
                            When you pay to use MOSSLET, you must input a payment card to be processed via Stripe. Upon doing so, Stripe will receive the email associated with your MOSSLET account (decrypted by your current session). They will also receive the name you input when you enter your payment, card details, and device IP address.
                          </p>
                          <p class="text-sm mb-3">
                            This information is used by Stripe for risk assessment and fraud prevention.
                          </p>
                          <div class="pl-4 border-l-2 border-blue-300 space-y-2">
                            <p class="text-sm font-medium text-blue-800 dark:text-blue-200">
                              IP Address Mitigation: To further mitigate identification from your device IP address that is sent to Stripe, you can use the
                              <a
                                class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                                href="https://www.torproject.org/"
                                target="_blank"
                                rel="_noopener"
                              >
                                Tor
                              </a>
                              browser or a trusted VPN (or both).
                            </p>
                            <div class="p-2 bg-red-50 dark:bg-red-900/20 rounded">
                              <p class="text-xs font-medium text-red-800 dark:text-red-200">
                                We cannot offer any guidance on protecting your privacy from the transaction of your payment card, and for this reason alone, if you are a high-risk person without the relevant expertise, then we recommend you not use <span class="px-1 bg-rose-200 dark:bg-rose-300 text-rose-900 rounded">the internet</span>.
                              </p>
                            </div>
                          </div>
                        </div>
                      </div>

                      <div class="mt-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <p class="text-sm">
                          While it is very difficult to minimize metadata, the metadata that can be gleamed from your Stripe payment (with the proper court orders) does not change the fact that only you can access the contents of your account.
                        </p>
                        <p class="text-sm mt-2">
                          Again, it is important to remember that none of this metadata can give someone access to your account or provide them with the actual information in your account.
                        </p>
                        <p class="text-sm mt-2">
                          Similar to a service like Signal, a legal government court order could enable a government entity to determine (1) who you are, (2) who you are connected to, and (3) who you may be in communication with — but it cannot reveal the contents of your communication, nor can your life be harvested for the benefit of surveillance capitalists.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>

                <%!-- Additional Information --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Additional Resources
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <div class="pt-4">
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-2">
                        Educational Resources
                      </h4>
                      <p class="mb-2">
                        Check out
                        <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          href="https://clickclickclick.click/"
                          target="_blank"
                          rel="_noopener"
                        >
                          ClickClickClick
                        </a>
                        to see what creepy things can happen to you on other websites.
                      </p>
                      <p>
                        Are you a business or startup that needs analytics?
                        <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          href="https://usefathom.com/ref/6PUHXH"
                          target="_blank"
                          rel="_noopener"
                        >
                          Fathom Analytics
                        </a>
                        is a trusted privacy-focused solution for businesses of all sizes.
                      </p>
                    </div>
                    <div>
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-2">
                        Acknowledgments
                      </h4>
                      <p>
                        This policy is heavily influenced by Gabriel Weinberg's for DuckDuckGo — thank you.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Updates & Contact --%>
                <div
                  class="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden"
                  x-data="{ open: false }"
                >
                  <button
                    class="w-full text-left cursor-pointer p-6 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors duration-200"
                    @click="open = !open"
                  >
                    <div class="flex items-center justify-between">
                      <h3 class="text-lg font-bold text-gray-900 dark:text-gray-100">
                        Updates & Feedback
                      </h3>
                      <.icon
                        name="hero-chevron-down"
                        class="h-5 w-5 text-gray-500 transition-transform duration-200 flex-shrink-0"
                        x-bind:class="{ 'rotate-180': open }"
                      />
                    </div>
                  </button>
                  <div
                    x-show="open"
                    x-transition
                    class="px-6 pb-6 space-y-4 text-gray-600 dark:text-gray-400 border-t border-gray-100 dark:border-gray-800"
                  >
                    <div class="pt-4">
                      <h4 class="font-semibold text-gray-900 dark:text-gray-100 mb-2">
                        Policy Updates
                      </h4>
                      <p class="mb-3">
                        If this policy is substantively updated, we will update the text of this page and provide notice to you by writing '(Updated)' in rose next to the link to this page (in the footer) for a period of at least 30 days.
                      </p>
                      <p>
                        We will also mention the update to our terms, and potentially discuss in more detail, on the latest episode of our
                        <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                          href="https://podcast.mosslet.com"
                          target="_blank"
                          rel="noopener"
                        >
                          podcast
                        </a>
                        to air after the update.
                      </p>
                    </div>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-lg border border-teal-200 dark:border-teal-700">
                      <h4 class="font-semibold text-teal-800 dark:text-teal-200 mb-2">
                        Have Questions or Feedback?
                      </h4>
                      <p class="text-teal-700 dark:text-teal-300">
                        I (Mark) am the creator of MOSSLET, and personally wrote this privacy policy. If you have any questions or concerns, please <a
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 font-medium"
                          href="mailto:support@mosslet.com"
                        >send feedback</a>.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

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
     |> assign(:page_title, "Privacy")
     |> assign_new(:meta_description, fn ->
       "Privacy is the standard on MOSSLET. We do not log or share personal information. That is our privacy policy in a nutshell. The rest of this policy tries to explain what information we may have, why we have it, how we protect it, and why you should care."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/privacy/privacy_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Privacy is the standard"
     )}
  end
end
