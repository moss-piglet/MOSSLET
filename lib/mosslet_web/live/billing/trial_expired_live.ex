defmodule MossletWeb.TrialExpiredLive do
  @moduledoc """
  A friendly page shown to users whose free trial has expired.
  Guides them to add a payment method to continue using MOSSLET.
  """
  use MossletWeb, :live_view

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Subscriptions
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    customer = Customers.get_customer_by_source(:user, user.id)

    subscription =
      if customer do
        Subscriptions.get_subscription_by(%{billing_customer_id: customer.id})
      end

    payment_intent =
      if customer do
        Mosslet.Billing.PaymentIntents.get_active_payment_intent_by_customer_id(customer.id)
      end

    has_active_access =
      payment_intent != nil ||
        (subscription && subscription.status in ["active", "trialing"])

    if has_active_access do
      {:ok, push_navigate(socket, to: ~p"/app/billing")}
    else
      socket =
        socket
        |> assign(:page_title, gettext("Continue Your Journey"))
        |> assign(:customer, customer)
        |> assign(:subscription, subscription)
        |> assign(:loading, false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("add_payment_method", _params, socket) do
    socket = assign(socket, :loading, true)

    customer = socket.assigns.customer
    user = socket.assigns.current_scope.user
    key = socket.assigns.current_scope.key

    provider_customer_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        customer.provider_customer_id,
        user,
        key
      )

    return_url = MossletWeb.Endpoint.url() <> ~p"/app"

    case billing_provider().create_portal_session(%{
           customer: provider_customer_id,
           return_url: return_url,
           flow_data: %{
             type: "payment_method_update"
           }
         }) do
      {:ok, session} ->
        {:noreply, redirect(socket, external: session.url)}

      {:error, _reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(
            :error,
            gettext("Something went wrong. Please try again or contact support.")
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("view_plans", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/subscribe")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main
      role="main"
      class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-slate-100 dark:from-slate-900 dark:via-slate-800 dark:to-slate-900"
    >
      <div class="absolute inset-0 overflow-hidden pointer-events-none">
        <div class="absolute -top-40 -right-32 h-96 w-96 rounded-full bg-gradient-to-br from-teal-400/20 via-emerald-500/15 to-cyan-400/20 blur-3xl animate-pulse">
        </div>
        <div
          class="absolute top-1/3 -left-32 h-96 w-96 rounded-full bg-gradient-to-tr from-emerald-400/15 via-teal-500/10 to-cyan-400/15 blur-3xl animate-pulse"
          style="animation-delay: -2s;"
        >
        </div>
      </div>

      <div class="relative z-10 flex flex-col items-center justify-center min-h-screen px-4 py-12 sm:px-6 lg:px-8">
        <div class="w-full max-w-lg">
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-gradient-to-br from-amber-100 to-orange-100 dark:from-amber-900/30 dark:to-orange-900/30 mb-6 shadow-lg shadow-amber-500/20">
              <.phx_icon name="hero-clock" class="w-10 h-10 text-amber-600 dark:text-amber-400" />
            </div>

            <h1 class="text-3xl font-bold tracking-tight text-slate-900 dark:text-slate-100 mb-3">
              {gettext("Your Free Trial Has Ended")}
            </h1>

            <p class="text-lg text-slate-600 dark:text-slate-400 max-w-md mx-auto">
              {gettext(
                "We hope you enjoyed exploring MOSSLET! Add a payment method to continue your journey."
              )}
            </p>
          </div>

          <DesignSystem.liquid_card
            padding="lg"
            class="bg-gradient-to-br from-white via-teal-50/30 to-emerald-50/40 dark:from-slate-800/90 dark:via-teal-900/10 dark:to-emerald-900/10 border-teal-200/70 dark:border-teal-700/40 shadow-xl"
          >
            <div class="space-y-6">
              <div class="text-center">
                <div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-emerald-50 dark:bg-emerald-900/30 border border-emerald-200/50 dark:border-emerald-700/30 mb-4">
                  <.phx_icon
                    name="hero-sparkles"
                    class="w-4 h-4 text-emerald-600 dark:text-emerald-400"
                  />
                  <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                    {gettext("Continue where you left off")}
                  </span>
                </div>

                <h2 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
                  {gettext("Keep All Your Data & Progress")}
                </h2>

                <p class="text-slate-600 dark:text-slate-400">
                  {gettext(
                    "Your posts, connections, journals, circles and everything you've created are safe and waiting for you."
                  )}
                </p>
              </div>

              <div class="space-y-3">
                <div class="flex items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50">
                  <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-100 dark:bg-emerald-900/30">
                    <.phx_icon
                      name="hero-check-circle"
                      class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span class="text-sm text-slate-700 dark:text-slate-300">
                    {gettext("All your data is preserved")}
                  </span>
                </div>

                <div class="flex items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50">
                  <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-100 dark:bg-emerald-900/30">
                    <.phx_icon
                      name="hero-check-circle"
                      class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span class="text-sm text-slate-700 dark:text-slate-300">
                    {gettext("Cancel anytime, no commitment")}
                  </span>
                </div>

                <div class="flex items-center gap-3 p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50">
                  <div class="flex items-center justify-center w-8 h-8 rounded-lg bg-emerald-100 dark:bg-emerald-900/30">
                    <.phx_icon
                      name="hero-check-circle"
                      class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                    />
                  </div>
                  <span class="text-sm text-slate-700 dark:text-slate-300">
                    {gettext("Same plan, instant reactivation")}
                  </span>
                </div>
              </div>

              <div class="pt-4">
                <DesignSystem.liquid_button
                  variant="primary"
                  size="lg"
                  class="w-full"
                  icon="hero-credit-card"
                  phx-click="add_payment_method"
                  disabled={@loading}
                >
                  <%= if @loading do %>
                    {gettext("Redirecting...")}
                  <% else %>
                    {gettext("Add Payment Method")}
                  <% end %>
                </DesignSystem.liquid_button>

                <div class="mt-4 text-center">
                  <button
                    type="button"
                    phx-click="view_plans"
                    class="text-sm text-slate-600 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
                  >
                    {gettext("or view other plans →")}
                  </button>
                </div>
              </div>
            </div>
          </DesignSystem.liquid_card>

          <.security_notice />

          <.account_management_notice />

          <div class="mt-8 text-center">
            <p class="text-sm text-slate-500 dark:text-slate-400 mb-4">
              {gettext("Questions? We're here to help.")}
            </p>
            <div class="flex flex-wrap items-center justify-center gap-4">
              <a
                href="mailto:support@mosslet.com"
                class="inline-flex items-center gap-1.5 text-sm text-slate-600 hover:text-emerald-600 dark:text-slate-400 dark:hover:text-emerald-400 transition-colors"
              >
                <.phx_icon name="hero-envelope" class="w-4 h-4" />
                {gettext("Contact Support")}
              </a>
              <span class="text-slate-300 dark:text-slate-600">•</span>
              <.link
                href={~p"/auth/sign_out"}
                method="delete"
                class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-rose-500 dark:text-slate-400 dark:hover:text-rose-400 transition-colors"
              >
                <.phx_icon name="hero-arrow-left-on-rectangle" class="w-4 h-4" />
                {gettext("Sign out")}
              </.link>
            </div>
          </div>
        </div>
      </div>
    </main>
    """
  end

  defp security_notice(assigns) do
    ~H"""
    <div class="mt-6 p-4 rounded-xl bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-900/20 dark:to-cyan-900/20 border border-blue-200/50 dark:border-blue-700/30">
      <div class="flex items-start gap-3">
        <div class="flex-shrink-0">
          <.phx_icon name="hero-shield-check" class="w-6 h-6 text-blue-600 dark:text-blue-400" />
        </div>
        <div>
          <h3 class="text-sm font-semibold text-blue-800 dark:text-blue-200 mb-1">
            {gettext("Your payment info is secure")}
          </h3>
          <p class="text-sm text-blue-700 dark:text-blue-300">
            {gettext("We use")}
            <a
              href="https://stripe.com"
              target="_blank"
              rel="noopener noreferrer"
              class="font-semibold underline decoration-dotted hover:decoration-solid"
            >
              Stripe
            </a>
            {gettext(
              "— the industry-standard payment processor trusted by millions of businesses worldwide. We never see or store your card details. Your information goes directly to Stripe's secure, PCI-compliant servers."
            )}
          </p>
          <div class="mt-3 flex flex-wrap items-center gap-3 text-xs text-blue-600 dark:text-blue-400">
            <div class="flex items-center gap-1">
              <.phx_icon name="hero-lock-closed" class="w-3.5 h-3.5" />
              <span>{gettext("256-bit encryption")}</span>
            </div>
            <div class="flex items-center gap-1">
              <.phx_icon name="hero-shield-check" class="w-3.5 h-3.5" />
              <span>{gettext("PCI Level 1 certified")}</span>
            </div>
            <div class="flex items-center gap-1">
              <.phx_icon name="hero-eye-slash" class="w-3.5 h-3.5" />
              <span>{gettext("We never see your card")}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp account_management_notice(assigns) do
    ~H"""
    <div class="mt-4 p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200/50 dark:border-slate-700/30">
      <div class="flex items-start gap-3">
        <div class="flex-shrink-0">
          <.phx_icon name="hero-cog-6-tooth" class="w-5 h-5 text-slate-500 dark:text-slate-400" />
        </div>
        <div>
          <p class="text-sm text-slate-600 dark:text-slate-400">
            {gettext("You can still")}
            <.link
              navigate={~p"/app/users/edit-details"}
              class="font-medium text-slate-700 dark:text-slate-300 underline decoration-dotted hover:decoration-solid hover:text-emerald-600 dark:hover:text-emerald-400"
            >
              {gettext("manage your account")}
            </.link>
            {gettext("and all of your settings, including Bluesky, or")}
            <.link
              navigate={~p"/app/users/delete-account"}
              class="font-medium text-slate-700 dark:text-slate-300 underline decoration-dotted hover:decoration-solid hover:text-emerald-600 dark:hover:text-emerald-400"
            >
              {gettext("delete your account and data")}
            </.link>
            {gettext("at any time.")}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
