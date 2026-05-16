defmodule Mosslet.Billing.Providers.Stripe.Services.FindOrCreateCustomer do
  @moduledoc """
  This module provides a function to find or create a customer in Stripe and locally.
  """

  require Logger

  alias Mosslet.Billing.Customers
  alias Mosslet.Encrypted.Users.Utils
  alias Mosslet.Billing.Providers.Stripe.Provider

  @doc """
  Finds or creates a Stripe customer.

  The `session_key` is needed temporarily to decrypt `user.email` (which is
  still user-key encrypted until the profile ZK migration). Billing-specific
  data (customer IDs, etc.) is stored as Cloak-only — no user-key layer.
  """
  def call(current_user, source, source_id, session_key) do
    case Customers.get_customer_by_source(source, source_id) do
      nil ->
        Logger.debug("FindOrCreateCustomer: No local customer found, creating new one")
        user_email = decrypt_email(current_user, session_key)
        create_customer(user_email, source, source_id)

      customer ->
        Logger.debug(
          "FindOrCreateCustomer: Found local customer #{customer.id}, verifying with Stripe"
        )

        verify_or_recreate_stripe_customer(
          customer,
          current_user,
          source,
          source_id,
          session_key
        )
    end
  end

  defp verify_or_recreate_stripe_customer(customer, current_user, source, source_id, session_key) do
    # provider_customer_id is now Cloak-only — read directly
    provider_customer_id = customer.provider_customer_id

    Logger.debug("FindOrCreateCustomer: Retrieving Stripe customer #{provider_customer_id}")

    case Provider.retrieve_customer(provider_customer_id) do
      {:ok, %{created: nil}} ->
        Logger.warning(
          "Stripe customer #{provider_customer_id} was deleted, recreating for source #{source}:#{source_id}"
        )

        user_email = decrypt_email(current_user, session_key)
        recreate_stripe_customer(user_email, source, source_id)

      {:ok, _stripe_customer} ->
        Logger.debug("FindOrCreateCustomer: Stripe customer exists, returning local customer")
        {:ok, customer}

      {:error, %Stripe.Error{extra: %{card_code: :resource_missing}} = error} ->
        Logger.warning(
          "Stripe customer #{provider_customer_id} not found, recreating for source #{source}:#{source_id}. Error: #{inspect(error)}"
        )

        user_email = decrypt_email(current_user, session_key)
        recreate_stripe_customer(user_email, source, source_id)

      {:error, error} ->
        Logger.error("Failed to retrieve Stripe customer: #{inspect(error)}")
        {:error, error}
    end
  end

  defp recreate_stripe_customer(user_email, source, source_id) do
    case Provider.create_customer(%{email: user_email}) do
      {:ok, stripe_customer} ->
        Customers.update_customer_for_source(
          source,
          source_id,
          %{provider_customer_id: stripe_customer.id}
        )

      {:error, error} ->
        Logger.error("Failed to recreate Stripe Customer: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_customer(user_email, source, source_id) do
    case Provider.create_customer(%{email: user_email}) do
      {:ok, stripe_customer} ->
        Customers.create_customer_for_source(
          source,
          source_id,
          %{
            email: user_email,
            provider: "stripe",
            provider_customer_id: stripe_customer.id
          }
        )

      {:error, error} ->
        Logger.error("Failed to create Stripe Customer: #{inspect(error)}")
        {:error, error}
    end
  end

  # Temporary: user.email is still user-key encrypted until profile ZK migration.
  # Once profile data uses browser-side encryption, this can be replaced with
  # direct field access.
  defp decrypt_email(current_user, session_key) do
    Utils.decrypt_user_data(current_user.email, current_user, session_key)
  end
end
