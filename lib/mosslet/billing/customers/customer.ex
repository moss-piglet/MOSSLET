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

  def changeset_by_source(customer, source, attrs, current_user \\ nil, session_key \\ nil) do
    # e.g. if source is "user", then we need to make sure that the user_id is set
    source_id_field = source_id_field(source)

    cast_attrs = [:email, :provider, :provider_customer_id, source_id_field]
    required_attrs = [:email, :provider, :provider_customer_id, source_id_field]

    customer
    |> cast(attrs, cast_attrs)
    |> validate_required(required_attrs)
    |> maybe_encrypt_and_hash_fields(current_user, session_key)
  end

  def source_id_field(:user), do: :user_id
  def source_id_field(:org), do: :org_id

  # This will reset existing user's accounts to have the correctly encrypted
  # email fields on their account, as well as newly created accounts
  defp maybe_encrypt_and_hash_fields(changeset, current_user, session_key) do
    email = get_field(changeset, :email)
    provider = get_field(changeset, :provider)
    provider_customer_id = get_field(changeset, :provider_customer_id)

    if email && provider_customer_id && current_user && session_key do
      changeset
      |> put_change(
        :email,
        Encrypted.Users.Utils.encrypt_user_data(email, current_user, session_key)
      )
      |> put_change(
        :provider,
        Encrypted.Users.Utils.encrypt_user_data(provider, current_user, session_key)
      )
      |> put_change(
        :provider_customer_id,
        Encrypted.Users.Utils.encrypt_user_data(provider_customer_id, current_user, session_key)
      )
      |> put_change(:email_hash, email)
      |> put_change(:provider_hash, provider)
      |> put_change(:provider_customer_id_hash, provider_customer_id)
    else
      changeset
    end
  end
end
