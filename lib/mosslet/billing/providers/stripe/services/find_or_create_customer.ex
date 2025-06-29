defmodule Mosslet.Billing.Providers.Stripe.Services.FindOrCreateCustomer do
  @moduledoc """
  This module provides a function to find or create a customer in Stripe and locally.
  """

  alias Mosslet.Billing.Customers
  alias Mosslet.Encrypted.Users.Utils
  alias Mosslet.Billing.Providers.Stripe.Provider

  def call(current_user, source, source_id, session_key) do
    case Customers.get_customer_by_source(source, source_id) do
      nil -> create_customer(current_user, source, source_id, session_key)
      customer -> {:ok, customer}
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
        raise "Failed to create Stripe Customer: #{inspect(error)}"
    end
  end
end
