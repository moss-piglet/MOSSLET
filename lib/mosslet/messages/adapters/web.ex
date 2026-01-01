defmodule Mosslet.Messages.Adapters.Web do
  @moduledoc """
  Web adapter for message operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Messages.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Messages.Message

  @impl true
  def list_messages(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [asc: m.inserted_at]
    )
    |> Repo.all()
  end

  @impl true
  def get_message!(conversation_id, id) do
    from(m in Message, where: m.conversation_id == ^conversation_id, where: m.id == ^id)
    |> Repo.one!()
  end

  @impl true
  def get_last_message!(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [desc: m.id],
      limit: 1
    )
    |> Repo.one!()
  end

  @impl true
  def create_message(conversation_id, attrs) do
    case Repo.transaction_on_primary(fn ->
           conversation_id
           |> Message.create_changeset(attrs)
           |> Repo.insert()
         end) do
      {:ok, {:ok, message}} ->
        {:ok, message}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_message(message, attrs) do
    case Repo.transaction_on_primary(fn ->
           message
           |> Message.changeset(attrs)
           |> Repo.update()
         end) do
      {:ok, {:ok, message}} ->
        {:ok, message}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def delete_message(message) do
    case Repo.transaction_on_primary(fn ->
           Repo.delete(message)
         end) do
      {:ok, {:ok, message}} ->
        {:ok, message}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end
end
