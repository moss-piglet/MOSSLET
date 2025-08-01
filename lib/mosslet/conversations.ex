defmodule Mosslet.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Mosslet.Repo

  alias Mosslet.Conversations.Conversation
  alias Mosslet.Messages.Message

  @doc """
  Returns the list of conversations.
  """
  def load_conversations(user) do
    from(c in Conversation, where: c.user_id == ^user.id, order_by: [desc: c.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single conversation.

  Raises `Ecto.NoResultsError` if the Conversation does not exist.

  ## Examples

      iex> get_conversation!(123, user)
      %Conversation{}

      iex> get_conversation!(456, user)
      ** (Ecto.NoResultsError)

  """
  def get_conversation!(id, user) do
    from(c in Conversation, where: c.id == ^id, where: c.user_id == ^user.id)
    |> Repo.one!()
  end

  def total_conversation_tokens(conversation, user) do
    from(m in Message,
      where: m.conversation_id == ^conversation.id,
      join: c in Conversation,
      on: c.user_id == ^user.id
    )
    |> Repo.aggregate(:sum, :tokens)
  end

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(%{field: value})
      {:ok, %Conversation{}}

      iex> create_conversation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(attrs \\ %{}) do
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

  @doc """
  Updates a conversation.

  ## Examples

      iex> update_conversation(conversation, %{field: new_value}, user)
      {:ok, %Conversation{}}

      iex> update_conversation(conversation, %{field: bad_value}, user)
      {:error, %Ecto.Changeset{}}

  """
  def update_conversation(%Conversation{} = conversation, attrs, user) do
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

  @doc """
  Deletes a conversation.

  ## Examples

      iex> delete_conversation(conversation, user)
      {:ok, %Conversation{}}

      iex> delete_conversation(conversation, user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_conversation(%Conversation{} = conversation, user) do
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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking conversation changes.

  ## Examples

      iex> change_conversation(conversation)
      %Ecto.Changeset{data: %Conversation{}}

  """
  def change_conversation(%Conversation{} = conversation, attrs \\ %{}) do
    Conversation.changeset(conversation, attrs)
  end
end
