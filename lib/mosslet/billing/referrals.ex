defmodule Mosslet.Billing.Referrals do
  @moduledoc """
  Context for managing the referral program.
  Handles referral codes, tracking referrals, calculating commissions, and payouts.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Accounts.User
  alias Mosslet.Billing.Referrals.{ReferralCode, Referral, Commission, Payout}
  alias Mosslet.Billing.Subscriptions
  alias Mosslet.Billing.PaymentIntents

  def config do
    Application.get_env(:mosslet, :referral_program)
  end

  def enabled?, do: config()[:enabled]

  def beta_mode?, do: config()[:beta_mode]

  def current_rates do
    if beta_mode?() do
      config()[:beta]
    else
      config()[:production]
    end
  end

  def commission_rate, do: Decimal.new(current_rates()[:commission_rate])
  def one_time_commission_rate, do: Decimal.new(current_rates()[:one_time_commission_rate])
  def referee_discount_percent, do: current_rates()[:referee_discount_percent]
  def min_payout_cents, do: current_rates()[:min_payout_cents]

  @first_commission_hold_days 35
  @subsequent_payment_buffer_days 7

  @doc """
  Calculates the available_at date for a commission based on payment type.

  The goal is to ensure payouts happen AFTER we receive payment from the referee:
  - Monthly subscriptions: 1 month after payment (aligns with next billing cycle)
  - Annual subscriptions: 35 days for first commission, 7 days for subsequent
  - One-time/Lifetime: 35 days after payment

  For subscriptions, we determine monthly vs annual by the billing period length.
  """
  def calculate_available_at(payment_type, opts \\ [])

  def calculate_available_at(:one_time, opts) do
    payment_date = Keyword.get(opts, :payment_date, DateTime.utc_now())
    DateTime.add(payment_date, @first_commission_hold_days, :day) |> DateTime.truncate(:second)
  end

  def calculate_available_at(:subscription, opts) do
    payment_date = Keyword.get(opts, :payment_date, DateTime.utc_now())
    period_start = Keyword.get(opts, :period_start)
    period_end = Keyword.get(opts, :period_end)
    is_first_commission = Keyword.get(opts, :is_first_commission, false)

    billing_interval = determine_billing_interval(period_start, period_end)

    case billing_interval do
      :monthly ->
        DateTime.add(payment_date, 30, :day) |> DateTime.truncate(:second)

      :annual ->
        if is_first_commission do
          DateTime.add(payment_date, @first_commission_hold_days, :day)
          |> DateTime.truncate(:second)
        else
          DateTime.add(payment_date, @subsequent_payment_buffer_days, :day)
          |> DateTime.truncate(:second)
        end
    end
  end

  defp determine_billing_interval(nil, _), do: :monthly
  defp determine_billing_interval(_, nil), do: :monthly

  defp determine_billing_interval(period_start, period_end) do
    days = DateTime.diff(period_end, period_start, :day)

    if days > 60 do
      :annual
    else
      :monthly
    end
  end

  @doc """
  Checks if this is the first commission for a given referral.
  """
  def first_commission_for_referral?(referral_id) do
    count =
      Commission
      |> where([c], c.referral_id == ^referral_id)
      |> where([c], c.status != "voided")
      |> select([c], count(c.id))
      |> Repo.one()

    count == 0
  end

  def get_referral_code(id), do: Repo.get(ReferralCode, id)
  def get_referral_code!(id), do: Repo.get!(ReferralCode, id)

  def get_referral_code_by_hash(code_hash) do
    Repo.get_by(ReferralCode, code_hash: code_hash)
  end

  def get_referral_code_by_user(user_id) do
    Repo.get_by(ReferralCode, user_id: user_id)
  end

  def get_referral_code_by_connect_account(account_id_hash) do
    Repo.get_by(ReferralCode, stripe_connect_account_id_hash: account_id_hash)
  end

  def valid_code?(code) when is_binary(code) do
    case get_referral_code_by_hash(code) do
      %ReferralCode{is_active: true} -> true
      _ -> false
    end
  end

  def valid_code?(_), do: false

  def user_eligible_for_referrals?(%User{} = user) do
    with true <- enabled?(),
         customer when not is_nil(customer) <- user.customer do
      has_active_subscription?(customer.id) or has_succeeded_payment?(customer.id)
    else
      _ -> false
    end
  end

  defp has_active_subscription?(customer_id) do
    case Subscriptions.get_active_subscription_by_customer_id(customer_id) do
      %{status: "active"} -> true
      _ -> false
    end
  end

  defp has_succeeded_payment?(customer_id) do
    PaymentIntents.get_active_payment_intent_by_customer_id(customer_id) != nil
  end

  def get_or_create_code(%User{} = user, session_key) do
    case get_referral_code_by_user(user.id) do
      %ReferralCode{} = code ->
        {:ok, code}

      nil ->
        create_referral_code(user, session_key)
    end
  end

  def create_referral_code(%User{} = user, session_key) do
    code = generate_unique_code()

    Repo.transaction_on_primary(fn ->
      %ReferralCode{}
      |> ReferralCode.changeset(%{code: code, user_id: user.id}, user, session_key)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  defp generate_unique_code do
    prefix = config()[:code_prefix] || "MOSS"
    random = :crypto.strong_rand_bytes(4) |> Base.encode32(padding: false) |> String.slice(0, 6)
    "#{prefix}-#{random}"
  end

  def get_referral(id), do: Repo.get(Referral, id)
  def get_referral!(id), do: Repo.get!(Referral, id)

  def get_referral_by_user(user_id) do
    Repo.get_by(Referral, referred_user_id: user_id)
  end

  def get_pending_referral_for_user(user_id) do
    Referral
    |> where([r], r.referred_user_id == ^user_id)
    |> where([r], r.status == "pending")
    |> Repo.one()
  end

  def create_pending_referral(referral_code_id, referred_user_id) do
    result =
      Repo.transaction_on_primary(fn ->
        %Referral{}
        |> Referral.changeset(%{
          referral_code_id: referral_code_id,
          referred_user_id: referred_user_id,
          status: "pending",
          referred_at: DateTime.utc_now() |> DateTime.truncate(:second),
          commission_rate: commission_rate(),
          discount_percent: referee_discount_percent(),
          beta_referral: beta_mode?()
        })
        |> Repo.insert()
      end)
      |> handle_transaction_result()

    case result do
      {:ok, referral} ->
        broadcast_referral_created(referral_code_id)
        {:ok, referral}

      error ->
        error
    end
  end

  defp broadcast_referral_created(referral_code_id) do
    case Repo.get(ReferralCode, referral_code_id) do
      %ReferralCode{user_id: user_id} when not is_nil(user_id) ->
        broadcast_referral_update(user_id, :referral_updated)

      _ ->
        :ok
    end
  end

  def qualify_referral(%Referral{} = referral) do
    Repo.transaction_on_primary(fn ->
      referral
      |> Referral.qualify_changeset()
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def activate_referral(%Referral{} = referral) do
    Repo.transaction_on_primary(fn ->
      referral
      |> Referral.activate_changeset()
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def cancel_referral(%Referral{} = referral) do
    Repo.transaction_on_primary(fn ->
      referral
      |> Referral.cancel_changeset()
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def reactivate_referral(%Referral{status: "canceled"} = referral) do
    Repo.transaction_on_primary(fn ->
      referral
      |> Referral.reactivate_changeset()
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def reactivate_referral(%Referral{} = _referral), do: :ok

  def get_commission(id), do: Repo.get(Commission, id)

  def create_commission(attrs, current_user \\ nil, session_key \\ nil) do
    Repo.transaction_on_primary(fn ->
      %Commission{}
      |> Commission.changeset(attrs, current_user, session_key)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  def calculate_commission(gross_amount, %Referral{commission_rate: rate}) do
    Decimal.mult(Decimal.new(gross_amount), rate)
    |> Decimal.round(0, :down)
    |> Decimal.to_integer()
  end

  def list_pending_commissions(referral_code_id) do
    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], c.status == "pending")
    |> Repo.all()
  end

  def list_available_commissions(referral_code_id) do
    now = DateTime.utc_now()

    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], c.status == "available")
    |> where([c], c.available_at <= ^now or is_nil(c.available_at))
    |> Repo.all()
  end

  def sum_available_commissions(referral_code_id) do
    now = DateTime.utc_now()

    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], c.status == "available")
    |> where([c], c.available_at <= ^now or is_nil(c.available_at))
    |> select([c], sum(c.commission_amount))
    |> Repo.one()
    |> Kernel.||(0)
  end

  def mark_commissions_available(referral_id) do
    Repo.transaction_on_primary(fn ->
      Commission
      |> where([c], c.referral_id == ^referral_id)
      |> where([c], c.status == "pending")
      |> Repo.update_all(set: [status: "available"])
    end)
  end

  def mark_commissions_paid_out(commission_ids) when is_list(commission_ids) do
    Repo.transaction_on_primary(fn ->
      Commission
      |> where([c], c.id in ^commission_ids)
      |> where([c], c.status == "available")
      |> Repo.update_all(set: [status: "paid_out"])
    end)
  end

  def get_payout(id), do: Repo.get(Payout, id)

  def create_payout(attrs, current_user \\ nil, session_key \\ nil) do
    Repo.transaction_on_primary(fn ->
      %Payout{}
      |> Payout.changeset(attrs, current_user, session_key)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  def complete_payout(%Payout{} = payout, transfer_id, current_user, session_key) do
    Repo.transaction_on_primary(fn ->
      payout
      |> Payout.complete_changeset(transfer_id, current_user, session_key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def fail_payout(%Payout{} = payout, reason, current_user, session_key) do
    Repo.transaction_on_primary(fn ->
      payout
      |> Payout.fail_changeset(reason, current_user, session_key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def mark_payout_needs_review(%Payout{} = payout, reason, current_user, session_key) do
    Repo.transaction_on_primary(fn ->
      payout
      |> Payout.needs_review_changeset(reason, current_user, session_key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def list_payouts(referral_code_id) do
    Payout
    |> where([p], p.referral_code_id == ^referral_code_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def list_codes_eligible_for_payout do
    min_amount = min_payout_cents()

    ReferralCode
    |> where([rc], rc.is_active == true)
    |> where([rc], rc.connect_payouts_enabled == true)
    |> select([rc], rc)
    |> Repo.all()
    |> Enum.filter(fn rc ->
      sum_available_commissions(rc.id) >= min_amount
    end)
  end

  def get_stats(user_id) do
    case get_referral_code_by_user(user_id) do
      nil ->
        %{
          total_referrals: 0,
          active_referrals: 0,
          one_time_referrals: 0,
          pending_earnings: 0,
          available_for_payout: 0,
          total_paid_out: 0,
          has_code: false
        }

      %ReferralCode{id: code_id} ->
        referrals = list_referrals_for_code(code_id)
        total = length(referrals)
        active = Enum.count(referrals, &(&1.status in ["qualified", "active"]))

        one_time = count_one_time_referrals(code_id)

        pending = sum_commissions_by_status(code_id, "pending")
        in_waiting_period = sum_commissions_in_waiting_period(code_id)
        available = sum_available_commissions(code_id)
        paid_out = sum_paid_out(code_id)

        %{
          total_referrals: total,
          active_referrals: active - one_time,
          one_time_referrals: one_time,
          pending_earnings: pending + in_waiting_period,
          available_for_payout: available,
          total_paid_out: paid_out,
          has_code: true
        }
    end
  end

  defp count_one_time_referrals(referral_code_id) do
    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], is_nil(c.subscription_id))
    |> where([c], c.status != "voided")
    |> select([c, r], count(r.id, :distinct))
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp list_referrals_for_code(referral_code_id) do
    Referral
    |> where([r], r.referral_code_id == ^referral_code_id)
    |> Repo.all()
  end

  defp sum_commissions_by_status(referral_code_id, status) do
    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], c.status == ^status)
    |> select([c], sum(c.commission_amount))
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp sum_commissions_in_waiting_period(referral_code_id) do
    now = DateTime.utc_now()

    Commission
    |> join(:inner, [c], r in Referral, on: c.referral_id == r.id)
    |> where([c, r], r.referral_code_id == ^referral_code_id)
    |> where([c], c.status == "available")
    |> where([c], c.available_at > ^now)
    |> select([c], sum(c.commission_amount))
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp sum_paid_out(referral_code_id) do
    Payout
    |> where([p], p.referral_code_id == ^referral_code_id)
    |> where([p], p.status == "completed")
    |> select([p], sum(p.amount))
    |> Repo.one()
    |> Kernel.||(0)
  end

  def update_connect_account(%ReferralCode{} = code, attrs, current_user, session_key) do
    Repo.transaction_on_primary(fn ->
      code
      |> ReferralCode.connect_changeset(attrs, current_user, session_key)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  def mark_connect_onboarding_complete(connect_account_id) do
    case get_referral_code_by_connect_account(connect_account_id) do
      %ReferralCode{} = code ->
        Repo.transaction_on_primary(fn ->
          code
          |> Ecto.Changeset.change(%{
            connect_onboarding_complete: true,
            connect_payouts_enabled: true
          })
          |> Repo.update()
        end)
        |> handle_transaction_result()

      nil ->
        {:error, :not_found}
    end
  end

  def deactivate_code(%ReferralCode{} = code) do
    Repo.transaction_on_primary(fn ->
      code
      |> Ecto.Changeset.change(%{is_active: false})
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:ok, result}), do: {:ok, result}
  defp handle_transaction_result({:error, _reason} = error), do: error

  def list_referrals_with_commissions(referral_code_id) do
    Referral
    |> where([r], r.referral_code_id == ^referral_code_id)
    |> order_by([r], desc: r.referred_at)
    |> preload([:commissions, referred_user: [customer: :subscriptions]])
    |> Repo.all()
  end

  def subscribe_referrals(user_id) do
    Phoenix.PubSub.subscribe(Mosslet.PubSub, "referrals:#{user_id}")
  end

  def broadcast_referral_update(user_id, event, payload \\ %{}) do
    Phoenix.PubSub.broadcast(
      Mosslet.PubSub,
      "referrals:#{user_id}",
      {event, payload}
    )
  end

  def void_pending_commissions(%Referral{id: referral_id}) do
    Repo.transaction_on_primary(fn ->
      Commission
      |> where([c], c.referral_id == ^referral_id)
      |> where([c], c.status in ["pending", "available"])
      |> Repo.update_all(set: [status: "voided"])
    end)
  end

  @doc """
  Gets detailed account deletion info for a user who is a referrer.
  Returns info about their referral code, Connect account, and unpaid earnings.
  """
  def get_referrer_deletion_info(user_id, current_user, session_key) do
    case get_referral_code_by_user(user_id) do
      nil ->
        %{
          has_referral_code: false,
          has_connect_account: false,
          connect_payouts_enabled: false,
          available_for_payout: 0,
          pending_in_waiting_period: 0,
          total_unpaid: 0
        }

      %ReferralCode{} = code ->
        connect_account_id =
          MossletWeb.Helpers.maybe_decrypt_user_data(
            code.stripe_connect_account_id,
            current_user,
            session_key
          )

        available = sum_available_commissions(code.id)
        pending = sum_commissions_in_waiting_period(code.id)

        %{
          has_referral_code: true,
          referral_code: code,
          has_connect_account: !is_nil(connect_account_id),
          connect_account_id: connect_account_id,
          connect_payouts_enabled: code.connect_payouts_enabled == true,
          available_for_payout: available,
          pending_in_waiting_period: pending,
          total_unpaid: available + pending
        }
    end
  end

  @doc """
  Gets info about whether a deleting user was referred by someone.
  Returns the referral if found, so we can void the referrer's pending commissions.
  """
  def get_referred_user_deletion_info(user_id) do
    case get_referral_by_user(user_id) do
      nil ->
        %{was_referred: false}

      %Referral{} = referral ->
        referral = Repo.preload(referral, [:commissions, referral_code: :user])

        pending_commissions =
          Enum.filter(referral.commissions, &(&1.status in ["pending", "available"]))

        pending_amount = Enum.reduce(pending_commissions, 0, &(&1.commission_amount + &2))

        %{
          was_referred: true,
          referral: referral,
          referrer_user_id: referral.referral_code.user_id,
          pending_commissions_count: length(pending_commissions),
          pending_commissions_amount: pending_amount
        }
    end
  end

  @doc """
  Handles cleanup when a referrer deletes their account.
  - Attempts final payout if eligible
  - Deactivates referral code
  - Does NOT delete Stripe Connect account (user retains access via Stripe directly)
  """
  def handle_referrer_account_deletion(referrer_info, current_user, session_key) do
    require Logger

    results = %{payout_result: nil, code_deactivated: false}

    results =
      if referrer_info.available_for_payout > 0 and referrer_info.connect_payouts_enabled do
        case attempt_final_payout(referrer_info, current_user, session_key) do
          {:ok, payout} ->
            %{results | payout_result: {:ok, payout}}

          {:error, reason} ->
            Logger.warning("Final payout failed for user #{current_user.id}: #{inspect(reason)}")
            %{results | payout_result: {:error, reason}}
        end
      else
        results
      end

    case deactivate_code(referrer_info.referral_code) do
      {:ok, _} -> %{results | code_deactivated: true}
      _ -> results
    end
  end

  defp attempt_final_payout(referrer_info, current_user, session_key) do
    alias Mosslet.Billing.Providers.Stripe.Services.StripeConnect

    code = referrer_info.referral_code
    amount = referrer_info.available_for_payout

    case StripeConnect.create_transfer(
           code,
           amount,
           "Final payout - account deletion",
           current_user,
           session_key
         ) do
      {:ok, transfer} ->
        commission_ids =
          list_available_commissions(code.id)
          |> Enum.map(& &1.id)

        mark_commissions_paid_out(commission_ids)

        {:ok, payout} =
          create_payout(
            %{
              referral_code_id: code.id,
              amount: amount,
              status: "completed",
              stripe_transfer_id: transfer.id,
              period_start: Date.utc_today() |> Date.beginning_of_month(),
              period_end: Date.utc_today()
            },
            current_user,
            session_key
          )

        {:ok, payout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles cleanup when a referred user deletes their account.
  Voids any pending/available commissions the referrer would have earned from this user.
  """
  def handle_referred_user_deletion(referred_info) do
    require Logger

    if referred_info.was_referred do
      case void_pending_commissions(referred_info.referral) do
        {:ok, {count, _}} ->
          Logger.info(
            "Voided #{count} commissions for referral #{referred_info.referral.id} due to referred user deletion"
          )

          {:ok, count}

        error ->
          Logger.warning("Failed to void commissions: #{inspect(error)}")
          error
      end
    else
      {:ok, 0}
    end
  end
end
