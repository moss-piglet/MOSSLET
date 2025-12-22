defmodule Mosslet.Billing.Workers.ReferralCommissionWorker do
  @moduledoc """
  Processes subscription invoice payments and creates commission records
  for referred users.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Logger

  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Subscriptions

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "stripe_invoice_id" => invoice_id,
          "stripe_subscription_id" => subscription_id,
          "amount_paid" => amount_paid,
          "period_start" => period_start,
          "period_end" => period_end
        }
      }) do
    with {:ok, subscription} <- get_subscription(subscription_id),
         {:ok, referral} <- get_referral_for_subscription(subscription),
         {:ok, _commission} <-
           create_commission(
             referral,
             subscription,
             invoice_id,
             amount_paid,
             period_start,
             period_end
           ) do
      maybe_activate_referral(referral)
      :ok
    else
      {:skip, reason} ->
        Logger.debug("Skipping commission for invoice #{invoice_id}: #{reason}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to process commission for invoice #{invoice_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_subscription(subscription_id) do
    case Subscriptions.get_subscription_by_provider_subscription_id(subscription_id) do
      nil -> {:skip, "subscription not found"}
      subscription -> {:ok, subscription}
    end
  end

  defp get_referral_for_subscription(subscription) do
    user_id = get_user_id_from_subscription(subscription)

    case Referrals.get_referral_by_user(user_id) do
      nil -> {:skip, "no referral for user"}
      %{status: "canceled"} -> {:skip, "referral canceled"}
      %{status: "expired"} -> {:skip, "referral expired"}
      referral -> {:ok, referral}
    end
  end

  defp get_user_id_from_subscription(subscription) do
    subscription = Mosslet.Repo.preload(subscription, customer: :user)
    subscription.customer.user_id
  end

  defp create_commission(
         referral,
         subscription,
         invoice_id,
         amount_paid,
         period_start,
         period_end
       ) do
    commission_amount = Referrals.calculate_commission(amount_paid, referral)
    is_first = Referrals.first_commission_for_referral?(referral.id)

    period_start_dt = unix_to_datetime(period_start)
    period_end_dt = unix_to_datetime(period_end)

    available_at =
      Referrals.calculate_available_at(:subscription,
        payment_date: DateTime.utc_now(),
        period_start: period_start_dt,
        period_end: period_end_dt,
        is_first_commission: is_first
      )

    attrs = %{
      referral_id: referral.id,
      subscription_id: subscription.id,
      stripe_invoice_id: invoice_id,
      gross_amount: amount_paid,
      commission_amount: commission_amount,
      status: "available",
      period_start: period_start_dt,
      period_end: period_end_dt,
      available_at: available_at
    }

    Referrals.create_commission(attrs)
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

  defp unix_to_datetime(nil), do: nil

  defp unix_to_datetime(unix) when is_integer(unix) do
    DateTime.from_unix!(unix) |> DateTime.truncate(:second)
  end
end
