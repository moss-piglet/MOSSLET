defmodule Mosslet.Billing.PaymentIntents.PaymentIntent do
  @moduledoc false
  use Mosslet.Schema
  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_payment_intents" do
    field :provider_payment_intent_id, Encrypted.Binary, redact: true
    field :provider_payment_intent_id_hash, Encrypted.HMAC, redact: true
    field :provider_customer_id, Encrypted.Binary, redact: true
    field :provider_customer_id_hash, Encrypted.HMAC, redact: true
    field :provider_latest_charge_id, Encrypted.Binary, redact: true
    field :provider_latest_charge_id_hash, Encrypted.HMAC, redact: true
    field :provider_payment_method_id, Encrypted.Binary, redact: true
    field :provider_payment_method_id_hash, Encrypted.HMAC, redact: true

    field :provider_created_at, :utc_datetime
    field :amount, :integer
    field :amount_received, :integer
    field :status, :string

    belongs_to :customer, Customer,
      foreign_key: :billing_customer_id,
      type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(payment_intent, attrs, current_user \\ nil, session_key \\ nil) do
    payment_intent
    |> cast(attrs, [
      :provider_payment_intent_id,
      :provider_customer_id,
      :provider_latest_charge_id,
      :provider_payment_method_id,
      :provider_created_at,
      :amount,
      :amount_received,
      :status,
      :billing_customer_id
    ])
    |> cast_assoc(:customer)
    |> validate_required([
      :provider_payment_intent_id,
      :provider_customer_id,
      :provider_latest_charge_id,
      :provider_payment_method_id,
      :provider_created_at,
      :amount,
      :amount_received,
      :status,
      :billing_customer_id
    ])
    |> maybe_encrypt_and_hash_fields(current_user, session_key)
  end

  # This will reset existing user's accounts to have the correctly encrypted
  # email fields on their account, as well as newly created accounts
  defp maybe_encrypt_and_hash_fields(changeset, current_user, session_key) do
    customer_id = get_field(changeset, :customer_id)
    provider_payment_intent_id = get_field(changeset, :provider_payment_intent_id)
    provider_customer_id = get_field(changeset, :provider_customer_id)
    provider_latest_charge_id = get_field(changeset, :provider_latest_charge_id)
    provider_payment_method_id = get_field(changeset, :provider_payment_method_id)

    if customer_id && current_user && session_key do
      changeset
      |> put_change(
        :provider_payment_intent_id,
        Encrypted.Users.Utils.encrypt_user_data(
          provider_payment_intent_id,
          current_user,
          session_key
        )
      )
      |> put_change(
        :provider_customer_id,
        Encrypted.Users.Utils.encrypt_user_data(provider_customer_id, current_user, session_key)
      )
      |> put_change(
        :provider_latest_charge_id,
        Encrypted.Users.Utils.encrypt_user_data(
          provider_latest_charge_id,
          current_user,
          session_key
        )
      )
      |> put_change(
        :provider_payment_method_id,
        Encrypted.Users.Utils.encrypt_user_data(
          provider_payment_method_id,
          current_user,
          session_key
        )
      )
      |> put_change(:provider_payment_intent_id_hash, provider_payment_intent_id)
      |> put_change(:provider_customer_id_hash, provider_customer_id)
      |> put_change(:provider_latest_charge_id_hash, provider_latest_charge_id)
      |> put_change(:provider_payment_method_id_hash, provider_payment_method_id)
    else
      changeset
    end
  end
end
