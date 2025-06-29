defmodule Mosslet.GroupMessages do
  @moduledoc """
  The GroupMessages context.
  """

  import Ecto.Query, warn: false
  alias Mosslet.Repo

  alias Mosslet.Groups.{Group, GroupMessage, GroupMessages}
  alias MossletWeb.Endpoint

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups do
    Repo.all(Group)
  end

  def get_message!(id) do
    Repo.get(GroupMessage, id)
  end

  def last_ten_messages_for(group_id) do
    GroupMessages.Query.for_group(group_id)
    |> Repo.all()
    |> Repo.preload(:sender)
  end

  def last_user_message_for_group(group_id, user_id) do
    GroupMessages.Query.last_user_message_for_group(group_id, user_id)
    |> Repo.one()
  end

  def delete_message(%GroupMessage{} = message) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        Repo.delete(message)
      end)

    return |> publish_message_deleted()
  end

  def change_message(%GroupMessage{} = message, attrs \\ %{}) do
    GroupMessage.changeset(message, attrs)
  end

  def create_message(attrs \\ %{}, opts \\ []) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        %GroupMessage{}
        |> GroupMessage.changeset(attrs, opts)
        |> Repo.insert()
      end)

    return |> publish_message_created()
  end

  def update_message(%GroupMessage{} = message, attrs) do
    {:ok, return} =
      Repo.transaction_on_primary(fn ->
        message
        |> GroupMessage.changeset(attrs)
        |> Repo.update()
      end)

    return |> publish_message_updated()
  end

  def preload_message_sender(message) do
    message
    |> Repo.preload(:sender)
  end

  def publish_message_created({:ok, message} = result) do
    Endpoint.broadcast("group:#{message.group_id}", "new_message", %{message: message})
    result
  end

  def publish_message_created(result), do: result

  def publish_message_deleted({:ok, message} = result) do
    Endpoint.broadcast("group:#{message.group_id}", "deleted_message", %{message: message})
    result
  end

  def publish_message_deleted(result), do: result

  def publish_message_updated({:ok, message} = result) do
    Endpoint.broadcast("group:#{message.group_id}", "updated_message", %{message: message})
    result
  end

  def publish_message_updated(result), do: result

  def get_previous_n_messages(date, group_id, n) do
    if is_nil(date) do
      []
    else
      GroupMessages.Query.previous_n(date, group_id, n)
      |> Repo.all()
      |> Repo.preload(:sender)
    end
  end
end
