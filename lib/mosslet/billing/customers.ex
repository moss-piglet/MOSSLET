defmodule Mosslet.Billing.Customers do
  @moduledoc false
  import Ecto.Query, warn: false

  alias Mosslet.Billing.Customers.Customer
  alias Mosslet.Billing.Customers.CustomerQuery
  alias Mosslet.Repo

  def entity do
    Mosslet.config(:billing_entity)
  end

  def get_customer_by(attrs) do
    Customer
    |> Repo.get_by(attrs)
    |> Repo.preload([:payment_intents, :subscriptions])
  end

  def get_customer_by_provider_customer_id!(id) do
    Repo.get_by!(Customer, provider_customer_id_hash: id)
  end

  def get_customer_by_source(source, source_id) do
    source
    |> CustomerQuery.by_source(source_id)
    |> Repo.one()
  end

  def create_customer_for_source(
        source,
        source_id,
        attrs \\ %{},
        current_user \\ nil,
        session_key \\ nil
      ) do
    attrs =
      case source do
        :user -> Map.put(attrs, :user_id, source_id)
        :org -> Map.put(attrs, :org_id, source_id)
      end

    create_customer_by_source(source, attrs, current_user, session_key)
  end

  def create_customer_by_source(source, attrs \\ %{}, current_user \\ nil, session_key \\ nil) do
    {:ok, customer} =
      if current_user && session_key do
        Repo.transaction_on_primary(fn ->
          %Customer{}
          |> Customer.changeset_by_source(source, attrs, current_user, session_key)
          |> Repo.insert!()
          |> Repo.preload([:user, :org])
        end)
      else
        Repo.transaction_on_primary(fn ->
          %Customer{}
          |> Customer.changeset_by_source(source, attrs)
          |> Repo.insert!()
          |> Repo.preload([:user, :org])
        end)
      end

    {:ok, customer}
  end

  def update_customer_for_source(
        source,
        source_id,
        attrs \\ %{},
        current_user \\ nil,
        session_key \\ nil
      ) do
    attrs =
      case source do
        :user -> Map.put(attrs, :user_id, source_id)
        :org -> Map.put(attrs, :org_id, source_id)
      end

    update_customer_by_source(source, attrs, current_user, session_key)
  end

  def update_customer_by_source(source, attrs \\ %{}, current_user \\ nil, session_key \\ nil) do
    {:ok, customer} =
      if current_user && session_key do
        Repo.transaction_on_primary(fn ->
          current_user.customer
          |> Customer.changeset_by_source(source, attrs, current_user, session_key)
          |> Repo.update!()
          |> Repo.preload([:user, :org])
        end)
      else
        Repo.transaction_on_primary(fn ->
          current_user.customer
          |> Customer.changeset_by_source(source, attrs)
          |> Repo.update!()
          |> Repo.preload([:user, :org])
        end)
      end

    {:ok, customer}
  end

  def delete_customer_by_provider_customer_id(provider_customer_id) do
    Repo.transaction_on_primary(fn ->
      case Repo.get_by(Customer, provider_customer_id_hash: provider_customer_id) do
        nil -> {:error, :not_found}
        customer -> Repo.delete(customer)
      end
    end)
  end
end
