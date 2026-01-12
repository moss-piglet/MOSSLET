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

  def changeset(referral_code, attrs, current_user \\ nil, session_key \\ nil) do
    referral_code
    |> cast(attrs, [:code, :payout_email, :is_active, :user_id])
    |> validate_required([:code, :user_id])
    |> unique_constraint(:user_id)
    |> unique_constraint(:code_hash)
    |> maybe_encrypt_fields(current_user, session_key)
  end

  def connect_changeset(referral_code, attrs, current_user \\ nil, session_key \\ nil) do
    referral_code
    |> cast(attrs, [
      :stripe_connect_account_id,
      :connect_onboarding_complete,
      :connect_payouts_enabled
    ])
    |> maybe_encrypt_connect_fields(current_user, session_key)
  end

  def payout_email_changeset(referral_code, attrs, current_user, session_key) do
    referral_code
    |> cast(attrs, [:payout_email])
    |> validate_format(:payout_email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> maybe_encrypt_payout_email(current_user, session_key)
  end

  defp maybe_encrypt_fields(changeset, current_user, session_key) do
    code = get_field(changeset, :code)

    if code && current_user && session_key do
      changeset
      |> put_change(
        :code,
        Encrypted.Users.Utils.encrypt_user_data(code, current_user, session_key)
      )
      |> put_change(:code_hash, code)
    else
      changeset
    end
  end

  defp maybe_encrypt_connect_fields(changeset, current_user, session_key) do
    account_id = get_change(changeset, :stripe_connect_account_id)

    if account_id && current_user && session_key do
      changeset
      |> put_change(
        :stripe_connect_account_id,
        Encrypted.Users.Utils.encrypt_user_data(account_id, current_user, session_key)
      )
      |> put_change(:stripe_connect_account_id_hash, account_id)
    else
      changeset
    end
  end

  defp maybe_encrypt_payout_email(changeset, current_user, session_key) do
    email = get_change(changeset, :payout_email)

    if email && current_user && session_key do
      changeset
      |> put_change(
        :payout_email,
        Encrypted.Users.Utils.encrypt_user_data(email, current_user, session_key)
      )
      |> put_change(:payout_email_hash, String.downcase(email))
    else
      changeset
    end
  end
end
