defmodule Mosslet.Workers.InviteNewUserWorker do
  @moduledoc """
  Oban job for inviting new users to Mosslet.
  """
  use Oban.Worker,
    max_attempts: 3,
    queue: :invites,
    unique: [period: {3, :hour}, keys: [:recipient_email, :current_user_username]]

  use MossletWeb, :verified_routes
  alias Mosslet.Accounts

  def perform(%Oban.Job{
        args:
          %{
            "current_user_name" => name,
            "current_user_username" => username,
            "recipient_email" => recipient_email,
            "recipient_name" => recipient_name,
            "message" => message
          } = args
      }) do
    referral_code = args["referral_code"]

    user = %{
      name: name,
      username: username
    }

    invitation = %{
      email: recipient_email,
      name: recipient_name,
      message: message
    }

    registration_url = build_registration_url(referral_code)

    Accounts.UserNotifier.deliver_new_user_invitation(
      user,
      invitation,
      registration_url,
      referral_code
    )

    :ok
  end

  defp build_registration_url(nil), do: url(~p"/auth/register")
  defp build_registration_url(referral_code), do: url(~p"/auth/register?ref=#{referral_code}")
end
