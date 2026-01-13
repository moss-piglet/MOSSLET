defmodule Mosslet.Groups.GroupMessages.Query do
  @moduledoc false
  import Ecto.Query
  alias Mosslet.Groups.GroupMessage

  def base do
    GroupMessage
  end

  def for_group(query \\ base(), group_id) do
    query
    |> where([m], m.group_id == ^group_id)
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(10)
    |> subquery()
    |> order_by([m], {:asc, m.inserted_at})
  end

  def last_user_message_for_group(query \\ base(), group_id, sender_id) do
    query
    |> where([m], m.group_id == ^group_id)
    |> where([m], m.sender_id == ^sender_id)
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(1)
  end

  def preload_sender do
    base()
    |> join(:inner, [m], s in assoc(m, :sender))
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(10)
    |> preload([m, s], sender: s)
  end

  def previous_n(query \\ base(), date, group_id, n) do
    query
    |> where([m], m.group_id == ^group_id)
    |> where([m], m.inserted_at < ^date)
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(^n)
    |> subquery()
    |> order_by([m], {:asc, m.inserted_at})
  end

  def next_message_after(query \\ base(), message) do
    query
    |> where([m], m.group_id == ^message.group_id)
    |> where([m], m.inserted_at > ^message.inserted_at)
    |> order_by([m], {:asc, m.inserted_at})
    |> limit(1)
  end

  def previous_message_before(query \\ base(), message) do
    query
    |> where([m], m.group_id == ^message.group_id)
    |> where([m], m.inserted_at < ^message.inserted_at)
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(1)
  end

  def last_message_for_group(query \\ base(), group_id) do
    query
    |> where([m], m.group_id == ^group_id)
    |> order_by([m], {:desc, m.inserted_at})
    |> limit(1)
  end
end
