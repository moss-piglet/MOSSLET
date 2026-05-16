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
    field :stripe_transfer_id, Encrypted.Binary, redact: true
    field :stripe_transfer_id_hash, Encrypted.HMAC, redact: true
    field :failure_reason, Encrypted.Binary, redact: true
    field :processed_at, :utc_datetime
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime

    belongs_to :referral_code, Mosslet.Billing.Referrals.ReferralCode

    timestamps()
  end

  def changeset(payout, attrs) do
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
    |> put_hashed_fields()
  end

  def processing_changeset(payout) do
    payout
    |> change(%{status: "processing"})
  end

  def complete_changeset(payout, transfer_id) do
    payout
    |> change(%{
      status: "completed",
      processed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> put_change(:stripe_transfer_id, transfer_id)
    |> maybe_put_hash(:stripe_transfer_id_hash, :stripe_transfer_id)
  end

  def fail_changeset(payout, reason) do
    payout
    |> change(%{status: "failed"})
    |> put_change(:failure_reason, reason)
  end

  def needs_review_changeset(payout, reason) do
    payout
    |> change(%{status: "needs_review"})
    |> put_change(:failure_reason, reason)
  end

  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:stripe_transfer_id_hash, :stripe_transfer_id)
  end

  defp maybe_put_hash(changeset, hash_field, source_field) do
    case get_change(changeset, source_field) do
      nil -> changeset
      value -> put_change(changeset, hash_field, value)
    end
  end
end
