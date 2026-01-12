defmodule Mosslet.Repo.Local.Migrations.FinalizeSubscriptionEncryption do
  use Ecto.Migration

  def up do
    if column_exists?(:billing_subscriptions, :encrypted_provider_subscription_id) do
      if column_exists?(:billing_subscriptions, :provider_subscription_id) do
        alter table(:billing_subscriptions) do
          remove :provider_subscription_id
          remove :provider_subscription_items
        end
      end

      rename table(:billing_subscriptions), :encrypted_provider_subscription_id,
        to: :provider_subscription_id

      rename table(:billing_subscriptions), :encrypted_provider_subscription_items,
        to: :provider_subscription_items
    end
  end

  def down do
    if column_exists?(:billing_subscriptions, :provider_subscription_id) do
      rename table(:billing_subscriptions), :provider_subscription_id,
        to: :encrypted_provider_subscription_id

      rename table(:billing_subscriptions), :provider_subscription_items,
        to: :encrypted_provider_subscription_items

      alter table(:billing_subscriptions) do
        add :provider_subscription_id, :string
        add :provider_subscription_items, {:array, :map}, default: []
      end
    end
  end

  defp column_exists?(table, column) do
    query = """
    SELECT column_name FROM information_schema.columns
    WHERE table_name = '#{table}' AND column_name = '#{column}'
    """

    case repo().query(query) do
      {:ok, %{num_rows: num}} when num > 0 -> true
      _ -> false
    end
  end
end
