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

  def changeset(payment_intent, attrs) do
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
    |> put_hashed_fields()
  end

  # Plaintext values stored directly — Cloak Encrypted.Binary handles
  # at-rest encryption transparently. HMAC hashes computed for lookups.
  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:provider_payment_intent_id_hash, :provider_payment_intent_id)
    |> maybe_put_hash(:provider_customer_id_hash, :provider_customer_id)
    |> maybe_put_hash(:provider_latest_charge_id_hash, :provider_latest_charge_id)
    |> maybe_put_hash(:provider_payment_method_id_hash, :provider_payment_method_id)
  end

  defp maybe_put_hash(changeset, hash_field, source_field) do
    case get_field(changeset, source_field) do
      nil -> changeset
      value -> put_change(changeset, hash_field, value)
    end
  end
end
