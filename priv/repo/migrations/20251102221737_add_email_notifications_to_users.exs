defmodule Mosslet.Repo.Local.Migrations.AddEmailNotificationsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_subscribed_to_email_notifications, :boolean, default: false, null: false
    end
  end
end
