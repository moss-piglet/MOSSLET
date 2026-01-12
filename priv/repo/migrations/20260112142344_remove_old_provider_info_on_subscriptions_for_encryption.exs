defmodule Mosslet.Repo.Local.Migrations.RemoveOldProviderInfoOnSubscriptionsForEncryption do
  use Ecto.Migration

  @doc """
  IMPORTANT: Only run this migration AFTER running the backfill script in production:

      alias Mosslet.Billing.Subscriptions.Subscription
      alias Mosslet.Repo

      Subscription
      |> Repo.all()
      |> Enum.each(fn sub ->
        sub
        |> Ecto.Changeset.change(%{
          encrypted_provider_subscription_id: sub.provider_subscription_id,
          provider_subscription_id_hash: sub.provider_subscription_id,
          encrypted_provider_subscription_items: sub.provider_subscription_items
        })
        |> Repo.update!()
      end)
  """
  def change do
    # Intentionally left empty until data migration is complete.
    # Once backfill is done, uncomment the following:
    #
    # alter table(:billing_subscriptions) do
    #   remove :provider_subscription_id, :string
    #   remove :provider_subscription_items, {:array, :map}
    # end
    #
    # rename table(:billing_subscriptions), :encrypted_provider_subscription_id,
    #   to: :provider_subscription_id
    #
    # rename table(:billing_subscriptions), :encrypted_provider_subscription_items,
    #   to: :provider_subscription_items
  end
end
