defmodule Mosslet.Conversations do
  @moduledoc """
  The Conversations context.

  This context uses platform-aware adapters for database operations:
  - Web (Fly.io): Direct Postgres access via `Mosslet.Conversations.Adapters.Web`
  - Native (Desktop/Mobile): API + SQLite cache via `Mosslet.Conversations.Adapters.Native`

  The adapter is selected at runtime based on `Mosslet.Platform.native?()`.

  Note: Conversations is a legacy feature being phased out. This adapter
  implementation provides platform support during the transition period.
  """

  alias Mosslet.Conversations.Conversation
  alias Mosslet.Platform

  require Logger

  @doc """
  Returns the appropriate adapter module based on the current platform.
  """
  def adapter do
    if Platform.native?() do
      Mosslet.Conversations.Adapters.Native
    else
      Mosslet.Conversations.Adapters.Web
    end
  end

  @doc """
  Returns the list of conversations.
  """
  def load_conversations(user), do: adapter().load_conversations(user)

  @doc """
  Gets a single conversation.

  Raises `Ecto.NoResultsError` if the Conversation does not exist.

  ## Examples

      iex> get_conversation!(123, user)
      %Conversation{}

      iex> get_conversation!(456, user)
      ** (Ecto.NoResultsError)

  """
  def get_conversation!(id, user), do: adapter().get_conversation!(id, user)

  def total_conversation_tokens(conversation, user) do
    adapter().total_conversation_tokens(conversation, user)
  end

  @doc """
  Creates a conversation.

  ## Examples

      iex> create_conversation(%{field: value})
      {:ok, %Conversation{}}

      iex> create_conversation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_conversation(attrs \\ %{}), do: adapter().create_conversation(attrs)

  @doc """
  Updates a conversation.

  ## Examples

      iex> update_conversation(conversation, %{field: new_value}, user)
      {:ok, %Conversation{}}

      iex> update_conversation(conversation, %{field: bad_value}, user)
      {:error, %Ecto.Changeset{}}

  """
  def update_conversation(%Conversation{} = conversation, attrs, user) do
    adapter().update_conversation(conversation, attrs, user)
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
    adapter().delete_conversation(conversation, user)
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
