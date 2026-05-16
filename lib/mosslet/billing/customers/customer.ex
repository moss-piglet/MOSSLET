defmodule Mosslet.Billing.Customers.Customer do
  @moduledoc """
  A customer is something that has a subscription to a product. It can be attached to either a user or org.

  You can choose which one to associate it with. It's usually better to attach it to an org, so if a user leaves the org, the subscription can continue.

  However, if you know you'll never have more than one user per account/org, you can attach it to a user.
  """

  use Mosslet.Schema
  alias Mosslet.Encrypted

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "billing_customers" do
    field :email, Encrypted.Binary, redact: true
    field :email_hash, Encrypted.HMAC, redact: true
    field :provider, Encrypted.Binary, redact: true
    field :provider_customer_id, Encrypted.Binary, redact: true
    field :provider_hash, Encrypted.HMAC, redact: true
    field :provider_customer_id_hash, Encrypted.HMAC, redact: true
    field :trial_used_at, :utc_datetime

    belongs_to :user, Mosslet.Accounts.User
    belongs_to :org, Mosslet.Orgs.Org

    has_many :subscriptions, Mosslet.Billing.Subscriptions.Subscription,
      foreign_key: :billing_customer_id

    has_many :payment_intents, Mosslet.Billing.PaymentIntents.PaymentIntent,
      foreign_key: :billing_customer_id

    timestamps()
  end

  def changeset_by_source(customer, source, attrs) do
    # e.g. if source is "user", then we need to make sure that the user_id is set
    source_id_field = source_id_field(source)

    cast_attrs = [:email, :provider, :provider_customer_id, source_id_field]
    required_attrs = [:email, :provider, :provider_customer_id, source_id_field]

    customer
    |> cast(attrs, cast_attrs)
    |> validate_required(required_attrs)
    |> put_hashed_fields()
  end

  def source_id_field(:user), do: :user_id
  def source_id_field(:org), do: :org_id

  # Plaintext values are stored directly — Cloak Encrypted.Binary handles
  # at-rest encryption transparently. HMAC hashes are computed for lookups.
  defp put_hashed_fields(changeset) do
    changeset
    |> maybe_put_hash(:email_hash, :email)
    |> maybe_put_hash(:provider_hash, :provider)
    |> maybe_put_hash(:provider_customer_id_hash, :provider_customer_id)
  end

  defp maybe_put_hash(changeset, hash_field, source_field) do
    case get_field(changeset, source_field) do
      nil -> changeset
      value -> put_change(changeset, hash_field, value)
    end
  end
end
