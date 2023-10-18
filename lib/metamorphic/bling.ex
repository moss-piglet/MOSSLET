defmodule Metamorphic.Bling do
  use Phoenix.VerifiedRoutes,
    endpoint: MetamorphicWeb.Endpoint,
    router: MetamorphicWeb.Router,
    statics: MetamorphicWeb.static_paths()

  alias Metamorphic.Accounts

  @behaviour Bling

  @impl Bling
  def can_manage_billing?(conn, customer) do
    conn.assigns.current_user.id == customer.id
  end

  @impl Bling
  def to_stripe_params(customer) do
    # pass any valid Stripe.Customer.create/2 params here
    # e.g. %{name: user.name, email: user.email}
    case customer do
      # %Accounts.User{} -> %{email: customer.email}
      _ -> %{}
    end
  end

  @impl Bling
  def tax_rate_ids(_customer), do: []

  @impl Bling
  def handle_stripe_webhook_event(%Stripe.Event{} = event) do
    case event.type do
      "invoice.payment_action_required" ->
        send_payment_failure_email(event.data.object)

      "invoice.payment.failed" ->
        send_payment_failure_email(event.data.object)

      "invoice.paid" ->
        update_user_and_reset_ai_tokens_used(event.data.object)

      "customer.subscription.created" ->
        update_user(event.data.object)

      "customer.subscription.updated" ->
        update_user(event.data.object)

      "customer.subscription.deleted" ->
        update_user(event.data.object)

      _ ->
        nil
    end

    :ok
  end

  # When a new billing interval occurs and the payment has succeeded,
  # we want to update the user tokens (just in case) and reset the
  # ai_tokens_used for the billing interval.
  defp update_user_and_reset_ai_tokens_used(%Stripe.Invoice{} = invoice) do
    interval = get_interval_from_stripe_invoice(invoice)
    customer = Bling.customer_from_stripe_id(invoice.customer)

    subscription =
      Bling.Customers.subscription(customer) |> Metamorphic.Repo.preload(:subscription_items)

    plan = get_plan(subscription)

    tokens = update_user_ai_tokens(customer, plan)
    reset_user_ai_tokens_used(customer, tokens, interval)
  end

  defp update_user(%Stripe.Subscription{} = subscription) do
    customer = Bling.customer_from_stripe_id(subscription.customer)

    subscription =
      Bling.Customers.subscription(customer) |> Metamorphic.Repo.preload(:subscription_items)

    plan = get_plan(subscription)

    update_user_ai_tokens(customer, plan)
  end

  defp get_interval_from_stripe_invoice(invoice) do
    # We first find the correct line item based on whether
    # the proration field is true or false. A true proration
    # field indicates that the line_item is for a subscription
    # that was possibly changed or canceled and may not reflect
    # the current subscription interval for a customer (user).
    line_item =
      Enum.find(invoice.lines.data, fn line_item ->
        line_item.proration == false
      end)

    line_item.price.recurring.interval
  end

  defp get_plan(subscription) do
    subscription_items = Bling.Subscriptions.subscription_items(subscription)

    case Enum.count(subscription_items) do
      1 ->
        Bankroll.plan_from_price_id(List.first(subscription_items).stripe_price_id)

      _rest ->
        nil
    end
  end

  defp update_user_ai_tokens(user, plan) do
    case plan.title do
      "Starter" ->
        maybe_update_user_ai_tokens(user, 0)
        0

      "Lite" ->
        maybe_update_user_ai_tokens(user, 2_500)
        2_500

      "Plus" ->
        maybe_update_user_ai_tokens(user, 25_000)
        25_000

      "Pro" ->
        maybe_update_user_ai_tokens(user, 50_000)
        50_000

      "Pro AI" ->
        maybe_update_user_ai_tokens(user, 100_000)
        100_000

      _rest ->
        maybe_update_user_ai_tokens(user, 0)
        0
    end
  end

  defp reset_user_ai_tokens_used(user, tokens, interval) do
    case interval do
      "month" ->
        # Reset the tokens each month
        Accounts.update_user_tokens(user, %{ai_tokens: tokens, ai_tokens_used: 0})

        # Maybe cancel any jobs existing if user had an annual plan before and
        # reset the job id for the user in the database.
        unless is_nil(user.oban_reset_token_id) do
          Oban.cancel_job(Oban, user.oban_reset_token_id)
          Accounts.update_user_oban_reset_token_id(user, %{oban_reset_token_id: nil})
        end

      "year" ->
        # Reset the tokens
        Accounts.update_user_tokens(user, %{ai_tokens: tokens, ai_tokens_used: 0})

        # Insert the job to run in a month to reset the tokens
        # Save the job_id to the user account in order to cancel
        # the scheduled job if user switches to monthly plan.
        case insert_reset_token_job(user, tokens, interval) do
          {:ok, job} ->
            Accounts.update_user_oban_reset_token_id(user, %{oban_reset_token_id: job.id})

          {:error, _changeset} ->
            raise "Error inserting ResetTokenWorker Oban job."
        end

      _rest ->
        Accounts.update_user_tokens(user, %{ai_tokens: tokens, ai_tokens_used: 0})
    end
  end

  defp insert_reset_token_job(user, tokens, interval) do
    keys = [:user_id, :interval]

    args = %{
      "user_id" => user.id,
      "tokens" => tokens,
      "interval" => interval
    }

    args
    |> Metamorphic.Workers.ResetTokenWorker.new(
      schedule_in: 2_628_000,
      unique: [fields: [:args, :worker], keys: keys]
    )
    |> Oban.insert()
  end

  defp maybe_update_user_ai_tokens(user, tokens) do
    if(user.ai_tokens == tokens) do
      :ok
    else
      Accounts.update_user_tokens(user, %{ai_tokens: tokens})
    end
  end

  defp send_payment_failure_email(%Stripe.Invoice{} = invoice) do
    customer = Bling.customer_from_stripe_id(invoice.customer)
    type = Bling.customer_type_from_struct(customer)

    finalize_url =
      url(~p"/billing/#{type}/#{customer.id}/finalize?payment_intent=#{invoice.payment_intent}")

    email_body = """
    Your payment method requires additional action in order to proceed.

    Please visit the following link to resolve this issue to ensure your subscription remains active:

    #{finalize_url}
    """

    import Swoosh.Email

    new()
    |> to(customer.email)
    |> from({"Metamorphic", "support@metamorphic.app"})
    |> subject("[Action Required] We failed to process your last payment")
    |> text_body(email_body)
    |> Metamorphic.Mailer.deliver()

    :ok
  end
end
