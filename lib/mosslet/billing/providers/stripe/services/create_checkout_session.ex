defmodule Mosslet.Billing.Providers.Stripe.Services.CreateCheckoutSession do
  @moduledoc false
  use MossletWeb, :verified_routes

  alias Mosslet.Billing.Providers.Stripe.Provider

  @enforce_keys [
    :customer_id,
    :source,
    :source_id,
    :success_url,
    :cancel_url,
    :provider_customer_id,
    :allow_promotion_codes,
    :trial_period_days,
    :line_items
  ]

  defstruct [
    :customer_id,
    :source,
    :source_id,
    :success_url,
    :cancel_url,
    :provider_customer_id,
    :allow_promotion_codes,
    :trial_period_days,
    :line_items,
    checkout_session_options_overrides: %{}
  ]

  @doc """
  Create a Stripe session for a product. This should be called once a user clicks a subscribe button.

  -> User/Org clicks subscribe
  -> Create a Stripe Customer for user/org
  -> Create Stripe Checkout Session <-- This step
  -> User redirected to a Stripe-hosted checkout page
  -> User enters credit card details and subscribes
  -> Stripe redirects user to a success page
  -> Stripe sends a webhook ("checkout.session.completed") to our server
  -> We update the user's billing_subscription

  It will return a Stripe.Checkout.Session struct, which includes a `url` field that you can redirect the user to. For example:

      case Mosslet.Billing.Providers.Stripe.Checkout.Session.create("single", socket.assigns.current_user) do
        {:ok, session} ->
          {:noreply, redirect(socket, external: session.url)}

        {:error, error} ->
          {:noreply,
          put_flash(socket, :error, "Something went wrong with our payment portal.")}
      end
  """
  def call(%__MODULE__{} = session) do
    session
    |> checkout_session_options()
    |> Map.merge(session.checkout_session_options_overrides)
    |> Provider.create_checkout_session()
  end

  defp checkout_session_options(%{
         customer_id: customer_id,
         source: source,
         source_id: source_id,
         success_url: success_url,
         cancel_url: cancel_url,
         provider_customer_id: provider_customer_id,
         allow_promotion_codes: allow_promotion_codes,
         trial_period_days: trial_period_days,
         line_items: line_items
       }) do
    if trial_period_days do
      %{
        trial_period_days: trial_period_days,
        metadata: %{
          source: source,
          source_id: source_id
        }
      }
    else
      %{
        metadata: %{
          source: source,
          source_id: source_id
        }
      }
    end

    %{
      client_reference_id: customer_id,
      customer: provider_customer_id,
      success_url: success_url,
      cancel_url: cancel_url,
      mode: "payment",
      allow_promotion_codes: allow_promotion_codes,
      line_items: line_items
    }
  end
end
