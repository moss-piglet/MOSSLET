defmodule Mosslet.Conversations.Adapters.Web do
  @moduledoc """
  Web adapter for conversation operations.

  This adapter uses direct Postgres access via `Mosslet.Repo` and
  `Fly.Repo.transaction_on_primary/1` for writes.

  This is the default adapter for web deployments on Fly.io.
  """

  @behaviour Mosslet.Conversations.Adapter

  import Ecto.Query, warn: false

  alias Mosslet.Repo
  alias Mosslet.Conversations.Conversation
  alias Mosslet.Messages.Message

  @impl true
  def load_conversations(user) do
    from(c in Conversation, where: c.user_id == ^user.id, order_by: [desc: c.inserted_at])
    |> Repo.all()
  end

  @impl true
  def get_conversation!(id, user) do
    from(c in Conversation, where: c.id == ^id, where: c.user_id == ^user.id)
    |> Repo.one!()
  end

  @impl true
  def total_conversation_tokens(conversation, user) do
    from(m in Message,
      where: m.conversation_id == ^conversation.id,
      join: c in Conversation,
      on: c.user_id == ^user.id
    )
    |> Repo.aggregate(:sum, :tokens)
  end

  @impl true
  def create_conversation(attrs) do
    case Repo.transaction_on_primary(fn ->
           %Conversation{}
           |> Conversation.changeset(attrs)
           |> Repo.insert()
         end) do
      {:ok, {:ok, conversation}} ->
        {:ok, conversation}

      {:ok, {:error, changeset}} ->
        {:error, changeset}
    end
  end

  @impl true
  def update_conversation(conversation, attrs, user) do
    if conversation.user_id == user.id do
      case Repo.transaction_on_primary(fn ->
             conversation
             |> Conversation.changeset(attrs)
             |> Repo.update()
           end) do
        {:ok, {:ok, conversation}} ->
          {:ok, conversation}

        {:ok, {:error, changeset}} ->
          {:error, changeset}
      end
    end
  end

  @impl true
  def delete_conversation(conversation, user) do
    if conversation.user_id == user.id do
      case Repo.transaction_on_primary(fn ->
             Repo.delete(conversation)
           end) do
        {:ok, {:ok, conversation}} ->
          {:ok, conversation}

        {:ok, {:error, changeset}} ->
          {:error, changeset}
      end
    end
  end
end
