defmodule Mosslet.Billing.Workers.OneTimePaymentCommissionWorker do
  @moduledoc """
  Processes one-time payment intents and creates commission records
  for referred users.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Logger

  alias Mosslet.Billing.Customers
  alias Mosslet.Billing.Referrals

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "provider_payment_intent_id" => payment_intent_id,
          "provider_customer_id" => customer_id,
          "amount" => amount
        }
      }) do
    with {:ok, customer} <- get_customer(customer_id),
         {:ok, referral} <- get_referral_for_customer(customer),
         {:ok, _commission} <- create_commission(referral, payment_intent_id, amount) do
      maybe_activate_referral(referral)
      :ok
    else
      {:skip, reason} ->
        Logger.debug("Skipping commission for payment #{payment_intent_id}: #{reason}")
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to process commission for payment #{payment_intent_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp get_customer(customer_id) do
    case Customers.get_customer_by_provider_customer_id!(customer_id) do
      nil -> {:skip, "customer not found"}
      customer -> {:ok, customer}
    end
  rescue
    Ecto.NoResultsError -> {:skip, "customer not found"}
  end

  defp get_referral_for_customer(customer) do
    user_id = customer.user_id

    case Referrals.get_referral_by_user(user_id) do
      nil -> {:skip, "no referral for user"}
      %{status: "canceled"} -> {:skip, "referral canceled"}
      %{status: "expired"} -> {:skip, "referral expired"}
      referral -> {:ok, referral}
    end
  end

  defp create_commission(referral, payment_intent_id, amount) do
    commission_amount = calculate_one_time_commission(amount, referral)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    available_at = Referrals.calculate_available_at(:one_time, payment_date: now)

    attrs = %{
      referral_id: referral.id,
      subscription_id: nil,
      stripe_invoice_id: payment_intent_id,
      gross_amount: amount,
      commission_amount: commission_amount,
      status: "available",
      period_start: now,
      period_end: now,
      available_at: available_at
    }

    Referrals.create_commission(attrs)
  end

  defp calculate_one_time_commission(gross_amount, %{commission_rate: _rate}) do
    one_time_rate = Referrals.one_time_commission_rate()

    Decimal.mult(Decimal.new(gross_amount), one_time_rate)
    |> Decimal.round(0, :down)
    |> Decimal.to_integer()
  end

  defp maybe_activate_referral(%{status: "pending"} = referral) do
    case Referrals.qualify_referral(referral) do
      {:ok, _} -> broadcast_update(referral)
      _ -> :ok
    end
  end

  defp maybe_activate_referral(%{status: "qualified"} = referral) do
    case Referrals.activate_referral(referral) do
      {:ok, _} -> broadcast_update(referral)
      _ -> :ok
    end
  end

  defp maybe_activate_referral(referral) do
    broadcast_update(referral)
  end

  defp broadcast_update(referral) do
    referral = Mosslet.Repo.preload(referral, :referral_code)

    if referral.referral_code do
      Referrals.broadcast_referral_update(
        referral.referral_code.user_id,
        :referral_updated
      )
    end
  end
end
