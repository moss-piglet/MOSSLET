defmodule MossletWeb.PublicLive.Terms do
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      current_user={assigns[:current_user]}
      current_page={:terms}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <%!-- Enhanced liquid metal background --%>
      <div class="min-h-screen bg-gradient-to-br from-slate-50/30 via-transparent to-emerald-50/20 dark:from-slate-900/30 dark:via-transparent dark:to-teal-900/10">
        <main class="isolate">
          <%!-- Hero section with liquid effects matching other pages --%>
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
                    Terms & Conditions
                  </h1>

                  <%!-- Enhanced subtitle --%>
                  <p class="mt-8 text-pretty text-lg font-medium sm:text-xl/8 text-slate-600 dark:text-slate-400 transition-colors duration-300 ease-out">
                    Clear, fair terms that respect your rights and privacy. We believe in transparency and treating you with dignity.
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

          <%!-- Terms content section --%>
          <div class="mx-auto -mt-12 max-w-7xl px-6 sm:mt-0 lg:px-8 xl:-mt-8">
            <div class="mx-auto max-w-4xl">
              <div class="text-center mb-16">
                <p class="mt-4 text-lg text-gray-600 dark:text-gray-400">
                  Effective Date: March 24, 2025
                </p>
                <p class="mt-8 text-xl text-gray-600 dark:text-gray-400 leading-8">
                  Welcome to MOSSLET, a privacy-first social networking web application operated by Moss Piglet Corporation, a family-owned and operated public benefit company.
                </p>
              </div>

              <%!-- Overview Section --%>
              <div class="mb-12 p-6 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-2xl border border-teal-200 dark:border-emerald-700/30 dark:shadow-xl dark:shadow-emerald-500/20">
                <h3 class="text-xl font-bold text-teal-800 dark:text-teal-200 mb-6">
                  Our Commitment to You
                </h3>
                <div class="space-y-6 text-gray-700 dark:text-gray-300">
                  <p class="text-lg leading-relaxed">
                    Our mission is to create a platform that prioritizes <strong>user privacy and human dignity</strong>. By using our services, you agree to comply with and be bound by the following terms and conditions.
                  </p>

                  <%!-- Key Principles Grid --%>
                  <div class="bg-white dark:bg-gray-800/80 rounded-xl p-6 border border-teal-100 dark:border-teal-800">
                    <h4 class="font-semibold text-teal-800 dark:text-teal-200 mb-4 text-center">
                      Our Core Principles
                    </h4>
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-shield-check"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">Privacy First</span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center">
                        <.icon
                          name="hero-heart"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">Human Dignity</span>
                      </div>
                      <div class="flex items-center lg:flex-col lg:text-center lg:items-center sm:col-span-2 lg:col-span-1">
                        <.icon
                          name="hero-scale"
                          class="text-emerald-600 dark:text-emerald-400 mr-2 lg:mr-0 lg:mb-2 h-6 w-6 flex-shrink-0"
                        />
                        <span class="text-sm lg:text-xs">Fair & Transparent</span>
                      </div>
                    </div>
                  </div>

                  <p>
                    These terms are designed to create a safe, respectful environment where you can connect with others while maintaining your privacy and autonomy.
                  </p>
                </div>
              </div>

              <%!-- Collapsible Sections --%>
              <div class="space-y-4" id="terms_and_conditions">
                <%!-- Acceptance of Terms --%>
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
                        1. Acceptance of Terms
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
                      By accessing or using MOSSLET, you agree to these Terms and Conditions. If you do not agree, please do not use our services.
                    </p>
                  </div>
                </div>

                <%!-- User Conduct --%>
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
                        2. User Conduct
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
                      Users of MOSSLET are expected to engage in a respectful and safe manner. You agree not to upload, create, or share any content that is harmful, abusive, threatening, harassing, defamatory, obscene, or otherwise objectionable.
                    </p>
                    <div class="bg-red-50 dark:bg-red-900/20 rounded-lg p-4 border-l-4 border-red-500">
                      <h4 class="font-semibold text-red-800 dark:text-red-200 mb-2">
                        Prohibited Content Includes:
                      </h4>
                      <ul class="space-y-1 text-sm">
                        <li>• Hate speech or discriminatory remarks</li>
                        <li>• Harassment or bullying of any kind</li>
                        <li>• Promotion of violence or illegal activities</li>
                        <li>• Misinformation or deceptive content</li>
                        <li>• Pornographic, sexually explicit, or adult content</li>
                        <li>• Spam, excessive self-promotion, or commercial solicitation</li>
                        <li>• Content that violates intellectual property rights</li>
                        <li>• Impersonation of others or creation of fake accounts</li>
                        <li>• Sharing of private information without consent (doxxing)</li>
                        <li>• Content that exploits or endangers minors</li>
                        <li>• Promotion of self-harm or dangerous activities</li>
                      </ul>
                    </div>
                    <div class="p-4 bg-orange-50 dark:bg-orange-900/20 rounded-lg border-l-4 border-orange-500">
                      <p class="font-semibold text-orange-800 dark:text-orange-200 mb-2">
                        Enforcement Rights
                      </p>
                      <p class="text-sm text-orange-700 dark:text-orange-300">
                        MOSSLET and Moss Piglet Corporation reserve the right to:
                      </p>
                      <ul class="text-sm text-orange-700 dark:text-orange-300 mt-2 space-y-1">
                        <li>• Remove any content that violates these guidelines</li>
                        <li>• Issue warnings or temporary suspensions for violations</li>
                        <li>
                          • Suspend or terminate accounts of users who engage in prohibited behavior
                        </li>
                        <li>
                          • Take any other action deemed necessary to maintain platform safety and integrity
                        </li>
                        <li>
                          • Report illegal activities to appropriate authorities when required by law
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>

                <%!-- Privacy and Data Protection --%>
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
                        3. Privacy and Data Protection
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
                      Your privacy is important to us. We are committed to protecting your personal data. All user data is secured with strong encryption, ensuring that your information remains private and protected.
                    </p>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-lg border-l-4 border-teal-500 dark:border-emerald-500">
                      <p class="font-semibold text-teal-800 dark:text-teal-200">
                        For more details on how we handle your data, please refer to our <.link
                          navigate={~p"/privacy#privacy_policy"}
                          class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                        >Privacy Policy</.link>.
                      </p>
                    </div>
                  </div>
                </div>

                <%!-- Attribution --%>
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
                        4. Attribution
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
                      We gratefully acknowledge the following resources that help make MOSSLET possible:
                    </p>
                    <div class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border-l-4 border-blue-500">
                      <ul class="space-y-2 text-blue-800 dark:text-blue-200">
                        <li>
                          <span class="font-semibold">Icons:</span>
                          Anonymous group member icons provided by Freepik at <.link
                            href="https://www.flaticon.com/"
                            target="_blank"
                            rel="noopener"
                            class="text-blue-600 dark:text-blue-400 hover:text-blue-500 dark:hover:text-blue-300 underline"
                          >Flaticon</.link>.
                        </li>
                        <li>
                          <span class="font-semibold">Profile Banners:</span>
                          Profile banners provided by various artists at <.link
                            href="https://unsplash.com/"
                            target="_blank"
                            rel="noopener"
                            class="text-blue-600 dark:text-blue-400 hover:text-blue-500 dark:hover:text-blue-300 underline"
                          >Unsplash</.link>.
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>

                <%!-- Compliance with Applicable Laws --%>
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
                        5. Compliance with Applicable Laws
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
                      Moss Piglet Corporation is committed to complying with all applicable laws and regulations in the jurisdictions where we operate, including California and Massachusetts. Users are also expected to comply with all relevant laws while using our services.
                    </p>
                  </div>
                </div>

                <%!-- Changes to Terms --%>
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
                        6. Changes to Terms
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
                      Moss Piglet Corporation may update these Terms and Conditions from time to time. We will notify users of any significant changes. Your continued use of MOSSLET after any changes indicates your acceptance of the new terms.
                    </p>
                  </div>
                </div>

                <%!-- Limitation of Liability --%>
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
                        7. Limitation of Liability
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
                      Moss Piglet Corporation is not liable for any direct, indirect, incidental, or consequential damages arising from your use of MOSSLET or any content shared on the platform.
                    </p>
                  </div>
                </div>

                <%!-- Governing Law --%>
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
                        8. Governing Law
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
                      These Terms and Conditions are governed by the laws of the State of Delaware. However, we acknowledge the applicability of laws in California and Massachusetts as relevant to our operations and user interactions.
                    </p>
                  </div>
                </div>

                <%!-- Contact Information --%>
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
                        9. Contact Information
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
                      If you have any questions or concerns about these Terms and Conditions, please contact us at <a
                        class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                        href="mailto:support@mosslet.com"
                      >support@mosslet.com</a>.
                    </p>
                    <div class="p-4 bg-teal-50 dark:bg-teal-900/60 dark:bg-gray-800/60 rounded-lg border border-teal-200 dark:border-teal-700">
                      <p class="font-semibold text-teal-800 dark:text-teal-200">
                        By using MOSSLET, you acknowledge that you have read, understood, and agree to these Terms and Conditions.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </main>

        <%!-- Spacer for proper footer separation --%>
        <div class="pb-24"></div>
      </div>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign_new(:max_width, fn -> "full" end)
     |> assign(:page_title, "Terms")
     |> assign_new(:meta_description, fn ->
       "Terms and conditions for MOSSLET. Welcome to MOSSLET, a privacy-first social networking web application operated by Moss Piglet Corporation, a family-owned and operated public benefit company. Our mission is to create a platform that prioritizes user privacy and human dignity. By using our services, you agree to comply with and be bound by the following terms and conditions. Please read them carefully."
     end)
     |> assign(:og_image, MossletWeb.Endpoint.url() <> ~p"/images/terms/terms_og.png")
     |> assign(:og_image_type, "image/png")
     |> assign(
       :og_image_alt,
       "Clear, fair terms that respect your rights and privacy"
     )}
  end
end
