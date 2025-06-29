defmodule Mosslet.Accounts.UserNotifier do
  @moduledoc """
  When sending an email we use the functions in Mosslet.Email to generate the Email struct ready for Swoosh to send off.
  Here we generate an Email struct based on a user and then deliver it.
  For some emails, we also filter which users can actually be sent an email (see can_receive_mail?/1)
  """
  alias Mosslet.Email
  alias Mosslet.Mailer

  require Logger

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(_user, email, url) do
    email
    |> Email.confirm_register_email(url)
    |> deliver()
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(_user, email, url) do
    email
    |> Email.reset_password(url)
    |> deliver()
  end

  @doc """
  Deliver instructions to update a user email. This contains the url
  to confirm the email change.
  """
  def deliver_update_email_instructions(_user, email, new_email, url) do
    email
    |> Email.change_email(url, new_email)
    |> deliver()
  end

  @doc """
  Deliver a notification to user email that their email is being updated. This
  is important to help thwart account takeovers. We include the url in case
  we can use the token to invalidate the token if necessary.
  """
  def deliver_update_email_notification(_user, email, new_email, url) do
    email
    |> Email.notify_change_email(url, new_email)
    |> deliver()
  end

  @doc """
  Deliver instructions to accept an invite to an organization.
  """
  def deliver_org_invitation(org, invitation, url) do
    org
    |> Email.org_invitation(invitation, url)
    |> deliver()
  end

  @doc """
  Deliver instructions to accept a new user invite to Mosslet.
  """
  def deliver_new_user_invitation(user, invitation, url) do
    user
    |> Email.new_user_invitation(invitation, url)
    |> deliver()
  end

  @doc """
  Deliver a pin code to sign in without a password.
  """
  def deliver_passwordless_pin(user, pin) do
    user.email
    |> Email.passwordless_pin(pin)
    |> deliver()
  end

  defp deliver(email) do
    with {:ok, _metadata} <- Mailer.deliver(email) do
      # Returning the email helps with testing
      {:ok, email}
    end
  end

  # Use this instead of deliver/1 for emails that are not essential to a users account.
  # eg. imagine a user replied to a comment, and you want to notify the original commenter.
  # If the original commenter is suspended, then we don't want to send that email.
  # This function will ensure these "inactive" users don't get mail.
  def deliver_non_essential_email(email, recipient_user) do
    if can_receive_mail?(recipient_user) do
      deliver(email)
    else
      {:error, :user_cannot_receive_emails}
    end
  end

  # See deliver_non_essential_email/2
  def can_receive_mail?(user) do
    cond do
      is_nil(user.confirmed_at) ->
        Logger.info("Mail not delivered. User ##{user.id} has not confirmed their email")
        false

      user.is_suspended? ->
        Logger.info("Mail not delivered. User ##{user.id} is suspended")
        false

      user.is_deleted? ->
        Logger.info("Mail not delivered. User ##{user.id} has been deleted")
        false

      true ->
        true
    end
  end
end
