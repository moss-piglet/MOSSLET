defmodule Mosslet.Logs.LogQuery do
  @moduledoc """
  Functions that take an ecto query, alter it, then return it.
  Can be used like lego to build up queries.
  """
  import Ecto.Query, warn: false

  alias Mosslet.Logs.Log

  def join_users(query \\ Log) do
    from log in query,
      join: u in assoc(log, :user),
      as: :user
  end

  def by_action(query \\ Log, action)
  def by_action(query, nil), do: query

  def by_action(query, action) do
    from l in query,
      where: l.action == ^action
  end

  def by_user(query \\ Log, user_id)
  def by_user(query, nil), do: query

  def by_user(query, user_id) do
    from l in query,
      where: l.user_id == ^user_id or l.target_user_id == ^user_id
  end

  @spec preload(any, atom | maybe_improper_list) :: Ecto.Query.t()
  def preload(query \\ Log, preloads) do
    from l in query,
      preload: ^preloads
  end

  def limit(query \\ Log, limit) do
    from l in query,
      limit: ^limit
  end

  def order_by(query \\ Log, default \\ :newest)

  def order_by(query, :newest) do
    from l in query, order_by: [desc: l.inserted_at]
  end

  def order_by(query, _), do: query
end
