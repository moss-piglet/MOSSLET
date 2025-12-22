defmodule Mosslet.Billing.Providers.Stripe.Services.StripeConnect do
  @moduledoc """
  Service for managing Stripe Connect Express accounts for referral payouts.
  """
  require Logger

  use MossletWeb, :verified_routes

  alias Mosslet.Billing.Referrals
  alias Mosslet.Billing.Referrals.ReferralCode
  alias Mosslet.Encrypted.Users.Utils, as: EncryptedUtils

  def create_connect_account(%ReferralCode{} = referral_code, current_user, session_key) do
    email = EncryptedUtils.decrypt_user_data(current_user.email, current_user, session_key)

    account_params = %{
      type: "express",
      country: "US",
      email: email,
      capabilities: %{
        transfers: %{requested: true}
      },
      metadata: %{
        user_id: current_user.id,
        referral_code_id: referral_code.id
      },
      settings: %{
        payouts: %{
          schedule: %{
            interval: "manual"
          }
        }
      }
    }

    case Stripe.Account.create(account_params) do
      {:ok, account} ->
        {:ok, _updated_code} =
          Referrals.update_connect_account(
            referral_code,
            %{stripe_connect_account_id: account.id},
            current_user,
            session_key
          )

        {:ok, account}

      {:error, error} ->
        Logger.error("Failed to create Stripe Connect account: #{inspect(error)}")
        {:error, error}
    end
  end

  def create_account_link(%ReferralCode{} = referral_code, current_user, session_key) do
    account_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        referral_code.stripe_connect_account_id,
        current_user,
        session_key
      )

    link_params = %{
      account: account_id,
      refresh_url: url(~p"/app/referrals/connect/refresh"),
      return_url: url(~p"/app/referrals/connect/complete"),
      type: "account_onboarding"
    }

    case Stripe.AccountLink.create(link_params) do
      {:ok, link} ->
        {:ok, link.url}

      {:error, error} ->
        Logger.error("Failed to create Stripe account link: #{inspect(error)}")
        {:error, error}
    end
  end

  def create_login_link(%ReferralCode{} = referral_code, current_user, session_key) do
    account_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        referral_code.stripe_connect_account_id,
        current_user,
        session_key
      )

    case Stripe.LoginLink.create(account_id, %{}) do
      {:ok, link} ->
        {:ok, link.url}

      {:error, error} ->
        Logger.error("Failed to create Stripe login link: #{inspect(error)}")
        {:error, error}
    end
  end

  def get_account_status(%ReferralCode{} = referral_code, current_user, session_key) do
    account_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        referral_code.stripe_connect_account_id,
        current_user,
        session_key
      )

    if account_id do
      case Stripe.Account.retrieve(account_id) do
        {:ok, account} ->
          {:ok,
           %{
             charges_enabled: account.charges_enabled,
             payouts_enabled: account.payouts_enabled,
             details_submitted: account.details_submitted,
             requirements: account.requirements
           }}

        {:error, error} ->
          {:error, error}
      end
    else
      {:ok, %{charges_enabled: false, payouts_enabled: false, details_submitted: false}}
    end
  end

  def create_transfer(
        %ReferralCode{} = referral_code,
        amount_cents,
        description,
        current_user,
        session_key
      ) do
    account_id =
      MossletWeb.Helpers.maybe_decrypt_user_data(
        referral_code.stripe_connect_account_id,
        current_user,
        session_key
      )

    transfer_params = %{
      amount: amount_cents,
      currency: "usd",
      destination: account_id,
      description: description,
      metadata: %{
        referral_code_id: referral_code.id,
        period: Date.utc_today() |> Calendar.strftime("%Y-%m")
      }
    }

    case Stripe.Transfer.create(transfer_params) do
      {:ok, transfer} ->
        Logger.info(
          "Created transfer #{transfer.id} for #{amount_cents} cents to account #{account_id}"
        )

        {:ok, transfer}

      {:error, error} ->
        Logger.error("Failed to create transfer: #{inspect(error)}")
        {:error, error}
    end
  end

  def retrieve_balance do
    Stripe.Balance.retrieve()
  end
end
