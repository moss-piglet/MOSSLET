defmodule Mosslet.Billing.Customers.CustomerQuery do
  @moduledoc """
  Functions that take an ecto query, alter it, then return it.
  Can be used like lego to build up queries.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Billing.Customers.Customer

  @doc """
  Load the customer and preload the source of the customer (user or org).
  """
  def by_source(query \\ Customer, source, source_id) do
    from c in query,
      where: field(c, ^source_field(source)) == ^source_id,
      preload: ^source
  end

  defp source_field(:user), do: :user_id
  defp source_field(:org), do: :org_id
end
