defmodule Mosslet.Billing.Referrals.Commission do
  @moduledoc """
  Tracks commission earned from a single subscription payment.
  Created when invoice.paid webhook fires for a referred user's subscription.
  """
  use Mosslet.Schema

  alias Mosslet.Encrypted

  @status_values ~w(pending available paid_out voided)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_commissions" do
    field :stripe_invoice_id, Encrypted.Binary
    field :stripe_invoice_id_hash, Encrypted.HMAC
    field :gross_amount, :integer
    field :commission_amount, :integer
    field :status, :string, default: "pending"
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :available_at, :utc_datetime

    belongs_to :referral, Mosslet.Billing.Referrals.Referral
    belongs_to :subscription, Mosslet.Billing.Subscriptions.Subscription

    timestamps()
  end

  def changeset(commission, attrs, current_user \\ nil, session_key \\ nil) do
    commission
    |> cast(attrs, [
      :stripe_invoice_id,
      :gross_amount,
      :commission_amount,
      :status,
      :period_start,
      :period_end,
      :available_at,
      :referral_id,
      :subscription_id
    ])
    |> validate_required([
      :stripe_invoice_id,
      :gross_amount,
      :commission_amount,
      :status,
      :referral_id
    ])
    |> validate_inclusion(:status, @status_values)
    |> validate_number(:gross_amount, greater_than: 0)
    |> validate_number(:commission_amount, greater_than_or_equal_to: 0)
    |> maybe_encrypt_invoice_id(current_user, session_key)
  end

  def mark_available_changeset(commission) do
    commission
    |> change(%{status: "available"})
  end

  def mark_paid_out_changeset(commission) do
    commission
    |> change(%{status: "paid_out"})
  end

  def void_changeset(commission) do
    commission
    |> change(%{status: "voided"})
  end

  defp maybe_encrypt_invoice_id(changeset, current_user, session_key) do
    invoice_id = get_change(changeset, :stripe_invoice_id)

    if invoice_id && current_user && session_key do
      changeset
      |> put_change(
        :stripe_invoice_id,
        Encrypted.Users.Utils.encrypt_user_data(invoice_id, current_user, session_key)
      )
      |> put_change(:stripe_invoice_id_hash, invoice_id)
    else
      changeset
    end
  end
end
