defmodule MossletWeb.MailblusterRoutes do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      scope "/", MossletWeb do
        pipe_through [:browser]
        # Mailbluster must be setup to send users here (see mail_bluster.ex)
        get "/unsubscribe/mailbluster",
            UserSettingsController,
            :unsubscribe_from_mailbluster

        # Mailbluster unsubscribers will end up here
        get "/unsubscribe/marketing",
            UserSettingsController,
            :mailbluster_unsubscribed_confirmation

        get "/unsubscribe/:code/:notification_subscription",
            UserSettingsController,
            :unsubscribe_from_notification_subscription

        put "/unsubscribe/:code/:notification_subscription",
            UserSettingsController,
            :toggle_notification_subscription
      end
    end
  end
end
