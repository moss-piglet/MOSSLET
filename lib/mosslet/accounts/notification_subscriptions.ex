defmodule Mosslet.Accounts.NotificationSubscriptions do
  @moduledoc false
  # Every time a user receives a notification of some kind (mainly emails), then they should be able to opt out (except for transactional emails like confirming your account).
  # A common case is marketing emails like product updates - a user should be able to unsubscribe from this.
  # In this module we keep list/0 up to date with the types of notifications a user can sub/unsub from.
  # unsubscribe_url/2 will generate a url for a user to unsub from a particular notification type.
  # eg unsubscribe_url(user, "marketing_notifications") will generate a URL for that user to unsubscribe from marketing emails.
  # These urls are then placed at the bottom of emails for easy unsubscribing.
  def get(name), do: Enum.find(list(), &(&1.name == name))

  def list do
    [
      %{
        name: "marketing_notifications",
        user_field: :is_subscribed_to_marketing_notifications,
        label: "Marketing Notifications",
        description: "Receive the occasional marketing notification",
        unsub_description: "You will no longer get marketing notifications",
        sent_by_mailbluster: true
      }

      # Example:
      # %{
      #   name: "comment_replies",
      #   user_field: :is_subscribed_to_comment_replies,
      #   label: "Comment replies",
      #   description: "Get notified when someone replies to your comment",
      #   unsub_description: "You will no longer be notified when someone replies to your comment"
      # },
    ]
  end

  # Will turn a notification subscription on/off
  # why would we also toggle an admin change?
  # this doesn't make any sense to me.
  #
  # I made a dummy function for this `update_user_as_admin/2`
  # that currently does nothing.
  def toggle_user_subscription(user, notification_subscription_name) do
    notification_subscription = get(notification_subscription_name)

    if notification_subscription do
      current_value = Map.get(user, notification_subscription.user_field)
      user_updates = Map.put(%{}, notification_subscription.user_field, !current_value)

      case Mosslet.Accounts.update_user_as_admin(user, user_updates) do
        {:ok, _user} ->
          true

        {:error, _changeset} ->
          false
      end
    else
      false
    end
  end

  @doc "Generates a URL allowing users to unsub from an email subscription"
  def unsubscribe_url(user, notification_subscription_name) do
    MossletWeb.Router.Helpers.user_settings_url(
      MossletWeb.Endpoint,
      :unsubscribe_from_notification_subscription,
      Util.HashId.encode(user.id),
      notification_subscription_name
    )
  end
end
