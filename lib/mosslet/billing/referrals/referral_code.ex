defmodule Mosslet.Billing.Referrals.ReferralCode do
  @moduledoc """
  A referral code that belongs to a paying subscriber.
  Users share their code to earn commission on referred subscriptions.
  """
  use Mosslet.Schema

  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_referral_codes" do
    field :code, Encrypted.Binary, redact: true
    field :code_hash, Encrypted.HMAC, redact: true
    field :payout_email, Encrypted.Binary, redact: true
    field :payout_email_hash, Encrypted.HMAC, redact: true
    field :stripe_connect_account_id, Encrypted.Binary, redact: true
    field :stripe_connect_account_id_hash, Encrypted.HMAC, redact: true
    field :connect_onboarding_complete, :boolean, default: false
    field :connect_payouts_enabled, :boolean, default: false
    field :is_active, :boolean, default: true

    belongs_to :user, Mosslet.Accounts.User

    has_many :referrals, Mosslet.Billing.Referrals.Referral
    has_many :payouts, Mosslet.Billing.Referrals.Payout

    timestamps()
  end

  def changeset(referral_code, attrs) do
    referral_code
    |> cast(attrs, [:code, :payout_email, :is_active, :user_id])
    |> validate_required([:code, :user_id])
    |> unique_constraint(:user_id)
    |> unique_constraint(:code_hash)
    |> put_hashed_fields()
  end

  def connect_changeset(referral_code, attrs) do
    referral_code
    |> cast(attrs, [
      :stripe_connect_account_id,
      :connect_onboarding_complete,
      :connect_payouts_enabled
    ])
    |> maybe_put_hash(:stripe_connect_account_id_hash, :stripe_connect_account_id)
  end

  def payout_email_changeset(referral_code, attrs) do
    referral_code
    |> cast(attrs, [:payout_email])
    |> validate_format(:payout_email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> maybe_put_hash(:payout_email_hash, :payout_email, &String.downcase/1)
  end

  # Plaintext values stored directly — Cloak Encrypted.Binary handles
  # at-rest encryption transparently. HMAC hashes computed for lookups.
  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:code_hash, :code)
  end

  defp maybe_put_hash(changeset, hash_field, source_field, transform \\ &Function.identity/1) do
    case get_change(changeset, source_field) do
      nil -> changeset
      value -> put_change(changeset, hash_field, transform.(value))
    end
  end
end
