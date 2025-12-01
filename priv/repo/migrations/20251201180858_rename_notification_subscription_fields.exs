defmodule Mosslet.Repo.Local.Migrations.RenameNotificationSubscriptionFields do
  use Ecto.Migration

  def up do
    rename table(:users), :is_subscribed_to_marketing_notifications, to: :calm_notifications
    rename table(:users), :is_subscribed_to_email_notifications, to: :email_notifications
  end

  def down do
    rename table(:users), :calm_notifications, to: :is_subscribed_to_marketing_notifications
    rename table(:users), :email_notifications, to: :is_subscribed_to_email_notifications
  end
end
