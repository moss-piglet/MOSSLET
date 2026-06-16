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

  @doc """
  Returns the customer's PAID subscription (status `active` only — a `trialing`
  sub is NOT yet paid), or `nil`.

  Distinct from `get_active_subscription_by_customer_id/1`, which also counts a
  trial as "active" for coverage/access. Used by entitlement gates that must
  require an actually-converted, paying plan (e.g. unlocking a SECOND business —
  Task #214/#218: a business on a free trial does not yet entitle creating
  another).
  """
  def get_paid_subscription_by_customer_id(customer_id) do
    Subscription
    |> by_customer_id(customer_id)
    |> by_status(["active"])
    |> order_by_period_desc()
    |> Repo.first()
  end

  @doc """
  Lists ALL subscriptions for a billing customer (most recent period first).

  Unlike `get_active_subscription_by_customer_id/1`, this returns lapsed/canceled
  rows too — used by the org name-reclaim engine (Task #236) to distinguish an
  org that NEVER had a subscription (inert) from one whose sub has lapsed.
  """
  def list_subscriptions_by_customer_id(customer_id) do
    Subscription
    |> by_customer_id(customer_id)
    |> order_by_period_desc()
    |> Repo.all()
  end

  def get_payment_required_subscription_by_customer_id(customer_id) do
    Subscription
    |> by_customer_id(customer_id)
    |> by_status(["past_due", "incomplete"])
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
