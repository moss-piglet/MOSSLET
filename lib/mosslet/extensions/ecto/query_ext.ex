defmodule Mosslet.Extensions.Ecto.QueryExt do
  @moduledoc """
  Helpful query functions. Similar to the QueryBuilder lib, but for cases where you don't want to use QueryBuilder.
  """
  import Ecto.Query

  @doc """
  Limit a the number of results from a query. Can be compined with other queryables
  UserQuery.text_search("Matt") |> QueryExt.limit(query, 5)
  """
  def limit(query, limit) do
    from(x in query, limit: ^limit)
  end

  @doc """
  Preload associations.
  UserQuery.text_search("Matt") |> QueryExt.preload(:posts) |> Repo.all()
  """
  def preload(query, preloads) do
    from(x in query,
      preload: ^preloads
    )
  end

  @doc """
  Construct a where query on the fly. Only works when `use QueryBuilder` is added to the schema file
  eg QueryExt.where(Log, %{post_id: 1814, user_id: 24688, user_type: "user"}) |> Repo.all()
  """
  def where(query, params) do
    Enum.reduce(params, query, fn {key, value}, q ->
      QueryBuilder.where(q, {key, value})
    end)
  end

  @doc """
  order_by(query, [:name, :population])
  order_by(query, [asc: :name, desc_nulls_first: :population])
  """
  def order_by(query, order) do
    from(x in query, order_by: ^order)
  end

  @doc "Order by newest first"
  def order_newest_first(query) do
    from(x in query,
      order_by: [desc: x.inserted_at, desc: x.id]
    )
  end

  @doc "Order by oldest first"
  def order_oldest_first(query) do
    from(x in query,
      order_by: [asc: x.inserted_at, asc: x.id]
    )
  end
end
