defmodule MossletWeb.BillingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Repo
  alias MossletWeb.DesignSystem

  defp billing_provider, do: Application.get_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:source, socket.assigns.live_action)
      |> assign(:billing_provider, billing_provider())

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, maybe_load_provider_data(socket)}
  end

  defp maybe_load_provider_data(socket) do
    user = socket.assigns[:current_user] |> Repo.preload(:customer)
    payment_intent = socket.assigns[:payment_intent]
    session_key = socket.assigns.key

    assign_async(socket, [:provider_payment_intent_async, :provider_charge_async], fn ->
      case payment_intent do
        nil ->
          # check if there's a customer
          if user.customer do
            payment_intent =
              PaymentIntents.get_active_payment_intent_by_customer_id(user.customer.id)

            # check if a payment has been made
            if payment_intent do
              provider_charge =
                if payment_intent do
                  case Stripe.Charge.retrieve(payment_intent.provider_latest_charge_id) do
                    {:ok, provider_charge} ->
                      provider_charge

                    _rest ->
                      nil
                  end
                else
                  {:ok, stripe_charge_list} =
                    Stripe.Charge.list(%{
                      customer:
                        maybe_decrypt_user_data(
                          user.customer.provider_customer_id,
                          user,
                          session_key
                        )
                    })

                  List.first(stripe_charge_list.data)
                end

              # sync the payment intent
              %{provider_payment_intent_id: provider_charge.payment_intent}
              |> Mosslet.Billing.Providers.Stripe.Workers.PaymentIntentSyncWorker.new()
              |> Oban.insert()

              {:ok,
               %{
                 provider_payment_intent_async: payment_intent,
                 provider_charge_async: provider_charge
               }}
            else
              # customer, but no payment intent because they haven't paid yet
              # perhaps they initiated the Stripe checkout process but didn't complete it
              {:ok, %{provider_payment_intent_async: nil, provider_charge_async: nil}}
            end
          else
            # no customer because the user has not initiated the sign up process with Stripe
            {:ok, %{provider_payment_intent_async: nil, provider_charge_async: nil}}
          end

        payment_intent ->
          {:ok, provider_payment_intent} =
            billing_provider().retrieve_payment_intent(payment_intent.provider_payment_intent_id)

          case billing_provider().retrieve_charge(payment_intent.provider_latest_charge_id) do
            {:ok, provider_charge} ->
              {:ok,
               %{
                 provider_payment_intent_async: provider_payment_intent,
                 provider_charge_async: provider_charge
               }}

            _rest ->
              {:ok,
               %{
                 provider_payment_intent_async: provider_payment_intent,
                 provider_charge_async: nil
               }}
          end
      end
    end)
  end

  def billing_path(:user, _assigns), do: ~p"/app/billing"
  def billing_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/billing"

  defp subscribe_path(:user, _assigns), do: ~p"/app/subscribe"
  defp subscribe_path(:org, assigns), do: ~p"/app/org/#{assigns.current_org.slug}/subscribe"

  @impl true
  def render(assigns) do
    ~H"""
    <%= case @source do %>
      <% :user -> %>
        <.layout
          current_user={@current_user}
          current_page={:billing}
          sidebar_current_page={:billing}
          key={@key}
          type="sidebar"
        >
          <DesignSystem.liquid_container max_width="lg" class="py-16">
            <%!-- Page header with liquid metal styling --%>
            <div class="mb-12">
              <div class="mb-8">
                <h1 class="text-3xl font-bold tracking-tight sm:text-4xl bg-gradient-to-r from-teal-500 to-emerald-500 bg-clip-text text-transparent">
                  Billing & Payments
                </h1>
                <p class="mt-4 text-lg text-slate-600 dark:text-slate-400">
                  Manage your subscription and view payment history for your MOSSLET account.
                </p>
              </div>
              <%!-- Decorative accent line --%>
              <div class="h-1 w-24 rounded-full bg-gradient-to-r from-teal-400 via-emerald-400 to-cyan-400 shadow-sm shadow-emerald-500/30">
              </div>
            </div>

            <div class="space-y-8 max-w-3xl">
              <.active_payment_intent_info
                subscribe_path={subscribe_path(@source, assigns)}
                billing_provider={@billing_provider}
                provider_charge_async={@provider_charge_async}
                provider_payment_intent_async={@provider_payment_intent_async}
                current_user={@current_user}
                key={@key}
              />
            </div>
          </DesignSystem.liquid_container>
        </.layout>
    <% end %>
    """
  end

  attr :billing_provider, :atom
  attr :provider_payment_intent_async, :map
  attr :provider_charge_async, :map
  attr :subscribe_path, :string
  attr :current_user, Mosslet.Accounts.User, required: true, doc: "the current user struct"
  attr :key, :string, required: true, doc: "the current user's session key"

  def active_payment_intent_info(assigns) do
    ~H"""
    <%!-- Loading State --%>
    <div :if={@provider_payment_intent_async.loading}>
      <DesignSystem.liquid_card>
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
              <.phx_icon name="hero-credit-card" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <span>Loading Payment Information</span>
          </div>
        </:title>

        <div class="flex items-center justify-center py-8">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500"></div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <%!-- Error State --%>
    <div :if={@provider_payment_intent_async.failed}>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-rose-50/50 to-pink-50/30 dark:from-rose-900/20 dark:to-pink-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-rose-100 via-pink-50 to-rose-100 dark:from-rose-900/30 dark:via-pink-900/25 dark:to-rose-900/30">
              <.phx_icon
                name="hero-exclamation-triangle"
                class="h-4 w-4 text-rose-600 dark:text-rose-400"
              />
            </div>
            <span class="text-rose-800 dark:text-rose-200">Payment Provider Error</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-rose-700 dark:text-rose-300">
            {gettext("Something went wrong with our payment provider. Please contact support.")}
          </p>

          <div class="flex justify-start">
            <DesignSystem.liquid_button
              href="mailto:support@mosslet.com"
              color="rose"
              icon="hero-envelope"
            >
              Contact Support
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <%!-- No Payments State --%>
    <div :if={@provider_payment_intent_async.ok? && !@provider_payment_intent_async.result}>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-amber-50/50 to-orange-50/30 dark:from-amber-900/20 dark:to-orange-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-amber-100 via-orange-50 to-amber-100 dark:from-amber-900/30 dark:via-orange-900/25 dark:to-amber-900/30">
              <.phx_icon name="hero-credit-card" class="h-4 w-4 text-amber-600 dark:text-amber-400" />
            </div>
            <span class="text-amber-800 dark:text-amber-200">No Payment History</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-amber-700 dark:text-amber-300">
            {gettext("No payments made.")} You haven't made any payments yet, but you can browse our available plans and choose one that fits your needs.
          </p>

          <div class="flex justify-start">
            <DesignSystem.liquid_button
              href={@subscribe_path}
              color="amber"
              icon="hero-eye"
            >
              {gettext("View plans")}
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>

    <%!-- Payment Success State --%>
    <div
      :if={@provider_payment_intent_async.ok? && @provider_payment_intent_async.result}
      class="space-y-8"
    >
      <%!-- Payment Summary Card --%>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-emerald-50/50 to-teal-50/30 dark:from-emerald-900/20 dark:to-teal-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-emerald-100 via-teal-50 to-emerald-100 dark:from-emerald-900/30 dark:via-teal-900/25 dark:to-emerald-900/30">
              <.phx_icon
                name="hero-check-circle"
                class="h-4 w-4 text-emerald-600 dark:text-emerald-400"
              />
            </div>
            <span class="text-emerald-800 dark:text-emerald-200">Payment Confirmed</span>
            <DesignSystem.liquid_badge
              :if={@provider_payment_intent_async.result.status == "succeeded"}
              variant="solid"
              color="emerald"
              size="sm"
            >
              {gettext("success")}
            </DesignSystem.liquid_badge>
          </div>
        </:title>

        <div class="space-y-6">
          <p class="text-emerald-700 dark:text-emerald-300">
            Thank you for your payment! Your MOSSLET account is active and ready to use.
          </p>

          <%!-- Payment amount highlight --%>
          <div class="bg-emerald-100 dark:bg-emerald-900/30 rounded-lg p-6 border border-emerald-200 dark:border-emerald-700">
            <div class="text-center space-y-3">
              <div class="flex items-center justify-center gap-2 mb-2">
                <.phx_icon
                  name="hero-check-badge"
                  class="h-5 w-5 text-emerald-600 dark:text-emerald-400"
                />
                <span class="text-sm font-medium text-emerald-700 dark:text-emerald-300 uppercase tracking-wide">
                  One-Time Payment Complete
                </span>
              </div>

              <div class="text-3xl font-bold text-emerald-800 dark:text-emerald-200">
                {@provider_charge_async.result.amount_captured |> Util.format_money()}
                <span class="text-lg uppercase ml-1">{@provider_charge_async.result.currency}</span>
              </div>

              <div class="space-y-1">
                <p class="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                  Lifetime access to MOSSLET
                </p>
                <p class="text-xs text-emerald-700 dark:text-emerald-300">
                  No recurring charges • Pay once, use forever
                </p>
              </div>
            </div>
          </div>

          <%!-- Additional clarification --%>
          <div class="bg-emerald-50 dark:bg-emerald-900/20 rounded-lg p-4 border border-emerald-100 dark:border-emerald-800">
            <div class="flex items-start gap-3">
              <.phx_icon
                name="hero-information-circle"
                class="h-5 w-5 text-emerald-600 dark:text-emerald-400 mt-0.5 flex-shrink-0"
              />
              <div class="text-sm text-emerald-700 dark:text-emerald-300">
                <strong>This was a one-time payment.</strong>
                You will never be charged again for your MOSSLET account.
                Your lifetime access is now active and will never expire.
              </div>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>

      <%!-- Payment Details Card --%>
      <DesignSystem.liquid_card>
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
              <.phx_icon name="hero-document-text" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <span>Payment Details</span>
          </div>
        </:title>

        <div class="space-y-6">
          <%!-- Charge Information Section --%>
          <div class="space-y-4">
            <h3 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
              <.phx_icon name="hero-credit-card" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
              Charge Information
            </h3>

            <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
              <div class="space-y-4">
                <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                    Charge ID:
                  </span>
                  <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                    {@provider_charge_async.result.id}
                  </code>
                </div>

                <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

                <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                    Customer ID:
                  </span>
                  <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                    {maybe_update_customer_provider_info_encryption(
                      @current_user.customer,
                      @current_user,
                      @key
                    )}
                  </code>
                </div>

                <div class="h-px bg-slate-200 dark:bg-slate-700"></div>

                <div class="flex flex-col sm:flex-row sm:justify-between sm:items-start gap-2">
                  <span class="text-sm font-medium text-slate-600 dark:text-slate-400">
                    Payment Email:
                  </span>
                  <code class="text-sm bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-slate-800 dark:text-slate-200 break-all max-w-full">
                    {maybe_update_customer_email_encryption(
                      @current_user.customer.email,
                      @current_user,
                      @key
                    )}
                  </code>
                </div>
              </div>
            </div>
          </div>

          <%!-- Billing Date Section --%>
          <div class="space-y-4">
            <h4 class="flex items-center gap-2 font-medium text-slate-900 dark:text-slate-100">
              <.phx_icon name="hero-calendar-days" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
              Billing Date
            </h4>

            <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 border border-slate-200 dark:border-slate-700">
              <div class="flex items-center gap-3">
                <div class="flex items-center justify-center w-10 h-10 rounded-lg bg-blue-100 dark:bg-blue-900/30">
                  <.phx_icon name="hero-clock" class="h-5 w-5 text-blue-600 dark:text-blue-400" />
                </div>
                <div>
                  <time
                    datetime={@provider_payment_intent_async.result.provider_created_at}
                    class="text-sm font-medium text-slate-900 dark:text-slate-100"
                  >
                    <.local_time_full
                      id={@current_user.id}
                      at={@provider_payment_intent_async.result.provider_created_at}
                    />
                  </time>
                  <p class="text-xs text-slate-600 dark:text-slate-400 mt-0.5">
                    Payment processed successfully
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </DesignSystem.liquid_card>

      <%!-- Action Buttons Card --%>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-blue-50/50 to-cyan-50/30 dark:from-blue-900/20 dark:to-cyan-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-blue-100 via-cyan-50 to-blue-100 dark:from-blue-900/30 dark:via-cyan-900/25 dark:to-blue-900/30">
              <.phx_icon name="hero-cog-6-tooth" class="h-4 w-4 text-blue-600 dark:text-blue-400" />
            </div>
            <span class="text-blue-800 dark:text-blue-200">Account Actions</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-blue-700 dark:text-blue-300">
            Manage your account and access additional resources.
          </p>

          <div class="flex flex-col sm:flex-row gap-4">
            <DesignSystem.liquid_button
              href={@subscribe_path}
              color="blue"
              icon="hero-eye"
              variant="secondary"
            >
              {gettext("View Plans")}
            </DesignSystem.liquid_button>

            <DesignSystem.liquid_button
              href={@provider_charge_async.result.receipt_url}
              target="_blank"
              rel="noopener noreferrer"
              color="blue"
              icon="hero-document-arrow-down"
            >
              {gettext("View Receipt")}
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>

      <%!-- Support Information Card --%>
      <DesignSystem.liquid_card class="bg-gradient-to-br from-purple-50/50 to-violet-50/30 dark:from-purple-900/20 dark:to-violet-900/10">
        <:title>
          <div class="flex items-center gap-3">
            <div class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden bg-gradient-to-br from-purple-100 via-violet-50 to-purple-100 dark:from-purple-900/30 dark:via-violet-900/25 dark:to-purple-900/30">
              <.phx_icon
                name="hero-question-mark-circle"
                class="h-4 w-4 text-purple-600 dark:text-purple-400"
              />
            </div>
            <span class="text-purple-800 dark:text-purple-200">Need Help?</span>
          </div>
        </:title>

        <div class="space-y-4">
          <p class="text-purple-700 dark:text-purple-300">
            If you have any questions about your payment or need assistance with your account,
            our support team is here to help.
          </p>

          <div class="flex flex-col sm:flex-row gap-4">
            <DesignSystem.liquid_button
              href="mailto:support@mosslet.com"
              color="purple"
              icon="hero-envelope"
            >
              Contact Support
            </DesignSystem.liquid_button>

            <DesignSystem.liquid_button
              href="/faq"
              color="purple"
              icon="hero-question-mark-circle"
              variant="ghost"
            >
              View FAQ
            </DesignSystem.liquid_button>
          </div>
        </div>
      </DesignSystem.liquid_card>
    </div>
    """
  end

  defp maybe_update_customer_email_encryption(email, current_user, key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_data(email, current_user, key) do
      :failed_verification ->
        {:ok, customer} = update_customer_for_source(email, current_user, key)

        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          customer.email,
          current_user,
          key
        )

      d_email ->
        d_email
    end
  end

  defp maybe_update_customer_provider_info_encryption(customer, current_user, key) do
    case Mosslet.Encrypted.Users.Utils.decrypt_user_data(
           customer.provider_customer_id,
           current_user,
           key
         ) do
      :failed_verification ->
        {:ok, customer} =
          update_customer_provider_info_for_source(
            customer.provider_customer_id,
            current_user,
            key
          )

        Mosslet.Encrypted.Users.Utils.decrypt_user_data(
          customer.provider_customer_id,
          current_user,
          key
        )

      d_provider_customer_id ->
        d_provider_customer_id
    end
  end

  defp update_customer_for_source(email, current_user, key) do
    Mosslet.Billing.Customers.update_customer_for_source(
      :user,
      current_user.id,
      %{
        email: email,
        provider: "stripe",
        provider_customer_id:
          maybe_decrypt_user_data(current_user.customer.provider_customer_id, current_user, key)
      },
      current_user,
      key
    )
  end

  defp update_customer_provider_info_for_source(provider_customer_id, current_user, key) do
    Mosslet.Billing.Customers.update_customer_for_source(
      :user,
      current_user.id,
      %{
        provider: "stripe",
        provider_customer_id: maybe_decrypt_user_data(provider_customer_id, current_user, key)
      },
      current_user,
      key
    )
  end
end
