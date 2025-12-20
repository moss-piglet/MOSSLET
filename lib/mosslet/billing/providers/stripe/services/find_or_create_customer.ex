defmodule Mosslet.Billing.Providers.Stripe.Services.FindOrCreateCustomer do
  @moduledoc """
  This module provides a function to find or create a customer in Stripe and locally.
  """

  require Logger

  alias Mosslet.Billing.Customers
  alias Mosslet.Encrypted.Users.Utils
  alias Mosslet.Billing.Providers.Stripe.Provider

  def call(current_user, source, source_id, session_key) do
    case Customers.get_customer_by_source(source, source_id) do
      nil ->
        Logger.debug("FindOrCreateCustomer: No local customer found, creating new one")
        create_customer(current_user, source, source_id, session_key)

      customer ->
        Logger.debug(
          "FindOrCreateCustomer: Found local customer #{customer.id}, verifying with Stripe"
        )

        verify_or_recreate_stripe_customer(customer, current_user, source, source_id, session_key)
    end
  end

  defp verify_or_recreate_stripe_customer(customer, current_user, source, source_id, session_key) do
    provider_customer_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        customer.provider_customer_id,
        current_user,
        session_key
      )

    Logger.debug("FindOrCreateCustomer: Retrieving Stripe customer #{provider_customer_id}")

    case Provider.retrieve_customer(provider_customer_id) do
      {:ok, %{created: nil}} ->
        Logger.warning(
          "Stripe customer #{provider_customer_id} was deleted, recreating for source #{source}:#{source_id}"
        )

        recreate_stripe_customer(customer, current_user, source, source_id, session_key)

      {:ok, _stripe_customer} ->
        Logger.debug("FindOrCreateCustomer: Stripe customer exists, returning local customer")
        {:ok, customer}

      {:error, %Stripe.Error{extra: %{card_code: :resource_missing}} = error} ->
        Logger.warning(
          "Stripe customer #{provider_customer_id} not found, recreating for source #{source}:#{source_id}. Error: #{inspect(error)}"
        )

        recreate_stripe_customer(customer, current_user, source, source_id, session_key)

      {:error, error} ->
        Logger.error("Failed to retrieve Stripe customer: #{inspect(error)}")
        {:error, error}
    end
  end

  defp recreate_stripe_customer(_customer, current_user, source, source_id, session_key) do
    case Provider.create_customer(%{
           email: Utils.decrypt_user_data(current_user.email, current_user, session_key)
         }) do
      {:ok, stripe_customer} ->
        Customers.update_customer_for_source(
          source,
          source_id,
          %{
            provider_customer_id:
              MossletWeb.Helpers.maybe_decrypt_user_data(
                stripe_customer.id,
                current_user,
                session_key
              )
          },
          current_user,
          session_key
        )

      {:error, error} ->
        Logger.error("Failed to recreate Stripe Customer: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_customer(current_user, source, source_id, session_key) do
    case Provider.create_customer(%{
           email: Utils.decrypt_user_data(current_user.email, current_user, session_key)
         }) do
      {:ok, stripe_customer} ->
        Customers.create_customer_for_source(
          source,
          source_id,
          %{
            email: Utils.decrypt_user_data(current_user.email, current_user, session_key),
            provider: "stripe",
            provider_customer_id:
              MossletWeb.Helpers.maybe_decrypt_user_data(
                stripe_customer.id,
                current_user,
                session_key
              )
          },
          current_user,
          session_key
        )

      {:error, error} ->
        Logger.error("Failed to create Stripe Customer: #{inspect(error)}")
        {:error, error}
    end
  end
end
