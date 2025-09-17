defmodule MossletWeb.BillingLive do
  @moduledoc false
  use MossletWeb, :live_view

  alias Mosslet.Billing.PaymentIntents
  alias Mosslet.Repo

  @billing_provider Application.compile_env(:mosslet, :billing_provider)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:source, socket.assigns.live_action)
      |> assign(:billing_provider, @billing_provider)

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
            @billing_provider.retrieve_payment_intent(payment_intent.provider_payment_intent_id)

          case @billing_provider.retrieve_charge(payment_intent.provider_latest_charge_id) do
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
        <.layout current_user={@current_user} current_page={:billing} key={@key} type="sidebar">
          <.container class="py-16">
            <.page_header title="Billing" />
            <.active_payment_intent_info
              subscribe_path={subscribe_path(@source, assigns)}
              billing_provider={@billing_provider}
              provider_charge_async={@provider_charge_async}
              provider_payment_intent_async={@provider_payment_intent_async}
              current_user={@current_user}
              key={@key}
            />
          </.container>
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
    <div :if={@provider_payment_intent_async.loading}><.spinner /></div>

    <div :if={@provider_payment_intent_async.failed}>
      {gettext("Something went wrong with our payment provider. Please contact support.")}
    </div>

    <div :if={@provider_payment_intent_async.ok? && !@provider_payment_intent_async.result}>
      {gettext("No payments made.")}
      <div class="mt-3">
        <.button
          class="rounded-full"
          label={gettext("View plans")}
          link_type="live_redirect"
          to={@subscribe_path}
          color="light"
        />
      </div>
    </div>

    <div :if={@provider_payment_intent_async.ok? && @provider_payment_intent_async.result}>
      <div>
        <span class="font-semibold dark:text-gray-200">{gettext("Charge ID: ")}</span>
        {@provider_charge_async.result.id}
        <span :if={@provider_payment_intent_async.result.status == "succeeded"} class="align-top">
          <.badge label={gettext("success")} color="primary" class="rounded-full" />
        </span>
      </div>
      <div>
        <span class="font-semibold dark:text-gray-200">{gettext("Customer ID: ")}</span>
        {maybe_update_customer_provider_info_encryption(@current_user.customer, @current_user, @key)}
      </div>

      <div>
        <span class="font-semibold dark:text-gray-200">{gettext("Payment Email: ")}</span>

        {maybe_update_customer_email_encryption(@current_user.customer.email, @current_user, @key)}
      </div>
      <div>
        <span class="font-semibold dark:text-gray-200">{gettext("Amount Paid: ")}</span>
        {@provider_charge_async.result.amount_captured |> Util.format_money()}
        <span class="uppercase">{@provider_charge_async.result.currency}</span>
      </div>
      <div>
        <span class="font-semibold dark:text-gray-200">{gettext("Billing charge: ")}</span>
        <time datetime={@provider_payment_intent_async.result.provider_created_at}>
          <.local_time_full
            id={@current_user.id}
            at={@provider_payment_intent_async.result.provider_created_at}
          />
        </time>
      </div>

      <div class="mt-5 flex justify-start gap-2">
        <.button
          class="rounded-full"
          label={gettext("View plans")}
          link_type="live_redirect"
          to={@subscribe_path}
          color="light"
        />
        <.button
          class="rounded-full"
          label={gettext("View receipt")}
          link_type="live_redirect"
          target="_blank"
          rel="noopener noreferrer"
          to={@provider_charge_async.result.receipt_url}
          color="primary"
        />
      </div>
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
