defmodule Mosslet.Billing.Workers.CommissionAvailabilityWorker do
  @moduledoc """
  Runs daily to broadcast updates for users whose commissions became available
  in the last 24 hours (hold period expired).

  This ensures users who aren't actively viewing the referrals page get updated
  stats when they return, and triggers real-time updates for connected sessions.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1

  require Logger

  import Ecto.Query

  alias Mosslet.Repo
  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Referrals.{Commission, Referral, ReferralCode}

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting commission availability check")

    user_ids = list_users_with_newly_available_commissions()
    count = length(user_ids)

    Logger.info("Found #{count} users with newly available commissions")

    Enum.each(user_ids, fn user_id ->
      Referrals.broadcast_referral_update(user_id, :referral_updated)
    end)

    Logger.info("Commission availability check complete")
    :ok
  end

  defp list_users_with_newly_available_commissions do
    now = DateTime.utc_now()
    yesterday = DateTime.add(now, -1, :day)

    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> join(:inner, [c, r], rc in ReferralCode, on: r.referral_code_id == rc.id)
    |> where([c], c.status == "available")
    |> where([c], c.available_at > ^yesterday and c.available_at <= ^now)
    |> select([c, r, rc], rc.user_id)
    |> distinct(true)
    |> Repo.all()
  end
end
