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
    <main
      role="main"
      class="fixed inset-0 z-10 overflow-y-auto bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900"
    >
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
        </div>
        <div
          class="absolute -bottom-40 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
          style="animation-delay: -2s;"
        >
        </div>
      </div>

      <div class="relative z-10 flex items-center justify-center min-h-screen px-4 py-8 sm:px-6 sm:py-12">
        <div class="w-full max-w-lg mx-auto">
          <.liquid_card padding="lg" class="overflow-hidden">
            <div class="text-center mb-8">
              <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gradient-to-r from-teal-50 to-emerald-50 dark:from-teal-900/30 dark:to-emerald-900/30 border border-teal-200/50 dark:border-teal-700/30 mb-6">
                <span class="text-xl">✨</span>
                <span class="text-sm font-medium text-teal-700 dark:text-teal-300">
                  {gettext("Almost there")}
                </span>
              </div>

              <h1 class={[
                "text-2xl sm:text-3xl font-bold tracking-tight leading-tight mb-3",
                "bg-gradient-to-r from-teal-600 via-emerald-500 to-teal-500",
                "dark:from-teal-400 dark:via-emerald-400 dark:to-teal-300",
                "bg-clip-text text-transparent"
              ]}>
                {gettext("Set up your space")}
              </h1>

              <p class="text-base text-slate-600 dark:text-slate-400">
                {gettext("A few quick choices—you're in control")}
              </p>
            </div>

            <.form
              id="update_profile_form"
              for={@form}
              phx-submit="submit"
              class="space-y-8"
            >
              <div>
                <.phx_input
                  field={@form[:name]}
                  type="text"
                  label={gettext("Your name")}
                  placeholder={gettext("How should we call you?")}
                  value={@name || @form[:name].value}
                  autocomplete="given-name"
                  required
                  apply_classes?={true}
                  classes={[
                    "block w-full rounded-xl border-0 py-3.5 px-4 text-slate-900 dark:text-white",
                    "bg-white dark:bg-slate-700/80 backdrop-blur-sm",
                    "ring-1 ring-inset ring-slate-200 dark:ring-slate-600/50",
                    "placeholder:text-slate-400 dark:placeholder:text-slate-500",
                    "focus:ring-2 focus:ring-inset focus:ring-emerald-500",
                    "transition-all duration-200 ease-out",
                    "text-base sm:text-sm"
                  ]}
                >
                  <:description_block>
                    <p class="mt-2 text-sm text-slate-500 dark:text-slate-400 flex items-center gap-1.5">
                      <.phx_icon name="hero-lock-closed" class="w-3.5 h-3.5 text-emerald-500" />
                      {gettext("Only visible to people you connect with")}
                    </p>
                  </:description_block>
                </.phx_input>
              </div>

              <fieldset class="space-y-3">
                <legend class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-3">
                  {gettext("Notification preferences")}
                </legend>

                <label class="flex items-start gap-3 p-3.5 rounded-xl cursor-pointer transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700/30 group">
                  <.phx_input
                    field={@form[:is_subscribed_to_marketing_notifications]}
                    type="checkbox"
                    label=""
                    apply_classes?={true}
                    classes={[
                      "mt-0.5 h-5 w-5 rounded border-2 border-slate-300 dark:border-slate-500",
                      "text-emerald-600 focus:ring-emerald-500/50 focus:ring-2 focus:ring-offset-0",
                      "transition-colors duration-200",
                      "checked:border-emerald-500 dark:checked:border-emerald-400"
                    ]}
                  />
                  <div class="flex-1 min-w-0">
                    <div class="text-sm font-medium text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                      {gettext("Calm in-app notifications")}
                    </div>
                    <p class="mt-1 text-sm text-slate-500 dark:text-slate-400 leading-relaxed">
                      {gettext("Gentle badges only while you're active—we respect your offline time")}
                    </p>
                  </div>
                </label>

                <label class="flex items-start gap-3 p-3.5 rounded-xl cursor-pointer transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700/30 group">
                  <.phx_input
                    field={@form[:is_subscribed_to_email_notifications]}
                    type="checkbox"
                    label=""
                    apply_classes?={true}
                    classes={[
                      "mt-0.5 h-5 w-5 rounded border-2 border-slate-300 dark:border-slate-500",
                      "text-emerald-600 focus:ring-emerald-500/50 focus:ring-2 focus:ring-offset-0",
                      "transition-colors duration-200",
                      "checked:border-emerald-500 dark:checked:border-emerald-400"
                    ]}
                  />
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                        {gettext("Calm email digests")}
                      </span>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300">
                        {gettext("Max 1/day")}
                      </span>
                    </div>
                    <p class="mt-1 text-sm text-slate-500 dark:text-slate-400 leading-relaxed">
                      {gettext("Privacy-first summaries—no personal details, no inbox clutter")}
                    </p>
                  </div>
                </label>

                <p class="text-xs text-slate-400 dark:text-slate-500 text-center pt-1">
                  {gettext("You can adjust these anytime in Settings")}
                </p>
              </fieldset>

              <div class="pt-2">
                <.liquid_button
                  type="submit"
                  size="lg"
                  icon="hero-arrow-right"
                  class="w-full"
                >
                  {gettext("Continue")}
                </.liquid_button>

                <div class="mt-4 text-center">
                  <.link
                    class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-rose-500 dark:text-slate-400 dark:hover:text-rose-400 transition-colors duration-200"
                    href={~p"/auth/sign_out"}
                    method="delete"
                  >
                    <.phx_icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" />
                    {gettext("Sign out")}
                  </.link>
                </div>
              </div>
            </.form>

            <div class="mt-10 pt-6 border-t border-slate-200/60 dark:border-slate-700/50">
              <div class="flex items-center gap-2 mb-4">
                <.phx_icon name="hero-shield-check" class="w-4 h-4 text-emerald-500" />
                <span class="text-xs font-medium uppercase tracking-wider text-slate-500 dark:text-slate-400">
                  {gettext("Learn more")}
                </span>
              </div>

              <div class="space-y-2">
                <button
                  type="button"
                  phx-click="toggle_details"
                  class="flex items-center justify-between w-full text-left p-3 rounded-lg transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700/30 group"
                >
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                    {gettext("Why privacy matters")}
                  </span>
                  <.phx_icon
                    name="hero-chevron-down"
                    class={[
                      "w-4 h-4 text-slate-400 group-hover:text-emerald-500 transition-all duration-200",
                      if(@show_details, do: "rotate-180", else: "")
                    ]}
                  />
                </button>

                <div class={[
                  "overflow-hidden transition-all duration-300 ease-out",
                  if(@show_details, do: "max-h-[500px] opacity-100", else: "max-h-0 opacity-0")
                ]}>
                  <div class="px-3 pb-4 pt-2 space-y-4 text-sm text-slate-600 dark:text-slate-400">
                    <p class="leading-relaxed">
                      {gettext(
                        "We live in an era of surveillance capitalism, where your personal data is harvested and sold without your knowledge."
                      )}
                    </p>
                    <div class="grid grid-cols-2 gap-3">
                      <div class="text-center p-3 rounded-lg bg-gradient-to-br from-rose-50 to-red-50 dark:from-rose-900/20 dark:to-red-900/20 border border-rose-200/50 dark:border-rose-800/30">
                        <div class="text-lg font-bold text-rose-600 dark:text-rose-400">
                          450+ TB
                        </div>
                        <div class="text-xs text-rose-700 dark:text-rose-300 leading-tight">
                          {gettext("Daily data Facebook collects")}
                        </div>
                      </div>
                      <div class="text-center p-3 rounded-lg bg-gradient-to-br from-rose-50 to-red-50 dark:from-rose-900/20 dark:to-red-900/20 border border-rose-200/50 dark:border-rose-800/30">
                        <div class="text-lg font-bold text-rose-600 dark:text-rose-400">
                          2,230+
                        </div>
                        <div class="text-xs text-rose-700 dark:text-rose-300 leading-tight">
                          {gettext("Companies tracking each user")}
                        </div>
                      </div>
                    </div>
                    <.link
                      class="inline-flex items-center gap-1.5 text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 transition-colors duration-200 font-medium text-sm"
                      href="https://themarkup.org/privacy/2024/01/17/each-facebook-user-is-monitored-by-thousands-of-companies-study-indicates"
                      target="_blank"
                    >
                      {gettext("Read the research")}
                      <.phx_icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
                    </.link>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="toggle_payment_info"
                  class="flex items-center justify-between w-full text-left p-3 rounded-lg transition-all duration-200 hover:bg-slate-50 dark:hover:bg-slate-700/30 group"
                >
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-300 group-hover:text-emerald-600 dark:group-hover:text-emerald-400 transition-colors">
                    {gettext("Why we charge for privacy")}
                  </span>
                  <.phx_icon
                    name="hero-chevron-down"
                    class={[
                      "w-4 h-4 text-slate-400 group-hover:text-emerald-500 transition-all duration-200",
                      if(@show_payment_info, do: "rotate-180", else: "")
                    ]}
                  />
                </button>

                <div class={[
                  "overflow-hidden transition-all duration-300 ease-out",
                  if(@show_payment_info, do: "max-h-[600px] opacity-100", else: "max-h-0 opacity-0")
                ]}>
                  <div class="px-3 pb-4 pt-2 space-y-4 text-sm text-slate-600 dark:text-slate-400 leading-relaxed">
                    <p>
                      {gettext(
                        "When a service is \"free,\" you become the \"oil\" in a behavioral futures stock market. Your data is harvested, refined, packaged as a behavioral future product, and sold to the highest bidder."
                      )}
                    </p>
                    <p>
                      {gettext("By charging a fair, one-time fee, we can:")}
                    </p>
                    <ul class="space-y-2">
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                        />
                        <span>{gettext("Keep your data completely private")}</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                        />
                        <span>{gettext("Maintain our servers and security")}</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                        />
                        <span>{gettext("Build features for you, not advertisers")}</span>
                      </li>
                      <li class="flex items-start gap-2">
                        <.phx_icon
                          name="hero-check-circle"
                          class="w-4 h-4 text-emerald-500 mt-0.5 flex-shrink-0"
                        />
                        <span>{gettext("Stay independent from Big Tech")}</span>
                      </li>
                    </ul>
                    <div class="p-4 rounded-xl bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 border border-emerald-200/50 dark:border-emerald-700/30">
                      <div class="flex items-center gap-3">
                        <div class="flex items-center justify-center w-10 h-10 rounded-full bg-emerald-100 dark:bg-emerald-900/40">
                          <.phx_icon
                            name="hero-sparkles"
                            class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                          />
                        </div>
                        <div>
                          <div class="font-semibold text-emerald-800 dark:text-emerald-200 text-sm">
                            {gettext("Pay once, own forever")}
                          </div>
                          <div class="text-sm text-emerald-700 dark:text-emerald-300">
                            {gettext("No subscriptions, no recurring fees")}
                          </div>
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
    </main>
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
