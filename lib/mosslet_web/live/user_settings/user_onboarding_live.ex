defmodule MossletWeb.UserOnboardingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Accounts

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(user_return_to: Map.get(params, "user_return_to", nil))
      |> assign(:name, nil)
      |> assign(:show_details, false)
      |> assign(:show_payment_info, false)
      |> assign_form(Accounts.change_user_onboarding(socket.assigns.current_user))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-10 overflow-y-auto bg-background-100 dark:bg-gray-900">
      <div class="flex items-center justify-center min-h-screen px-3 py-6 sm:px-4 sm:py-8">
        <div
          class="w-full max-w-sm mx-auto bg-white dark:bg-gray-800 rounded-2xl shadow-xl dark:shadow-emerald-500/20 overflow-hidden sm:max-w-md"
          role="dialog"
          aria-modal="true"
          aria-labelledby="modal-headline"
        >
          <%!-- Header Section --%>
          <div class="bg-gradient-to-r from-teal-500 to-emerald-500 px-4 py-6 text-center sm:px-6 sm:py-8">
            <div class="flex items-center justify-center w-12 h-12 mx-auto mb-3 text-2xl bg-white/20 rounded-full backdrop-blur-sm sm:w-16 sm:h-16 sm:mb-4 sm:text-3xl">
              👋
            </div>
            <h1 class="text-lg font-bold text-white sm:text-xl" id="modal-headline">
              {gettext("Welcome to MOSSLET")}
            </h1>
            <p class="mt-1 text-xs text-white/80 sm:mt-2 sm:text-sm">
              Join the movement for digital privacy
            </p>
          </div>

          <%!-- Form Section --%>
          <div class="px-4 py-6 sm:px-6 sm:py-8">
            <.form
              id="update_profile_form"
              for={@form}
              phx-submit="submit"
              class="space-y-4 sm:space-y-6"
            >
              <%!-- Name Field --%>
              <div class="space-y-2">
                <.field
                  field={@form[:name]}
                  value={@name || @form[:name].value}
                  label={gettext("What's your name?")}
                  placeholder={gettext("Enter your name")}
                  autocomplete="given-name"
                  required
                  class="w-full px-3 py-2.5 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500 dark:bg-gray-700 dark:border-gray-600 dark:text-white sm:px-4 sm:py-3 sm:text-base sm:rounded-xl"
                />
                <p class="text-xs text-gray-500 dark:text-gray-400">
                  Your name stays private and is only shared with people you choose.
                </p>
              </div>

              <%!-- Notifications Checkbox --%>
              <div class="space-y-3">
                <div class="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3 sm:p-4 sm:rounded-xl">
                  <div class="space-y-3">
                    <%!-- Label and description above checkbox --%>
                    <div>
                      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 leading-tight">
                        {gettext("Allow calm, in-app notifications")}
                      </label>
                      <p class="mt-1 text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
                        These will appear on your home page when you're already using our service. We won't pull you back in when you're offline, and you can always change this later in your settings.
                      </p>
                    </div>

                    <%!-- Checkbox --%>
                    <div class="flex items-center space-x-3">
                      <.field
                        type="checkbox"
                        field={@form[:is_subscribed_to_marketing_notifications]}
                        label={gettext("Yes, I'd like to receive these notifications")}
                        class="h-4 w-4 text-emerald-600 border-gray-300 rounded focus:ring-emerald-500 focus:ring-2 focus:ring-offset-2 sm:h-5 sm:w-5 flex-shrink-0"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Action Buttons --%>
              <div class="space-y-3">
                <.button class="w-full bg-gradient-to-r from-teal-500 to-emerald-500 hover:from-teal-600 hover:to-emerald-600 text-white font-medium py-2.5 px-4 rounded-lg transition-all duration-200 transform hover:scale-[1.02] focus:ring-4 focus:ring-emerald-500/25 text-sm sm:py-3 sm:px-6 sm:rounded-xl sm:text-base">
                  {gettext("Complete Setup")}
                </.button>

                <div class="text-center">
                  <.link
                    class="text-xs text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200 underline transition-colors sm:text-sm"
                    href={~p"/auth/sign_out"}
                    method="delete"
                  >
                    {gettext("Sign out instead")}
                  </.link>
                </div>
              </div>
            </.form>

            <%!-- Learn More Sections --%>
            <div class="mt-6 pt-4 border-t border-gray-200 dark:border-gray-700 space-y-4 sm:mt-8 sm:pt-6">
              <%!-- Why Privacy Matters Section --%>
              <div>
                <button
                  type="button"
                  phx-click="toggle_details"
                  class="flex items-center justify-between w-full text-left text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
                >
                  <span>Why privacy matters</span>
                  <svg
                    class={"w-4 h-4 transition-transform duration-200 #{if @show_details, do: "rotate-180", else: ""}"}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>

                <div class={"mt-3 space-y-3 text-sm text-gray-600 dark:text-gray-400 #{unless @show_details, do: "hidden"}"}>
                  <p class="text-xs leading-relaxed sm:text-sm">
                    We live in an era of surveillance capitalism, where your personal data is harvested and sold without your knowledge.
                  </p>
                  <div class="grid grid-cols-1 gap-2 text-center sm:gap-3">
                    <div class="bg-red-50 dark:bg-red-900/20 p-2 rounded-lg sm:p-3">
                      <div class="text-base font-bold text-red-600 dark:text-red-400 sm:text-lg">
                        450+ TB
                      </div>
                      <div class="text-xs leading-tight">Daily data Facebook collects</div>
                    </div>
                    <div class="bg-red-50 dark:bg-red-900/20 p-2 rounded-lg sm:p-3">
                      <div class="text-base font-bold text-red-600 dark:text-red-400 sm:text-lg">
                        2,230+
                      </div>
                      <div class="text-xs leading-tight">Companies tracking each user</div>
                    </div>
                  </div>
                  <p class="text-xs leading-relaxed">
                    <.link
                      class="text-emerald-600 dark:text-emerald-400 hover:underline"
                      href="https://themarkup.org/privacy/2024/01/17/each-facebook-user-is-monitored-by-thousands-of-companies-study-indicates"
                      target="_blank"
                    >
                      Read "How thousands of companies monitor users" →
                    </.link>
                  </p>
                </div>
              </div>

              <%!-- Why Pay for Privacy Section --%>
              <div>
                <button
                  type="button"
                  phx-click="toggle_payment_info"
                  class="flex items-center justify-between w-full text-left text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
                >
                  <span>Why we charge for privacy</span>
                  <svg
                    class={"w-4 h-4 transition-transform duration-200 #{if @show_payment_info, do: "rotate-180", else: ""}"}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>

                <div class={"mt-3 space-y-3 text-xs leading-relaxed text-gray-600 dark:text-gray-400 #{unless @show_payment_info, do: "hidden"} sm:text-sm"}>
                  <p>
                    When a service is "free," you become the product. Your data is harvested, packaged, and sold to advertisers.
                  </p>
                  <p>
                    By charging a fair, one-time fee, we can:
                  </p>
                  <ul class="list-disc list-inside space-y-1 ml-2">
                    <li>Keep your data completely private</li>
                    <li>Maintain our servers and security</li>
                    <li>Develop new features based on your needs, not advertisers'</li>
                    <li>Stay independent from Big Tech influence</li>
                  </ul>
                  <div class="bg-emerald-50 dark:bg-emerald-900/20 p-3 rounded-lg">
                    <div class="flex items-center space-x-2">
                      <div class="text-emerald-600 dark:text-emerald-400">💡</div>
                      <div>
                        <div class="font-medium text-emerald-800 dark:text-emerald-300 text-xs sm:text-sm">
                          Pay once, own forever
                        </div>
                        <div class="text-xs text-emerald-700 dark:text-emerald-400">
                          No subscriptions, no recurring fees
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :show_details, !socket.assigns.show_details)}
  end

  def handle_event("toggle_payment_info", _params, socket) do
    {:noreply, assign(socket, :show_payment_info, !socket.assigns.show_payment_info)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    user_params = Map.put(user_params, "is_onboarded?", true)
    current_user = socket.assigns.current_user
    key = socket.assigns.key

    case Accounts.update_user_onboarding_profile(current_user, user_params,
           change_name: true,
           key: key,
           user: current_user
         ) do
      {:ok, updated_user} ->
        Accounts.user_lifecycle_action("after_update_profile", updated_user)

        socket =
          socket
          |> put_flash(:success, gettext("Welcome aboard! Let's get you set up."))
          |> push_navigate(to: ~p"/app/subscribe")

        {:noreply, socket}

      {:error, changeset} ->
        socket =
          socket
          |> assign(:name, changeset.changes[:name_hash])
          |> assign_form(changeset)

        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
