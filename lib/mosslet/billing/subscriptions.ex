defmodule Mosslet.Billing.Subscriptions do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Mosslet.Billing.Subscriptions.Subscription
  alias Mosslet.Repo

  def list_subscriptions_query do
    from(s in Subscription, preload: [customer: [:user, :org]])
  end

  def get_subscription!(id), do: Repo.get!(Subscription, id)
  def get_subscription_by(attrs), do: Repo.get_by(Subscription, attrs)

  def get_subscription_by_provider_subscription_id(id) do
    Subscription
    |> Repo.get_by(provider_subscription_id_hash: id)
    |> Repo.preload(:customer)
  end

  def get_active_subscription_by_customer_id(customer_id) do
    Subscription
    |> by_customer_id(customer_id)
    |> by_status(["active", "trialing"])
    |> order_by_period_desc()
    |> Repo.first()
  end

  def active_count(customer_id) do
    Subscription
    |> by_customer_id(customer_id)
    |> by_status(["active", "trialing"])
    |> Repo.count()
  end

  def create_subscription(attrs \\ %{}) do
    Repo.transaction_on_primary(fn ->
      %Subscription{}
      |> Subscription.changeset(attrs)
      |> Repo.insert()
    end)
    |> handle_transaction_result()
  end

  def cancel_subscription(%Subscription{} = subscription) do
    update_subscription(subscription, %{
      cancel_at: subscription.current_period_end_at
    })
  end

  def cancel_subscription_immediately(%Subscription{} = subscription) do
    update_subscription(subscription, %{
      status: "canceled",
      canceled_at: NaiveDateTime.utc_now()
    })
  end

  def resume_subscription(%Subscription{} = subscription) do
    update_subscription(subscription, %{
      cancel_at: nil
    })
  end

  def update_subscription(%Subscription{} = subscription, attrs) do
    Repo.transaction_on_primary(fn ->
      subscription
      |> Subscription.changeset(attrs)
      |> Repo.update()
    end)
    |> handle_transaction_result()
  end

  defp handle_transaction_result({:ok, {:ok, result}}), do: {:ok, result}
  defp handle_transaction_result({:ok, {:error, changeset}}), do: {:error, changeset}
  defp handle_transaction_result({:error, _reason} = error), do: error

  defp by_customer_id(query, customer_id) do
    from s in query, where: s.billing_customer_id == ^customer_id
  end

  defp by_status(query, status) when is_list(status) do
    from s in query, where: s.status in ^status
  end

  defp order_by_period_desc(query) do
    from s in query, order_by: [desc: s.current_period_start]
  end
end
