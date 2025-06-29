defmodule Mosslet.Billing.PaymentIntents do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Mosslet.Billing.PaymentIntents.PaymentIntent
  alias Mosslet.Repo

  def list_payment_intent_intents_query do
    from(s in PaymentIntent, preload: [customer: [:user, :org]])
  end

  def get_payment_intent!(id), do: Repo.get!(PaymentIntent, id)
  def get_payment_intent_by(attrs), do: Repo.get_by(PaymentIntent, attrs)

  def get_all_payment_intents_by(attrs) do
    PaymentIntent
    |> where([p], p.status == ^attrs[:status])
    |> where([p], p.billing_customer_id == ^attrs[:billing_customer_id])
    |> Repo.all()
  end

  def get_payment_intent_by_provider_payment_intent_id(id) do
    PaymentIntent
    |> Repo.get_by(provider_payment_intent_id: id)
    |> Repo.preload(:customer)
  end

  def get_active_payment_intent_by_customer_id(customer_id) do
    PaymentIntent
    |> by_customer_id(customer_id)
    |> by_status(["succeeded"])
    |> order_by_period_desc()
    |> Repo.first()
  end

  def active_count(customer_id) do
    PaymentIntent
    |> by_customer_id(customer_id)
    |> Repo.count()
  end

  def create_payment_intent!(attrs \\ %{}, current_user \\ nil, session_key \\ nil) do
    payment_intent =
      Repo.transaction_on_primary(fn ->
        %PaymentIntent{}
        |> PaymentIntent.changeset(attrs, current_user, session_key)
        |> Repo.insert!()
      end)

    case payment_intent do
      {:ok, {:ok, payment_intent}} -> {:ok, payment_intent}
      {:ok, payment_intent} -> {:ok, payment_intent}
      {:error, {:error, error}} -> {:error, error}
      {:error, error} -> {:error, error}
    end
  end

  def update_payment_intent(
        %PaymentIntent{} = payment_intent,
        attrs,
        current_user \\ nil,
        session_key \\ nil
      ) do
    payment_intent =
      Repo.transaction_on_primary(fn ->
        payment_intent
        |> PaymentIntent.changeset(attrs, current_user, session_key)
        |> Repo.update()
      end)

    case payment_intent do
      {:ok, {:ok, payment_intent}} -> {:ok, payment_intent}
      {:ok, payment_intent} -> {:ok, payment_intent}
      {:error, {:error, error}} -> {:error, error}
      {:error, error} -> {:error, error}
    end
  end

  defp by_customer_id(query, customer_id) do
    from s in query, where: s.billing_customer_id == ^customer_id
  end

  defp by_status(query, status) when is_list(status) do
    from s in query, where: s.status in ^status
  end

  defp order_by_period_desc(query) do
    from s in query, order_by: [desc: s.provider_created_at]
  end
end
