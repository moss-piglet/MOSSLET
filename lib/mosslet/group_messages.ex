defmodule Mosslet.GroupMessages do
  @moduledoc """
  The GroupMessages context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.GroupMessages.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.GroupMessages.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.
  """

  alias Mosslet.Platform
  alias Mosslet.Groups.GroupMessage
  alias MossletWeb.Endpoint

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Module.concat([__MODULE__, Adapters, Native])
    else
      Mosslet.GroupMessages.Adapters.Web
    end
  end

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups do
    adapter().list_groups()
  end

  def get_message!(id) do
    adapter().get_message!(id)
  end

  def last_ten_messages_for(group_id) do
    adapter().last_ten_messages_for(group_id)
  end

  def last_user_message_for_group(group_id, user_id) do
    adapter().last_user_message_for_group(group_id, user_id)
  end

  def delete_message(%GroupMessage{} = message) do
    adapter().delete_message(message)
    |> publish_message_deleted()
  end

  def change_message(%GroupMessage{} = message, attrs \\ %{}) do
    GroupMessage.changeset(message, attrs)
  end

  def create_message(attrs \\ %{}, opts \\ []) do
    adapter().create_message(attrs, opts)
    |> publish_message_created()
  end

  def update_message(%GroupMessage{} = message, attrs) do
    adapter().update_message(message, attrs)
    |> publish_message_updated()
  end

  def preload_message_sender(message) do
    adapter().preload_message_sender(message)
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
    adapter().get_previous_n_messages(date, group_id, n)
  end

  def get_message_count_for_group(group_id) do
    adapter().get_message_count_for_group(group_id)
  end
end
