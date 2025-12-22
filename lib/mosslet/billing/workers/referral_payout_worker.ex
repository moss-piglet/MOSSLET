defmodule Mosslet.Billing.Workers.ReferralPayoutWorker do
  @moduledoc """
  Processes a single referral payout via Stripe Connect transfer.
  Includes retry logic and admin escalation on persistent failures.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    priority: 1

  require Logger

  alias Mosslet.Accounts
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Referrals.{Payout, ReferralCode}
  alias Mosslet.Billing.Providers.Stripe.Services.StripeConnect
  alias Mosslet.Vendor.Slack

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"referral_code_id" => code_id, "payout_id" => payout_id},
        attempt: attempt
      }) do
    with {:ok, code} <- get_referral_code(code_id),
         {:ok, payout} <- get_payout(payout_id),
         {:ok, user, session_key} <- get_user_and_key(code),
         {:ok, transfer} <- create_transfer(code, payout, user, session_key),
         {:ok, _payout} <- complete_payout(payout, transfer, user, session_key),
         {:ok, _} <- mark_commissions_paid(code_id) do
      send_success_notification(code, payout)
      :ok
    else
      {:error, %Stripe.Error{} = error} ->
        handle_stripe_error(error, code_id, payout_id, attempt)

      {:error, :code_not_found} ->
        Logger.error("Referral code #{code_id} not found")
        :ok

      {:error, :payout_not_found} ->
        Logger.error("Payout #{payout_id} not found")
        :ok

      {:error, :connect_not_enabled} ->
        Logger.info("Skipping payout for #{code_id}: Connect not enabled")
        :ok

      {:error, reason} ->
        handle_error(reason, code_id, payout_id, attempt)
    end
  end

  defp get_referral_code(code_id) do
    case Referrals.get_referral_code(code_id) do
      nil -> {:error, :code_not_found}
      %ReferralCode{connect_payouts_enabled: false} -> {:error, :connect_not_enabled}
      code -> {:ok, code}
    end
  end

  defp get_payout(payout_id) do
    case Referrals.get_payout(payout_id) do
      nil -> {:error, :payout_not_found}
      payout -> {:ok, payout}
    end
  end

  defp get_user_and_key(%ReferralCode{user_id: user_id}) do
    user = Accounts.get_user!(user_id)
    {:ok, user, nil}
  end

  defp create_transfer(code, payout, user, session_key) do
    description = "MOSSLET Referral Payout - #{format_period(payout)}"
    StripeConnect.create_transfer(code, payout.amount, description, user, session_key)
  end

  defp complete_payout(payout, transfer, user, session_key) do
    Referrals.complete_payout(payout, transfer.id, user, session_key)
  end

  defp mark_commissions_paid(code_id) do
    commissions = Referrals.list_available_commissions(code_id)
    commission_ids = Enum.map(commissions, & &1.id)
    Referrals.mark_commissions_paid_out(commission_ids)
  end

  defp send_success_notification(code, payout) do
    Logger.info("Payout of #{payout.amount} cents completed for referral code #{code.id}")
  end

  defp handle_stripe_error(error, code_id, payout_id, attempt) when attempt >= 5 do
    notify_admin_payout_failure(code_id, payout_id, error)
    mark_payout_needs_review(payout_id, inspect(error))
    :ok
  end

  defp handle_stripe_error(error, _code_id, _payout_id, _attempt) do
    {:error, error}
  end

  defp handle_error(reason, code_id, payout_id, attempt) when attempt >= 5 do
    notify_admin_payout_failure(code_id, payout_id, reason)
    mark_payout_needs_review(payout_id, inspect(reason))
    :ok
  end

  defp handle_error(reason, _code_id, _payout_id, _attempt) do
    {:error, reason}
  end

  defp notify_admin_payout_failure(code_id, payout_id, error) do
    message = """
    🚨 Referral payout failed after 5 attempts
    Code ID: #{code_id}
    Payout ID: #{payout_id}
    Error: #{inspect(error)}
    """

    Slack.send_message("#billing-alerts", message)

    Logger.error(message)
  end

  defp mark_payout_needs_review(payout_id, reason) do
    case Referrals.get_payout(payout_id) do
      nil ->
        :ok

      payout ->
        Referrals.mark_payout_needs_review(payout, reason, nil, nil)
    end
  end

  defp format_period(%Payout{period_start: start_date, period_end: end_date}) do
    start_str = Calendar.strftime(start_date, "%b %d")
    end_str = Calendar.strftime(end_date, "%b %d, %Y")
    "#{start_str} - #{end_str}"
  end
end
