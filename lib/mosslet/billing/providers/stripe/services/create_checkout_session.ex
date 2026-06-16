defmodule Mosslet.Billing.Providers.Stripe.Services.CreateCheckoutSession do
  @moduledoc false
  use MossletWeb, :verified_routes

  alias Mosslet.Billing.Providers.Stripe.Provider
  alias Mosslet.Billing.Referrals.Referral

  @enforce_keys [
    :customer_id,
    :source,
    :source_id,
    :success_url,
    :cancel_url,
    :provider_customer_id,
    :allow_promotion_codes,
    :trial_period_days,
    :line_items,
    :mode
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
    :mode,
    :referral,
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
    |> maybe_add_referral_discount(session.referral)
    |> Map.merge(session.checkout_session_options_overrides)
    |> Provider.create_checkout_session()
  end

  @doc """
  Builds the Stripe checkout session option map (everything except the referral
  discount, which requires a live Stripe coupon call, and any caller overrides).

  Exposed so the source-keyed wiring — `client_reference_id`, `metadata.source`,
  `metadata.source_id`, the explicit `org_id` for :org sessions, and the trial
  `subscription_data` — can be verified without hitting Stripe.
  """
  def build_options(%__MODULE__{} = session), do: checkout_session_options(session)

  defp checkout_session_options(%{
         customer_id: customer_id,
         source: source,
         source_id: source_id,
         success_url: success_url,
         cancel_url: cancel_url,
         provider_customer_id: provider_customer_id,
         allow_promotion_codes: allow_promotion_codes,
         trial_period_days: trial_period_days,
         line_items: line_items,
         mode: mode,
         referral: referral
       }) do
    base_options = %{
      client_reference_id: customer_id,
      customer: provider_customer_id,
      success_url: success_url,
      cancel_url: cancel_url,
      mode: mode,
      allow_promotion_codes: allow_promotion_codes,
      line_items: line_items,
      metadata:
        %{
          source: source,
          source_id: source_id
        }
        |> maybe_add_org_id(source, source_id)
        |> maybe_add_referral_metadata(referral)
    }

    if mode == "subscription" && trial_period_days && trial_period_days > 0 do
      base_options
      |> Map.put(:subscription_data, %{trial_period_days: trial_period_days})
      |> Map.put(:payment_method_collection, "if_required")
    else
      base_options
    end
  end

  defp maybe_add_referral_discount(options, nil), do: options

  defp maybe_add_referral_discount(options, %Referral{discount_percent: discount_percent})
       when discount_percent > 0 do
    coupon_params = %{
      percent_off: discount_percent,
      duration: "once",
      name: "Referral Discount"
    }

    case Stripe.Coupon.create(coupon_params) do
      {:ok, coupon} ->
        options
        |> Map.put(:discounts, [%{coupon: coupon.id}])
        |> Map.delete(:allow_promotion_codes)

      {:error, _} ->
        options
    end
  end

  defp maybe_add_referral_discount(options, _), do: options

  # Stamp an explicit `org_id` on the checkout metadata for :org-source sessions.
  # `source_id` already equals the org id, but a dedicated `org_id` key is cheap
  # insurance for Stripe dashboard filtering and webhook debugging. ZK guardrail:
  # org_id is an internal id — never names/keys/emails.
  defp maybe_add_org_id(metadata, :org, org_id), do: Map.put(metadata, :org_id, org_id)
  defp maybe_add_org_id(metadata, _source, _source_id), do: metadata

  defp maybe_add_referral_metadata(metadata, nil), do: metadata

  defp maybe_add_referral_metadata(metadata, %Referral{id: referral_id}) do
    Map.put(metadata, :referral_id, referral_id)
  end
end
