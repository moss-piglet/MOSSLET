defmodule Mosslet.Billing.Referrals.Referral do
  @moduledoc """
  Tracks a referral relationship between a referrer (via their code) and a referred user.
  """
  use Mosslet.Schema

  @status_values ~w(pending qualified active expired canceled)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_referrals" do
    field :status, :string, default: "pending"
    field :referred_at, :utc_datetime
    field :qualified_at, :utc_datetime
    field :commission_rate, :decimal
    field :discount_percent, :integer
    field :beta_referral, :boolean, default: false

    belongs_to :referral_code, Mosslet.Billing.Referrals.ReferralCode
    belongs_to :referred_user, Mosslet.Accounts.User

    has_many :commissions, Mosslet.Billing.Referrals.Commission

    timestamps()
  end

  def changeset(referral, attrs) do
    referral
    |> cast(attrs, [
      :status,
      :referred_at,
      :qualified_at,
      :commission_rate,
      :discount_percent,
      :beta_referral,
      :referral_code_id,
      :referred_user_id
    ])
    |> validate_required([
      :status,
      :referred_at,
      :commission_rate,
      :discount_percent,
      :referral_code_id,
      :referred_user_id
    ])
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:referred_user_id)
  end

  def qualify_changeset(referral) do
    referral
    |> change(%{
      status: "qualified",
      qualified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def activate_changeset(referral) do
    referral
    |> change(%{status: "active"})
  end

  def cancel_changeset(referral) do
    referral
    |> change(%{status: "canceled"})
  end

  def reactivate_changeset(referral) do
    referral
    |> change(%{status: "pending"})
  end

  def expire_changeset(referral) do
    referral
    |> change(%{status: "expired"})
  end
end
