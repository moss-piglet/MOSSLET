defmodule Mosslet.Workers.InviteNewUserWorker do
  @moduledoc """
  Oban job for inviting new users to Mosslet.
  """
  use Oban.Worker,
    max_attempts: 3,
    queue: :invites,
    unique: [period: {3, :hour}, keys: [:recipient_email, :current_user_email]]

  use MossletWeb, :verified_routes
  alias Mosslet.Accounts

  def perform(%Oban.Job{
        args: %{
          "current_user_email" => email,
          "current_user_name" => name,
          "current_user_username" => username,
          "recipient_email" => recipient_email,
          "recipient_name" => recipient_name,
          "message" => message
        }
      }) do
    user = %{
      email: email,
      name: name,
      username: username
    }

    invitation = %{
      email: recipient_email,
      name: recipient_name,
      message: message
    }

    to = url(~p"/auth/register")

    Accounts.UserNotifier.deliver_new_user_invitation(
      user,
      invitation,
      to
    )

    :ok
  end
end
