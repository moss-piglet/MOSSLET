defmodule Mosslet.Billing.Workers.MonthlyPayoutOrchestratorWorker do
  @moduledoc """
  Runs monthly to identify referral codes eligible for payout
  and enqueues individual payout jobs for each.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1

  require Logger

  alias Mosslet.Billing.Referrals

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting monthly referral payout orchestration")

    eligible_codes = Referrals.list_codes_eligible_for_payout()
    Logger.info("Found #{length(eligible_codes)} codes eligible for payout")

    period_start = beginning_of_previous_month()
    period_end = end_of_previous_month()

    Enum.each(eligible_codes, fn code ->
      amount = Referrals.sum_available_commissions(code.id)

      case create_payout_record(code, amount, period_start, period_end) do
        {:ok, payout} ->
          enqueue_payout_job(code, payout)

        {:error, reason} ->
          Logger.error("Failed to create payout record for code #{code.id}: #{inspect(reason)}")
      end
    end)

    Logger.info("Monthly payout orchestration complete")
    :ok
  end

  defp create_payout_record(code, amount, period_start, period_end) do
    Referrals.create_payout(%{
      referral_code_id: code.id,
      amount: amount,
      status: "pending",
      period_start: period_start,
      period_end: period_end
    })
  end

  defp enqueue_payout_job(code, payout) do
    %{referral_code_id: code.id, payout_id: payout.id}
    |> Mosslet.Billing.Workers.ReferralPayoutWorker.new()
    |> Oban.insert()
  end

  defp beginning_of_previous_month do
    today = Date.utc_today()
    first_of_this_month = Date.beginning_of_month(today)
    last_month = Date.add(first_of_this_month, -1)
    Date.beginning_of_month(last_month) |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp end_of_previous_month do
    today = Date.utc_today()
    first_of_this_month = Date.beginning_of_month(today)
    Date.add(first_of_this_month, -1) |> DateTime.new!(~T[23:59:59], "Etc/UTC")
  end
end
