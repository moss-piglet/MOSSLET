defmodule Mosslet.Repo.Local.Migrations.RenameNotificationSubscriptionFields do
  use Ecto.Migration

  def up do
    if column_exists?(:users, :is_subscribed_to_marketing_notifications) do
      rename table(:users), :is_subscribed_to_marketing_notifications, to: :calm_notifications
    end

    if column_exists?(:users, :is_subscribed_to_email_notifications) do
      rename table(:users), :is_subscribed_to_email_notifications, to: :email_notifications
    end
  end

  def down do
    if column_exists?(:users, :calm_notifications) do
      rename table(:users), :calm_notifications, to: :is_subscribed_to_marketing_notifications
    end

    if column_exists?(:users, :email_notifications) do
      rename table(:users), :email_notifications, to: :is_subscribed_to_email_notifications
    end
  end

  defp column_exists?(table, column) do
    query = """
    SELECT 1 FROM information_schema.columns
    WHERE table_name = '#{table}' AND column_name = '#{column}'
    """

    case repo().query(query) do
      {:ok, %{num_rows: n}} when n > 0 -> true
      _ -> false
    end
  end
end
