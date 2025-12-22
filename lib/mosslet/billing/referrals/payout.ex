defmodule Mosslet.Billing.Referrals.Payout do
  @moduledoc """
  Tracks payouts sent to referrers via Stripe Connect transfers.
  """
  use Mosslet.Schema

  alias Mosslet.Encrypted

  @status_values ~w(pending processing completed failed needs_review)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_payouts" do
    field :amount, :integer
    field :status, :string, default: "pending"
    field :stripe_transfer_id, Encrypted.Binary
    field :stripe_transfer_id_hash, Encrypted.HMAC
    field :failure_reason, Encrypted.Binary
    field :processed_at, :utc_datetime
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime

    belongs_to :referral_code, Mosslet.Billing.Referrals.ReferralCode

    timestamps()
  end

  def changeset(payout, attrs, current_user \\ nil, session_key \\ nil) do
    payout
    |> cast(attrs, [
      :amount,
      :status,
      :stripe_transfer_id,
      :failure_reason,
      :processed_at,
      :period_start,
      :period_end,
      :referral_code_id
    ])
    |> validate_required([:amount, :status, :period_start, :period_end, :referral_code_id])
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:amount, greater_than: 0)
    |> maybe_encrypt_fields(current_user, session_key)
  end

  def processing_changeset(payout) do
    payout
    |> change(%{status: "processing"})
  end

  def complete_changeset(payout, transfer_id, current_user, session_key) do
    payout
    |> change(%{
      status: "completed",
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> put_change(:stripe_transfer_id, transfer_id)
    |> maybe_encrypt_transfer_id(current_user, session_key)
  end

  def fail_changeset(payout, reason, current_user, session_key) do
    payout
    |> change(%{status: "failed"})
    |> put_change(:failure_reason, reason)
    |> maybe_encrypt_failure_reason(current_user, session_key)
  end

  def needs_review_changeset(payout, reason, current_user, session_key) do
    payout
    |> change(%{status: "needs_review"})
    |> put_change(:failure_reason, reason)
    |> maybe_encrypt_failure_reason(current_user, session_key)
  end

  defp maybe_encrypt_fields(changeset, current_user, session_key) do
    changeset
    |> maybe_encrypt_transfer_id(current_user, session_key)
    |> maybe_encrypt_failure_reason(current_user, session_key)
  end

  defp maybe_encrypt_transfer_id(changeset, current_user, session_key) do
    transfer_id = get_change(changeset, :stripe_transfer_id)

    if transfer_id && current_user && session_key do
      changeset
      |> put_change(
        :stripe_transfer_id,
        Encrypted.Users.Utils.encrypt_user_data(transfer_id, current_user, session_key)
      )
      |> put_change(:stripe_transfer_id_hash, transfer_id)
    else
      changeset
    end
  end

  defp maybe_encrypt_failure_reason(changeset, current_user, session_key) do
    reason = get_change(changeset, :failure_reason)

    if reason && current_user && session_key do
      changeset
      |> put_change(
        :failure_reason,
        Encrypted.Users.Utils.encrypt_user_data(reason, current_user, session_key)
      )
    else
      changeset
    end
  end
end
