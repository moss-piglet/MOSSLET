defmodule MossletWeb.ReferralConnectController do
  @moduledoc """
  Handles Stripe Connect onboarding callbacks.
  """
  use MossletWeb, :controller

  def complete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Payout setup complete! You'll receive payouts automatically."))
    |> redirect(to: ~p"/app/referrals")
  end

  def refresh(conn, _params) do
    conn
    |> put_flash(:info, gettext("Please complete your payout setup."))
    |> redirect(to: ~p"/app/referrals")
  end
end
