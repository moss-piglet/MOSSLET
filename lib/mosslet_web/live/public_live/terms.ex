defmodule MossletWeb.PublicLive.Terms do
  use MossletWeb, :live_view

  def render(assigns) do
    ~H"""
    <.layout
      type="public"
      user={assigns[:user]}
      current_page={:terms}
      container_max_width={@max_width}
      socket={@socket}
      key={@key}
    >
      <.container>
        <div id="terms_and_conditions" class="bg-white dark:bg-gray-950 pt-24 sm:pt-32">
          <div class="mx-auto max-w-prose">
            <div class="mx-auto max-w-prose space-y-16 divide-y divide-gray-100 lg:mx-0 lg:max-w-none ">
              <div class="grid grid-cols-1 gap-x-8 gap-y-10">
                <div>
                  <.h2 class="text-3xl font-bold tracking-tight text-gray-900 dark:text-gray-50">
                    Terms and Conditions for Mosslet
                  </.h2>
                  <.p class="mt-4 leading-7 text-gray-600 dark:text-gray-400">
                    Effective Date: March 24, 2025
                  </.p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Terms Policy --%>
        <div id="terms_policy" class="relative max-w-full mt-4 pt-4 pb-20">
          <div class="relative px-4 sm:px-6 lg:px-8 pb-20">
            <div class="flex-col p-8 mx-auto max-w-prose bg-gray-50 dark:bg-gray-800 space-y-4 rounded-lg shadow-lg shadow-emerald-500/50 border border-emerald-600 dark:border-emerald-400">
              <div class="text-lg mx-auto">
                <h1>
                  <span class="block text-base text-center text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 font-semibold tracking-wide uppercase">
                    Terms
                  </span>
                  <span class="mt-2 block text-3xl text-center leading-8 font-extrabold tracking-tight text-gray-900 dark:text-gray-50  sm:text-4xl">
                    March 24, 2025
                  </span>
                </h1>
                <.p class="mt-8 text-xl text-gray-600 dark:text-gray-400  leading-8">
                  Welcome to Mosslet, a privacy-first social networking web application operated by Moss Piglet Corporation, a family-owned and operated public benefit company. Our mission is to create a platform that prioritizes user privacy and human dignity. By using our services, you agree to comply with and be bound by the following terms and conditions. Please read them carefully.
                </.p>
              </div>
              <div class="space-y-4 mt-6 text-gray-600 dark:text-gray-400  mx-auto">
                <.h2 class="font-bold">1. Acceptance of Terms</.h2>
                <.p>
                  By accessing or using Mosslet, you agree to these Terms and Conditions. If you do not agree, please do not use our services.
                </.p>

                <.h2 class="font-bold">2. User Conduct</.h2>
                <.p>
                  Users of Mosslet are expected to engage in a respectful and safe manner. You agree not to upload, create, or share any content that is harmful, abusive, threatening, harassing, defamatory, obscene, or otherwise objectionable. This includes, but is not limited to:
                  <.ul class="list-disc">
                    <li>Hate speech or discriminatory remarks</li>
                    <li>Harassment or bullying of any kind</li>
                    <li>Promotion of violence or illegal activities</li>
                    <li>Misinformation or deceptive content</li>
                  </.ul>
                </.p>

                <.p>
                  Moss Piglet Corporation reserves the right to remove any content that violates these guidelines and to suspend or terminate accounts of users who engage in such behavior.
                </.p>

                <.h2 class="font-bold">
                  3. Privacy and Data Protection
                </.h2>
                <.p>
                  Your privacy is important to us. We are committed to protecting your personal data. All user data is secured with strong encryption, ensuring that your information remains private and protected. For more details on how we handle your data, please refer to our <.link
                    navigate={~p"/privacy#privacy_policy"}
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                  >Privacy Policy</.link>.
                </.p>

                <.h2 class="font-bold">
                  4. Attribution
                </.h2>
                <.p>
                  Image icons used for anonymous group members in Groups are provided for free by Freepik at <.link
                    href="https://www.flaticon.com/"
                    target="_blank"
                    rel="noopener"
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                  >Flat Icon</.link>.
                </.p>

                <.p>
                  Nature images used for profile banners are provided for free by various artists at <.link
                    href="https://unsplash.com/"
                    target="_blank"
                    rel="noopener"
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300"
                  >Unsplash</.link>.
                </.p>

                <.h2 class="font-bold">
                  5. Compliance with Applicable Laws
                </.h2>
                <.p>
                  Moss Piglet Corporation is committed to complying with all applicable laws and regulations in the jurisdictions where we operate, including California and Massachusetts. Users are also expected to comply with all relevant laws while using our services.
                </.p>

                <.h2 class="font-bold">
                  6. Changes to Terms
                </.h2>
                <.p>
                  Moss Piglet Corporation may update these Terms and Conditions from time to time. We will notify users of any significant changes. Your continued use of Mosslet after any changes indicates your acceptance of the new terms.
                </.p>

                <.h2 class="font-bold">
                  7. Limitation of Liability
                </.h2>
                <.p>
                  Moss Piglet Corporation is not liable for any direct, indirect, incidental, or consequential damages arising from your use of Mosslet or any content shared on the platform.
                </.p>

                <.h2 class="font-bold">
                  8. Governing Law
                </.h2>
                <.p>
                  These Terms and Conditions are governed by the laws of the State of Delaware. However, we acknowledge the applicability of laws in California and Massachusetts as relevant to our operations and user interactions.
                </.p>

                <.h2 class="font-bold">9. Contact Information</.h2>
                <.p>
                  If you have any questions or concerns about these Terms and Conditions, please contact us at <a
                    class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-500 dark:hover:text-emerald-300 "
                    href="mailto:support@mosslet.com"
                  >support</a>.
                  By using Mosslet, you acknowledge that you have read, understood, and agree to these Terms and Conditions.
                </.p>
              </div>
            </div>
          </div>
        </div>
      </.container>
    </.layout>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket |> assign_new(:max_width, fn -> "full" end) |> assign(:page_title, "Terms")}
  end
end
