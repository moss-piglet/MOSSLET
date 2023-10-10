defmodule Metamorphic.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias Metamorphic.Repo

  alias Metamorphic.Conversations.Conversation

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

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(%{field: value})
      {:ok, %Conversation{}}

      iex> create_conversation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(attrs \\ %{}) do
    {:ok, {:ok, conversation}} =
      Repo.transaction_on_primary(fn ->
        %Conversation{}
        |> Conversation.changeset(attrs)
        |> Repo.insert()
      end)

    {:ok, conversation}
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
      {:ok, {:ok, conversation}} =
        Repo.transaction_on_primary(fn ->
          conversation
          |> Conversation.changeset(attrs)
          |> Repo.update()
        end)

      {:ok, conversation}
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
      {:ok, {:ok, conversation}} =
        Repo.transaction_on_primary(fn ->
          Repo.delete(conversation)
        end)

      {:ok, conversation}
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
