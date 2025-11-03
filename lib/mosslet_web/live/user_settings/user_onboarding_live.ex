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
    <div class="fixed inset-0 z-10 overflow-y-auto bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900">
      <%!-- Background decorative elements --%>
      <div class="absolute inset-0 overflow-hidden">
        <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
        </div>
        <div
          class="absolute -bottom-40 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
          style="animation-delay: -2s;"
        >
        </div>
      </div>

      <div class="relative z-10 flex items-center justify-center min-h-screen px-4 py-6 sm:px-6 sm:py-8">
        <div class="w-full max-w-md mx-auto">
          <%!-- Auth card with liquid metal styling --%>
          <.liquid_card padding="lg" class="overflow-hidden">
            <%!-- Header Section --%>
            <div class="text-center mb-8">
              <%!-- Welcome badge --%>
              <div class="mb-6">
                <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/20 dark:to-emerald-900/20 border border-teal-200/50 dark:border-teal-700/30 mb-4">
                  <span class="text-2xl">👋</span>
                  <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
                    Welcome aboard!
                  </span>
                </div>
              </div>

              <%!-- Main heading with gradient --%>
              <h1 class={[
                "text-2xl sm:text-3xl font-bold tracking-tight leading-tight mb-4",
                "bg-gradient-to-r from-teal-500 to-emerald-500",
                "dark:from-teal-400 dark:via-emerald-400 dark:to-emerald-300",
                "bg-clip-text text-transparent"
              ]}>
                {gettext("Welcome to MOSSLET")}
              </h1>

              <%!-- Subtitle --%>
              <p class="text-base text-slate-600 dark:text-slate-300">
                Choose privacy-first social
              </p>
            </div>

            <%!-- Form Section --%>
            <.form
              id="update_profile_form"
              for={@form}
              phx-submit="submit"
              class="space-y-6"
            >
              <%!-- Name Field --%>
              <div class="space-y-2">
                <.phx_input
                  field={@form[:name]}
                  type="text"
                  label={gettext("What's your name?")}
                  placeholder={gettext("Enter your name")}
                  value={@name || @form[:name].value}
                  autocomplete="given-name"
                  required
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-xl border-0 py-4 px-4 text-slate-900 dark:text-white",
                    "bg-white/80 dark:bg-slate-700/80 backdrop-blur-sm",
                    "ring-1 ring-inset ring-slate-300/50 dark:ring-slate-600/50",
                    "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                    "focus:ring-2 focus:ring-inset focus:ring-emerald-500/50",
                    "transition-all duration-200 ease-out",
                    "hover:ring-emerald-400/50 dark:hover:ring-emerald-500/50",
                    "text-base sm:text-sm sm:leading-6"
                  ]}
                >
                  <:description_block>
                    <p class="text-sm text-slate-600 dark:text-slate-400">
                      Your name stays private and is only shared with people you choose.
                    </p>
                  </:description_block>
                </.phx_input>
              </div>

              <%!-- Notifications Section --%>
              <div class="space-y-4">
                <div class="p-4 rounded-xl bg-gradient-to-r from-emerald-50/50 to-teal-50/50 dark:from-emerald-900/10 dark:to-teal-900/10 border border-emerald-200/30 dark:border-emerald-700/20">
                  <.phx_input
                    field={@form[:is_subscribed_to_marketing_notifications]}
                    type="checkbox"
                    label={gettext("Allow calm notifications")}
                    apply_classes?={true}
                    classes={[
                      "h-5 w-5 rounded border-2 border-slate-300 dark:border-slate-600",
                      "text-emerald-600 focus:ring-emerald-500/50 focus:ring-2 focus:ring-offset-2",
                      "dark:focus:ring-offset-slate-800",
                      "transition-all duration-200 ease-out",
                      "hover:border-emerald-400 dark:hover:border-emerald-500",
                      "checked:bg-gradient-to-br checked:from-emerald-500 checked:to-teal-600",
                      "checked:border-emerald-500 dark:checked:border-emerald-400"
                    ]}
                  >
                    <:description_block>
                      <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                        These will appear softly when you're already using our service. We won't pull you back in when you're offline.
                      </p>
                    </:description_block>
                  </.phx_input>
                </div>

                <div class="p-4 rounded-xl bg-gradient-to-r from-blue-50/50 to-cyan-50/50 dark:from-blue-900/10 dark:to-cyan-900/10 border border-blue-200/30 dark:border-blue-700/20">
                  <.phx_input
                    field={@form[:is_subscribed_to_email_notifications]}
                    type="checkbox"
                    label={gettext("Allow email notifications")}
                    apply_classes?={true}
                    classes={[
                      "h-5 w-5 rounded border-2 border-slate-300 dark:border-slate-600",
                      "text-blue-600 focus:ring-blue-500/50 focus:ring-2 focus:ring-offset-2",
                      "dark:focus:ring-offset-slate-800",
                      "transition-all duration-200 ease-out",
                      "hover:border-blue-400 dark:hover:border-blue-500",
                      "checked:bg-gradient-to-br checked:from-blue-500 checked:to-cyan-600",
                      "checked:border-blue-500 dark:checked:border-blue-400"
                    ]}
                  >
                    <:description_block>
                      <p class="text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                        Receive privacy-first email summaries when you have unread posts. No poster details revealed, just counts.
                      </p>
                    </:description_block>
                  </.phx_input>
                </div>

                <p class="text-xs text-slate-500 dark:text-slate-400 text-center">
                  You can always change these settings later in your preferences.
                </p>
              </div>

              <%!-- Action Buttons --%>
              <div class="space-y-4 pt-4">
                <.liquid_button
                  type="submit"
                  size="lg"
                  icon="hero-check-circle"
                  class="w-full"
                >
                  {gettext("Complete Setup")}
                </.liquid_button>

                <div class="text-center">
                  <.link
                    class="inline-flex items-center gap-2 text-sm font-medium text-slate-600 hover:text-rose-600 dark:text-slate-400 dark:hover:text-rose-400 transition-colors duration-200"
                    href={~p"/auth/sign_out"}
                    method="delete"
                  >
                    <.phx_icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" />
                    {gettext("Sign out instead")}
                  </.link>
                </div>
              </div>
            </.form>

            <%!-- Learn More Sections --%>
            <div class="mt-8 pt-6 border-t border-slate-200/50 dark:border-slate-700/50 space-y-4">
              <%!-- Why Privacy Matters Section --%>
              <div class="rounded-xl bg-slate-50/50 dark:bg-slate-800/50 p-4">
                <button
                  type="button"
                  phx-click="toggle_details"
                  class="flex items-center justify-between w-full text-left group"
                >
                  <span class="text-sm font-semibold text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
                    Why privacy matters
                  </span>
                  <.phx_icon
                    name="hero-chevron-down"
                    class={[
                      "w-5 h-5 text-slate-500 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-all duration-200",
                      if(@show_details, do: "rotate-180", else: "")
                    ]}
                  />
                </button>

                <div class={[
                  "mt-4 space-y-4 text-sm text-slate-600 dark:text-slate-400",
                  unless(@show_details, do: "hidden")
                ]}>
                  <p class="leading-relaxed">
                    We live in an era of surveillance capitalism, where your personal data is harvested and sold without your knowledge.
                  </p>
                  <div class="grid grid-cols-2 gap-3">
                    <div class="text-center p-3 rounded-lg bg-gradient-to-br from-rose-50 to-red-50 dark:from-rose-900/20 dark:to-red-900/20 border border-rose-200/50 dark:border-rose-800/30">
                      <div class="text-lg font-bold text-rose-600 dark:text-rose-400">
                        450+ TB
                      </div>
                      <div class="text-xs text-rose-700 dark:text-rose-300 leading-tight">
                        Daily data Facebook collects
                      </div>
                    </div>
                    <div class="text-center p-3 rounded-lg bg-gradient-to-br from-rose-50 to-red-50 dark:from-rose-900/20 dark:to-red-900/20 border border-rose-200/50 dark:border-rose-800/30">
                      <div class="text-lg font-bold text-rose-600 dark:text-rose-400">
                        2,230+
                      </div>
                      <div class="text-xs text-rose-700 dark:text-rose-300 leading-tight">
                        Companies tracking each user
                      </div>
                    </div>
                  </div>
                  <p class="text-sm">
                    <.link
                      class="inline-flex items-center gap-1 text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 transition-colors duration-200 font-medium"
                      href="https://themarkup.org/privacy/2024/01/17/each-facebook-user-is-monitored-by-thousands-of-companies-study-indicates"
                      target="_blank"
                    >
                      Read "How thousands of companies monitor users"
                      <.phx_icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                    </.link>
                  </p>
                </div>
              </div>

              <%!-- Why Pay for Privacy Section --%>
              <div class="rounded-xl bg-slate-50/50 dark:bg-slate-800/50 p-4">
                <button
                  type="button"
                  phx-click="toggle_payment_info"
                  class="flex items-center justify-between w-full text-left group"
                >
                  <span class="text-sm font-semibold text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors duration-200">
                    Why we charge for privacy
                  </span>
                  <.phx_icon
                    name="hero-chevron-down"
                    class={[
                      "w-5 h-5 text-slate-500 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-all duration-200",
                      if(@show_payment_info, do: "rotate-180", else: "")
                    ]}
                  />
                </button>

                <div class={[
                  "mt-4 space-y-4 text-sm text-slate-600 dark:text-slate-400 leading-relaxed",
                  unless(@show_payment_info, do: "hidden")
                ]}>
                  <p>
                    When a service is "free," you become the product. Your data is harvested, packaged, and sold to advertisers.
                  </p>
                  <p>
                    By charging a fair, one-time fee, we can:
                  </p>
                  <ul class="space-y-1 ml-4">
                    <li class="flex items-start gap-2">
                      <span class="w-1.5 h-1.5 bg-emerald-500 rounded-full mt-2 flex-shrink-0"></span>
                      <span>Keep your data completely private</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="w-1.5 h-1.5 bg-emerald-500 rounded-full mt-2 flex-shrink-0"></span>
                      <span>Maintain our servers and security</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="w-1.5 h-1.5 bg-emerald-500 rounded-full mt-2 flex-shrink-0"></span>
                      <span>Develop new features based on your needs, not advertisers'</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="w-1.5 h-1.5 bg-emerald-500 rounded-full mt-2 flex-shrink-0"></span>
                      <span>Stay independent from Big Tech influence</span>
                    </li>
                  </ul>
                  <div class="p-4 rounded-xl bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
                    <div class="flex items-start gap-3">
                      <span class="text-2xl">💡</span>
                      <div>
                        <div class="font-semibold text-emerald-800 dark:text-emerald-200 text-sm">
                          Pay once, own forever
                        </div>
                        <div class="text-sm text-emerald-700 dark:text-emerald-300">
                          No subscriptions, no recurring fees
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </.liquid_card>
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
