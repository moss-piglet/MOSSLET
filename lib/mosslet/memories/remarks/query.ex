defmodule Mosslet.Memories.Remarks.Query do
  @moduledoc false
  import Ecto.Query
  alias Mosslet.Memories.Remark

  def base do
    Remark
  end

  def for_memory(query \\ base(), memory_id) do
    query
    |> where([r], r.memory_id == ^memory_id)
    |> order_by([r], {:desc, r.inserted_at})
    |> limit(10)
    |> subquery()
    |> order_by([r], {:asc, r.inserted_at})
    |> preload([:user, :memory])
  end

  def last_user_remark_for_memory(query \\ base(), memory_id, user_id) do
    query
    |> where([r], r.memory_id == ^memory_id)
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], {:desc, r.inserted_at})
    |> limit(1)
    |> preload([:user, :memory])
  end

  def preload_user do
    base()
    |> join(:inner, [r], s in assoc(r, :user))
    |> order_by([r], {:desc, r.inserted_at})
    |> limit(10)
    |> preload([r, s], user: s)
  end

  def previous_n(query \\ base(), date, memory_id, n) do
    query
    |> where([r], r.memory_id == ^memory_id)
    |> where([r], r.inserted_at < ^date)
    |> order_by([r], {:desc, r.inserted_at})
    |> limit(^n)
    |> subquery()
    |> order_by([r], {:asc, r.inserted_at})
    |> preload([:user, :memory])
  end
end
