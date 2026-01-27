defmodule Mosslet.Billing.Providers.Stripe.Workers.RetryPastDueInvoiceWorker do
  @moduledoc """
  Retries payment for past_due subscription invoices when a new payment method is attached.

  When a customer adds a payment method via the Stripe portal, Stripe does NOT
  automatically retry failed invoices. This worker handles that by:
  1. Finding open invoices for the customer
  2. Attempting to pay them with the new payment method
  """
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"provider_customer_id" => customer_id, "payment_method_id" => payment_method_id}
      }) do
    Logger.info("#{__MODULE__} attempting to pay open invoices for customer #{customer_id}")

    case Stripe.Invoice.list(%{customer: customer_id, status: "open", limit: 10}) do
      {:ok, %{data: invoices}} when invoices != [] ->
        Enum.each(invoices, fn invoice ->
          Logger.info(
            "Attempting to pay invoice #{invoice.id} with payment method #{payment_method_id}"
          )

          case Stripe.Invoice.pay(invoice.id, %{payment_method: payment_method_id}) do
            {:ok, paid_invoice} ->
              Logger.info("Successfully paid invoice #{paid_invoice.id}")

            {:error, %Stripe.Error{} = error} ->
              Logger.warning("Failed to pay invoice #{invoice.id}: #{inspect(error)}")
          end
        end)

        :ok

      {:ok, %{data: []}} ->
        Logger.info("No open invoices found for customer #{customer_id}")
        :ok

      {:error, error} ->
        Logger.error("Failed to list invoices for customer #{customer_id}: #{inspect(error)}")
        {:error, error}
    end
  end
end
