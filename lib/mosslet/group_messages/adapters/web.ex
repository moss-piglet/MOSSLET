defmodule Mosslet.GroupMessages.Adapters.Web do
  @moduledoc """
  Web adapter for group message operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.GroupMessages.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Groups.{Group, GroupMessage, GroupMessages}

  @impl true
  def list_groups do
    Repo.all(Group)
  end

  @impl true
  def get_message!(id) do
    Repo.get(GroupMessage, id)
  end

  @impl true
  def last_ten_messages_for(group_id) do
    GroupMessages.Query.for_group(group_id)
    |> Repo.all()
    |> Repo.preload(:sender)
  end

  @impl true
  def last_user_message_for_group(group_id, user_id) do
    GroupMessages.Query.last_user_message_for_group(group_id, user_id)
    |> Repo.one()
  end

  @impl true
  def create_message(attrs, opts) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        %GroupMessage{}
        |> GroupMessage.changeset(attrs, opts)
        |> Repo.insert()
      end)

    return
  end

  @impl true
  def update_message(message, attrs) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        message
        |> GroupMessage.changeset(attrs)
        |> Repo.update()
      end)

    return
  end

  @impl true
  def delete_message(message) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        Repo.delete(message)
      end)

    return
  end

  @impl true
  def preload_message_sender(message) do
    message
    |> Repo.preload(:sender)
  end

  @impl true
  def get_previous_n_messages(date, group_id, n) do
    if is_nil(date) do
      []
    else
      GroupMessages.Query.previous_n(date, group_id, n)
      |> Repo.all()
      |> Repo.preload(:sender)
    end
  end

  @impl true
  def get_message_count_for_group(group_id) do
    from(m in GroupMessage, where: m.group_id == ^group_id)
    |> Repo.aggregate(:count, :id)
  end
end
